//! Draws a frame of a character: its shapes, nested sprites, masks, filters and blend modes.

use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use swf::{BlendMode, CharacterId, FillStyle, GradientSpread, LineCapStyle, LineJoinStyle, LineStyle};
use tiny_skia::{
    FilterQuality, GradientStop, LinearGradient, Paint, Pattern, Pixmap, PixmapPaint, Point, RadialGradient, Rect,
    Shader, SpreadMode, Stroke, Transform,
};

use crate::art::{self, Art, Character, Placed};
use crate::color::ColorTransform;
use crate::filters;
use crate::shape::{self, ShapeLayer};
use crate::samples::{Masks, Samples};
use crate::snap;

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
    /// corner of the bounds, as the frames that the Flash tools export, moved
    /// to a whole twip, so that a SWF file can place a frame on its grid of pixels.
    pub fn canvas(&self, id: CharacterId) -> Option<Canvas> {
        let r = self.visual_bounds(id)?;
        let (left, top) = (r.left().floor(), r.top().floor());
        Some(Canvas {
            x: left / TWIPS,
            y: top / TWIPS,
            width: ((r.right() - left) / TWIPS).ceil().max(1.0) as u32,
            height: ((r.bottom() - top) / TWIPS).ceil().max(1.0) as u32,
        })
    }

    /// The part of the canvas that frame (from 0) of a character covers, in
    /// whole pixels: (x, y, width, height). None when the frame draws nothing.
    pub fn frame_area(&self, id: CharacterId, frame: usize, canvas: Canvas) -> Option<(u32, u32, u32, u32)> {
        let b = self.frame_visual_bounds(id, frame)?;
        let left = ((b.left() / TWIPS - canvas.x).floor().max(0.0) as u32).min(canvas.width);
        let top = ((b.top() / TWIPS - canvas.y).floor().max(0.0) as u32).min(canvas.height);
        let right = ((b.right() / TWIPS - canvas.x).ceil().max(0.0) as u32).min(canvas.width);
        let bottom = ((b.bottom() / TWIPS - canvas.y).ceil().max(0.0) as u32).min(canvas.height);
        (right > left && bottom > top).then_some((left, top, right - left, bottom - top))
    }

    /// Draws frame (from 0) of a character on a new image of the canvas, scaled.
    pub fn render(&self, id: CharacterId, frame: usize, canvas: Canvas, scale: f32) -> Option<Pixmap> {
        self.render_area(id, frame, canvas, (0, 0, canvas.width, canvas.height), scale)
    }

    /// Draws frame (from 0) of a character on a new image of one area of the canvas, see frame_area().
    pub fn render_area(&self, id: CharacterId, frame: usize, canvas: Canvas, area: (u32, u32, u32, u32), scale: f32) -> Option<Pixmap> {
        let (mut samples, transform, flash) = area_target(canvas, area, scale)?;
        Renderer { art: self, scale, filter_scale: scale, layers: None }.draw(&mut samples, id, frame, 0, transform, &flash, &ColorTransform::IDENTITY, None);
        Some(samples.resolve())
    }

    /// Draws frame (from 0) of a character on images of one area of the
    /// canvas, as render_area(), for a graphic on the map. The parts with a
    /// blend mode that mixes with the map (see mixes_with_background) mix with
    /// the graphic where it is below them; where the map is below them, they
    /// go to a layer of their blend mode, one for each mode. The game first
    /// mixes these layers with the map, in their order, and then draws the
    /// last layer, the normal image, over them. A frame without such parts is
    /// only the normal image.
    ///
    /// Where the graphic covers the map in part (alpha between 0 and 1), a
    /// part mixes with the graphic and with the map each by itself, by the
    /// alpha of the graphic, not with the mix of the two; this is exact for
    /// the blend modes that are linear in the backdrop (multiply, screen).
    /// Parts of the same mode that overlap over the map are one layer, drawn
    /// as normal one over the other; parts of different modes mix with the map
    /// in the order of their modes, not of their depths.
    pub fn render_layers(&self, id: CharacterId, frame: usize, canvas: Canvas, area: (u32, u32, u32, u32), scale: f32, parent_scale: f32) -> Option<Vec<Layer>> {
        let (mut samples, transform, flash) = area_target(canvas, area, scale)?;
        let layers = RefCell::new(Vec::new());
        Renderer { art: self, scale, filter_scale: scale / parent_scale, layers: Some(&layers) }.draw(&mut samples, id, frame, 0, transform, &flash, &ColorTransform::IDENTITY, None);
        let mut layers: Vec<Layer> = layers.into_inner().into_iter().filter(|l| l.pixels.pixels().iter().any(|p| p.alpha() != 0)).collect();
        layers.push(Layer { blend: BlendMode::Normal, pixels: samples.resolve() });
        Some(layers)
    }
}

impl Art {
    /// Draws the state (0 up, 1 over, 2 down) of a button at a scale on a new
    /// image of its canvas, which covers all its states. The image has the
    /// size of the canvas times the scale, rounded up.
    pub fn render_button(&self, id: CharacterId, state: usize, canvas: Canvas, scale: f32) -> Option<Pixmap> {
        let Some(Character::Button(states)) = self.characters.get(&id) else { return None };
        let width = ((canvas.width as f32 * scale).ceil() as u32).max(1);
        let height = ((canvas.height as f32 * scale).ceil() as u32).max(1);
        let mut samples = Samples::new(width, height)?;
        let transform = Transform::from_row(scale / TWIPS, 0.0, 0.0, scale / TWIPS, -canvas.x * scale, -canvas.y * scale);
        let flash = snap::Matrix::translate((-canvas.x * TWIPS).round() as i32, (-canvas.y * TWIPS).round() as i32);
        Renderer { art: self, scale, filter_scale: scale, layers: None }.draw_list(&mut samples, states.get(state)?, 0, 1, transform, &flash, &ColorTransform::IDENTITY, None);
        Some(samples.resolve())
    }
}

/// One image of a frame on the map, see Art::render_layers().
pub struct Layer {
    pub blend: BlendMode,
    /// The pixels of the whole area, premultiplied.
    pub pixels: Pixmap,
}

/// True for the blend modes of a part that mix it with everything below it:
/// in the game also with the map, unless a parent of the part is drawn as one
/// image (with filters or a blend mode), which then mixes only with that image.
fn mixes_with_background(mode: BlendMode) -> bool {
    matches!(
        mode,
        BlendMode::Multiply | BlendMode::Screen | BlendMode::Lighten | BlendMode::Darken | BlendMode::Difference | BlendMode::Add | BlendMode::Overlay | BlendMode::HardLight
    )
}

/// One color channel (0 to 1) of a blend mode of Flash: backdrop b, source s.
fn blend_channel(mode: BlendMode, b: f32, s: f32) -> f32 {
    match mode {
        BlendMode::Multiply => b * s,
        BlendMode::Screen => b + s - b * s,
        BlendMode::Lighten => b.max(s),
        BlendMode::Darken => b.min(s),
        BlendMode::Difference => (b - s).abs(),
        BlendMode::Add => (b + s).min(1.0),
        BlendMode::Overlay => blend_channel(BlendMode::HardLight, s, b),
        BlendMode::HardLight if s <= 0.5 => 2.0 * s * b,
        BlendMode::HardLight => 1.0 - 2.0 * (1.0 - s) * (1.0 - b),
        _ => s,
    }
}

/// The samples of an area of the canvas at a scale, the transform from the
/// twips of the character to their pixels, and the place of Flash for filters.
fn area_target(canvas: Canvas, area: (u32, u32, u32, u32), scale: f32) -> Option<(Samples, Transform, snap::Matrix)> {
    let width = ((area.2 as f32 * scale).ceil() as u32).max(1);
    let height = ((area.3 as f32 * scale).ceil() as u32).max(1);
    let samples = Samples::new(width, height)?;
    let (x, y) = (canvas.x + area.0 as f32, canvas.y + area.1 as f32);
    let transform = Transform::from_row(scale / TWIPS, 0.0, 0.0, scale / TWIPS, -x * scale, -y * scale);
    let flash = snap::Matrix::translate((-canvas.x * TWIPS).round() as i32, (-canvas.y * TWIPS).round() as i32);
    Some((samples, transform, flash))
}

#[derive(Clone, Copy)]
struct Renderer<'a> {
    art: &'a Art,
    /// Pixels of the image for each pixel of Flash.
    scale: f32,
    /// Pixels of the image for each pixel of the stage, in which the sizes of
    /// the filters are: scale, or more for a clip that its parent makes smaller.
    filter_scale: f32,
    /// For a frame on the map: the layers of render_layers() for the parts
    /// over the map. Then the target of draw() is the normal image of the
    /// frame. None in a part that is drawn as one image, and for the windows.
    layers: Option<&'a RefCell<Vec<Layer>>>,
}

impl Renderer<'_> {
    /// The renderer for the parts of an object that is drawn as one image: their blend modes mix only with that image.
    fn isolated(&self) -> Self {
        Renderer { layers: None, ..*self }
    }

    /// age: the frames that the character played since it was placed; a
    /// sprite shows frame age modulo its frame count. transform: from twips
    /// of the character to pixels of the target. flash: the same place as
    /// Ruffle computes it, for the objects with filters (see snap.rs).
    #[allow(clippy::too_many_arguments)]
    fn draw(&self, target: &mut Samples, id: CharacterId, age: usize, ratio: u16, transform: Transform, flash: &snap::Matrix, color: &ColorTransform, mask: Option<&Masks>) {
        match self.art.characters.get(&id) {
            Some(Character::Shape { layers, .. }) => self.draw_shape(target, layers, transform, color, mask),
            Some(Character::Morph(_)) => {
                if let Some(layers) = self.morph(id, ratio) {
                    self.draw_shape(target, &layers, transform, color, mask);
                }
            }
            Some(Character::Sprite(sprite)) => {
                let list = &sprite.frames[age % sprite.frames.len()];
                self.draw_list(target, list, age, sprite.frames.len(), transform, flash, color, mask);
            }
            Some(Character::Text { matrix, records, .. }) => self.draw_text(target, records, transform.pre_concat(*matrix), color, mask),
            // A button inside a sprite shows its up state.
            Some(Character::Button(states)) => self.draw_list(target, &states[0], age, 1, transform, flash, color, mask),
            _ => {}
        }
    }

    /// Draws a display list. A mask applies to the depths after it up to its clip depth.
    #[allow(clippy::too_many_arguments)]
    fn draw_list(&self, target: &mut Samples, list: &[Placed], age: usize, count: usize, transform: Transform, flash: &snap::Matrix, color: &ColorTransform, mask: Option<&Masks>) {
        let mut i = 0;
        while i < list.len() {
            let placed = &list[i];
            if placed.clip_depth == 0 {
                self.draw_placed(target, placed, child_age(placed, age, count), transform, flash, color, mask);
                i += 1;
                continue;
            }
            let end = i + 1 + list[i + 1..].iter().take_while(|p| p.depth <= placed.clip_depth).count();
            if let Some(group_mask) = self.mask(target, placed, child_age(placed, age, count), transform, flash, mask) {
                self.draw_list(target, &list[i + 1..end], age, count, transform, flash, color, Some(&group_mask));
            }
            i = end;
        }
    }

    /// age: the age of the placed character, see draw().
    #[allow(clippy::too_many_arguments)]
    fn draw_placed(&self, target: &mut Samples, placed: &Placed, age: usize, transform: Transform, flash: &snap::Matrix, color: &ColorTransform, mask: Option<&Masks>) {
        if !placed.visible {
            return;
        }
        if let Some(layers) = self.layers
            && mixes_with_background(placed.blend)
        {
            // The part is drawn as normal on an image of its own. It mixes
            // with the target where the target has pixels, and goes to the
            // layer of its blend mode, which mixes with the map. The normal
            // image covers that layer by its alpha, so that the part mixes
            // with the map only where the map shows through the target.
            let Some(mut own) = Samples::new(target.width(), target.height()) else { return };
            let normal = Placed { blend: BlendMode::Normal, ..placed.clone() };
            self.isolated().draw_placed(&mut own, &normal, age, transform, flash, color, mask);
            let own = own.resolve();
            target.blend_atop(&own, |b, s| blend_channel(placed.blend, b, s));
            let mut layers = layers.borrow_mut();
            let at = match layers.iter().position(|l| l.blend == placed.blend) {
                Some(at) => at,
                None => {
                    let Some(pixels) = Pixmap::new(target.width(), target.height()) else { return };
                    layers.push(Layer { blend: placed.blend, pixels });
                    layers.len() - 1
                }
            };
            layers[at].pixels.draw_pixmap(0, 0, own.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
            return;
        }
        let mut transform = transform.pre_concat(placed.matrix);
        let color = color.then_child(&placed.color);
        let frame = age;
        let active: Vec<&swf::Filter> = placed.filters.iter().filter(|f| filters::is_active(f)).collect();
        // An object with filters, also with filters that change nothing, is drawn
        // as one image (as cacheAsBitmap) and put back on whole pixels: the
        // top-left corner of its bounds moves to the nearest pixel. Its color
        // transform then applies to the whole image. This is the rule of Ruffle.
        let cached = !placed.filters.is_empty();
        let mut flash = flash.then(&placed.matrix);
        if cached && let Some(snapped) = snap::offset(self.art, placed, frame, &flash) {
            transform = transform.post_translate(snapped.shift.0 * self.scale, snapped.shift.1 * self.scale);
            flash = snapped.inner;
        }
        if active.is_empty() && matches!(placed.blend, BlendMode::Normal) && !(cached && !color.is_identity()) {
            self.draw(target, placed.id, frame, placed.ratio, transform, &flash, &color, mask);
            return;
        }
        // Filters and blend modes work on the whole object: it is drawn on a
        // layer of its own, which is then changed and put on the target.
        let Some(bounds) = self.art.visual_bounds(placed.id).and_then(|b| transform_rect(b, transform)) else { return };
        let (mut margin_x, mut margin_y) = (1.0f32, 1.0f32);
        for filter in &active {
            let (x, y) = filters::margin(filter, self.filter_scale);
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
        let Some(mut samples) = Samples::new((right - left) as u32, (bottom - top) as u32) else { return };
        let layer_transform = transform.post_translate(-left as f32, -top as f32);
        self.isolated().draw(&mut samples, placed.id, frame, placed.ratio, layer_transform, &flash, &ColorTransform::IDENTITY, None);
        // Ruffle averages the samples of the image of the object before its filters.
        let mut layer = samples.resolve();
        for filter in active {
            filters::apply(&mut layer, filter, self.filter_scale);
        }
        let mut opacity = 1.0;
        if color.is_alpha_only() {
            opacity = color.mult[3].clamp(0.0, 1.0);
        } else {
            color.apply_pixmap(&mut layer);
        }
        let paint = PixmapPaint { opacity, blend_mode: blend_mode(placed.blend), quality: FilterQuality::Nearest };
        target.draw_pixmap(left, top, &layer, &paint, mask);
    }

    /// The area that a mask covers on the target, within the outer mask.
    /// A mask covers each sample fully or not at all, as the stencil of Ruffle.
    fn mask(&self, target: &Samples, placed: &Placed, age: usize, transform: Transform, flash: &snap::Matrix, outer: Option<&Masks>) -> Option<Masks> {
        let mut samples = Samples::new(target.width(), target.height())?;
        self.isolated().draw(&mut samples, placed.id, age, placed.ratio, transform.pre_concat(placed.matrix), &flash.then(&placed.matrix), &MASK_COLOR, None);
        Some(samples.masks(outer))
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

    /// Static text: each glyph is the shape of its font glyph, scaled to the
    /// height of its run, at the pen position, which moves by the advance of each glyph.
    fn draw_text(&self, target: &mut Samples, records: &[swf::TextRecord], transform: Transform, color: &ColorTransform, mask: Option<&Masks>) {
        let (mut font, mut fill, mut height) = (None, swf::Color { r: 0, g: 0, b: 0, a: 255 }, 0.0f32);
        let (mut x, mut y) = (0.0f32, 0.0f32);
        for record in records {
            if let Some(id) = record.font_id {
                font = match self.art.characters.get(&id) {
                    Some(Character::Font(f)) => Some(f),
                    _ => None,
                };
            }
            if let Some(c) = record.color {
                fill = c;
            }
            if let Some(h) = record.height {
                height = h.get() as f32;
            }
            if let Some(v) = record.x_offset {
                x = v.get() as f32;
            }
            if let Some(v) = record.y_offset {
                y = v.get() as f32;
            }
            let Some(font) = font else { continue };
            let scale = height / font.em();
            for glyph in &record.glyphs {
                let layers = font.glyph_layers(glyph.index as usize, fill);
                let at = transform.pre_concat(Transform::from_row(scale, 0.0, 0.0, scale, x, y));
                self.draw_shape(target, &layers, at, color, mask);
                x += glyph.advance as f32;
            }
        }
    }

    fn draw_shape(&self, target: &mut Samples, layers: &[ShapeLayer], transform: Transform, color: &ColorTransform, mask: Option<&Masks>) {
        for layer in layers {
            for (style, path) in &layer.fills {
                self.with_paint(style, color, transform, |paint| target.fill_path(path, paint, transform, mask));
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
        // Lines are at least one pixel wide, as in Ruffle.
        if pixels_per_twip > 0.0 {
            width = width.max(1.0 / pixels_per_twip);
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
        // Without antialiasing: each sample is covered or not (see samples.rs).
        let mut paint = Paint { anti_alias: false, ..Paint::default() };
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
                let quality = if *is_smoothed { FilterQuality::Bilinear } else { FilterQuality::Nearest };
                let mut pattern = art::matrix(matrix);
                // A smoothed bitmap is sampled bilinear at its exact place, also between
                // two pixels, as Ruffle does. tiny-skia samples a bitmap that is only
                // moved with the nearest pixel, so a scale that changes no pixel turns it.
                let on_target = transform.pre_concat(pattern);
                if *is_smoothed && on_target.is_translate() && (on_target.tx.fract() != 0.0 || on_target.ty.fract() != 0.0) {
                    pattern = pattern.pre_scale(1.0 + 1e-6, 1.0);
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

/// The age of a character on the display list of a sprite of this age and
/// frame count. Every sprite of Flash plays on from the frame in which it was
/// placed, also when its parent has only one frame. After the parent loops,
/// a character of its first frame that the last frame also has stays and
/// plays on (see Placed::stays); the others came back on the list and count
/// from their frame.
pub(crate) fn child_age(placed: &Placed, age: usize, count: usize) -> usize {
    if placed.start == 0 && placed.stays { age } else { (age % count).saturating_sub(placed.start) }
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

/// A fill of a morph shape at t, interpolated as Ruffle does: colors and
/// gradient ratios rounded down, matrices in fixed point.
fn lerp_fill(a: &FillStyle, b: &FillStyle, t: f32) -> FillStyle {
    let (wa, wb) = (1.0 - t, t);
    let color = |a: &swf::Color, b: &swf::Color| {
        let mix = |x: u8, y: u8| (wa * x as f32 + wb * y as f32) as u8;
        swf::Color { r: mix(a.r, b.r), g: mix(a.g, b.g), b: mix(a.b, b.b), a: mix(a.a, b.a) }
    };
    let matrix = |a: &swf::Matrix, b: &swf::Matrix| {
        let (fa, fb) = (swf::Fixed16::from_f32(wa), swf::Fixed16::from_f32(wb));
        let twips = |x: swf::Twips, y: swf::Twips| swf::Twips::new((x.get() as f32 * wa + y.get() as f32 * wb).round() as i32);
        swf::Matrix { a: a.a * fa + b.a * fb, b: a.b * fa + b.b * fb, c: a.c * fa + b.c * fb, d: a.d * fa + b.d * fb, tx: twips(a.tx, b.tx), ty: twips(a.ty, b.ty) }
    };
    let gradient = |a: &swf::Gradient, b: &swf::Gradient| swf::Gradient {
        matrix: matrix(&a.matrix, &b.matrix),
        spread: a.spread,
        interpolation: a.interpolation,
        records: a.records.iter().zip(&b.records).map(|(ra, rb)| swf::GradientRecord { ratio: (wa * ra.ratio as f32 + wb * rb.ratio as f32) as u8, color: color(&ra.color, &rb.color) }).collect(),
    };
    match (a, b) {
        (FillStyle::Color(x), FillStyle::Color(y)) => FillStyle::Color(color(x, y)),
        (FillStyle::LinearGradient(x), FillStyle::LinearGradient(y)) => FillStyle::LinearGradient(gradient(x, y)),
        (FillStyle::RadialGradient(x), FillStyle::RadialGradient(y)) => FillStyle::RadialGradient(gradient(x, y)),
        (FillStyle::FocalGradient { gradient: x, focal_point: fx }, FillStyle::FocalGradient { gradient: y, focal_point: fy }) => {
            FillStyle::FocalGradient { gradient: gradient(x, y), focal_point: *fx * swf::Fixed8::from_f32(wa) + *fy * swf::Fixed8::from_f32(wb) }
        }
        (FillStyle::Bitmap { id, matrix: x, is_smoothed, is_repeating }, FillStyle::Bitmap { matrix: y, .. }) => {
            FillStyle::Bitmap { id: *id, matrix: matrix(x, y), is_smoothed: *is_smoothed, is_repeating: *is_repeating }
        }
        _ => a.clone(),
    }
}
