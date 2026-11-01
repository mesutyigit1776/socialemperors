//! The characters of one SWF file, kept in memory to draw their frames.

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};

use swf::{CharacterId, Depth, Tag};
use tiny_skia::{Pixmap, Rect, Transform};

use crate::bitmap::{self, BitmapData};
use crate::color::ColorTransform;
use crate::filters;
use crate::render::MorphCache;
use crate::shape::{self, ShapeLayer};

/// A shape, morph shape or sprite of the file, or a bitmap that shapes fill with.
pub enum Character {
    Shape { bounds: Rect, layers: Vec<ShapeLayer> },
    Morph(Box<swf::DefineMorphShape>),
    Sprite(Sprite),
    Bitmap(BitmapData),
    /// Text and the other characters that the art of the game does not draw.
    /// Texts have bounds, which count in the bounds of their sprites.
    Other { bounds: Option<Rect> },
}

pub struct Sprite {
    /// The display list of each frame, in the order of the depths.
    pub frames: Vec<Vec<Placed>>,
}

/// A character on the display list of a sprite.
#[derive(Clone)]
pub struct Placed {
    pub depth: Depth,
    pub id: CharacterId,
    /// From the coordinates of the character, in twips, to the sprite.
    pub matrix: Transform,
    pub color: ColorTransform,
    /// The point between the start (0) and the end (65535) of a morph shape.
    pub ratio: u16,
    /// A mask hides the depths above it up to clip_depth, outside its shapes. 0: not a mask.
    pub clip_depth: Depth,
    pub filters: Arc<Vec<swf::Filter>>,
    pub blend: swf::BlendMode,
    /// The frame (from 0) in which the character came on the list. A nested
    /// sprite plays its frames from there.
    pub start: usize,
    pub visible: bool,
    /// The instance name, by which the client finds a part.
    pub name: Option<String>,
}

pub struct Art {
    pub characters: HashMap<CharacterId, Character>,
    /// Class name -> character id of the exported symbols.
    pub symbols: HashMap<String, CharacterId>,
    bitmaps: Mutex<HashMap<CharacterId, Option<Arc<Pixmap>>>>,
    bounds: Mutex<HashMap<(CharacterId, bool), Option<Rect>>>,
    pub(crate) morphs: MorphCache,
}

impl Art {
    pub fn load(file: &[u8]) -> Result<Art, String> {
        let buffer = swf::decompress_swf(file).map_err(|e| e.to_string())?;
        let movie = swf::parse_swf(&buffer).map_err(|e| e.to_string())?;
        let mut art = Art {
            characters: HashMap::new(),
            symbols: HashMap::new(),
            bitmaps: Mutex::new(HashMap::new()),
            bounds: Mutex::new(HashMap::new()),
            morphs: MorphCache::default(),
        };
        let mut jpeg_tables: Option<Vec<u8>> = None;
        for tag in &movie.tags {
            art.read_definition(tag, &mut jpeg_tables);
        }
        Ok(art)
    }

    fn read_definition(&mut self, tag: &Tag, jpeg_tables: &mut Option<Vec<u8>>) {
        let (id, character) = match tag {
            Tag::DefineShape(s) => (s.id, Character::Shape { bounds: rect(&s.shape_bounds), layers: shape::convert(&s.styles, &s.shape) }),
            Tag::DefineMorphShape(m) => (m.id, Character::Morph(Box::new((**m).clone()))),
            Tag::DefineSprite(s) => (s.id, Character::Sprite(read_sprite(&s.tags, s.num_frames as usize))),
            Tag::JpegTables(data) => {
                *jpeg_tables = Some(data.to_vec());
                return;
            }
            Tag::DefineBits { id, jpeg_data } => (*id, Character::Bitmap(BitmapData::jpeg(jpeg_data, jpeg_tables.as_deref(), None))),
            Tag::DefineBitsJpeg2 { id, jpeg_data } => (*id, Character::Bitmap(BitmapData::jpeg(jpeg_data, None, None))),
            Tag::DefineBitsJpeg3(b) => (b.id, Character::Bitmap(BitmapData::jpeg(b.data, None, Some(b.alpha_data)))),
            Tag::DefineBitsLossless(b) => (b.id, Character::Bitmap(BitmapData::lossless(b))),
            Tag::DefineText(t) => (t.id, Character::Other { bounds: Some(rect(&t.bounds)) }),
            Tag::DefineEditText(t) => (t.id(), Character::Other { bounds: Some(rect(t.bounds())) }),
            Tag::DefineButton2(b) => (b.id, Character::Other { bounds: None }),
            Tag::SymbolClass(links) => {
                for link in links {
                    self.symbols.insert(link.class_name.to_string_lossy(swf::UTF_8), link.id);
                }
                return;
            }
            _ => return,
        };
        self.characters.insert(id, character);
    }

    pub fn symbol(&self, name: &str) -> Option<CharacterId> {
        self.symbols.get(name).copied()
    }

    pub fn frame_count(&self, id: CharacterId) -> usize {
        match self.characters.get(&id) {
            Some(Character::Sprite(s)) => s.frames.len(),
            Some(_) => 1,
            None => 0,
        }
    }

    /// The decoded pixels of a bitmap, premultiplied, or None when it cannot be decoded.
    pub fn bitmap(&self, id: CharacterId) -> Option<Arc<Pixmap>> {
        if let Some(found) = self.bitmaps.lock().unwrap().get(&id) {
            return found.clone();
        }
        let decoded = match self.characters.get(&id) {
            Some(Character::Bitmap(data)) => bitmap::decode(data).map(Arc::new),
            _ => None,
        };
        self.bitmaps.lock().unwrap().insert(id, decoded.clone());
        decoded
    }

    /// The bounds in twips of a character over all its frames, as the Flash
    /// tools measure them: the rectangles of the shapes, without filters.
    /// None when the character draws nothing.
    pub fn bounds(&self, id: CharacterId) -> Option<Rect> {
        self.measure(id, false)
    }

    /// The bounds with the space in which filters draw outside the shapes.
    pub fn visual_bounds(&self, id: CharacterId) -> Option<Rect> {
        self.measure(id, true)
    }

    /// The visual bounds of one frame of a sprite, or of another character.
    pub fn frame_visual_bounds(&self, id: CharacterId, frame: usize) -> Option<Rect> {
        match self.characters.get(&id) {
            Some(Character::Sprite(s)) => s.frames[frame % s.frames.len()].iter().fold(None, |r, placed| union(r, self.placed_bounds(placed, true))),
            _ => self.visual_bounds(id),
        }
    }

    /// The bounds of a placed character over all its frames, in the coordinates of its sprite.
    fn placed_bounds(&self, placed: &Placed, with_filters: bool) -> Option<Rect> {
        let bounds = self.measure(placed.id, with_filters).and_then(|r| r.transform(placed.matrix))?;
        if !with_filters {
            return Some(bounds);
        }
        let (x, y) = placed.filters.iter().filter(|f| filters::is_active(f)).map(|f| filters::margin(f, 1.0)).fold((0.0, 0.0), |a, m| (a.0 + m.0, a.1 + m.1));
        Rect::from_ltrb(bounds.left() - x * 20.0, bounds.top() - y * 20.0, bounds.right() + x * 20.0, bounds.bottom() + y * 20.0)
    }

    fn measure(&self, id: CharacterId, with_filters: bool) -> Option<Rect> {
        if let Some(found) = self.bounds.lock().unwrap().get(&(id, with_filters)) {
            return *found;
        }
        // Stops the recursion in a file in which a sprite contains itself.
        self.bounds.lock().unwrap().insert((id, with_filters), None);
        let result = match self.characters.get(&id) {
            Some(Character::Shape { bounds, .. } | Character::Other { bounds: Some(bounds) }) => Some(*bounds),
            Some(Character::Morph(m)) => union(Some(rect(&m.start.shape_bounds)), Some(rect(&m.end.shape_bounds))),
            Some(Character::Sprite(s)) => s.frames.iter().flatten().fold(None, |r, placed| union(r, self.placed_bounds(placed, with_filters))),
            _ => None,
        };
        self.bounds.lock().unwrap().insert((id, with_filters), result);
        result
    }
}

fn read_sprite(tags: &[Tag], frame_count: usize) -> Sprite {
    let mut list: BTreeMap<Depth, Placed> = BTreeMap::new();
    let mut frames = Vec::new();
    for tag in tags {
        match tag {
            Tag::ShowFrame => frames.push(list.values().cloned().collect()),
            Tag::RemoveObject(r) => {
                list.remove(&r.depth);
            }
            Tag::PlaceObject(p) => {
                let start = frames.len();
                let placed = match p.action {
                    swf::PlaceObjectAction::Place(id) => list.entry(p.depth).insert_entry(Placed::new(p.depth, id, start)).into_mut(),
                    swf::PlaceObjectAction::Replace(id) => {
                        let placed = list.entry(p.depth).or_insert_with(|| Placed::new(p.depth, id, start));
                        if placed.id != id {
                            placed.id = id;
                            placed.start = start;
                        }
                        placed.name = None;
                        placed
                    }
                    swf::PlaceObjectAction::Modify => match list.get_mut(&p.depth) {
                        Some(placed) => placed,
                        None => continue,
                    },
                };
                if let Some(m) = &p.matrix {
                    placed.matrix = matrix(m);
                }
                if let Some(c) = &p.color_transform {
                    placed.color = ColorTransform::from_swf(c);
                }
                if let Some(ratio) = p.ratio {
                    placed.ratio = ratio;
                }
                if let Some(clip_depth) = p.clip_depth {
                    placed.clip_depth = clip_depth;
                }
                if let Some(filters) = &p.filters {
                    placed.filters = Arc::new(filters.clone());
                }
                if let Some(blend) = p.blend_mode {
                    placed.blend = blend;
                }
                if let Some(name) = p.name {
                    placed.name = Some(name.to_string_lossy(swf::UTF_8));
                }
                if let Some(visible) = p.is_visible {
                    placed.visible = visible;
                }
            }
            _ => {}
        }
    }
    // A sprite can declare more frames than it shows; they repeat the last list.
    while frames.len() < frame_count.max(1) {
        frames.push(list.values().cloned().collect());
    }
    Sprite { frames }
}

impl Placed {
    fn new(depth: Depth, id: CharacterId, start: usize) -> Placed {
        Placed {
            depth,
            id,
            matrix: Transform::identity(),
            color: ColorTransform::IDENTITY,
            ratio: 0,
            clip_depth: 0,
            filters: Arc::new(Vec::new()),
            blend: swf::BlendMode::Normal,
            start,
            visible: true,
            name: None,
        }
    }
}

/// x' = a x + c y + tx, y' = b x + d y + ty, in twips.
pub fn matrix(m: &swf::Matrix) -> Transform {
    Transform::from_row(m.a.to_f32(), m.b.to_f32(), m.c.to_f32(), m.d.to_f32(), m.tx.get() as f32, m.ty.get() as f32)
}

pub fn rect(r: &swf::Rectangle<swf::Twips>) -> Rect {
    Rect::from_ltrb(r.x_min.get() as f32, r.y_min.get() as f32, r.x_max.get() as f32, r.y_max.get() as f32)
        .unwrap_or_else(|| Rect::from_xywh(r.x_min.get() as f32, r.y_min.get() as f32, 0.0, 0.0).unwrap())
}

pub fn union(a: Option<Rect>, b: Option<Rect>) -> Option<Rect> {
    match (a, b) {
        (Some(a), Some(b)) => Rect::from_ltrb(a.left().min(b.left()), a.top().min(b.top()), a.right().max(b.right()), a.bottom().max(b.bottom())),
        (a, None) => a,
        (None, b) => b,
    }
}

impl Art {
    /// Prints the display list tree of a frame, to find the cause of a difference.
    pub fn dump(&self, id: CharacterId, frame: usize, indent: usize) {
        let pad = "  ".repeat(indent);
        match self.characters.get(&id) {
            Some(Character::Sprite(s)) => {
                println!("{pad}sprite {id} frame {}/{}", frame + 1, s.frames.len());
                for p in &s.frames[frame % s.frames.len()] {
                    let child = if p.start == 0 { frame } else { (frame % s.frames.len()).saturating_sub(p.start) };
                    let m = p.matrix;
                    println!("{pad} depth {} clip {} m [{:.3} {:.3} {:.3} {:.3} {} {}] cx {:?} blend {:?} filters {:?} start {}", p.depth, p.clip_depth, m.sx, m.ky, m.kx, m.sy, m.tx, m.ty, if p.color.is_identity() { None } else { Some(p.color) }, p.blend, p.filters.iter().filter(|f| crate::filters::is_active(f)).collect::<Vec<_>>(), p.start);
                    self.dump(p.id, child, indent + 2);
                }
            }
            Some(Character::Shape { layers, .. }) => {
                let fills: Vec<String> = layers.iter().flat_map(|l| l.fills.iter().map(|(f, _)| match f { swf::FillStyle::Bitmap { id, matrix, is_smoothed, .. } => format!("bitmap {id} [{:.3} {:.3} {:.3} {:.3} {} {}] s{}", matrix.a.to_f32(), matrix.b.to_f32(), matrix.c.to_f32(), matrix.d.to_f32(), matrix.tx.get(), matrix.ty.get(), is_smoothed), swf::FillStyle::Color(c) => format!("#{:02x}{:02x}{:02x}{:02x}", c.r, c.g, c.b, c.a), _ => "gradient".into() })).collect();
                println!("{pad}shape {id} fills {fills:?} strokes {}", layers.iter().map(|l| l.strokes.len()).sum::<usize>());
            }
            Some(Character::Morph(_)) => println!("{pad}morph {id}"),
            _ => println!("{pad}other {id}"),
        }
    }
}
