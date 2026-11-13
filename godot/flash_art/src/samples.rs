//! An image with four samples in each pixel, as the 4x multisampling of
//! Ruffle (MSAA). A shape covers each sample fully or not at all; its color
//! comes from the center of the pixel. resolve() averages the samples.
//!
//! This gives the edges of Ruffle (five steps of alpha), and no thin gaps
//! between two shapes that touch: with one coverage value for each pixel,
//! two shapes that each cover half a pixel leave a quarter of it empty.

use tiny_skia::{FillRule, Mask, MaskType, Paint, Path, Pixmap, PixmapPaint, Stroke, Transform};

/// The standard sample positions of 4x multisampling, in a pixel from (0, 0) to (1, 1).
const POSITIONS: [(f32, f32); 4] = [(0.375, 0.125), (0.875, 0.375), (0.125, 0.625), (0.625, 0.875)];

/// The masks of the four samples.
pub type Masks = [Mask; 4];

pub struct Samples {
    planes: [Pixmap; 4],
}

impl Samples {
    pub fn new(width: u32, height: u32) -> Option<Samples> {
        let plane = Pixmap::new(width, height)?;
        Some(Samples { planes: [plane.clone(), plane.clone(), plane.clone(), plane] })
    }

    pub fn width(&self) -> u32 {
        self.planes[0].width()
    }

    pub fn height(&self) -> u32 {
        self.planes[0].height()
    }

    pub fn fill_path(&mut self, path: &Path, paint: &Paint, transform: Transform, masks: Option<&Masks>) {
        self.each(paint, transform, masks, |plane, paint, transform, mask| plane.fill_path(path, paint, FillRule::EvenOdd, transform, mask));
    }

    pub fn stroke_path(&mut self, path: &Path, paint: &Paint, stroke: &Stroke, transform: Transform, masks: Option<&Masks>) {
        self.each(paint, transform, masks, |plane, paint, transform, mask| plane.stroke_path(path, paint, stroke, transform, mask));
    }

    /// Draws with each sample plane. The shape moves so that the center of a
    /// pixel of the plane is at the sample position; the paint moves back, so
    /// that its color comes from the center of the pixel.
    fn each(&mut self, paint: &Paint, transform: Transform, masks: Option<&Masks>, draw: impl Fn(&mut Pixmap, &Paint, Transform, Option<&Mask>)) {
        let inverse = transform.invert();
        for (i, plane) in self.planes.iter_mut().enumerate() {
            let (dx, dy) = (POSITIONS[i].0 - 0.5, POSITIONS[i].1 - 0.5);
            let moved = transform.post_translate(-dx, -dy);
            let mut paint = paint.clone();
            if let Some(inverse) = inverse {
                paint.shader.transform(inverse.pre_concat(Transform::from_translate(dx, dy)).pre_concat(transform));
            }
            draw(plane, &paint, moved, masks.map(|m| &m[i]));
        }
    }

    /// Puts an image on all samples of its pixels.
    pub fn draw_pixmap(&mut self, x: i32, y: i32, pixmap: &Pixmap, paint: &PixmapPaint, masks: Option<&Masks>) {
        for (i, plane) in self.planes.iter_mut().enumerate() {
            plane.draw_pixmap(x, y, pixmap.as_ref(), paint, Transform::identity(), masks.map(|m| &m[i]));
        }
    }

    /// The masks of the samples from the alpha of this image, within outer masks.
    pub fn masks(&self, outer: Option<&Masks>) -> Masks {
        std::array::from_fn(|i| {
            let mut mask = Mask::from_pixmap(self.planes[i].as_ref(), MaskType::Alpha);
            if let Some(outer) = outer {
                for (value, &o) in mask.data_mut().iter_mut().zip(outer[i].data()) {
                    *value = ((*value as u32 * o as u32 + 127) / 255) as u8;
                }
            }
            mask
        })
    }

    /// Mixes an image with the pixels of the samples by a blend function of
    /// one color channel (backdrop, source, both from 0 to 1). Only where the
    /// samples have pixels, and with their alpha: the image does not add
    /// pixels (as "source atop").
    pub fn blend_atop(&mut self, image: &Pixmap, blend: impl Fn(f32, f32) -> f32) {
        for plane in &mut self.planes {
            for (b, s) in plane.pixels_mut().iter_mut().zip(image.pixels()) {
                let (back_alpha, source_alpha) = (b.alpha() as f32 / 255.0, s.alpha() as f32 / 255.0);
                if back_alpha == 0.0 || source_alpha == 0.0 {
                    continue;
                }
                let channel = |pb: u8, ps: u8| {
                    let (cb, cs) = ((pb as f32 / 255.0 / back_alpha).min(1.0), (ps as f32 / 255.0 / source_alpha).min(1.0));
                    let mixed = (1.0 - source_alpha) * cb + source_alpha * blend(cb, cs);
                    (mixed * back_alpha * 255.0).round().clamp(0.0, b.alpha() as f32) as u8
                };
                *b = tiny_skia::PremultipliedColorU8::from_rgba(channel(b.red(), s.red()), channel(b.green(), s.green()), channel(b.blue(), s.blue()), b.alpha()).unwrap();
            }
        }
    }

    /// The image with the average of the samples of each pixel.
    pub fn resolve(&self) -> Pixmap {
        let mut out = self.planes[0].clone();
        let [_, b, c, d] = &self.planes;
        for (i, v) in out.data_mut().iter_mut().enumerate() {
            let sum = *v as u32 + b.data()[i] as u32 + c.data()[i] as u32 + d.data()[i] as u32;
            *v = ((sum + 2) / 4) as u8;
        }
        out
    }
}
