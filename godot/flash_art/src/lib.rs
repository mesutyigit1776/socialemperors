//! Draws the art of the user's Social Empires SWF files while the game runs:
//! the shapes, bitmaps, nested sprites, masks, filters and blend modes of
//! Flash. Godot uses it through the class FlashArt (see godot_api.rs).

mod art;
mod bitmap;
mod color;
mod filters;
mod layout;
mod render;
mod shape;

#[cfg(feature = "godot")]
mod godot_api;

pub use art::Art;
pub use layout::FrameClip;
pub use render::Canvas;
