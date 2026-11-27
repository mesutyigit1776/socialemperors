//! Draws the art of the user's Social Empires SWF files while the game runs:
//! the shapes, bitmaps, nested sprites, masks, filters and blend modes of
//! Flash. Godot uses it through the class FlashArt (see godot_api.rs). The
//! import of the game files uses the classes of import_api.rs.

mod art;
mod bitmap;
mod color;
mod filters;
mod font;
mod layout;
mod py_json;
mod py_random;
mod render;
mod samples;
mod shape;
mod snap;
mod swf_import;

#[cfg(feature = "godot")]
mod godot_api;
#[cfg(feature = "godot")]
mod import_api;

pub use art::Art;
pub use layout::FrameClip;
pub use render::{Canvas, Layer};
