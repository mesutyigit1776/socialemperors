//! Renders the frames of a symbol or sprite to PNG files, to compare them with other renderers.
//! cargo run --release --no-default-features --example render -- <file.swf> <symbol name or id> <out dir> [frame]

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let art = flash_art::Art::load(&std::fs::read(&args[1]).unwrap()).unwrap();
    let id = args[2].parse().ok().or_else(|| art.symbol(&args[2])).expect("no such symbol");
    let canvas = art.canvas(id).expect("nothing to draw");
    std::fs::create_dir_all(&args[3]).unwrap();
    println!("{{\"x\": {}, \"y\": {}, \"width\": {}, \"height\": {}, \"frames\": {}}}", canvas.x, canvas.y, canvas.width, canvas.height, art.frame_count(id));
    let frames: Vec<usize> = match args.get(4) {
        Some(f) => vec![f.parse().unwrap()],
        None => (0..art.frame_count(id)).collect(),
    };
    let start = std::time::Instant::now();
    for frame in frames {
        let pixmap = art.render(id, frame, canvas, 1.0).unwrap();
        pixmap.save_png(format!("{}/{}.png", args[3], frame + 1)).unwrap();
    }
    eprintln!("{:?}", start.elapsed());
}
