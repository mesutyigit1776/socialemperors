//! Decodes the bitmaps of a SWF file to premultiplied pixels.

use std::io::Read;

use swf::{BitmapFormat, DefineBitsLossless};
use tiny_skia::{ColorU8, Pixmap, PremultipliedColorU8};

/// The encoded data of a bitmap. It is decoded when a shape first draws it.
pub enum BitmapData {
    /// JPEG, PNG or GIF data, with the zlib-compressed alpha of DefineBitsJPEG3.
    Encoded { data: Vec<u8>, alpha: Option<Vec<u8>> },
    Lossless { version: u8, format: BitmapFormat, width: u32, height: u32, data: Vec<u8> },
}

impl BitmapData {
    pub fn jpeg(data: &[u8], tables: Option<&[u8]>, alpha: Option<&[u8]>) -> BitmapData {
        let data = match tables {
            // DefineBits keeps the JPEG tables in one tag for the whole file:
            // the tables end with an end marker, the image starts with a start marker.
            Some(tables) if tables.len() >= 2 && data.len() >= 2 => [&tables[..tables.len() - 2], &data[2..]].concat(),
            _ => data.to_vec(),
        };
        BitmapData::Encoded { data, alpha: alpha.map(|a| a.to_vec()) }
    }

    pub fn lossless(b: &DefineBitsLossless) -> BitmapData {
        BitmapData::Lossless { version: b.version, format: b.format, width: b.width as u32, height: b.height as u32, data: b.data.to_vec() }
    }
}

pub fn decode(bitmap: &BitmapData) -> Option<Pixmap> {
    match bitmap {
        BitmapData::Encoded { data, alpha } => {
            let mut pixmap = if data.starts_with(b"\x89PNG") {
                decode_png(data)?
            } else if data.starts_with(b"GIF8") {
                // The art of the game has no GIF images.
                return None;
            } else {
                decode_jpeg(data)?
            };
            if let Some(alpha) = alpha {
                apply_alpha(&mut pixmap, alpha);
            }
            Some(pixmap)
        }
        BitmapData::Lossless { version, format, width, height, data } => decode_lossless(*version, *format, *width, *height, data),
    }
}

fn decode_jpeg(data: &[u8]) -> Option<Pixmap> {
    // Before SWF 8, the Flash tools could write the bytes FF D9 FF D8 before the
    // start of a JPEG image, and some files also have them inside the data.
    let mut data = data;
    while data.starts_with(&[0xFF, 0xD9, 0xFF, 0xD8]) {
        data = &data[4..];
    }
    let decoded = jpeg_pixels(data).or_else(|| {
        let mut cleaned = Vec::with_capacity(data.len());
        let mut i = 0;
        while i < data.len() {
            if i > 0 && data[i..].starts_with(&[0xFF, 0xD9, 0xFF, 0xD8]) {
                i += 4;
                continue;
            }
            cleaned.push(data[i]);
            i += 1;
        }
        jpeg_pixels(&cleaned)
    })?;
    let (width, height, pixels, format) = decoded;
    let mut pixmap = Pixmap::new(width, height)?;
    for (i, pixel) in pixmap.pixels_mut().iter_mut().enumerate() {
        let (r, g, b) = match format {
            jpeg_decoder::PixelFormat::L8 => (pixels[i], pixels[i], pixels[i]),
            jpeg_decoder::PixelFormat::RGB24 => (pixels[i * 3], pixels[i * 3 + 1], pixels[i * 3 + 2]),
            jpeg_decoder::PixelFormat::CMYK32 => {
                let [c, m, y, k] = [pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3]];
                let f = |v: u8| ((255 - v as u32) * (255 - k as u32) / 255) as u8;
                (f(c), f(m), f(y))
            }
            jpeg_decoder::PixelFormat::L16 => (pixels[i * 2], pixels[i * 2], pixels[i * 2]),
        };
        *pixel = PremultipliedColorU8::from_rgba(r, g, b, 255).unwrap();
    }
    Some(pixmap)
}

fn jpeg_pixels(data: &[u8]) -> Option<(u32, u32, Vec<u8>, jpeg_decoder::PixelFormat)> {
    let mut decoder = jpeg_decoder::Decoder::new(data);
    let pixels = decoder.decode().ok()?;
    let info = decoder.info()?;
    Some((info.width as u32, info.height as u32, pixels, info.pixel_format))
}

/// DefineBitsJPEG3: one byte of alpha for each pixel, zlib-compressed. The
/// colors of the JPEG image are already multiplied by the alpha.
fn apply_alpha(pixmap: &mut Pixmap, compressed: &[u8]) {
    let mut alpha = Vec::new();
    if flate2::read::ZlibDecoder::new(compressed).read_to_end(&mut alpha).is_err() || alpha.len() < pixmap.pixels().len() {
        return;
    }
    for (pixel, &a) in pixmap.pixels_mut().iter_mut().zip(alpha.iter()) {
        let (r, g, b) = (pixel.red().min(a), pixel.green().min(a), pixel.blue().min(a));
        *pixel = PremultipliedColorU8::from_rgba(r, g, b, a).unwrap();
    }
}

fn decode_png(data: &[u8]) -> Option<Pixmap> {
    let mut decoder = png::Decoder::new(std::io::Cursor::new(data));
    decoder.set_transformations(png::Transformations::EXPAND | png::Transformations::STRIP_16);
    let mut reader = decoder.read_info().ok()?;
    let mut buffer = vec![0; reader.output_buffer_size()?];
    let info = reader.next_frame(&mut buffer).ok()?;
    let mut pixmap = Pixmap::new(info.width, info.height)?;
    let channels = info.color_type.samples();
    for (i, pixel) in pixmap.pixels_mut().iter_mut().enumerate() {
        let p = &buffer[i * channels..(i + 1) * channels];
        let color = match channels {
            1 => ColorU8::from_rgba(p[0], p[0], p[0], 255),
            2 => ColorU8::from_rgba(p[0], p[0], p[0], p[1]),
            3 => ColorU8::from_rgba(p[0], p[1], p[2], 255),
            _ => ColorU8::from_rgba(p[0], p[1], p[2], p[3]),
        };
        *pixel = color.premultiply();
    }
    Some(pixmap)
}

/// DefineBitsLossless (version 1, no alpha) and DefineBitsLossless2 (version 2,
/// premultiplied alpha). Rows of the color-map and 15-bit formats are padded to 4 bytes.
fn decode_lossless(version: u8, format: BitmapFormat, width: u32, height: u32, compressed: &[u8]) -> Option<Pixmap> {
    let mut data = Vec::new();
    flate2::read::ZlibDecoder::new(compressed).read_to_end(&mut data).ok()?;
    let mut pixmap = Pixmap::new(width, height)?;
    let (w, h) = (width as usize, height as usize);
    let pixels = pixmap.pixels_mut();
    match format {
        BitmapFormat::ColorMap8 { num_colors } => {
            let entry = if version == 1 { 3 } else { 4 };
            let palette_size = (num_colors as usize + 1) * entry;
            let stride = (w + 3) & !3;
            if data.len() < palette_size + stride * h {
                return None;
            }
            let palette: Vec<PremultipliedColorU8> = data[..palette_size]
                .chunks(entry)
                .map(|c| {
                    let a = if entry == 4 { c[3] } else { 255 };
                    PremultipliedColorU8::from_rgba(c[0].min(a), c[1].min(a), c[2].min(a), a).unwrap()
                })
                .collect();
            for y in 0..h {
                for x in 0..w {
                    let index = data[palette_size + y * stride + x] as usize;
                    pixels[y * w + x] = palette.get(index).copied().unwrap_or(PremultipliedColorU8::TRANSPARENT);
                }
            }
        }
        BitmapFormat::Rgb15 => {
            let stride = (w * 2 + 3) & !3;
            if data.len() < stride * h {
                return None;
            }
            for y in 0..h {
                for x in 0..w {
                    let v = u16::from_be_bytes([data[y * stride + x * 2], data[y * stride + x * 2 + 1]]);
                    let c = |shift: u16| (((v >> shift) & 0x1F) as u32 * 255 / 31) as u8;
                    pixels[y * w + x] = PremultipliedColorU8::from_rgba(c(10), c(5), c(0), 255).unwrap();
                }
            }
        }
        BitmapFormat::Rgb32 => {
            if data.len() < w * h * 4 {
                return None;
            }
            for (pixel, c) in pixels.iter_mut().zip(data.chunks_exact(4)) {
                let a = if version == 1 { 255 } else { c[0] };
                *pixel = PremultipliedColorU8::from_rgba(c[1].min(a), c[2].min(a), c[3].min(a), a).unwrap();
            }
        }
    }
    Some(pixmap)
}
