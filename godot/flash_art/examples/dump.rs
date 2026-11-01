//! Prints the display list tree of a frame: cargo run --example dump -- <file.swf> <symbol or id> [frame]
use flash_art::Art;
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let art = Art::load(&std::fs::read(&a[1]).unwrap()).unwrap();
    let id = a[2].parse().ok().or_else(|| art.symbol(&a[2])).unwrap();
    let frame: usize = a.get(3).map(|f| f.parse().unwrap()).unwrap_or(0);
    art.dump(id, frame, 0);
}
