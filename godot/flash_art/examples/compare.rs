//! Compares the frames of the `render` example with the frames that another
//! player drew of the `stage` file, once on black and once on white. The two
//! backgrounds give the alpha of the other player: a = 1 - (white - black).
//! cargo run --release --no-default-features --example compare -- <ours dir> <black dir> <white dir> [diff dir]
//!
//! For each frame it prints the drawn pixels (alpha above 0 in one of the two
//! images), the percent of them where a premultiplied channel differs by more
//! than 24 of 255, and the mean difference. With a diff dir it writes the two
//! frames and the difference side by side, on gray.

use tiny_skia::Pixmap;

const LIMIT: u8 = 24;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let diff_dir = args.get(4);
    if let Some(dir) = diff_dir {
        std::fs::create_dir_all(dir).unwrap();
    }
    let mut others: Vec<String> = std::fs::read_dir(&args[2]).unwrap().map(|e| e.unwrap().file_name().into_string().unwrap()).filter(|n| n.ends_with(".png")).collect();
    others.sort();
    let (mut all_drawn, mut all_bad, mut all_sum) = (0usize, 0usize, 0f64);
    for (frame, name) in others.iter().enumerate() {
        let ours = Pixmap::load_png(format!("{}/{}.png", args[1], frame + 1)).unwrap();
        let black = Pixmap::load_png(format!("{}/{}", args[2], name)).unwrap();
        let white = Pixmap::load_png(format!("{}/{}", args[3], name)).unwrap();
        assert_eq!((ours.width(), ours.height()), (black.width(), black.height()), "frame {} has another size", frame + 1);
        let other: Vec<[u8; 4]> = black
            .pixels()
            .iter()
            .zip(white.pixels())
            .map(|(b, w)| {
                let gap = (w.red() as i32 - b.red() as i32 + w.green() as i32 - b.green() as i32 + w.blue() as i32 - b.blue() as i32) / 3;
                let a = (255 - gap).clamp(0, 255) as u8;
                [b.red().min(a), b.green().min(a), b.blue().min(a), a]
            })
            .collect();
        let (mut drawn, mut bad, mut sum) = (0usize, 0usize, 0f64);
        let mut diff = Vec::with_capacity(other.len());
        for (p, q) in ours.pixels().iter().zip(&other) {
            let p = [p.red(), p.green(), p.blue(), p.alpha()];
            let d = (0..4).map(|i| p[i].abs_diff(q[i])).max().unwrap();
            diff.push(d);
            if p[3] > 0 || q[3] > 0 {
                drawn += 1;
                sum += d as f64;
                if d > LIMIT {
                    bad += 1;
                }
            }
        }
        println!("frame {:3}: {:7} drawn, {:5.1} % differ, mean {:5.1}", frame + 1, drawn, percent(bad, drawn), sum / drawn.max(1) as f64);
        all_drawn += drawn;
        all_bad += bad;
        all_sum += sum;
        if let Some(dir) = diff_dir {
            write_diff(dir, frame + 1, &ours, &other, &diff);
        }
    }
    println!("all frames: {} drawn, {:.1} % differ, mean {:.1}", all_drawn, percent(all_bad, all_drawn), all_sum / all_drawn.max(1) as f64);
}

fn percent(part: usize, whole: usize) -> f64 {
    100.0 * part as f64 / whole.max(1) as f64
}

fn write_diff(dir: &str, frame: usize, ours: &Pixmap, other: &[[u8; 4]], diff: &[u8]) {
    let (w, h) = (ours.width() as usize, ours.height() as usize);
    let mut out = Pixmap::new(3 * w as u32, h as u32).unwrap();
    let gray = 128u32;
    let over = |c: u8, a: u8| (c as u32 + gray * (255 - a as u32) / 255).min(255) as u8;
    let data = out.data_mut();
    for y in 0..h {
        for x in 0..w {
            let i = y * w + x;
            let p = ours.pixels()[i];
            let q = other[i];
            let cells = [
                [over(p.red(), p.alpha()), over(p.green(), p.alpha()), over(p.blue(), p.alpha())],
                [over(q[0], q[3]), over(q[1], q[3]), over(q[2], q[3])],
                if diff[i] > LIMIT { [255, 0, 0] } else { [diff[i] * 4, diff[i] * 4, diff[i] * 4] },
            ];
            for (n, c) in cells.iter().enumerate() {
                let o = 4 * (y * 3 * w + n * w + x);
                data[o..o + 4].copy_from_slice(&[c[0], c[1], c[2], 255]);
            }
        }
    }
    out.save_png(format!("{dir}/{frame}.png")).unwrap();
}
