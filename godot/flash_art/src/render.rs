//! Draws a frame of a character: its shapes, nested sprites, masks, filters and blend modes.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use swf::{BlendMode, CharacterId, FillStyle, GradientSpread, LineCapStyle, LineJoinStyle, LineStyle};
use tiny_skia::{
    FillRule, FilterQuality, GradientStop, LinearGradient, Mask, MaskType, Paint, Pattern, Pixmap, PixmapPaint, Point, RadialGradient, Rect,
    Shader, SpreadMode, Stroke, Transform,
};

use crate::art::{self, Art, Character, Placed};
use crate::color::ColorTransform;
use crate::filters;
use crate::shape::{self, ShapeLayer};

/// The place of the frame images of a character: the top-left corner in
/// pixels relative to the registration point, and the size.
#[derive(Clone, Copy, Debug)]
pub struct Canvas {
    pub x: f32,
    pub y: f32,
    pub width: u32,
    pub height: u32,
}

/// The colors of a mask do not count: everything that it draws is opaque.
const MASK_COLOR: ColorTransform = ColorTransform { mult: [0.0; 4], add: [255.0; 4] };
/// Twips in one pixel.
const TWIPS: f32 = 20.0;

/// Morph shapes at each ratio that a frame showed.
#[derive(Default)]
pub struct MorphCache(Mutex<HashMap<(CharacterId, u16), Arc<Vec<ShapeLayer>>>>);

impl Art {
    /// The canvas of a character over all its frames: its bounds with the
    /// space of its filters, rounded up to whole pixels. It starts at the
    /// corner of the bounds, as the frames that the Flash tools export.
    pub fn canvas(&self, id: CharacterId) -> Option<Canvas> {
        let r = self.visual_bounds(id)?;
        Some(Canvas {
            x: r.left() / TWIPS,
            y: r.top() / TWIPS,
            width: (r.width() / TWIPS).ceil().max(1.0) as u32,
            height: (r.height() / TWIPS).ceil().max(1.0) as u32,
        })
    }

    /// Draws frame (from 0) of a character on a new image of the canvas, scaled.
    pub fn render(&self, id: CharacterId, frame: usize, canvas: Canvas, scale: f32) -> Option<Pixmap> {
        let width = ((canvas.width as f32 * scale).ceil() as u32).max(1);
        let height = ((canvas.height as f32 * scale).ceil() as u32).max(1);
        let mut pixmap = Pixmap::new(width, height)?;
        let transform = Transform::from_row(scale / TWIPS, 0.0, 0.0, scale / TWIPS, -canvas.x * scale, -canvas.y * scale);
        Renderer { art: self, scale }.draw(&mut pixmap, id, frame, 0, transform, &ColorTransform::IDENTITY, None);
        Some(pixmap)
    }
}

struct Renderer<'a> {
    art: &'a Art,
    /// Pixels of the image for each pixel of Flash. Filters are in pixels of Flash.
    scale: f32,
}

impl Renderer<'_> {
    /// transform: from twips of the character to pixels of the target.
    fn draw(&self, target: &mut Pixmap, id: CharacterId, frame: usize, ratio: u16, transform: Transform, color: &ColorTransform, mask: Option<&Mask>) {
        match self.art.characters.get(&id) {
            Some(Character::Shape { layers, .. }) => self.draw_shape(target, layers, transform, color, mask),
            Some(Character::Morph(_)) => {
                if let Some(layers) = self.morph(id, ratio) {
                    self.draw_shape(target, &layers, transform, color, mask);
                }
            }
            Some(Character::Sprite(sprite)) => {
                let list = &sprite.frames[frame.min(sprite.frames.len() - 1)];
                self.draw_list(target, list, frame, transform, color, mask);
            }
            _ => {}
        }
    }

    /// Draws a display list. A mask applies to the depths after it up to its clip depth.
    fn draw_list(&self, target: &mut Pixmap, list: &[Placed], frame: usize, transform: Transform, color: &ColorTransform, mask: Option<&Mask>) {
        let mut i = 0;
        while i < list.len() {
            let placed = &list[i];
            if placed.clip_depth == 0 {
                self.draw_placed(target, placed, frame, transform, color, mask);
                i += 1;
                continue;
            }
            let end = i + 1 + list[i + 1..].iter().take_while(|p| p.depth <= placed.clip_depth).count();
            if let Some(group_mask) = self.mask(target, placed, frame, transform, mask) {
                self.draw_list(target, &list[i + 1..end], frame, transform, color, Some(&group_mask));
            }
            i = end;
        }
    }

    fn draw_placed(&self, target: &mut Pixmap, placed: &Placed, parent_frame: usize, transform: Transform, color: &ColorTransform, mask: Option<&Mask>) {
        if !placed.visible {
            return;
        }
        let transform = transform.pre_concat(placed.matrix);
        let color = color.then_child(&placed.color);
        let frame = child_frame(self.art, placed, parent_frame);
        let active: Vec<&swf::Filter> = placed.filters.iter().filter(|f| filters::is_active(f)).collect();
        if active.is_empty() && matches!(placed.blend, BlendMode::Normal) {
            self.draw(target, placed.id, frame, placed.ratio, transform, &color, mask);
            return;
        }
        // Filters and blend modes work on the whole object: it is drawn on a
        // layer of its own, which is then changed and put on the target.
        let Some(bounds) = self.art.visual_bounds(placed.id).and_then(|b| transform_rect(b, transform)) else { return };
        let (mut margin_x, mut margin_y) = (1.0f32, 1.0f32);
        for filter in &active {
            let (x, y) = filters::margin(filter, self.scale);
            margin_x += x;
            margin_y += y;
        }
        let left = (bounds.left() - margin_x).max(-margin_x).floor() as i32;
        let top = (bounds.top() - margin_y).max(-margin_y).floor() as i32;
        let right = (bounds.right() + margin_x).min(target.width() as f32 + margin_x).ceil() as i32;
        let bottom = (bounds.bottom() + margin_y).min(target.height() as f32 + margin_y).ceil() as i32;
        if right <= left || bottom <= top {
            return;
        }
        let Some(mut layer) = Pixmap::new((right - left) as u32, (bottom - top) as u32) else { return };
        let layer_transform = transform.post_translate(-left as f32, -top as f32);
        self.draw(&mut layer, placed.id, frame, placed.ratio, layer_transform, &ColorTransform::IDENTITY, None);
        for filter in active {
            filters::apply(&mut layer, filter, self.scale);
        }
        let mut opacity = 1.0;
        if color.is_alpha_only() {
            opacity = color.mult[3].clamp(0.0, 1.0);
        } else {
            color.apply_pixmap(&mut layer);
        }
        let paint = PixmapPaint { opacity, blend_mode: blend_mode(placed.blend), quality: FilterQuality::Nearest };
        target.draw_pixmap(left, top, layer.as_ref(), &paint, Transform::identity(), mask);
    }

    /// The area that a mask covers on the target, within the outer mask.
    fn mask(&self, target: &Pixmap, placed: &Placed, parent_frame: usize, transform: Transform, outer: Option<&Mask>) -> Option<Mask> {
        let mut pixmap = Pixmap::new(target.width(), target.height())?;
        let frame = child_frame(self.art, placed, parent_frame);
        self.draw(&mut pixmap, placed.id, frame, placed.ratio, transform.pre_concat(placed.matrix), &MASK_COLOR, None);
        let mut mask = Mask::from_pixmap(pixmap.as_ref(), MaskType::Alpha);
        if let Some(outer) = outer {
            for (value, &o) in mask.data_mut().iter_mut().zip(outer.data()) {
                *value = ((*value as u32 * o as u32 + 127) / 255) as u8;
            }
        }
        Some(mask)
    }

    fn morph(&self, id: CharacterId, ratio: u16) -> Option<Arc<Vec<ShapeLayer>>> {
        let cache = &self.art.morphs;
        if let Some(found) = cache.0.lock().unwrap().get(&(id, ratio)) {
            return Some(found.clone());
        }
        let Some(Character::Morph(m)) = self.art.characters.get(&id) else { return None };
        let t = ratio as f32 / 65535.0;
        let styles = swf::ShapeStyles {
            fill_styles: m.start.fill_styles.iter().zip(&m.end.fill_styles).map(|(a, b)| lerp_fill(a, b, t)).collect(),
            line_styles: m
                .start
                .line_styles
                .iter()
                .zip(&m.end.line_styles)
                .map(|(a, b)| a.clone().with_width(swf::Twips::new(lerp(a.width().get() as f32, b.width().get() as f32, t).round() as i32)).with_fill_style(lerp_fill(a.fill_style(), b.fill_style(), t)))
                .collect(),
        };
        let layers = Arc::new(shape::convert(&styles, &shape::morph_records(&m.start.shape, &m.end.shape, t)));
        cache.0.lock().unwrap().insert((id, ratio), layers.clone());
        Some(layers)
    }

    fn draw_shape(&self, target: &mut Pixmap, layers: &[ShapeLayer], transform: Transform, color: &ColorTransform, mask: Option<&Mask>) {
        for layer in layers {
            for (style, path) in &layer.fills {
                self.with_paint(style, color, transform, |paint| target.fill_path(path, paint, FillRule::EvenOdd, transform, mask));
            }
            for (line, path) in &layer.strokes {
                let stroke = self.stroke(line, transform);
                self.with_paint(line.fill_style(), color, transform, |paint| target.stroke_path(path, paint, &stroke, transform, mask));
            }
        }
    }

    fn stroke(&self, line: &LineStyle, transform: Transform) -> Stroke {
        // Pixels of the target for one twip of the shape.
        let pixels_per_twip = (transform.sx * transform.sy - transform.kx * transform.ky).abs().sqrt();
        let mut width = line.width().get() as f32;
        if !line.allow_scale_x() && !line.allow_scale_y() && pixels_per_twip > 0.0 {
            width = width / TWIPS * self.scale / pixels_per_twip;
        }
        // Flash draws thinner lines one pixel wide; a width of 0 makes a line of one pixel.
        if width * pixels_per_twip < 1.0 {
            width = 0.0;
        }
        let cap = |c: LineCapStyle| match c {
            LineCapStyle::Round => tiny_skia::LineCap::Round,
            LineCapStyle::None => tiny_skia::LineCap::Butt,
            LineCapStyle::Square => tiny_skia::LineCap::Square,
        };
        let (line_join, miter_limit) = match line.join_style() {
            LineJoinStyle::Round => (tiny_skia::LineJoin::Round, 4.0),
            LineJoinStyle::Bevel => (tiny_skia::LineJoin::Bevel, 4.0),
            LineJoinStyle::Miter(limit) => (tiny_skia::LineJoin::Miter, limit.to_f32().max(1.0)),
        };
        Stroke { width, line_cap: cap(line.start_cap()), line_join, miter_limit, dash: None }
    }

    /// Calls draw with the paint of a fill style. Does nothing when the style
    /// cannot draw. transform: from the shape to the target.
    fn with_paint(&self, style: &FillStyle, color: &ColorTransform, transform: Transform, draw: impl FnOnce(&Paint)) {
        let mut paint = Paint { anti_alias: true, ..Paint::default() };
        let gradient = |g: &swf::Gradient| -> (Vec<GradientStop>, SpreadMode, Transform) {
            let stops = g.records.iter().map(|r| GradientStop::new(r.ratio as f32 / 255.0, color.apply_color(r.color))).collect();
            let spread = match g.spread {
                GradientSpread::Pad => SpreadMode::Pad,
                GradientSpread::Reflect => SpreadMode::Reflect,
                GradientSpread::Repeat => SpreadMode::Repeat,
            };
            (stops, spread, art::matrix(&g.matrix))
        };
        // The gradients of Flash fill a square from -16384 to 16384 twips, which their matrix places.
        const GRADIENT: f32 = 16384.0;
        let shader = match style {
            FillStyle::Color(c) => Some(Shader::SolidColor(color.apply_color(*c))),
            FillStyle::LinearGradient(g) => {
                let (stops, spread, matrix) = gradient(g);
                LinearGradient::new(Point::from_xy(-GRADIENT, 0.0), Point::from_xy(GRADIENT, 0.0), stops, spread, matrix)
            }
            FillStyle::RadialGradient(g) => {
                let (stops, spread, matrix) = gradient(g);
                RadialGradient::new(Point::zero(), Point::zero(), GRADIENT, stops, spread, matrix)
            }
            FillStyle::FocalGradient { gradient: g, focal_point } => {
                let (stops, spread, matrix) = gradient(g);
                RadialGradient::new(Point::from_xy(focal_point.to_f32() * GRADIENT, 0.0), Point::zero(), GRADIENT, stops, spread, matrix)
            }
            FillStyle::Bitmap { id, matrix, is_smoothed, is_repeating } => {
                let Some(bitmap) = self.art.bitmap(*id) else { return };
                let mut opacity = 1.0;
                let changed;
                let pixels = if color.is_identity() {
                    bitmap.as_ref()
                } else if color.is_alpha_only() {
                    opacity = color.mult[3];
                    bitmap.as_ref()
                } else {
                    let mut copy = (*bitmap).clone();
                    color.apply_pixmap(&mut copy);
                    changed = copy;
                    &changed
                };
                let spread = if *is_repeating { SpreadMode::Repeat } else { SpreadMode::Pad };
                let mut quality = if *is_smoothed { FilterQuality::Bilinear } else { FilterQuality::Nearest };
                let mut pattern = art::matrix(matrix);
                // Flash puts a bitmap that is not scaled or turned on whole pixels, so that it stays sharp.
                let on_target = transform.pre_concat(pattern);
                let unit = |v: f32| (v.abs() - 1.0).abs() < 0.001;
                if unit(on_target.sx) && unit(on_target.sy) && on_target.kx.abs() < 0.001 && on_target.ky.abs() < 0.001 {
                    let snapped = Transform::from_row(on_target.sx.signum(), 0.0, 0.0, on_target.sy.signum(), on_target.tx.round(), on_target.ty.round());
                    if let Some(inverse) = transform.invert() {
                        pattern = inverse.pre_concat(snapped);
                        quality = FilterQuality::Nearest;
                    }
                }
                paint.shader = Pattern::new(pixels.as_ref(), spread, quality, opacity, pattern);
                draw(&paint);
                return;
            }
        };
        if let Some(shader) = shader {
            paint.shader = shader;
            draw(&paint);
        }
    }
}

/// The frame of a nested sprite: it plays from the frame in which it was placed.
fn child_frame(art: &Art, placed: &Placed, parent_frame: usize) -> usize {
    let count = art.frame_count(placed.id);
    if count > 1 { parent_frame.saturating_sub(placed.start) % count } else { 0 }
}

fn blend_mode(mode: BlendMode) -> tiny_skia::BlendMode {
    use tiny_skia::BlendMode as B;
    match mode {
        BlendMode::Multiply => B::Multiply,
        BlendMode::Screen => B::Screen,
        BlendMode::Lighten => B::Lighten,
        BlendMode::Darken => B::Darken,
        BlendMode::Difference => B::Difference,
        BlendMode::Add => B::Plus,
        BlendMode::Overlay => B::Overlay,
        BlendMode::HardLight => B::HardLight,
        BlendMode::Alpha => B::DestinationIn,
        BlendMode::Erase => B::DestinationOut,
        // Subtract and Invert are not in the art of the game.
        _ => B::SourceOver,
    }
}

fn transform_rect(r: Rect, ts: Transform) -> Option<Rect> {
    let mut points = [Point::from_xy(r.left(), r.top()), Point::from_xy(r.right(), r.top()), Point::from_xy(r.left(), r.bottom()), Point::from_xy(r.right(), r.bottom())];
    ts.map_points(&mut points);
    let (mut l, mut t, mut rr, mut b) = (f32::MAX, f32::MAX, f32::MIN, f32::MIN);
    for p in points {
        l = l.min(p.x);
        t = t.min(p.y);
        rr = rr.max(p.x);
        b = b.max(p.y);
    }
    Rect::from_ltrb(l, t, rr, b)
}

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

fn lerp_fill(a: &FillStyle, b: &FillStyle, t: f32) -> FillStyle {
    let color = |a: &swf::Color, b: &swf::Color| swf::Color {
        r: lerp(a.r as f32, b.r as f32, t).round() as u8,
        g: lerp(a.g as f32, b.g as f32, t).round() as u8,
        b: lerp(a.b as f32, b.b as f32, t).round() as u8,
        a: lerp(a.a as f32, b.a as f32, t).round() as u8,
    };
    let matrix = |a: &swf::Matrix, b: &swf::Matrix| swf::Matrix {
        a: swf::Fixed16::from_f32(lerp(a.a.to_f32(), b.a.to_f32(), t)),
        b: swf::Fixed16::from_f32(lerp(a.b.to_f32(), b.b.to_f32(), t)),
        c: swf::Fixed16::from_f32(lerp(a.c.to_f32(), b.c.to_f32(), t)),
        d: swf::Fixed16::from_f32(lerp(a.d.to_f32(), b.d.to_f32(), t)),
        tx: swf::Twips::new(lerp(a.tx.get() as f32, b.tx.get() as f32, t).round() as i32),
        ty: swf::Twips::new(lerp(a.ty.get() as f32, b.ty.get() as f32, t).round() as i32),
    };
    let gradient = |a: &swf::Gradient, b: &swf::Gradient| swf::Gradient {
        matrix: matrix(&a.matrix, &b.matrix),
        spread: a.spread,
        interpolation: a.interpolation,
        records: a
            .records
            .iter()
            .zip(&b.records)
            .map(|(ra, rb)| swf::GradientRecord { ratio: lerp(ra.ratio as f32, rb.ratio as f32, t).round() as u8, color: color(&ra.color, &rb.color) })
            .collect(),
    };
    match (a, b) {
        (FillStyle::Color(x), FillStyle::Color(y)) => FillStyle::Color(color(x, y)),
        (FillStyle::LinearGradient(x), FillStyle::LinearGradient(y)) => FillStyle::LinearGradient(gradient(x, y)),
        (FillStyle::RadialGradient(x), FillStyle::RadialGradient(y)) => FillStyle::RadialGradient(gradient(x, y)),
        (FillStyle::FocalGradient { gradient: x, focal_point: fx }, FillStyle::FocalGradient { gradient: y, focal_point: fy }) => {
            FillStyle::FocalGradient { gradient: gradient(x, y), focal_point: swf::Fixed8::from_f32(lerp(fx.to_f32(), fy.to_f32(), t)) }
        }
        (FillStyle::Bitmap { id, matrix: x, is_smoothed, is_repeating }, FillStyle::Bitmap { matrix: y, .. }) => {
            FillStyle::Bitmap { id: *id, matrix: matrix(x, y), is_smoothed: *is_smoothed, is_repeating: *is_repeating }
        }
        _ => a.clone(),
    }
}
