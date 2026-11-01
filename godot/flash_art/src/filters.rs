//! The filters of Flash on a layer of premultiplied pixels: blur, glow, drop
//! shadow, bevel, gradient glow and color matrix. Their sizes are in pixels
//! of Flash; scale gives the pixels of the image for one of them.

use swf::Filter;
use tiny_skia::{Pixmap, PremultipliedColorU8};

/// False for a filter that does not change the image, as many in the art of the game.
pub fn is_active(filter: &Filter) -> bool {
    match filter {
        Filter::BlurFilter(f) => !f.impotent(),
        Filter::GlowFilter(f) => f.is_knockout() || (f.strength.to_f32() > 0.0 && f.color.a > 0),
        Filter::DropShadowFilter(f) => f.is_knockout() || f.hide_object() || (f.strength.to_f32() > 0.0 && f.color.a > 0),
        Filter::BevelFilter(f) => f.is_knockout() || f.strength.to_f32() > 0.0,
        Filter::GradientGlowFilter(f) => f.is_knockout() || f.strength.to_f32() > 0.0,
        Filter::ColorMatrixFilter(f) => f.matrix != IDENTITY_MATRIX,
        // Convolution and gradient bevel filters are not in the art of the game.
        _ => false,
    }
}

const IDENTITY_MATRIX: [f32; 20] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0];

/// How far in pixels of the image the filter can draw outside the object.
pub fn margin(filter: &Filter, scale: f32) -> (f32, f32) {
    let blur = |x: f32, y: f32, passes: u8| (x * scale / 2.0 * passes.max(1) as f32, y * scale / 2.0 * passes.max(1) as f32);
    let offset = |angle: f32, distance: f32| ((angle.cos() * distance * scale).abs(), (angle.sin() * distance * scale).abs());
    match filter {
        Filter::BlurFilter(f) => blur(f.blur_x.to_f32(), f.blur_y.to_f32(), f.num_passes()),
        Filter::GlowFilter(f) => blur(f.blur_x.to_f32(), f.blur_y.to_f32(), f.num_passes()),
        Filter::DropShadowFilter(f) => {
            let (bx, by) = blur(f.blur_x.to_f32(), f.blur_y.to_f32(), f.num_passes());
            let (ox, oy) = offset(f.angle.to_f32(), f.distance.to_f32());
            (bx + ox, by + oy)
        }
        Filter::BevelFilter(f) => {
            let (bx, by) = blur(f.blur_x.to_f32(), f.blur_y.to_f32(), f.num_passes());
            let (ox, oy) = offset(f.angle.to_f32(), f.distance.to_f32());
            (bx + ox, by + oy)
        }
        Filter::GradientGlowFilter(f) => {
            let (bx, by) = blur(f.blur_x.to_f32(), f.blur_y.to_f32(), f.num_passes());
            let (ox, oy) = offset(f.angle.to_f32(), f.distance.to_f32());
            (bx + ox, by + oy)
        }
        _ => (0.0, 0.0),
    }
}

pub fn apply(layer: &mut Pixmap, filter: &Filter, scale: f32) {
    let (w, h) = (layer.width() as usize, layer.height() as usize);
    match filter {
        Filter::BlurFilter(f) => {
            let mut channels = split(layer);
            for channel in channels.iter_mut() {
                box_blur(channel, w, h, f.blur_x.to_f32() * scale, f.blur_y.to_f32() * scale, f.num_passes());
            }
            join(layer, &channels);
        }
        Filter::GlowFilter(f) => {
            let glow = Glow {
                color: [f.color.r, f.color.g, f.color.b, f.color.a],
                blur: (f.blur_x.to_f32() * scale, f.blur_y.to_f32() * scale),
                passes: f.num_passes(),
                strength: f.strength.to_f32(),
                inner: f.is_inner(),
                knockout: f.is_knockout(),
                show_object: true,
                offset: (0.0, 0.0),
                gradient: None,
            };
            glow.apply(layer);
        }
        Filter::DropShadowFilter(f) => {
            let (angle, distance) = (f.angle.to_f32(), f.distance.to_f32() * scale);
            let glow = Glow {
                color: [f.color.r, f.color.g, f.color.b, f.color.a],
                blur: (f.blur_x.to_f32() * scale, f.blur_y.to_f32() * scale),
                passes: f.num_passes(),
                strength: f.strength.to_f32(),
                inner: f.is_inner(),
                knockout: f.is_knockout(),
                show_object: !f.hide_object(),
                offset: (angle.cos() * distance, angle.sin() * distance),
                gradient: None,
            };
            glow.apply(layer);
        }
        Filter::GradientGlowFilter(f) => {
            let (angle, distance) = (f.angle.to_f32(), f.distance.to_f32() * scale);
            let glow = Glow {
                color: [255; 4],
                blur: (f.blur_x.to_f32() * scale, f.blur_y.to_f32() * scale),
                passes: f.num_passes(),
                strength: f.strength.to_f32(),
                inner: f.is_inner(),
                knockout: f.is_knockout(),
                show_object: true,
                offset: (angle.cos() * distance, angle.sin() * distance),
                gradient: Some(gradient_table(&f.colors)),
            };
            glow.apply(layer);
        }
        Filter::BevelFilter(f) => bevel(layer, f, scale),
        Filter::ColorMatrixFilter(f) => {
            let m = &f.matrix;
            for pixel in layer.pixels_mut() {
                let c = pixel.demultiply();
                let v = [c.red() as f32, c.green() as f32, c.blue() as f32, c.alpha() as f32];
                let row = |r: usize| (m[r * 5] * v[0] + m[r * 5 + 1] * v[1] + m[r * 5 + 2] * v[2] + m[r * 5 + 3] * v[3] + m[r * 5 + 4]).round().clamp(0.0, 255.0) as u8;
                *pixel = tiny_skia::ColorU8::from_rgba(row(0), row(1), row(2), row(3)).premultiply();
            }
        }
        _ => {}
    }
    let _ = (w, h);
}

/// Glow, drop shadow and gradient glow: a blurred copy of the alpha of the
/// object, in one color, behind the object (outer) or on it inside its edges (inner).
struct Glow {
    color: [u8; 4],
    blur: (f32, f32),
    passes: u8,
    strength: f32,
    inner: bool,
    knockout: bool,
    show_object: bool,
    offset: (f32, f32),
    /// For a gradient glow: the color for each strength of the glow.
    gradient: Option<Vec<[f32; 4]>>,
}

impl Glow {
    fn apply(&self, layer: &mut Pixmap) {
        let (w, h) = (layer.width() as usize, layer.height() as usize);
        let source: Vec<f32> = layer.pixels().iter().map(|p| p.alpha() as f32).collect();
        // An inner glow comes from the area outside the object.
        let mut alpha: Vec<f32> = shifted(&source, w, h, self.offset, if self.inner { 0.0 } else { 0.0 });
        if self.inner {
            let outside = shifted(&source.iter().map(|a| 255.0 - a).collect::<Vec<_>>(), w, h, self.offset, 255.0);
            alpha = outside;
        }
        box_blur(&mut alpha, w, h, self.blur.0, self.blur.1, self.passes);
        for (pixel, (a, s)) in layer.pixels_mut().iter_mut().zip(alpha.iter().zip(source.iter())) {
            let strength = (a * self.strength).clamp(0.0, 255.0) / 255.0;
            let (rgb, glow_alpha) = match &self.gradient {
                Some(table) => {
                    let c = table[(strength * 255.0).round() as usize];
                    ([c[0], c[1], c[2]], c[3])
                }
                None => ([self.color[0] as f32, self.color[1] as f32, self.color[2] as f32], strength * self.color[3] as f32 / 255.0),
            };
            let s = s / 255.0;
            // The glow as a premultiplied color, before it meets the object.
            let mut g = [rgb[0] * glow_alpha, rgb[1] * glow_alpha, rgb[2] * glow_alpha, glow_alpha * 255.0];
            let object = [pixel.red() as f32, pixel.green() as f32, pixel.blue() as f32, pixel.alpha() as f32];
            let keep = if self.inner { s } else { 1.0 - s };
            if self.inner || self.show_object {
                for v in g.iter_mut() {
                    *v *= keep;
                }
            }
            let out = if self.knockout || !self.show_object {
                g
            } else if self.inner {
                // On the object, inside its edges.
                let ga = g[3] / 255.0;
                [g[0] + object[0] * (1.0 - ga), g[1] + object[1] * (1.0 - ga), g[2] + object[2] * (1.0 - ga), g[3] + object[3] * (1.0 - ga)]
            } else {
                // Behind the object.
                [object[0] + g[0] * (1.0 - s), object[1] + g[1] * (1.0 - s), object[2] + g[2] * (1.0 - s), object[3] + g[3] * (1.0 - s)]
            };
            *pixel = premultiplied(out);
        }
    }
}

fn bevel(layer: &mut Pixmap, f: &swf::BevelFilter, scale: f32) {
    let (w, h) = (layer.width() as usize, layer.height() as usize);
    let source: Vec<f32> = layer.pixels().iter().map(|p| p.alpha() as f32).collect();
    let mut blurred = source.clone();
    box_blur(&mut blurred, w, h, f.blur_x.to_f32() * scale, f.blur_y.to_f32() * scale, f.num_passes());
    let (angle, distance) = (f.angle.to_f32(), f.distance.to_f32() * scale);
    let (dx, dy) = (angle.cos() * distance, angle.sin() * distance);
    // The light comes from the angle: the highlight is on the edges that face it, the shadow on the others.
    let toward = shifted(&blurred, w, h, (dx, dy), 0.0);
    let away = shifted(&blurred, w, h, (-dx, -dy), 0.0);
    let strength = f.strength.to_f32();
    let full = f.is_on_top();
    for (i, pixel) in layer.pixels_mut().iter_mut().enumerate() {
        let s = source[i] / 255.0;
        let highlight = ((away[i] - toward[i]) * strength / 255.0).clamp(0.0, 1.0);
        let shadow = ((toward[i] - away[i]) * strength / 255.0).clamp(0.0, 1.0);
        let keep = if full { 1.0 } else if f.is_inner() { s } else { 1.0 - s };
        let ha = highlight * f.highlight_color.a as f32 / 255.0 * keep;
        let sa = shadow * f.shadow_color.a as f32 / 255.0 * keep;
        let mut g = [0.0f32; 4];
        for (c, (hc, sc)) in [(f.highlight_color.r, f.shadow_color.r), (f.highlight_color.g, f.shadow_color.g), (f.highlight_color.b, f.shadow_color.b)].iter().enumerate() {
            g[c] = *hc as f32 * ha + *sc as f32 * sa;
        }
        g[3] = (ha + sa).min(1.0) * 255.0;
        let object = [pixel.red() as f32, pixel.green() as f32, pixel.blue() as f32, pixel.alpha() as f32];
        let out = if f.is_knockout() {
            g
        } else {
            let ga = g[3] / 255.0;
            [g[0] + object[0] * (1.0 - ga), g[1] + object[1] * (1.0 - ga), g[2] + object[2] * (1.0 - ga), g[3] + object[3] * (1.0 - ga)]
        };
        *pixel = premultiplied(out);
    }
}

fn premultiplied(v: [f32; 4]) -> PremultipliedColorU8 {
    let a = v[3].round().clamp(0.0, 255.0) as u8;
    let c = |x: f32| (x.round().clamp(0.0, 255.0) as u8).min(a);
    PremultipliedColorU8::from_rgba(c(v[0]), c(v[1]), c(v[2]), a).unwrap()
}

/// The colors of a gradient glow for each of 256 strengths, premultiplied by nothing: [r, g, b, alpha 0 to 1].
fn gradient_table(records: &[swf::GradientRecord]) -> Vec<[f32; 4]> {
    (0..256)
        .map(|i| {
            let i = i as f32;
            let after = records.iter().position(|r| r.ratio as f32 >= i);
            let pick = |r: &swf::GradientRecord| [r.color.r as f32, r.color.g as f32, r.color.b as f32, r.color.a as f32 / 255.0];
            match after {
                None => records.last().map(pick).unwrap_or([0.0; 4]),
                Some(0) => pick(&records[0]),
                Some(j) => {
                    let (a, b) = (&records[j - 1], &records[j]);
                    let t = (i - a.ratio as f32) / (b.ratio as f32 - a.ratio as f32).max(1.0);
                    let (pa, pb) = (pick(a), pick(b));
                    [pa[0] + (pb[0] - pa[0]) * t, pa[1] + (pb[1] - pa[1]) * t, pa[2] + (pb[2] - pa[2]) * t, pa[3] + (pb[3] - pa[3]) * t]
                }
            }
        })
        .collect()
}

/// The values moved by offset pixels, rounded; outside gets the value fill.
fn shifted(values: &[f32], w: usize, h: usize, offset: (f32, f32), fill: f32) -> Vec<f32> {
    let (dx, dy) = (offset.0.round() as isize, offset.1.round() as isize);
    if dx == 0 && dy == 0 {
        return values.to_vec();
    }
    let mut out = vec![fill; values.len()];
    for y in 0..h as isize {
        let sy = y - dy;
        if sy < 0 || sy >= h as isize {
            continue;
        }
        for x in 0..w as isize {
            let sx = x - dx;
            if sx >= 0 && sx < w as isize {
                out[y as usize * w + x as usize] = values[sy as usize * w + sx as usize];
            }
        }
    }
    out
}

fn split(layer: &Pixmap) -> [Vec<f32>; 4] {
    let pixels = layer.pixels();
    [
        pixels.iter().map(|p| p.red() as f32).collect(),
        pixels.iter().map(|p| p.green() as f32).collect(),
        pixels.iter().map(|p| p.blue() as f32).collect(),
        pixels.iter().map(|p| p.alpha() as f32).collect(),
    ]
}

fn join(layer: &mut Pixmap, channels: &[Vec<f32>; 4]) {
    for (i, pixel) in layer.pixels_mut().iter_mut().enumerate() {
        *pixel = premultiplied([channels[0][i], channels[1][i], channels[2][i], channels[3][i]]);
    }
}

/// The box blur of Flash: each pass averages a box of blur_x by blur_y
/// pixels around each pixel. A box of a size that is not whole counts its
/// two outer pixels in part.
pub fn box_blur(values: &mut [f32], w: usize, h: usize, blur_x: f32, blur_y: f32, passes: u8) {
    let mut line = Vec::new();
    for _ in 0..passes.max(1) {
        if blur_x > 1.0 {
            for y in 0..h {
                line.clear();
                line.extend_from_slice(&values[y * w..(y + 1) * w]);
                blur_line(&line, &mut values[y * w..(y + 1) * w], 1, blur_x);
            }
        }
        if blur_y > 1.0 {
            for x in 0..w {
                line.clear();
                line.extend((0..h).map(|y| values[y * w + x]));
                let mut out = vec![0.0; h];
                blur_line(&line, &mut out, 1, blur_y);
                for y in 0..h {
                    values[y * w + x] = out[y];
                }
            }
        }
    }
}

fn blur_line(input: &[f32], output: &mut [f32], _stride: usize, size: f32) {
    let n = input.len() as isize;
    let radius = (size - 1.0) / 2.0;
    let whole = radius.floor() as isize;
    let part = radius - whole as f32;
    let at = |i: isize| if i >= 0 && i < n { input[i as usize] } else { 0.0 };
    let mut sum: f32 = (-whole..=whole).map(at).sum();
    for i in 0..n {
        output[i as usize] = (sum + part * (at(i - whole - 1) + at(i + whole + 1))) / size;
        sum += at(i + whole + 1) - at(i - whole);
    }
}
