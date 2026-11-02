//! Writes a SWF file whose main timeline shows one symbol of another SWF file
//! on a stage of the size of its canvas, so that other players (for example
//! the Ruffle exporter) draw the same frames as the `render` example.
//! cargo run --release --no-default-features --example stage -- <file.swf> <symbol name or id> <out.swf> <background RRGGBB> [frames]
//!
//! The definition tags are copied without change. Scripts, class names and the
//! old main timeline are removed, because this renderer does not run scripts.
//! Frame n of the new main timeline shows frame n of the symbol, with the
//! nested sprites at the same age as in `Art::render`. The main timeline has
//! the frames of the symbol, or [frames] frames, to show the frames after a loop.

use std::io::Read;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let file = std::fs::read(&args[1]).unwrap();
    let art = flash_art::Art::load(&file).unwrap();
    let id = args[2].parse().ok().or_else(|| art.symbol(&args[2])).expect("no such symbol");
    let canvas = art.canvas(id).expect("nothing to draw");
    let background = u32::from_str_radix(&args[4], 16).expect("background is RRGGBB");
    let frames: u16 = args.get(5).map_or(art.frame_count(id) as u16, |f| f.parse().expect("frames is a number"));

    let version = file[3];
    let body = match &file[..3] {
        b"FWS" => file[8..].to_vec(),
        b"CWS" => {
            let mut body = Vec::new();
            flate2::read::ZlibDecoder::new(&file[8..]).read_to_end(&mut body).unwrap();
            body
        }
        _ => panic!("only FWS and CWS files"),
    };
    // Skip the stage rectangle, the frame rate and the frame count of the old header.
    let rect_bits = 5 + 4 * (body[0] >> 3) as usize;
    let mut at = rect_bits.div_ceil(8) + 4;

    let mut tags = Vec::new();
    while at < body.len() {
        let code_len = u16::from_le_bytes([body[at], body[at + 1]]);
        let (code, mut len, mut head) = (code_len >> 6, (code_len & 0x3f) as usize, 2);
        if len == 0x3f {
            len = u32::from_le_bytes(body[at + 2..at + 6].try_into().unwrap()) as usize;
            head = 6;
        }
        let end = at + head + len;
        if !REMOVED.contains(&code) {
            tags.extend_from_slice(&body[at..end]);
        }
        at = end;
        if code == 0 {
            break;
        }
    }

    tags.extend(tag(9, &background.to_be_bytes()[1..]));
    let mut place = vec![0x06]; // PlaceObject2 with a character and a matrix
    place.extend(1u16.to_le_bytes());
    place.extend(id.to_le_bytes());
    place.extend(translate((-canvas.x * 20.0).round() as i32, (-canvas.y * 20.0).round() as i32));
    tags.extend(tag(26, &place));
    for _ in 0..frames {
        tags.extend(tag(1, &[]));
    }
    tags.extend(tag(0, &[]));

    let mut header = rectangle(canvas.width as i32 * 20, canvas.height as i32 * 20);
    header.extend([0, 24]); // 24 frames per second, as 8.8 fixed point
    header.extend(frames.to_le_bytes());
    let length = 8 + header.len() + tags.len();
    let mut out = b"FWS".to_vec();
    out.push(version);
    out.extend((length as u32).to_le_bytes());
    out.extend(header);
    out.extend(tags);
    std::fs::write(&args[3], out).unwrap();
    println!("{{\"x\": {}, \"y\": {}, \"width\": {}, \"height\": {}, \"frames\": {}}}", canvas.x, canvas.y, canvas.width, canvas.height, frames);
}

/// Tags of the main timeline and of scripts: End, ShowFrame, PlaceObject,
/// RemoveObject, SetBackgroundColor, DoAction, Protect, FrameLabel,
/// PlaceObject2, RemoveObject2, DoInitAction, EnableDebugger, EnableDebugger2,
/// PlaceObject3, DoAbc, SymbolClass, DoAbc2, DefineSceneAndFrameLabelData.
const REMOVED: [u16; 18] = [0, 1, 4, 5, 9, 12, 24, 43, 26, 28, 59, 58, 64, 70, 72, 76, 82, 86];

fn tag(code: u16, data: &[u8]) -> Vec<u8> {
    let mut out = ((code << 6) | 0x3f).to_le_bytes().to_vec();
    out.extend((data.len() as u32).to_le_bytes());
    out.extend_from_slice(data);
    out
}

#[derive(Default)]
struct Bits {
    bytes: Vec<u8>,
    used: usize,
}

impl Bits {
    fn put(&mut self, value: i32, count: usize) {
        for i in (0..count).rev() {
            if self.used.is_multiple_of(8) {
                self.bytes.push(0);
            }
            if (value >> i) & 1 == 1 {
                *self.bytes.last_mut().unwrap() |= 0x80 >> (self.used % 8);
            }
            self.used += 1;
        }
    }
}

/// The number of bits of a signed value in a SWF bit field.
fn signed_bits(values: &[i32]) -> usize {
    values.iter().map(|v| 33 - if *v < 0 { v.leading_ones() } else { v.leading_zeros() } as usize).max().unwrap_or(1)
}

fn rectangle(width: i32, height: i32) -> Vec<u8> {
    let n = signed_bits(&[width, height]);
    let mut bits = Bits::default();
    bits.put(n as i32, 5);
    for v in [0, width, 0, height] {
        bits.put(v, n);
    }
    bits.bytes
}

fn translate(x: i32, y: i32) -> Vec<u8> {
    let n = signed_bits(&[x, y]);
    let mut bits = Bits::default();
    bits.put(0, 2); // no scale, no rotation
    bits.put(n as i32, 5);
    bits.put(x, n);
    bits.put(y, n);
    bits.bytes
}
