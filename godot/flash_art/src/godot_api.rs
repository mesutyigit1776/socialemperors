//! The class FlashArt that Godot uses: one SWF file of the user, whose frames
//! it draws on request. Frames can also be drawn ahead on other threads.

use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Condvar, Mutex};

use godot::classes::image::Format;
use godot::classes::{Image, ProjectSettings};
use godot::prelude::*;

use crate::Art;

struct FlashArtExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FlashArtExtension {}

/// Threads that draw frames ahead for all FlashArt objects.
const WORKERS: usize = 3;

type Key = (u16, usize);

/// Frames that wait to be drawn ahead, and the frames that are ready.
#[derive(Default)]
struct Ahead {
    queue: Vec<Key>,
    queued: HashSet<Key>,
    ready: HashMap<Key, Vec<u8>>,
    stopped: bool,
}

struct Shared {
    art: Art,
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
    /// Loads a SWF file. Returns null and reports an error when the file cannot be read.
    #[func]
    fn open(path: GString) -> Option<Gd<FlashArt>> {
        let global = ProjectSettings::singleton().globalize_path(&path).to_string();
        let art = match std::fs::read(&global).map_err(|e| e.to_string()).and_then(|data| Art::load(&data)) {
            Ok(art) => art,
            Err(e) => {
                godot_error!("Cannot read the art in '{}': {}", path, e);
                return None;
            }
        };
        let shared = Arc::new(Shared { art, ahead: Mutex::new(Ahead::default()), wake: Condvar::new() });
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

    /// Draws frame (from 0) of a character on an image of its canvas, or
    /// returns the image that the threads drew ahead. Null when it draws nothing.
    #[func]
    fn render(&self, id: i64, frame: i64) -> Option<Gd<Image>> {
        let key = (id as u16, frame.max(0) as usize);
        let ready = self.shared.ahead.lock().unwrap().ready.remove(&key);
        let canvas = self.shared.art.canvas(key.0)?;
        let pixels = match ready {
            Some(pixels) => pixels,
            None => draw(&self.shared.art, key)?,
        };
        Image::create_from_data(canvas.width as i32, canvas.height as i32, false, Format::RGBA8, &PackedByteArray::from(pixels))
    }

    /// Starts to draw these frames of a character on other threads, so that
    /// render() later only takes them.
    #[func]
    fn draw_ahead(&mut self, id: i64, frames: PackedInt32Array) {
        if !self.workers {
            self.workers = true;
            for _ in 0..WORKERS {
                let shared = self.shared.clone();
                std::thread::spawn(move || work(shared));
            }
        }
        let mut ahead = self.shared.ahead.lock().unwrap();
        for frame in frames.as_slice() {
            let key = (id as u16, (*frame).max(0) as usize);
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
        self.shared.ahead.lock().unwrap().stopped = true;
        self.shared.wake.notify_all();
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
        let pixels = draw(&shared.art, key);
        let mut ahead = shared.ahead.lock().unwrap();
        ahead.queued.remove(&key);
        if let Some(pixels) = pixels {
            ahead.ready.insert(key, pixels);
        }
    }
}

/// The pixels of a frame, not premultiplied, as Godot images keep them.
fn draw(art: &Art, (id, frame): Key) -> Option<Vec<u8>> {
    let canvas = art.canvas(id)?;
    let pixmap = art.render(id, frame, canvas, 1.0)?;
    let mut pixels = pixmap.take();
    for p in pixels.chunks_exact_mut(4) {
        let a = p[3] as u32;
        if a != 0 && a != 255 {
            for c in &mut p[..3] {
                *c = ((*c as u32 * 255 + a / 2) / a).min(255) as u8;
            }
        }
    }
    Some(pixels)
}
