//! Prints the game data of the frames of symbols as JSON lines, to compare them with other tools.
//! cargo run --release --no-default-features --example layout -- <file.swf> <symbol> [<file.swf> <symbol> ...]

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    for pair in args.chunks(2) {
        let Ok(art) = std::fs::read(&pair[0]).map_err(|e| e.to_string()).and_then(|d| flash_art::Art::load(&d)) else {
            println!("{{\"symbol\": \"{}\", \"error\": \"cannot read\"}}", pair[1]);
            continue;
        };
        let Some(id) = art.symbol(&pair[1]) else {
            println!("{{\"symbol\": \"{}\", \"error\": \"no symbol\"}}", pair[1]);
            continue;
        };
        let rects: Vec<String> = art.frame_rects(id).iter().map(|r| match r {
            Some(r) => format!("[{}, {}, {}, {}]", r.left() / 20.0, r.top() / 20.0, r.width() / 20.0, r.height() / 20.0),
            None => "[0, 0, 0, 0]".into(),
        }).collect();
        let points: Vec<String> = art.shot_points(id).iter().map(|p| p.map_or("null".into(), |p| format!("[{}, {}]", p.x / 20.0, p.y / 20.0))).collect();
        let clips: Vec<String> = art.frame_clips(id).iter().map(|c| c.as_ref().map_or("null".into(), |c| {
            let m = c.matrix;
            format!("[{}, {}, {}, {}, {}, {}, {}, {}]", c.id, m.sx, m.ky, m.kx, m.sy, m.tx / 20.0, m.ty / 20.0, art.frame_count(c.id))
        })).collect();
        let c = art.canvas(id).map_or("null".into(), |c| format!("[{}, {}, {}, {}]", c.x, c.y, c.width, c.height));
        println!("{{\"symbol\": \"{}\", \"canvas\": {c}, \"rects\": [{}], \"shots\": [{}], \"clips\": [{}]}}", pair[1], rects.join(", "), points.join(", "), clips.join(", "));
    }
}
