//! The class FlashArt that Godot uses: one SWF file of the user, whose frames
//! it draws on request. Frames can also be drawn ahead on other threads.

use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Condvar, Mutex, Weak};

use godot::classes::image::Format;
use godot::classes::{Image, ProjectSettings};
use godot::prelude::*;

use crate::Art;

struct FlashArtExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FlashArtExtension {}

/// Threads that draw frames ahead for all FlashArt objects.
const WORKERS: usize = 3;

/// The frames that all FlashArt objects drew ahead and that the game did not
/// take yet can use this much memory. Above it, the frames that were drawn
/// first are removed; render() draws such a frame again when the game asks for it.
const AHEAD_LIMIT: usize = 128 << 20;

/// Character id, frame, and the bits of the scale (f32::to_bits).
type Key = (u16, usize, u32);

/// A frame that was drawn ahead: the pixels (see draw), the size, the blend
/// modes of its layers, and its number in the order of all frames drawn ahead.
struct Drawn {
    pixels: Vec<u8>,
    width: u32,
    height: u32,
    blends: Vec<u8>,
    number: u64,
}

/// The codes of the blend modes of the layers of a map frame, as
/// sprites/blend_layers.gdshader reads them.
fn blend_code(mode: swf::BlendMode) -> u8 {
    use swf::BlendMode as B;
    match mode {
        B::Multiply => 1,
        B::Screen => 2,
        B::Lighten => 3,
        B::Darken => 4,
        B::Difference => 5,
        B::Add => 6,
        B::Overlay => 7,
        B::HardLight => 8,
        _ => 0,
    }
}

/// Frames that wait to be drawn ahead, and the frames that are ready.
#[derive(Default)]
struct Ahead {
    queue: Vec<Key>,
    queued: HashSet<Key>,
    ready: HashMap<Key, Drawn>,
    stopped: bool,
}

/// The frames drawn ahead by all FlashArt objects, first drawn first, and the
/// bytes of those that are still ready. An entry whose frame was taken stays
/// until it comes to the front. Lock order: ORDER before Shared::ahead, never the opposite.
struct Order {
    list: VecDeque<(Weak<Shared>, Key, u64)>,
    bytes: usize,
}

static ORDER: Mutex<Order> = Mutex::new(Order { list: VecDeque::new(), bytes: 0 });
static NUMBER: AtomicU64 = AtomicU64::new(0);

struct Shared {
    art: Art,
    /// The frames are for the map: see Art::render_layers().
    on_map: bool,
    /// Character id -> the scale at which its parent shows it (set_parent_scale).
    parent_scales: Mutex<HashMap<u16, f32>>,
    ahead: Mutex<Ahead>,
    wake: Condvar,
}

/// The art of one SWF file. FlashArt.open() loads it.
#[derive(GodotClass)]
#[class(base = RefCounted, no_init)]
pub struct FlashArt {
    shared: Arc<Shared>,
    workers: bool,
    base: Base<RefCounted>,
}

#[godot_api]
impl FlashArt {
    /// Loads a SWF file for the windows. Returns null and reports an error when the file cannot be read.
    #[func]
    fn open(path: GString) -> Option<Gd<FlashArt>> {
        Self::load(path, false)
    }

    /// Loads a SWF file for graphics on the map. A frame whose parts mix with
    /// the map behind the graphic is an image of layers: see render().
    #[func]
    fn open_map(path: GString) -> Option<Gd<FlashArt>> {
        Self::load(path, true)
    }

    fn load(path: GString, on_map: bool) -> Option<Gd<FlashArt>> {
        let global = ProjectSettings::singleton().globalize_path(&path).to_string();
        let art = match std::fs::read(&global).map_err(|e| e.to_string()).and_then(|data| Art::load(&data)) {
            Ok(art) => art,
            Err(e) => {
                godot_error!("Cannot read the art in '{}': {}", path, e);
                return None;
            }
        };
        let shared = Arc::new(Shared { art, on_map, parent_scales: Mutex::new(HashMap::new()), ahead: Mutex::new(Ahead::default()), wake: Condvar::new() });
        Some(Gd::from_init_fn(|base| FlashArt { shared, workers: false, base }))
    }

    /// The character id of an exported symbol, or -1.
    #[func]
    fn symbol(&self, name: GString) -> i64 {
        self.shared.art.symbol(&name.to_string()).map_or(-1, i64::from)
    }

    /// The number of frames of a sprite; 1 for a shape, 0 for an unknown id.
    #[func]
    fn frame_count(&self, id: i64) -> i64 {
        self.shared.art.frame_count(id as u16) as i64
    }

    /// The place of the images of a character: the top-left corner relative
    /// to its registration point, and the size, in pixels. Empty when it draws nothing.
    #[func]
    fn canvas(&self, id: i64) -> Rect2 {
        match self.shared.art.canvas(id as u16) {
            Some(c) => Rect2::new(Vector2::new(c.x, c.y), Vector2::new(c.width as f32, c.height as f32)),
            None => Rect2::default(),
        }
    }

    /// The bounds of each frame of a sprite in pixels, as Flash reports them,
    /// relative to the registration point. An empty Rect2 for a frame that draws nothing.
    #[func]
    fn frame_rects(&self, id: i64) -> Array<Rect2> {
        self.shared
            .art
            .frame_rects(id as u16)
            .iter()
            .map(|r| r.map_or(Rect2::default(), |r| Rect2::new(Vector2::new(r.left(), r.top()) / 20.0, Vector2::new(r.width(), r.height()) / 20.0)))
            .collect()
    }

    /// For each frame of a sprite, the point in pixels where its shots start (Vector2), or null.
    #[func]
    fn shot_points(&self, id: i64) -> VarArray {
        self.shared.art.shot_points(id as u16).iter().map(|p| p.map_or(Variant::nil(), |p| (Vector2::new(p.x, p.y) / 20.0).to_variant())).collect()
    }

    /// For each frame of a sprite, its clip, or null: a nested sprite with
    /// more frames that the frame shows alone. A clip is [sprite id, Transform2D in pixels].
    #[func]
    fn frame_clips(&self, id: i64) -> VarArray {
        self.shared
            .art
            .frame_clips(id as u16)
            .iter()
            .map(|c| match c {
                Some(c) => {
                    let m = c.matrix;
                    let transform = Transform2D::from_cols(Vector2::new(m.sx, m.ky), Vector2::new(m.kx, m.sy), Vector2::new(m.tx, m.ty) / 20.0);
                    varray![c.id as i64, transform].to_variant()
                }
                None => Variant::nil(),
            })
            .collect()
    }

    /// The part of the canvas that a frame covers, in pixels. Empty when the frame draws nothing.
    #[func]
    fn frame_area(&self, id: i64, frame: i64) -> Rect2i {
        let art = &self.shared.art;
        match art.canvas(id as u16).and_then(|c| art.frame_area(id as u16, frame.max(0) as usize, c)) {
            Some((x, y, w, h)) => Rect2i::new(Vector2i::new(x as i32, y as i32), Vector2i::new(w as i32, h as i32)),
            None => Rect2i::default(),
        }
    }

    /// Draws frame (from 0) of a character at a scale on an image of the
    /// part of its canvas that the frame covers (see frame_area), or returns
    /// the image that the threads drew ahead. The image has the size of the
    /// area times the scale, rounded up. Null when the frame draws nothing.
    ///
    /// For the map (open_map), a frame with parts that mix with the map has
    /// more than one layer (Art::render_layers). Then the image has the layers
    /// one below the other, all of the same size: first the normal image, then
    /// the layers that mix with the map. Its meta "blend_modes" is a
    /// PackedByteArray with the blend mode of each layer (see blend_code).
    #[func]
    fn render(&self, id: i64, frame: i64, scale: f32) -> Option<Gd<Image>> {
        let key = key(id, frame, scale);
        let drawn = match take(&self.shared, key) {
            Some(drawn) => drawn,
            None => draw(&self.shared, key)?,
        };
        image(drawn)
    }

    /// The image of a frame that the threads drew ahead at this scale, or
    /// null when it is not ready. It does not wait and does not draw.
    #[func]
    fn take_ahead(&self, id: i64, frame: i64, scale: f32) -> Option<Gd<Image>> {
        image(take(&self.shared, key(id, frame, scale))?)
    }

    /// True while a frame at this scale waits to be drawn ahead, is drawn, or is ready to take.
    #[func]
    fn is_ahead(&self, id: i64, frame: i64, scale: f32) -> bool {
        let key = key(id, frame, scale);
        let ahead = self.shared.ahead.lock().unwrap();
        ahead.queued.contains(&key) || ahead.ready.contains_key(&key)
    }

    /// Draws the state (0 up, 1 over, 2 down) of a button at a scale on an
    /// image of its canvas, which covers all its states. The image has the
    /// size of the canvas times the scale, rounded up. Null when the id is not a button.
    #[func]
    fn render_button(&self, id: i64, state: i64, scale: f32) -> Option<Gd<Image>> {
        let art = &self.shared.art;
        let canvas = art.canvas(id as u16)?;
        let pixmap = art.render_button(id as u16, state.clamp(0, 2) as usize, canvas, scale)?;
        let (width, height) = (pixmap.width(), pixmap.height());
        Image::create_from_data(width as i32, height as i32, false, Format::RGBA8, &PackedByteArray::from(straight(pixmap.take(), width as usize)))
    }

    /// Sets the scale at which the parent of a character shows it, for a clip
    /// that the game draws by itself: the filters of the clip then have the
    /// size of the stage, as in the parent (Art::render_layers). Call it before
    /// the first frame of the character is drawn.
    #[func]
    fn set_parent_scale(&self, id: i64, scale: f32) {
        if scale > 0.0 {
            self.shared.parent_scales.lock().unwrap().insert(id as u16, scale);
        }
    }

    /// A font of the file as the bytes of a TrueType file, for FontFile.data.
    /// Empty when the id is not a font.
    #[func]
    fn font_data(&self, id: i64) -> PackedByteArray {
        PackedByteArray::from(self.shared.art.font_ttf(id as u16).unwrap_or_default())
    }

    /// Starts to draw these frames of a character at a scale on other threads,
    /// so that render() later only takes them. The frames that wait at
    /// another scale are not drawn: the game uses one scale at a time.
    #[func]
    fn draw_ahead(&mut self, id: i64, frames: PackedInt32Array, scale: f32) {
        if !self.workers {
            self.workers = true;
            for _ in 0..WORKERS {
                let shared = self.shared.clone();
                std::thread::spawn(move || work(shared));
            }
        }
        let mut ahead = self.shared.ahead.lock().unwrap();
        let bits = scale.to_bits();
        if ahead.queue.iter().any(|k| k.2 != bits) {
            let Ahead { queue, queued, .. } = &mut *ahead;
            queue.retain(|k| k.2 == bits || !queued.remove(k));
        }
        for frame in frames.as_slice() {
            let key = key(id, *frame as i64, scale);
            if !ahead.ready.contains_key(&key) && ahead.queued.insert(key) {
                ahead.queue.push(key);
            }
        }
        // The frames asked last play first.
        ahead.queue.sort_by_key(|k| std::cmp::Reverse(k.1));
        drop(ahead);
        self.shared.wake.notify_all();
    }
}

impl Drop for FlashArt {
    fn drop(&mut self) {
        let ready = {
            let mut ahead = self.shared.ahead.lock().unwrap();
            ahead.stopped = true;
            std::mem::take(&mut ahead.ready)
        };
        self.shared.wake.notify_all();
        ORDER.lock().unwrap().bytes -= ready.values().map(|d| d.pixels.len()).sum::<usize>();
    }
}

fn key(id: i64, frame: i64, scale: f32) -> Key {
    (id as u16, frame.max(0) as usize, scale.to_bits())
}

/// Removes a frame from the frames drawn ahead.
fn take(shared: &Shared, key: Key) -> Option<Drawn> {
    let drawn = shared.ahead.lock().unwrap().ready.remove(&key)?;
    ORDER.lock().unwrap().bytes -= drawn.pixels.len();
    Some(drawn)
}

fn image(drawn: Drawn) -> Option<Gd<Image>> {
    let mut image = Image::create_from_data(drawn.width as i32, drawn.height as i32, false, Format::RGBA8, &PackedByteArray::from(drawn.pixels))?;
    if drawn.blends != [0] {
        image.set_meta("blend_modes", &PackedByteArray::from(drawn.blends).to_variant());
    }
    Some(image)
}

/// Adds a frame that a thread drew ahead, and removes the frames drawn first
/// while all frames drawn ahead use more than AHEAD_LIMIT.
fn keep(shared: &Arc<Shared>, key: Key, mut drawn: Drawn) {
    drawn.number = NUMBER.fetch_add(1, Ordering::Relaxed);
    let (number, bytes) = (drawn.number, drawn.pixels.len());
    let mut order = ORDER.lock().unwrap();
    {
        let mut ahead = shared.ahead.lock().unwrap();
        ahead.queued.remove(&key);
        // FlashArt::drop counted the ready frames already.
        if ahead.stopped {
            return;
        }
        ahead.ready.insert(key, drawn);
    }
    order.list.push_back((Arc::downgrade(shared), key, number));
    order.bytes += bytes;
    while let Some((art, key, number)) = order.list.front().cloned() {
        let mut removed = None;
        let live = art.upgrade().is_some_and(|art| {
            let mut ahead = art.ahead.lock().unwrap();
            let live = ahead.ready.get(&key).is_some_and(|d| d.number == number);
            if live && order.bytes > AHEAD_LIMIT {
                removed = ahead.ready.remove(&key);
            }
            live
        });
        if live && removed.is_none() {
            break;
        }
        order.list.pop_front();
        if let Some(d) = removed {
            order.bytes -= d.pixels.len();
        }
    }
}

fn work(shared: Arc<Shared>) {
    loop {
        let key = {
            let mut ahead = shared.ahead.lock().unwrap();
            loop {
                if ahead.stopped {
                    return;
                }
                if let Some(key) = ahead.queue.pop() {
                    break key;
                }
                ahead = shared.wake.wait(ahead).unwrap();
            }
        };
        match draw(&shared, key) {
            Some(drawn) => keep(&shared, key, drawn),
            None => {
                shared.ahead.lock().unwrap().queued.remove(&key);
            }
        }
    }
}

/// The pixels of the area of a frame at the scale, not premultiplied, as
/// Godot images keep them.
fn draw(shared: &Shared, (id, frame, scale): Key) -> Option<Drawn> {
    let art = &shared.art;
    let canvas = art.canvas(id)?;
    let area = art.frame_area(id, frame, canvas)?;
    let scale = f32::from_bits(scale);
    if !shared.on_map {
        let pixmap = art.render_area(id, frame, canvas, area, scale)?;
        let (width, height) = (pixmap.width(), pixmap.height());
        return Some(Drawn { width, height, pixels: straight(pixmap.take(), width as usize), blends: vec![0], number: 0 });
    }
    let parent_scale = shared.parent_scales.lock().unwrap().get(&id).copied().unwrap_or(1.0);
    let mut layers = art.render_layers(id, frame, canvas, area, scale, parent_scale)?;
    // The normal image first: a node without the shader of the layers shows only it.
    layers.rotate_right(1);
    let (width, height) = (layers[0].pixels.width(), layers[0].pixels.height());
    let blends: Vec<u8> = layers.iter().map(|l| blend_code(l.blend)).collect();
    let count = blends.len() as u32;
    let mut pixels = Vec::with_capacity((width * height * 4 * count) as usize);
    for layer in layers {
        pixels.extend(straight(layer.pixels.take(), width as usize));
    }
    Some(Drawn { width, height: height * count, pixels, blends, number: 0 })
}

/// Premultiplied pixels made straight, as Godot images keep them.
///
/// A transparent pixel next to a visible one also gets the color of that
/// neighbour. Godot filters straight pixels: where it draws a frame between
/// pixels or at another size, it mixes each edge pixel with its transparent
/// neighbours, and with a black neighbour the edge gets dark. Flash draws
/// the shapes themselves and has no such edge. This is the same as the "fix
/// alpha border" of Godot's import of image files.
fn straight(mut pixels: Vec<u8>, width: usize) -> Vec<u8> {
    for p in pixels.chunks_exact_mut(4) {
        let a = p[3] as u32;
        if a != 0 && a != 255 {
            for c in &mut p[..3] {
                *c = ((*c as u32 * 255 + a / 2) / a).min(255) as u8;
            }
        }
    }
    bleed_edges(&mut pixels, width);
    pixels
}

/// Gives each transparent pixel the color of a visible pixel next to it (left,
/// right, above, below), or of the first visible one of its diagonal
/// neighbours. Its alpha stays 0.
fn bleed_edges(pixels: &mut [u8], width: usize) {
    if width == 0 {
        return;
    }
    let height = pixels.len() / 4 / width;
    let visible = |pixels: &[u8], x: usize, y: usize| pixels[(y * width + x) * 4 + 3] != 0;
    let mut fills: Vec<(usize, usize)> = Vec::new();
    for y in 0..height {
        for x in 0..width {
            if visible(pixels, x, y) {
                continue;
            }
            let mut source = None;
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)] {
                let (nx, ny) = (x as isize + dx, y as isize + dy);
                if nx >= 0 && ny >= 0 && (nx as usize) < width && (ny as usize) < height && visible(pixels, nx as usize, ny as usize) {
                    source = Some(ny as usize * width + nx as usize);
                    break;
                }
            }
            if let Some(source) = source {
                fills.push((y * width + x, source));
            }
        }
    }
    for (target, source) in fills {
        let color = [pixels[source * 4], pixels[source * 4 + 1], pixels[source * 4 + 2]];
        pixels[target * 4..target * 4 + 3].copy_from_slice(&color);
    }
}
