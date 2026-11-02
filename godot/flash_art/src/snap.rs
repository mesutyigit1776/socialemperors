//! Where an object with filters goes on the grid of pixels.
//!
//! Ruffle draws an object with filters (also with filters that change
//! nothing) on an image of its own, as for cacheAsBitmap, and puts that image
//! back on whole pixels: the top-left corner of the bounds of the object moves
//! to the nearest pixel. The corner is often near half a pixel, so the bounds
//! are computed as Ruffle computes them: in whole twips, with a rounding at
//! each matrix product and at each corner. Ruffle rounds the corner of the
//! image with the space of the filters, which is a whole number of pixels
//! less than the corner of the bounds; a half pixel rounds away from zero.

use swf::CharacterId;
use tiny_skia::Transform;

use crate::art::{self, Art, Character, Placed};
use crate::filters;
use crate::render::child_age;

pub struct Snapped {
    /// The move in pixels of Flash that puts the object on whole pixels.
    pub shift: (f32, f32),
    /// The matrix of the object in its own image, in which its parts snap.
    pub inner: Matrix,
}

/// Where an object with filters goes, or None when it draws nothing.
/// matrix: the object in the coordinates in which it snaps (its matrix
/// included), see Matrix.
pub fn offset(art: &Art, placed: &Placed, age: usize, matrix: &Matrix) -> Option<Snapped> {
    let (left, top, _, _) = bounds(art, placed.id, age, placed.ratio, matrix)?;
    // The image starts this many whole pixels (in twips) before the corner, for the space of the filters.
    let (space_left, space_top) = placed.filters.iter().filter(|f| !impotent(f)).map(filters::bounds_growth).fold((0, 0), |s, g| (s.0 + g.0, s.1 + g.1));
    let start = |space: i32| (-space as f64 / TWIPS as f64).floor() as i32 * TWIPS as i32;
    let (start_x, start_y) = (start(space_left), start(space_top));
    let shift = |image: i32| {
        let at = image as f64 / TWIPS as f64;
        (at.round() - at) as f32
    };
    Some(Snapped {
        shift: (shift(left + start_x), shift(top + start_y)),
        inner: Matrix { tx: matrix.tx - left - start_x, ty: matrix.ty - top - start_y, ..*matrix },
    })
}

const TWIPS: f32 = 20.0;

/// A matrix as Ruffle keeps it, from twips to twips: the translation in
/// whole twips. It maps an object to the canvas, or to the image of the object
/// with filters that contains it.
#[derive(Clone, Copy)]
pub struct Matrix {
    a: f32,
    b: f32,
    c: f32,
    d: f32,
    tx: i32,
    ty: i32,
}

impl Matrix {
    pub fn translate(tx: i32, ty: i32) -> Matrix {
        Matrix { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx, ty }
    }

    pub fn then(&self, child: &Transform) -> Matrix {
        let (x, y) = (child.tx, child.ty);
        Matrix {
            a: self.a * child.sx + self.c * child.ky,
            b: self.b * child.sx + self.d * child.ky,
            c: self.a * child.kx + self.c * child.sy,
            d: self.b * child.kx + self.d * child.sy,
            tx: round(self.a * x + self.c * y) + self.tx,
            ty: round(self.b * x + self.d * y) + self.ty,
        }
    }

    fn point(&self, x: f32, y: f32) -> (i32, i32) {
        (round(self.a * x + self.c * y) + self.tx, round(self.b * x + self.d * y) + self.ty)
    }
}

/// The filters that Ruffle leaves out of the image.
fn impotent(filter: &swf::Filter) -> bool {
    match filter {
        swf::Filter::BlurFilter(f) => f.impotent(),
        swf::Filter::ColorMatrixFilter(f) => f.matrix == [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        _ => false,
    }
}

fn round(v: f32) -> i32 {
    v.round_ties_even() as i32
}

type Bounds = (i32, i32, i32, i32);

fn union(a: Option<Bounds>, b: Option<Bounds>) -> Option<Bounds> {
    match (a, b) {
        (Some(a), Some(b)) => Some((a.0.min(b.0), a.1.min(b.1), a.2.max(b.2), a.3.max(b.3))),
        (a, None) => a,
        (None, b) => b,
    }
}

fn rect(m: &Matrix, r: tiny_skia::Rect) -> Bounds {
    let corners = [m.point(r.left(), r.top()), m.point(r.left(), r.bottom()), m.point(r.right(), r.top()), m.point(r.right(), r.bottom())];
    corners.iter().fold((i32::MAX, i32::MAX, i32::MIN, i32::MIN), |b, p| (b.0.min(p.0), b.1.min(p.1), b.2.max(p.0), b.3.max(p.1)))
}

/// The bounds in twips of the target of a character at an age: the
/// rectangles of the shapes that the frame shows, and the growth by the
/// filters of the nested objects (not of the character itself).
fn bounds(art: &Art, id: CharacterId, age: usize, ratio: u16, m: &Matrix) -> Option<Bounds> {
    let list = |list: &[Placed], count: usize| {
        list.iter().fold(None, |all, placed| {
            let b = bounds(art, placed.id, child_age(placed, age, count), placed.ratio, &m.then(&placed.matrix)).map(|b| {
                placed.filters.iter().map(filters::bounds_growth).fold(b, |b, g| (b.0 - g.0, b.1 - g.1, b.2 + g.2, b.3 + g.3))
            });
            union(all, b)
        })
    };
    match art.characters.get(&id)? {
        Character::Shape { bounds, .. } | Character::Text { bounds, .. } | Character::Other { bounds: Some(bounds) } => Some(rect(m, *bounds)),
        Character::Morph(morph) => {
            let t = ratio as f32 / 65535.0;
            let (a, b) = (art::rect(&morph.start.shape_bounds), art::rect(&morph.end.shape_bounds));
            let lerp = |a: f32, b: f32| a + (b - a) * t;
            let r = tiny_skia::Rect::from_ltrb(lerp(a.left(), b.left()), lerp(a.top(), b.top()), lerp(a.right(), b.right()), lerp(a.bottom(), b.bottom()))?;
            Some(rect(m, r))
        }
        Character::Sprite(sprite) => list(&sprite.frames[age % sprite.frames.len()], sprite.frames.len()),
        Character::Button(states) => list(&states[0], 1),
        _ => None,
    }
}
