//! Color transforms of Flash: each channel becomes channel * multiply + add,
//! on colors that are not premultiplied, with channels from 0 to 255.

use tiny_skia::{Color, Pixmap};

#[derive(Clone, Copy, PartialEq, Debug)]
pub struct ColorTransform {
    pub mult: [f32; 4],
    pub add: [f32; 4],
}

impl ColorTransform {
    pub const IDENTITY: ColorTransform = ColorTransform { mult: [1.0; 4], add: [0.0; 4] };

    pub fn from_swf(c: &swf::ColorTransform) -> ColorTransform {
        ColorTransform {
            mult: [c.r_multiply.to_f32(), c.g_multiply.to_f32(), c.b_multiply.to_f32(), c.a_multiply.to_f32()],
            add: [c.r_add as f32, c.g_add as f32, c.b_add as f32, c.a_add as f32],
        }
    }

    /// The transform that applies child first, then self, as Flash does with the transform of a parent.
    pub fn then_child(&self, child: &ColorTransform) -> ColorTransform {
        let mut result = ColorTransform::IDENTITY;
        for i in 0..4 {
            result.mult[i] = self.mult[i] * child.mult[i];
            result.add[i] = self.mult[i] * child.add[i] + self.add[i];
        }
        result
    }

    pub fn is_identity(&self) -> bool {
        *self == ColorTransform::IDENTITY
    }

    /// True when the transform changes only the alpha, by a factor.
    pub fn is_alpha_only(&self) -> bool {
        self.mult[0] == 1.0 && self.mult[1] == 1.0 && self.mult[2] == 1.0 && self.add == [0.0; 4]
    }

    pub fn apply_rgba8(&self, rgba: [u8; 4]) -> [u8; 4] {
        let mut out = [0u8; 4];
        for i in 0..4 {
            out[i] = (rgba[i] as f32 * self.mult[i] + self.add[i]).round().clamp(0.0, 255.0) as u8;
        }
        out
    }

    pub fn apply_color(&self, color: swf::Color) -> Color {
        let [r, g, b, a] = self.apply_rgba8([color.r, color.g, color.b, color.a]);
        Color::from_rgba8(r, g, b, a)
    }

    /// Applies the transform to premultiplied pixels.
    pub fn apply_pixmap(&self, pixmap: &mut Pixmap) {
        for pixel in pixmap.pixels_mut() {
            let straight = pixel.demultiply();
            let [r, g, b, a] = self.apply_rgba8([straight.red(), straight.green(), straight.blue(), straight.alpha()]);
            *pixel = tiny_skia::ColorU8::from_rgba(r, g, b, a).premultiply();
        }
    }
}
