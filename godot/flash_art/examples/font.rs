//! Writes a font of a SWF file as a TrueType file: cargo run --example font -- <file.swf> <font id> <out.ttf>
fn main() {
    let a: Vec<String> = std::env::args().collect();
    let art = flash_art::Art::load(&std::fs::read(&a[1]).unwrap()).unwrap();
    std::fs::write(&a[3], art.font_ttf(a[2].parse().unwrap()).expect("not a font")).unwrap();
}
