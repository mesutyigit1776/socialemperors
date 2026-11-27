//! The SWF work of the import (godot/importer/): the exported symbols, the
//! frame labels of the spell graphics, the flames of the fire, the sounds,
//! and the windows of the client. A window of the client is a symbol of a
//! SWF file whose named parts (buttons, stars, text fields) change at run
//! time; the import writes a copy of the file without these parts
//! (windows.swf) and their places (layout.json), see godot/README.md.
//!
//! This reads the tags of the file itself, not through the crate `swf`,
//! because windows.swf copies the bytes of the tags that it keeps.

use std::collections::{HashMap, HashSet};
use std::io::Read;

use flate2::read::ZlibDecoder;
use indexmap::IndexMap;
use serde_json::{Map, Value, json};

const SHAPE_TAGS: [u16; 4] = [2, 22, 32, 83]; // DefineShape, DefineShape2, 3, 4
const MORPH_TAGS: [u16; 2] = [46, 84]; // DefineMorphShape, DefineMorphShape2
const TEXT_TAGS: [u16; 2] = [11, 33]; // DefineText, DefineText2
const EDIT_TEXT_TAG: u16 = 37;
const FONT_TAGS: [u16; 2] = [48, 75]; // DefineFont2, DefineFont3
const SPRITE_TAG: u16 = 39;
const BUTTON2_TAG: u16 = 34; // DefineButton2
const PLACE_OBJECT2_TAG: u16 = 26;
const PLACE_OBJECT3_TAG: u16 = 70;
const SYMBOL_CLASS_TAG: u16 = 76;
const SOUND_TAG: u16 = 14; // DefineSound
const MP3_FORMAT: u8 = 2;
const SHOW_FRAME_TAG: u16 = 1;
const FRAME_LABEL_TAG: u16 = 43;
const REMOVE_OBJECT2_TAG: u16 = 28;

/// [x min, y min, x max, y max] in twips.
type Rect = [f64; 4];
/// [a, b, c, d, x, y], x and y in twips.
type Matrix = [f64; 6];
const IDENTITY: Matrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
/// [color "#rrggbbaa", blur, strength] of a glow filter.
type Glow = (String, f64, f64);
/// (depth, character id, instance name) of a placement.
type PlaceKey = (u16, u16, Option<String>);

fn is_place_tag(code: u16) -> bool {
    code == PLACE_OBJECT2_TAG || code == PLACE_OBJECT3_TAG
}

fn u16_at(data: &[u8], pos: usize) -> u16 {
    u16::from_le_bytes([data[pos], data[pos + 1]])
}

fn u32_at(data: &[u8], pos: usize) -> u32 {
    u32::from_le_bytes([data[pos], data[pos + 1], data[pos + 2], data[pos + 3]])
}

/// The position of the next zero byte from pos.
fn zero_at(data: &[u8], pos: usize) -> usize {
    pos + data[pos..].iter().position(|&b| b == 0).expect("text without end")
}

fn text_at(data: &[u8], pos: usize) -> (String, usize) {
    let end = zero_at(data, pos);
    (String::from_utf8_lossy(&data[pos..end]).into_owned(), end)
}

/// min() and max() as Python has them: the first of equal values stays, so
/// that 0.0 and -0.0 come out as in the Python importer.
fn py_min(a: f64, b: f64) -> f64 {
    if b < a { b } else { a }
}

fn py_max(a: f64, b: f64) -> f64 {
    if b > a { b } else { a }
}

struct Bits<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Bits<'a> {
    fn new(data: &'a [u8], pos: usize) -> Bits<'a> {
        Bits { data, pos: pos * 8 }
    }

    fn read(&mut self, n: u32) -> u64 {
        let mut value = 0u64;
        for _ in 0..n {
            let byte = self.data[self.pos >> 3];
            value = (value << 1) | ((byte >> (7 - (self.pos & 7))) & 1) as u64;
            self.pos += 1;
        }
        value
    }

    fn read_signed(&mut self, n: u32) -> i64 {
        let value = self.read(n) as i64;
        if n > 0 && value & (1 << (n - 1)) != 0 { value - (1 << n) } else { value }
    }

    fn byte_pos(&self) -> usize {
        self.pos.div_ceil(8)
    }
}

fn read_rect(data: &[u8], pos: usize) -> (Rect, usize) {
    let mut bits = Bits::new(data, pos);
    let n = bits.read(5) as u32;
    let x_min = bits.read_signed(n) as f64;
    let x_max = bits.read_signed(n) as f64;
    let y_min = bits.read_signed(n) as f64;
    let y_max = bits.read_signed(n) as f64;
    ([x_min, y_min, x_max, y_max], bits.byte_pos())
}

fn read_matrix(data: &[u8], pos: usize) -> (Matrix, usize) {
    let mut bits = Bits::new(data, pos);
    let (mut a, mut b, mut c, mut d) = (1.0, 0.0, 0.0, 1.0);
    if bits.read(1) != 0 {
        let n = bits.read(5) as u32;
        a = bits.read_signed(n) as f64 / 65536.0;
        d = bits.read_signed(n) as f64 / 65536.0;
    }
    if bits.read(1) != 0 {
        let n = bits.read(5) as u32;
        b = bits.read_signed(n) as f64 / 65536.0;
        c = bits.read_signed(n) as f64 / 65536.0;
    }
    let n = bits.read(5) as u32;
    let tx = bits.read_signed(n) as f64;
    let ty = bits.read_signed(n) as f64;
    ([a, b, c, d, tx, ty], bits.byte_pos())
}

/// The alpha multiplier (0 to 1, or None) of a CXFORMWITHALPHA record and the position after it.
fn read_color_transform_alpha(data: &[u8], pos: usize) -> (Option<f64>, usize) {
    let mut bits = Bits::new(data, pos);
    let has_add = bits.read(1) != 0;
    let has_mult = bits.read(1) != 0;
    let n = bits.read(4) as u32;
    let mut alpha = None;
    if has_mult {
        bits.read_signed(n);
        bits.read_signed(n);
        bits.read_signed(n);
        alpha = Some(bits.read_signed(n) as f64 / 256.0);
    }
    if has_add {
        bits.read(n * 4);
    }
    (alpha, bits.byte_pos())
}

/// The first glow filter of a FILTERLIST, or None.
fn first_glow(data: &[u8], pos: usize) -> Option<Glow> {
    let count = data[pos];
    let mut p = pos + 1;
    for _ in 0..count {
        let kind = data[p];
        p += 1;
        if kind == 2 {
            // GlowFilter: RGBA, blur x and y (16.16), strength (8.8), flags.
            let color = format!("#{:02x}{:02x}{:02x}{:02x}", data[p], data[p + 1], data[p + 2], data[p + 3]);
            let blur = u32_at(data, p + 4) as f64 / 65536.0;
            let strength = u16_at(data, p + 12) as f64 / 256.0;
            return Some((color, blur, strength));
        }
        // Only the filters before the first glow filter need a size: drop shadow (0), blur (1), bevel (3).
        p += match kind {
            0 => 23,
            1 => 9,
            3 => 27,
            6 => 80,
            _ => return None,
        };
    }
    None
}

/// (code, start of the header, start of the content, end) of each tag, up to the End tag.
fn raw_tags(data: &[u8], mut pos: usize, end: usize) -> Vec<(u16, usize, usize, usize)> {
    let mut tags = Vec::new();
    while pos < end {
        let header = pos;
        let word = u16_at(data, pos);
        let (code, mut length) = (word >> 6, (word & 0x3f) as usize);
        pos += 2;
        if length == 0x3f {
            length = u32_at(data, pos) as usize;
            pos += 4;
        }
        tags.push((code, header, pos, pos + length));
        pos += length;
        if code == 0 {
            break;
        }
    }
    tags
}

fn transform(rect: Rect, m: Matrix) -> Rect {
    let [a, b, c, d, tx, ty] = m;
    let corners = [(rect[0], rect[1]), (rect[2], rect[1]), (rect[0], rect[3]), (rect[2], rect[3])];
    let xs: Vec<f64> = corners.iter().map(|&(x, y)| a * x + c * y + tx).collect();
    let ys: Vec<f64> = corners.iter().map(|&(x, y)| b * x + d * y + ty).collect();
    let min = |v: &[f64]| v[1..].iter().fold(v[0], |m, &x| py_min(m, x));
    let max = |v: &[f64]| v[1..].iter().fold(v[0], |m, &x| py_max(m, x));
    [min(&xs), min(&ys), max(&xs), max(&ys)]
}

fn union(r1: Option<Rect>, r2: Option<Rect>) -> Option<Rect> {
    match (r1, r2) {
        (None, r) | (r, None) => r,
        (Some(a), Some(b)) => Some([py_min(a[0], b[0]), py_min(a[1], b[1]), py_max(a[2], b[2]), py_max(a[3], b[3])]),
    }
}

/// A character on the display list of a frame.
#[derive(Clone)]
struct Place {
    char_id: u16,
    matrix: Matrix,
    name: Option<String>,
}

/// The other settings of the placements at a depth, over all tags of a sprite.
#[derive(Default)]
struct Detail {
    alpha: Option<f64>,
    clip_depth: Option<u16>,
    glow: Option<Glow>,
}

/// The display list of each frame of a sprite, see SwfFile::frame_places().
#[derive(Default)]
struct FramePlaces {
    /// For each frame, {depth: place} in the order in which the depths came.
    frames: Vec<IndexMap<u16, Place>>,
    details: HashMap<u16, Detail>,
    /// For each frame, {depth: alpha} of the placements with an alpha.
    alphas: Vec<HashMap<u16, f64>>,
    /// For each frame, {depth: index of the frame that placed the instance}.
    starts: Vec<HashMap<u16, usize>>,
    /// For each frame, {depth: glow} of the placements with a glow filter.
    glows: Vec<HashMap<u16, Glow>>,
}

pub struct SwfFile {
    data: Vec<u8>,
    version: u8,
    first_tag: usize,
    bounds: HashMap<u16, Rect>,
    sprites: HashMap<u16, (usize, usize)>,
    symbols: IndexMap<String, u16>,
    edit_texts: HashMap<u16, usize>,
    fonts: IndexMap<u16, String>,
    buttons: HashMap<u16, (usize, usize)>,
    sounds: HashMap<u16, (usize, usize)>,
    sprite_bounds: HashMap<u16, Option<Rect>>,
}

impl SwfFile {
    pub fn open(path: &str) -> Result<SwfFile, String> {
        let raw = std::fs::read(path).map_err(|e| format!("{path}: {e}"))?;
        SwfFile::from_bytes(&raw).map_err(|e| format!("{path}: {e}"))
    }

    pub fn from_bytes(raw: &[u8]) -> Result<SwfFile, String> {
        if raw.len() < 8 {
            return Err("not a SWF file".into());
        }
        let data = match &raw[..3] {
            b"FWS" => raw[8..].to_vec(),
            b"CWS" => {
                let mut body = Vec::new();
                ZlibDecoder::new(&raw[8..]).read_to_end(&mut body).map_err(|e| e.to_string())?;
                body
            }
            // The game files use zlib compression only (CWS); LZMA (ZWS) is not supported.
            _ => return Err("not an uncompressed or zlib-compressed SWF file".into()),
        };
        let (_, pos) = read_rect(&data, 0);
        let first_tag = pos + 4; // frame rate and frame count
        let mut swf = SwfFile {
            data,
            version: raw[3],
            first_tag,
            bounds: HashMap::new(),
            sprites: HashMap::new(),
            symbols: IndexMap::new(),
            edit_texts: HashMap::new(),
            fonts: IndexMap::new(),
            buttons: HashMap::new(),
            sounds: HashMap::new(),
            sprite_bounds: HashMap::new(),
        };
        swf.read_definitions();
        Ok(swf)
    }

    fn read_definitions(&mut self) {
        let data = &self.data;
        for (code, _, start, end) in raw_tags(data, self.first_tag, data.len()) {
            if SHAPE_TAGS.contains(&code) || TEXT_TAGS.contains(&code) || code == EDIT_TEXT_TAG {
                let char_id = u16_at(data, start);
                self.bounds.insert(char_id, read_rect(data, start + 2).0);
                if code == EDIT_TEXT_TAG {
                    self.edit_texts.insert(char_id, start);
                }
            } else if FONT_TAGS.contains(&code) {
                let font_id = u16_at(data, start);
                let name_length = data[start + 4] as usize;
                let name = &data[start + 5..start + 5 + name_length];
                let trimmed = &name[..name.iter().rposition(|&b| b != 0).map_or(0, |i| i + 1)];
                self.fonts.insert(font_id, String::from_utf8_lossy(trimmed).into_owned());
            } else if MORPH_TAGS.contains(&code) {
                let char_id = u16_at(data, start);
                let (start_rect, p) = read_rect(data, start + 2);
                let (end_rect, _) = read_rect(data, p);
                self.bounds.insert(char_id, union(Some(start_rect), Some(end_rect)).unwrap());
            } else if code == SPRITE_TAG {
                self.sprites.insert(u16_at(data, start), (start + 4, end));
            } else if code == BUTTON2_TAG {
                self.buttons.insert(u16_at(data, start), (start, end));
            } else if code == SOUND_TAG {
                self.sounds.insert(u16_at(data, start), (start, end));
            } else if code == SYMBOL_CLASS_TAG {
                let count = u16_at(data, start);
                let mut p = start + 2;
                for _ in 0..count {
                    let char_id = u16_at(data, p);
                    let (name, name_end) = text_at(data, p + 2);
                    self.symbols.insert(name, char_id);
                    p = name_end + 1;
                }
            }
        }
    }

    fn max_character_id(&self) -> u16 {
        let ids = self.bounds.keys().chain(self.sprites.keys()).chain(self.buttons.keys());
        let ids = ids.chain(self.edit_texts.keys()).chain(self.fonts.keys()).chain(self.sounds.keys());
        ids.copied().max().unwrap_or(0)
    }

    fn symbol_sprite(&self, class_name: &str) -> Result<u16, String> {
        let char_id = *self.symbols.get(class_name).ok_or_else(|| format!("symbol '{class_name}' is not exported"))?;
        if !self.sprites.contains_key(&char_id) {
            return Err(format!("symbol '{class_name}' is not a sprite"));
        }
        Ok(char_id)
    }

    /// Whether the symbol is an exported sprite, which the port can draw.
    pub fn check_sprite(&self, symbol: &str) -> Result<(), String> {
        match self.symbols.get(symbol) {
            Some(id) if self.sprites.contains_key(id) => Ok(()),
            _ => Err(format!("symbol '{symbol}' is not an exported sprite")),
        }
    }

    /// The frame labels of a symbol: label -> frame number (1-based).
    pub fn symbol_frame_labels(&self, class_name: &str) -> Result<IndexMap<String, i64>, String> {
        Ok(self.sprite_frame_labels(self.symbol_sprite(class_name)?))
    }

    fn sprite_frame_labels(&self, sprite_id: u16) -> IndexMap<String, i64> {
        let (start, end) = self.sprites[&sprite_id];
        let mut labels = IndexMap::new();
        let mut frame = 1;
        for (code, _, content, _) in raw_tags(&self.data, start, end) {
            if code == FRAME_LABEL_TAG {
                labels.insert(text_at(&self.data, content).0, frame);
            } else if code == SHOW_FRAME_TAG {
                frame += 1;
            }
        }
        labels
    }

    /// The MP3 frames of each sound with a class name, which an MP3 file can hold as they are.
    pub fn mp3_sounds(&self) -> Result<Vec<(String, &[u8])>, String> {
        let mut result = Vec::new();
        for (name, char_id) in &self.symbols {
            if let Some(&(start, end)) = self.sounds.get(char_id) {
                if self.data[start + 2] >> 4 != MP3_FORMAT {
                    return Err(format!("sound {char_id} is not MP3"));
                }
                // The id, the format byte and the sample count (7 bytes), then the seek samples (2 bytes).
                result.push((name.clone(), &self.data[start + 9..end]));
            }
        }
        Ok(result)
    }

    /// For each frame of an exported sprite, the matrix [a, b, c, d, x, y]
    /// (x and y in pixels) of each placed character.
    pub fn frame_matrices(&self, symbol: &str) -> Result<Vec<Vec<Matrix>>, String> {
        let char_id = *self.symbols.get(symbol).ok_or_else(|| format!("symbol '{symbol}' is not exported"))?;
        let &(start, end) = self.sprites.get(&char_id).ok_or_else(|| format!("symbol '{symbol}' is not a sprite"))?;
        Ok(self
            .frame_places(start, end)
            .frames
            .iter()
            .map(|places| places.values().map(|p| { let m = p.matrix; [m[0], m[1], m[2], m[3], m[4] / 20.0, m[5] / 20.0] }).collect())
            .collect())
    }

    /// The display list of each frame of a sprite, and the other settings of
    /// its placements, see FramePlaces. A move, also one that changes the
    /// character, keeps the instance.
    fn frame_places(&self, pos: usize, end: usize) -> FramePlaces {
        let data = &self.data;
        let mut result = FramePlaces::default();
        let mut depth_char: IndexMap<u16, u16> = IndexMap::new();
        let mut depth_matrix: HashMap<u16, Matrix> = HashMap::new();
        let mut depth_name: HashMap<u16, String> = HashMap::new();
        let mut depth_alpha: HashMap<u16, f64> = HashMap::new();
        let mut depth_start: HashMap<u16, usize> = HashMap::new();
        let mut depth_glow: HashMap<u16, Glow> = HashMap::new();
        for (code, _, start, _) in raw_tags(data, pos, end) {
            if code == SHOW_FRAME_TAG {
                let frame = depth_char
                    .iter()
                    .map(|(&depth, &char_id)| (depth, Place { char_id, matrix: depth_matrix[&depth], name: depth_name.get(&depth).cloned() }))
                    .collect();
                result.frames.push(frame);
                let alive = |depth: &u16| depth_char.contains_key(depth);
                result.alphas.push(depth_alpha.iter().filter(|(d, _)| alive(d)).map(|(&d, &a)| (d, a)).collect());
                result.starts.push(depth_char.keys().map(|&d| (d, depth_start[&d])).collect());
                result.glows.push(depth_glow.iter().filter(|(d, _)| alive(d)).map(|(&d, g)| (d, g.clone())).collect());
                continue;
            }
            if code == REMOVE_OBJECT2_TAG {
                let depth = u16_at(data, start);
                depth_char.shift_remove(&depth);
                depth_name.remove(&depth);
                depth_alpha.remove(&depth);
                depth_start.remove(&depth);
                depth_glow.remove(&depth);
                continue;
            }
            if !is_place_tag(code) {
                continue;
            }
            let flags = data[start];
            let mut flags3 = 0;
            let mut p = start + 1;
            if code == PLACE_OBJECT3_TAG {
                flags3 = data[p];
                p += 1;
            }
            let depth = u16_at(data, p);
            p += 2;
            // The SWF specification also names (HasImage and HasCharacter) as a
            // condition for the class name; the Flash tools write HasImage
            // without a class name, so only HasClassName counts.
            if code == PLACE_OBJECT3_TAG && flags3 & 0x08 != 0 {
                p = zero_at(data, p) + 1;
            }
            let frame_index = result.frames.len();
            if flags & 0x02 != 0 {
                depth_char.insert(depth, u16_at(data, p));
                p += 2;
                depth_matrix.insert(depth, IDENTITY);
                depth_name.remove(&depth);
                if flags & 0x01 == 0 {
                    // A new character, not a move.
                    depth_alpha.remove(&depth);
                    depth_glow.remove(&depth);
                    depth_start.insert(depth, frame_index);
                } else {
                    depth_start.entry(depth).or_insert(frame_index);
                }
            }
            if flags & 0x04 != 0 {
                let (matrix, next) = read_matrix(data, p);
                depth_matrix.insert(depth, matrix);
                p = next;
            }
            let mut alpha = None;
            if flags & 0x08 != 0 {
                let (value, next) = read_color_transform_alpha(data, p);
                alpha = value;
                p = next;
                if let Some(a) = alpha {
                    depth_alpha.insert(depth, a);
                }
            }
            if flags & 0x10 != 0 {
                p += 2; // ratio
            }
            if flags & 0x20 != 0 {
                let (name, name_end) = text_at(data, p);
                depth_name.insert(depth, name);
                p = name_end + 1;
            }
            let mut clip_depth = None;
            if flags & 0x40 != 0 {
                clip_depth = Some(u16_at(data, p));
                p += 2;
            }
            let glow = if flags3 & 0x01 != 0 { first_glow(data, p) } else { None };
            if let Some(g) = &glow {
                depth_glow.insert(depth, g.clone());
            }
            let entry = result.details.entry(depth).or_default();
            if alpha.is_some() {
                entry.alpha = alpha;
            }
            if clip_depth.is_some() {
                entry.clip_depth = clip_depth;
            }
            if glow.is_some() {
                entry.glow = glow;
            }
        }
        result
    }

    fn sprite_frames(&self, sprite_id: u16) -> FramePlaces {
        let (start, end) = self.sprites[&sprite_id];
        self.frame_places(start, end)
    }

    /// The bounds of a character in twips, over all frames, or None.
    fn character_bounds(&mut self, char_id: u16) -> Option<Rect> {
        if let Some(rect) = self.bounds.get(&char_id) {
            return Some(*rect);
        }
        if !self.sprites.contains_key(&char_id) {
            return None;
        }
        if let Some(rect) = self.sprite_bounds.get(&char_id) {
            return *rect;
        }
        self.sprite_bounds.insert(char_id, None); // stops recursion on bad files
        // The exported images cover nested sprites in all their frames.
        let mut result = None;
        for places in self.sprite_frames(char_id).frames {
            let mut rect = None;
            for place in places.values() {
                rect = union(rect, self.character_bounds(place.char_id).map(|r| transform(r, place.matrix)));
            }
            result = union(result, rect);
        }
        self.sprite_bounds.insert(char_id, result);
        result
    }

    /// The tags of the first frame of a sprite that place characters at
    /// these depths, as bytes with their headers.
    fn first_frame_placements(&self, sprite_id: u16, depths: &HashSet<u16>) -> Vec<u8> {
        let data = &self.data;
        let (start, end) = self.sprites[&sprite_id];
        let mut tags = Vec::new();
        for (code, header, inner_start, inner_end) in raw_tags(data, start, end) {
            if code == SHOW_FRAME_TAG {
                break;
            }
            if is_place_tag(code) {
                let depth_pos = inner_start + if code == PLACE_OBJECT3_TAG { 2 } else { 1 };
                if depths.contains(&u16_at(data, depth_pos)) {
                    tags.extend_from_slice(&data[header..inner_end]);
                }
            }
        }
        tags
    }

    /// An uncompressed copy of the file in which the sprites of drops no
    /// longer place these characters at these depths; other characters and
    /// other instances at the same depths, for example in other frames, stay.
    /// new_sprites {sprite id: placement tags} adds sprites of one frame.
    fn without_placements(&self, drops: &HashMap<u16, HashSet<PlaceKey>>, new_sprites: &IndexMap<u16, Vec<u8>>) -> Vec<u8> {
        let data = &self.data;
        let mut body = data[..self.first_tag].to_vec();
        let mut copied = self.first_tag;
        for (code, header, start, end) in raw_tags(data, self.first_tag, data.len()) {
            if code != SPRITE_TAG {
                continue;
            }
            let sprite_id = u16_at(data, start);
            let Some(dropped) = drops.get(&sprite_id) else { continue };
            let mut content = data[start..start + 4].to_vec();
            let mut placed: HashMap<u16, (Option<u16>, Option<String>)> = HashMap::new();
            for (inner_code, inner_header, inner_start, inner_end) in raw_tags(data, start + 4, end) {
                if inner_code == REMOVE_OBJECT2_TAG {
                    placed.remove(&u16_at(data, inner_start));
                } else if is_place_tag(inner_code) {
                    let (depth, char_id, name) = placed_character(data, inner_code, inner_start);
                    let (mut old_char, mut old_name) = placed.get(&depth).cloned().unwrap_or((None, None));
                    if char_id.is_some() {
                        // A new character at the depth has no name until the tag gives one.
                        old_char = char_id;
                        old_name = None;
                    }
                    let entry = (old_char, name.or(old_name));
                    let is_dropped = entry.0.is_some_and(|c| dropped.contains(&(depth, c, entry.1.clone())));
                    placed.insert(depth, entry);
                    if is_dropped {
                        continue;
                    }
                }
                content.extend_from_slice(&data[inner_header..inner_end]);
            }
            body.extend_from_slice(&data[copied..header]);
            push_long_tag(&mut body, SPRITE_TAG, &content);
            copied = end;
        }
        let mut rest = data[copied..].to_vec();
        if !new_sprites.is_empty() {
            // Before the End tag, which is the last tag of the file.
            let mut added = Vec::new();
            for (sprite_id, tags) in new_sprites {
                let mut content = sprite_id.to_le_bytes().to_vec();
                content.extend_from_slice(&1u16.to_le_bytes());
                content.extend_from_slice(tags);
                content.extend_from_slice(&(SHOW_FRAME_TAG << 6).to_le_bytes());
                content.extend_from_slice(&[0, 0]);
                push_long_tag(&mut added, SPRITE_TAG, &content);
            }
            let end_tag = rest.split_off(rest.len() - 2);
            rest.extend(added);
            rest.extend(end_tag);
        }
        body.extend(rest);
        let mut file = b"FWS".to_vec();
        file.push(self.version);
        file.extend_from_slice(&((body.len() + 8) as u32).to_le_bytes());
        file.extend(body);
        file
    }

    /// The character that the sprite places with the instance name in its first frame.
    fn named_child(&self, sprite_id: u16, name: &str) -> Result<u16, String> {
        let frames = self.sprite_frames(sprite_id).frames;
        let first = frames.first().ok_or_else(|| format!("sprite {sprite_id} has no frames"))?;
        first
            .values()
            .find(|place| place.name.as_deref() == Some(name))
            .map(|place| place.char_id)
            .ok_or_else(|| format!("sprite {sprite_id} has no child '{name}'"))
    }

    /// The settings of a text field (DefineEditText): its rectangle [x, y,
    /// width, height] in pixels, font id and name, size in pixels, color
    /// "#rrggbbaa", alignment, leading (the space between lines) in pixels,
    /// whether it has more lines, wraps words or reads HTML, whether it has an
    /// auto size (it grows with its text), and its initial text.
    fn edit_text(&self, char_id: u16) -> Value {
        let data = &self.data;
        let start = self.edit_texts[&char_id];
        let (rect, mut p) = read_rect(data, start + 2);
        let (flags1, flags2) = (data[p], data[p + 1]);
        p += 2;
        let mut result = Map::new();
        result.insert("rect".into(), json!([rect[0] / 20.0, rect[1] / 20.0, (rect[2] - rect[0]) / 20.0, (rect[3] - rect[1]) / 20.0]));
        result.insert("font_id".into(), Value::Null);
        result.insert("font".into(), Value::Null);
        result.insert("size".into(), json!(12.0));
        result.insert("color".into(), json!("#000000ff"));
        result.insert("align".into(), json!("left"));
        result.insert("leading".into(), json!(0.0));
        result.insert("multiline".into(), json!(flags1 & 0x20 != 0));
        result.insert("word_wrap".into(), json!(flags1 & 0x40 != 0));
        result.insert("html".into(), json!(flags2 & 0x02 != 0));
        result.insert("auto_size".into(), json!(flags2 & 0x40 != 0));
        result.insert("text".into(), json!(""));
        if flags1 & 0x01 != 0 {
            let font_id = u16_at(data, p);
            result.insert("font_id".into(), json!(font_id));
            result.insert("font".into(), self.fonts.get(&font_id).map_or(Value::Null, |name| json!(name)));
            p += 2;
        }
        if flags2 & 0x80 != 0 {
            p = zero_at(data, p) + 1;
        }
        if flags1 & 0x01 != 0 {
            result.insert("size".into(), json!(u16_at(data, p) as f64 / 20.0));
            p += 2;
        }
        if flags1 & 0x04 != 0 {
            result.insert("color".into(), json!(format!("#{:02x}{:02x}{:02x}{:02x}", data[p], data[p + 1], data[p + 2], data[p + 3])));
            p += 4;
        }
        if flags1 & 0x02 != 0 {
            p += 2;
        }
        if flags2 & 0x20 != 0 {
            let align = ["left", "right", "center", "justify"][data[p].min(3) as usize];
            result.insert("align".into(), json!(align));
            // After the alignment: the left and right margins and the indent.
            let leading = i16::from_le_bytes([data[p + 7], data[p + 8]]);
            result.insert("leading".into(), json!(leading as f64 / 20.0));
            p += 9;
        }
        p = zero_at(data, p) + 1; // variable name
        if flags1 & 0x80 != 0 {
            result.insert("text".into(), json!(text_at(data, p).0));
        }
        Value::Object(result)
    }

    fn is_empty_sprite(&self, sprite_id: u16) -> bool {
        self.sprites.contains_key(&sprite_id) && self.sprite_frames(sprite_id).frames.iter().all(|frame| frame.is_empty())
    }
}

fn push_long_tag(out: &mut Vec<u8>, code: u16, content: &[u8]) {
    out.extend_from_slice(&((code << 6) | 0x3f).to_le_bytes());
    out.extend_from_slice(&(content.len() as u32).to_le_bytes());
    out.extend_from_slice(content);
}

/// (depth, character id, instance name) of a PlaceObject2 or PlaceObject3
/// tag; the character id is None for a move of the character at the depth,
/// and the name is None when the tag sets none.
fn placed_character(data: &[u8], code: u16, start: usize) -> (u16, Option<u16>, Option<String>) {
    let flags = data[start];
    let mut flags3 = 0;
    let mut p = start + 1;
    if code == PLACE_OBJECT3_TAG {
        flags3 = data[p];
        p += 1;
    }
    let depth = u16_at(data, p);
    p += 2;
    if code == PLACE_OBJECT3_TAG && flags3 & 0x08 != 0 {
        p = zero_at(data, p) + 1;
    }
    let mut char_id = None;
    if flags & 0x02 != 0 {
        char_id = Some(u16_at(data, p));
        p += 2;
    }
    if flags & 0x04 != 0 {
        p = read_matrix(data, p).1;
    }
    if flags & 0x08 != 0 {
        p = read_color_transform_alpha(data, p).1;
    }
    if flags & 0x10 != 0 {
        p += 2;
    }
    let name = if flags & 0x20 != 0 { Some(text_at(data, p).0) } else { None };
    (depth, char_id, name)
}

/// How a spell graphic plays: {"labels": {label: frame (1-based)},
/// "loop_from": the frame from which it plays again after its last frame,
/// or null when it stops there}. The frame scripts of the graphics, compiled
/// code that the import does not read, either stop the graphic, or go to
/// the label "bucle1" (loop), or there are none and the graphic loops.
pub fn spell_graphic(swf: &SwfFile, symbol: &str) -> Result<Value, String> {
    let labels = swf.symbol_frame_labels(symbol)?;
    let contains = |word: &[u8]| swf.data.windows(word.len()).any(|w| w == word);
    let loop_from = match labels.get("bucle1") {
        Some(&frame) if contains(b"gotoAndPlay") => json!(frame),
        _ if contains(b"stop") => Value::Null,
        _ => json!(1),
    };
    Ok(json!({"labels": labels, "loop_from": loop_from}))
}

/// The output of import_windows().
pub struct Windows {
    /// windows.swf: the file without the parts of the windows that the port places itself.
    pub swf: Vec<u8>,
    /// layout.json, see godot/importer/ui_import.gd.
    pub layout: Value,
    /// The number of sprites and buttons in the layout.
    pub count: usize,
}

/// The state of import_windows() while it collects the sprites.
struct Collector {
    clips: IndexMap<u16, Map<String, Value>>,
    drops: HashMap<u16, HashSet<PlaceKey>>,
    buttons: IndexMap<u16, Value>,
    /// New sprites of one frame: {id: (sprite id, depths of its first frame)}.
    layers: IndexMap<u16, (u16, HashSet<u16>)>,
    next_id: u16,
}

/// The windows of the symbols of one SWF file; a name "A/b/c" is the child
/// with the instance names b and c of the symbol A.
pub fn import_windows(swf: &mut SwfFile, symbol_names: &[String]) -> Result<Windows, String> {
    let mut symbols = IndexMap::new();
    for name in symbol_names {
        symbols.insert(name.clone(), resolve(swf, name)?);
    }
    let mut collector = Collector {
        clips: IndexMap::new(),
        drops: HashMap::new(),
        buttons: IndexMap::new(),
        layers: IndexMap::new(),
        next_id: swf.max_character_id() + 1,
    };
    for &sprite_id in symbols.values() {
        collect(swf, sprite_id, &mut collector);
    }
    let new_sprites: IndexMap<u16, Vec<u8>> = collector
        .layers
        .iter()
        .map(|(&layer_id, (sprite_id, depths))| (layer_id, swf.first_frame_placements(*sprite_id, depths)))
        .collect();
    let windows = swf.without_placements(&collector.drops, &new_sprites);
    for &layer_id in collector.layers.keys() {
        collector.clips.insert(layer_id, json!({"origin": null, "frames": [[]]}).as_object().unwrap().clone());
    }
    let mut bases = SwfFile::from_bytes(&windows)?;
    for (&sprite_id, clip) in collector.clips.iter_mut() {
        let origin = bases.character_bounds(sprite_id).map_or(Value::Null, |b| json!([b[0] / 20.0, b[1] / 20.0]));
        clip.insert("origin".into(), origin);
    }
    let fonts: IndexMap<&String, u16> = swf.fonts.iter().map(|(&id, name)| (name, id)).collect();
    let clips: Map<String, Value> = collector.clips.into_iter().map(|(id, clip)| (id.to_string(), Value::Object(clip))).collect();
    let buttons: Map<String, Value> = collector.buttons.into_iter().map(|(id, button)| (id.to_string(), button)).collect();
    let count = clips.len() + buttons.len();
    let layout = json!({"symbols": symbols, "fonts": fonts, "clips": clips, "buttons": buttons});
    Ok(Windows { swf: windows, layout, count })
}

/// The sprite id of a symbol, or of a child named by a path such as GuiMC/bgBar/btnExit.
fn resolve(swf: &SwfFile, name: &str) -> Result<u16, String> {
    let mut parts = name.split('/');
    let first = parts.next().unwrap_or_default();
    let mut sprite_id = *swf.symbols.get(first).ok_or_else(|| format!("symbol '{first}' is not exported"))?;
    for child in parts {
        sprite_id = swf.named_child(sprite_id, child)?;
    }
    Ok(sprite_id)
}

fn depth_of(part: &Map<String, Value>) -> u16 {
    part["depth"].as_u64().unwrap() as u16
}

fn key_of(depth: u16, place: &Place) -> PlaceKey {
    (depth, place.char_id, place.name.clone())
}

/// Adds the sprite and its named sprites to the clips, and its buttons to
/// the buttons. The drops get the placements that the base images leave
/// out: named parts, text fields and buttons. A named mask, for example of a
/// bar that the client scales, gets the shapes under it in the first frame
/// as a sprite of its own: the layers get it, the part gets "masked": the
/// new sprite id, and the base image leaves the shapes out.
fn collect(swf: &mut SwfFile, sprite_id: u16, state: &mut Collector) {
    if state.clips.contains_key(&sprite_id) {
        return;
    }
    // The clip keeps its place in the order of the clips, before its children.
    state.clips.insert(sprite_id, Map::new());
    let places = swf.sprite_frames(sprite_id);
    let mut clip = Map::new();
    clip.insert("origin".into(), Value::Null);
    // Labels are 1-based frame numbers in the SWF file; the layout counts from 0.
    let labels: Map<String, Value> = swf.sprite_frame_labels(sprite_id).into_iter().map(|(label, frame)| (label, json!(frame - 1))).collect();
    let mut frames: Vec<Vec<Map<String, Value>>> = Vec::new();
    let mut dropped: HashSet<PlaceKey> = HashSet::new();
    let mut nested = Vec::new();
    for (index, frame) in places.frames.iter().enumerate() {
        let mut parts = Vec::new();
        let mut depths: Vec<u16> = frame.keys().copied().collect();
        depths.sort();
        for depth in depths {
            let place = &frame[&depth];
            let m = place.matrix;
            let mut part = Map::new();
            part.insert("name".into(), place.name.as_ref().map_or(Value::Null, |n| json!(n)));
            part.insert("depth".into(), json!(depth));
            part.insert("matrix".into(), json!([m[0], m[1], m[2], m[3], m[4] / 20.0, m[5] / 20.0]));
            if let Some(alpha) = places.alphas[index].get(&depth) {
                part.insert("alpha".into(), json!(alpha));
            }
            let start = places.starts[index][&depth];
            if start > 0 {
                part.insert("start".into(), json!(start));
            }
            if let Some((color, blur, strength)) = places.glows[index].get(&depth) {
                part.insert("glow".into(), json!([color, blur, strength]));
            }
            if places.details.get(&depth).is_some_and(|d| d.clip_depth.is_some()) {
                part.insert("mask".into(), json!(true));
            }
            let char_id = place.char_id;
            if swf.edit_texts.contains_key(&char_id) {
                part.insert("text".into(), swf.edit_text(char_id));
            } else if place.name.is_some() && swf.sprites.contains_key(&char_id) {
                part.insert("clip".into(), json!(char_id));
                nested.push(char_id);
            } else if swf.buttons.contains_key(&char_id) {
                // The drawing of a sprite leaves out its buttons, so unnamed
                // buttons are parts too, for example the icons of the HUD menus.
                part.insert("button".into(), json!(char_id));
                state.buttons.insert(char_id, json!({}));
            } else {
                continue;
            }
            dropped.insert(key_of(depth, place));
            parts.push(part);
        }
        frames.push(parts);
    }
    if let Some(first_places) = places.frames.first() {
        let named: HashSet<u16> = frames[0].iter().map(depth_of).collect();
        for i in 0..frames[0].len() {
            let part = &frames[0][i];
            let clip_depth = places.details.get(&depth_of(part)).and_then(|d| d.clip_depth);
            let (Some(clip_depth), true, Some(name)) = (clip_depth, part.contains_key("mask"), part["name"].as_str()) else { continue };
            let part_depth = depth_of(part);
            let name = name.to_string();
            let masked: HashSet<u16> =
                first_places.keys().copied().filter(|&d| part_depth < d && d <= clip_depth && !named.contains(&d)).collect();
            if masked.is_empty() {
                continue;
            }
            let layer_id = state.next_id;
            state.next_id += 1;
            dropped.extend(masked.iter().map(|&d| key_of(d, &first_places[&d])));
            state.layers.insert(layer_id, (sprite_id, masked));
            for other in frames.iter_mut().flatten() {
                if other["name"].as_str() == Some(&name) && other.contains_key("mask") {
                    other.insert("masked".into(), json!(layer_id));
                }
            }
        }
        // A shape that masks parts, for example the picture that the client
        // loads into an anchor. The port cuts the pictures to its bounds.
        for (&depth, place) in first_places {
            let Some(clip_depth) = places.details.get(&depth).and_then(|d| d.clip_depth) else { continue };
            if named.contains(&depth) {
                continue;
            }
            let Some(bounds) = swf.character_bounds(place.char_id) else { continue };
            let r = transform(bounds, place.matrix);
            let rect = json!([r[0] / 20.0, r[1] / 20.0, r[2] / 20.0, r[3] / 20.0]);
            for part in frames.iter_mut().flatten() {
                let part_depth = depth_of(part);
                if depth < part_depth && part_depth <= clip_depth {
                    part.insert("clip_rect".into(), rect.clone());
                }
            }
        }
    }
    if places.frames.len() == 1 {
        split_above_anchors(swf, sprite_id, &places.frames[0], &mut frames[0], &mut dropped, state);
    }
    // A part below all shapes of the base image, for example a faded panel
    // behind the drawing, is "under": the port draws it before the base image.
    for (frame, parts) in places.frames.iter().zip(frames.iter_mut()) {
        let base = frame.iter().filter(|(d, p)| !dropped.contains(&key_of(**d, p))).map(|(d, _)| *d).min();
        if let Some(base) = base {
            for part in parts.iter_mut() {
                if depth_of(part) < base {
                    part.insert("under".into(), json!(true));
                }
            }
        }
    }
    clip.insert("frames".into(), Value::Array(frames.into_iter().map(|parts| Value::Array(parts.into_iter().map(Value::Object).collect())).collect()));
    if !labels.is_empty() {
        clip.insert("labels".into(), Value::Object(labels));
    }
    state.clips.insert(sprite_id, clip);
    if !dropped.is_empty() {
        state.drops.insert(sprite_id, dropped);
    }
    for child_id in nested {
        collect(swf, child_id, state);
    }
}

/// The client loads pictures into empty named sprites (anchors). The base
/// image of the port is below all parts, so the shapes above the lowest
/// anchor, for example the numbers of the tips of PopupPvpHelp, become
/// sprites of their own (layers), one for each run of shapes between two
/// parts, and parts at the depth of their first shape. Only for sprites with
/// one frame.
fn split_above_anchors(
    swf: &SwfFile,
    sprite_id: u16,
    places: &IndexMap<u16, Place>,
    parts: &mut Vec<Map<String, Value>>,
    dropped: &mut HashSet<PlaceKey>,
    state: &mut Collector,
) {
    let is_anchor = |part: &&Map<String, Value>| part.get("clip").and_then(Value::as_u64).is_some_and(|clip| swf.is_empty_sprite(clip as u16));
    let Some(lowest) = parts.iter().filter(is_anchor).map(depth_of).min() else { return };
    let mut depths: Vec<u16> = places.keys().copied().collect();
    depths.sort();
    let mut run = Vec::new();
    let mut new_parts = Vec::new();
    for depth in depths {
        if depth <= lowest {
            continue;
        }
        if !dropped.contains(&key_of(depth, &places[&depth])) {
            run.push(depth);
            continue;
        }
        if !run.is_empty() {
            new_parts.push(layer_part(sprite_id, &run, places, dropped, state));
            run.clear();
        }
    }
    if !run.is_empty() {
        new_parts.push(layer_part(sprite_id, &run, places, dropped, state));
    }
    parts.extend(new_parts);
    parts.sort_by_key(depth_of);
}

fn layer_part(sprite_id: u16, depths: &[u16], places: &IndexMap<u16, Place>, dropped: &mut HashSet<PlaceKey>, state: &mut Collector) -> Map<String, Value> {
    let layer_id = state.next_id;
    state.next_id += 1;
    state.layers.insert(layer_id, (sprite_id, depths.iter().copied().collect()));
    dropped.extend(depths.iter().map(|&d| key_of(d, &places[&d])));
    json!({"name": null, "depth": depths[0], "matrix": [1, 0, 0, 1, 0, 0], "clip": layer_id}).as_object().unwrap().clone()
}
