//! Compares the map frames of a symbol (Art::render_layers), mixed with a
//! ground of one colour as the shader of the game mixes them, with the frames
//! that another player drew of a `stage` file of that colour.
//! cargo run --release --no-default-features --example ground_compare -- <file.swf> <symbol or id> <other dir> <RRGGBB> [old]
//!
//! The other frames are <other dir>/1.png, 2.png and so on. With "old" it
//! mixes the frame of Art::render instead, which mixes the blend modes only
//! with the graphic. For each frame it prints the pixels that the graphic
//! covers in one of the two pictures and the percent of them where a channel
//! differs by more than 24 of 255.

use swf::BlendMode;
use tiny_skia::Pixmap;

const LIMIT: i32 = 24;

fn hard_light(b: f32, s: f32) -> f32 {
    if s <= 0.5 { 2.0 * s * b } else { 1.0 - 2.0 * (1.0 - s) * (1.0 - b) }
}

/// The blend modes as blend_layers.gdshader mixes them: backdrop b, source s.
fn blend(mode: BlendMode, b: f32, s: f32) -> f32 {
    match mode {
        BlendMode::Multiply => b * s,
        BlendMode::Screen => b + s - b * s,
        BlendMode::Lighten => b.max(s),
        BlendMode::Darken => b.min(s),
        BlendMode::Difference => (b - s).abs(),
        BlendMode::Add => (b + s).min(1.0),
        BlendMode::Overlay => hard_light(s, b),
        BlendMode::HardLight => hard_light(b, s),
        _ => s,
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let art = flash_art::Art::load(&std::fs::read(&args[1]).unwrap()).unwrap();
    let id = args[2].parse().ok().or_else(|| art.symbol(&args[2])).expect("no such symbol");
    let canvas = art.canvas(id).expect("nothing to draw");
    let colour = u32::from_str_radix(&args[4], 16).expect("ground is RRGGBB");
    let ground = [(colour >> 16) as f32 / 255.0, ((colour >> 8) & 255) as f32 / 255.0, (colour & 255) as f32 / 255.0];
    let old = args.get(5).is_some_and(|a| a == "old");
    let (mut all_drawn, mut all_bad) = (0usize, 0usize);
    for frame in 0..art.frame_count(id) {
        let whole = (0, 0, canvas.width, canvas.height);
        // The layers that mix with the ground, then the normal image, the last of render_layers().
        let layers: Vec<(BlendMode, Pixmap)> = if old {
            vec![(BlendMode::Normal, art.render(id, frame, canvas, 1.0).unwrap())]
        } else {
            art.render_layers(id, frame, canvas, whole, 1.0, 1.0).unwrap().into_iter().map(|l| (l.blend, l.pixels)).collect()
        };
        let other = Pixmap::load_png(format!("{}/{}.png", args[3], frame + 1)).unwrap();
        let (mut drawn, mut bad) = (0, 0);
        for i in 0..(canvas.width * canvas.height) as usize {
            let mut c = ground;
            let mut covered = false;
            for (mode, pixels) in &layers {
                let p = pixels.pixels()[i];
                let alpha = p.alpha() as f32 / 255.0;
                if alpha == 0.0 {
                    continue;
                }
                covered = true;
                let source = [p.red(), p.green(), p.blue()].map(|v| (v as f32 / 255.0 / alpha).min(1.0));
                for k in 0..3 {
                    c[k] = c[k] * (1.0 - alpha) + alpha * blend(*mode, c[k], source[k]);
                }
            }
            let o = other.pixels()[i];
            let theirs = [o.red(), o.green(), o.blue()].map(|v| v as i32);
            let ours = c.map(|v| (v * 255.0).round() as i32);
            let ground_bytes = ground.map(|v| (v * 255.0).round() as i32);
            if covered || (0..3).any(|k| (theirs[k] - ground_bytes[k]).abs() > 2) {
                drawn += 1;
                if (0..3).any(|k| (ours[k] - theirs[k]).abs() > LIMIT) {
                    bad += 1;
                }
            }
        }
        all_drawn += drawn;
        all_bad += bad;
        println!("frame {}: {} pixels, {:.1} % differ", frame + 1, drawn, 100.0 * bad as f32 / drawn.max(1) as f32);
    }
    println!("all: {:.1} % of {} pixels differ by more than {}", 100.0 * all_bad as f32 / all_drawn.max(1) as f32, all_drawn, LIMIT);
}
