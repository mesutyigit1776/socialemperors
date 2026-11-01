//! The data of the game about the frames of a graphic: their bounds, the
//! points where shots start, and the clips that units play. The client
//! reads these from the display list of Flash; the rules are the same here.

use std::collections::HashMap;

use swf::CharacterId;
use tiny_skia::{Point, Rect, Transform};

use crate::art::{union, Art, Character};

/// Names of the point in a graphic where the shots of the client start. The
/// client looks for the first name; for some shots it also accepts the second.
const SHOT_POINT_NAMES: [&str; 2] = ["proyectilePoint", "projectilePoint"];

/// The clip of a frame of a unit: a nested sprite with more than one frame
/// that is the only part of the frame, and its matrix in twips.
pub struct FrameClip {
    pub id: CharacterId,
    pub matrix: Transform,
}

impl Art {
    /// The bounds in twips of each frame of a sprite, as Flash reports them:
    /// relative to the registration point. The client stops nested sprites
    /// on their first frame, so they count with that frame.
    pub fn frame_rects(&self, id: CharacterId) -> Vec<Option<Rect>> {
        let Some(Character::Sprite(sprite)) = self.characters.get(&id) else { return Vec::new() };
        let mut first = HashMap::new();
        sprite.frames.iter().map(|frame| frame.iter().fold(None, |r, p| union(r, self.first_frame_bounds(p.id, &mut first).and_then(|b| b.transform(p.matrix))))).collect()
    }

    fn first_frame_bounds(&self, id: CharacterId, known: &mut HashMap<CharacterId, Option<Rect>>) -> Option<Rect> {
        let Some(Character::Sprite(sprite)) = self.characters.get(&id) else { return self.bounds(id) };
        if let Some(found) = known.get(&id) {
            return *found;
        }
        // Stops the recursion in a file in which a sprite contains itself.
        known.insert(id, None);
        let result = sprite.frames[0].iter().fold(None, |r, p| union(r, self.first_frame_bounds(p.id, known).and_then(|b| b.transform(p.matrix))));
        known.insert(id, result);
        result
    }

    /// For each frame of a sprite, the point in twips where its shots start,
    /// or None. The client looks for the point in the first child of the
    /// frame, a sprite; the point can be in any frame of that sprite, and this
    /// takes the first frame that has it.
    pub fn shot_points(&self, id: CharacterId) -> Vec<Option<Point>> {
        let Some(Character::Sprite(sprite)) = self.characters.get(&id) else { return Vec::new() };
        sprite
            .frames
            .iter()
            .map(|frame| {
                let first = frame.first()?;
                let Some(Character::Sprite(child)) = self.characters.get(&first.id) else { return None };
                SHOT_POINT_NAMES.iter().find_map(|name| {
                    let point = child.frames.iter().flatten().find(|p| p.name.as_deref() == Some(*name))?;
                    let mut at = [Point::from_xy(point.matrix.tx, point.matrix.ty)];
                    first.matrix.map_points(&mut at);
                    Some(at[0])
                })
            })
            .collect()
    }

    /// For each frame of a sprite, its clip or None. The client shows only
    /// the first frame of nested sprites in buildings, but units play them.
    pub fn frame_clips(&self, id: CharacterId) -> Vec<Option<FrameClip>> {
        let Some(Character::Sprite(sprite)) = self.characters.get(&id) else { return Vec::new() };
        sprite
            .frames
            .iter()
            .map(|frame| match frame.as_slice() {
                [only] if matches!(self.characters.get(&only.id), Some(Character::Sprite(_))) && self.frame_count(only.id) > 1 => Some(FrameClip { id: only.id, matrix: only.matrix }),
                _ => None,
            })
            .collect()
    }
}
