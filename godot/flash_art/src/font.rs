//! Turns a font of a SWF file (DefineFont2 or DefineFont3) into a TrueType
//! font, which Godot can use for the text fields of the client windows.
//!
//! The glyphs of SWF fonts are quadratic curves, as in TrueType, so the
//! outlines stay the same. The font has 1024 units for each em, as DefineFont2;
//! DefineFont3 has 20 times more, which this divides by 20.

use swf::ShapeRecord;

pub struct FontData {
    name: String,
    /// Version 3 has coordinates in twentieths of the units of version 2.
    version: u8,
    bold: bool,
    italic: bool,
    ascent: i32,
    descent: i32,
    glyphs: Vec<GlyphData>,
}

struct GlyphData {
    code: u16,
    advance: i32,
    records: Vec<ShapeRecord>,
}

const UNITS_PER_EM: u16 = 1024;
/// The line gap of the fonts that JPEXS made for the earlier imports, so that the text keeps its line spacing.
const LINE_GAP: i16 = 170;

impl FontData {
    pub fn from_swf(font: &swf::Font) -> FontData {
        let layout = font.layout.as_ref();
        let scale = if font.version >= 3 { 20 } else { 1 };
        FontData {
            name: font.name.to_string_lossy(swf::UTF_8).trim_end_matches('\0').to_string(),
            version: font.version,
            bold: font.flags.contains(swf::FontFlag::IS_BOLD),
            italic: font.flags.contains(swf::FontFlag::IS_ITALIC),
            ascent: layout.map_or(UNITS_PER_EM as i32, |l| l.ascent as i32 / scale),
            descent: layout.map_or(0, |l| l.descent as i32 / scale),
            glyphs: font.glyphs.iter().map(|g| GlyphData { code: g.code, advance: g.advance as i32 / scale, records: g.shape_records.clone() }).collect(),
        }
    }

    /// The size of the em square of the glyph shapes: 1024 units, or 20 times more in DefineFont3.
    pub fn em(&self) -> f32 {
        if self.version >= 3 { 20480.0 } else { 1024.0 }
    }

    /// The shape of the glyph with this index, drawn in one color.
    pub fn glyph_layers(&self, index: usize, color: swf::Color) -> Vec<crate::shape::ShapeLayer> {
        let Some(glyph) = self.glyphs.get(index) else { return Vec::new() };
        let styles = swf::ShapeStyles { fill_styles: vec![swf::FillStyle::Color(color)], line_styles: Vec::new() };
        crate::shape::convert(&styles, &glyph.records)
    }

    /// The font as the bytes of a TrueType file.
    pub fn to_ttf(&self) -> Vec<u8> {
        let scale = if self.version >= 3 { 1.0 / 20.0 } else { 1.0 };
        // Glyph 0 is the empty glyph for characters that the font does not have.
        let mut outlines = vec![Vec::new()];
        outlines.extend(self.glyphs.iter().map(|g| contours(&g.records, scale)));
        let mut advances = vec![UNITS_PER_EM as i32 / 2];
        advances.extend(self.glyphs.iter().map(|g| g.advance));

        let mut glyf = Vec::new();
        let mut loca = Vec::new();
        let mut hmtx = Vec::new();
        let (mut x_min, mut y_min, mut x_max, mut y_max) = (0i32, 0i32, 0i32, 0i32);
        let (mut max_points, mut max_contours, mut min_lsb, mut min_rsb, mut max_extent) = (0usize, 0usize, i32::MAX, i32::MAX, 0i32);
        for (outline, &advance) in outlines.iter().zip(&advances) {
            loca.extend((glyf.len() as u32).to_be_bytes());
            let bounds = outline_bounds(outline);
            if let Some((l, b, r, t)) = bounds {
                write_glyph(&mut glyf, outline, (l, b, r, t));
                x_min = x_min.min(l);
                y_min = y_min.min(b);
                x_max = x_max.max(r);
                y_max = y_max.max(t);
                min_lsb = min_lsb.min(l);
                min_rsb = min_rsb.min(advance - r);
                max_extent = max_extent.max(r);
                max_points = max_points.max(outline.iter().map(|c| c.len()).sum());
                max_contours = max_contours.max(outline.len());
            }
            hmtx.extend((advance.max(0) as u16).to_be_bytes());
            hmtx.extend((bounds.map_or(0, |b| b.0) as i16).to_be_bytes());
        }
        loca.extend((glyf.len() as u32).to_be_bytes());
        let count = outlines.len() as u16;
        let (ascent, descent) = (self.ascent as i16, -(self.descent as i16));
        let advance_max = advances.iter().copied().max().unwrap_or(0) as u16;

        let mut head = Vec::new();
        put32(&mut head, 0x0001_0000);
        put32(&mut head, 0x0001_0000);
        put32(&mut head, 0); // checksum adjustment, set below
        put32(&mut head, 0x5F0F_3CF5);
        put16(&mut head, 0x000B);
        put16(&mut head, UNITS_PER_EM);
        head.extend([0u8; 16]); // created and modified
        for v in [x_min, y_min, x_max, y_max] {
            put16(&mut head, v as i16 as u16);
        }
        put16(&mut head, (self.bold as u16) | ((self.italic as u16) << 1));
        put16(&mut head, 8); // smallest readable size
        put16(&mut head, 2); // font direction hint
        put16(&mut head, 1); // long loca offsets
        put16(&mut head, 0);

        // The line height comes from the extent of the glyphs, as in the
        // fonts of JPEXS; the typographic values come from the font layout.
        let (top, bottom) = (y_max as i16, y_min as i16);
        let mut hhea = Vec::new();
        put32(&mut hhea, 0x0001_0000);
        for v in [top, bottom, LINE_GAP] {
            put16(&mut hhea, v as u16);
        }
        put16(&mut hhea, advance_max);
        for v in [if min_lsb == i32::MAX { 0 } else { min_lsb }, if min_rsb == i32::MAX { 0 } else { min_rsb }, max_extent] {
            put16(&mut hhea, v as i16 as u16);
        }
        for v in [1u16, 0, 0, 0, 0, 0, 0, 0, count] {
            put16(&mut hhea, v);
        }

        let mut maxp = Vec::new();
        put32(&mut maxp, 0x0001_0000);
        for v in [count, max_points as u16, max_contours as u16, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0] {
            put16(&mut maxp, v);
        }

        let codes: Vec<u16> = self.glyphs.iter().map(|g| g.code).collect();
        let mut os2 = Vec::new();
        put16(&mut os2, 3);
        let average = advances.iter().sum::<i32>() / advances.len() as i32;
        for v in [average as u16, if self.bold { 700 } else { 400 }, 5, 0] {
            put16(&mut os2, v);
        }
        os2.extend([0u8; 22]); // subscript, superscript and strikeout sizes, family class
        os2.extend([0u8; 10]); // panose
        os2.extend([0u8; 16]); // unicode ranges
        os2.extend(b"    ");
        put16(&mut os2, if self.bold { 0x20 } else { 0 } | if self.italic { 0x01 } else { 0 } | if !self.bold && !self.italic { 0x40 } else { 0 });
        put16(&mut os2, codes.iter().copied().min().unwrap_or(0));
        put16(&mut os2, codes.iter().copied().max().unwrap_or(0));
        for v in [ascent, descent, LINE_GAP] {
            put16(&mut os2, v as u16);
        }
        put16(&mut os2, top.max(0) as u16);
        put16(&mut os2, (-bottom).max(0) as u16);
        put32(&mut os2, 1);
        put32(&mut os2, 0);
        for v in [0u16, 0, 0, 32, 0] {
            put16(&mut os2, v);
        }

        let mut post = Vec::new();
        put32(&mut post, 0x0003_0000);
        post.extend([0u8; 28]);

        let tables: Vec<(&[u8; 4], Vec<u8>)> = vec![
            (b"OS/2", os2),
            (b"cmap", cmap(&codes)),
            (b"glyf", glyf),
            (b"head", head),
            (b"hhea", hhea),
            (b"hmtx", hmtx),
            (b"loca", loca),
            (b"maxp", maxp),
            (b"name", name_table(&self.name, if self.bold { "Bold" } else { "Regular" })),
            (b"post", post),
        ];
        let mut file = Vec::new();
        put32(&mut file, 0x0001_0000);
        let n = tables.len() as u16;
        let entry = 1u16 << (15 - n.leading_zeros());
        put16(&mut file, n);
        put16(&mut file, entry * 16);
        put16(&mut file, entry.trailing_zeros() as u16);
        put16(&mut file, n * 16 - entry * 16);
        let mut offset = 12 + 16 * tables.len();
        let mut body = Vec::new();
        let mut head_at = 0;
        for (tag, data) in &tables {
            if *tag == b"head" {
                head_at = offset;
            }
            file.extend(*tag);
            put32(&mut file, checksum(data));
            put32(&mut file, offset as u32);
            put32(&mut file, data.len() as u32);
            body.extend(data);
            while body.len() % 4 != 0 {
                body.push(0);
            }
            offset = 12 + 16 * tables.len() + body.len();
        }
        file.extend(body);
        let adjustment = 0xB1B0_AFBAu32.wrapping_sub(checksum(&file));
        file[head_at + 8..head_at + 12].copy_from_slice(&adjustment.to_be_bytes());
        file
    }
}

/// A point of an outline: x, y (up) and whether it is on the curve.
type OutlinePoint = (i32, i32, bool);

/// The contours of a glyph, with the outer contours clockwise and the holes
/// counterclockwise, as TrueType needs them. SWF fonts fill with the
/// even-odd rule, so a contour inside an odd number of others is a hole.
fn contours(records: &[ShapeRecord], scale: f32) -> Vec<Vec<OutlinePoint>> {
    let mut result: Vec<Vec<OutlinePoint>> = Vec::new();
    let (mut x, mut y) = (0i32, 0i32);
    // Truncated as JPEXS does, so that the fonts of earlier imports and these have the same metrics.
    let point = |x: i32, y: i32, on: bool| ((x as f32 * scale).trunc() as i32, -((y as f32 * scale).trunc() as i32), on);
    let mut current: Vec<OutlinePoint> = Vec::new();
    let close = |current: &mut Vec<OutlinePoint>, result: &mut Vec<Vec<OutlinePoint>>| {
        if current.len() > 1 && current.first().map(|p| (p.0, p.1)) == current.last().map(|p| (p.0, p.1)) {
            current.pop();
        }
        if current.len() >= 3 {
            result.push(std::mem::take(current));
        }
        current.clear();
    };
    for record in records {
        match record {
            ShapeRecord::StyleChange(change) => {
                if let Some(to) = change.move_to {
                    close(&mut current, &mut result);
                    x = to.x.get();
                    y = to.y.get();
                }
            }
            ShapeRecord::StraightEdge { delta } => {
                if current.is_empty() {
                    current.push(point(x, y, true));
                }
                x += delta.dx.get();
                y += delta.dy.get();
                current.push(point(x, y, true));
            }
            ShapeRecord::CurvedEdge { control_delta, anchor_delta } => {
                if current.is_empty() {
                    current.push(point(x, y, true));
                }
                x += control_delta.dx.get();
                y += control_delta.dy.get();
                current.push(point(x, y, false));
                x += anchor_delta.dx.get();
                y += anchor_delta.dy.get();
                current.push(point(x, y, true));
            }
        }
    }
    close(&mut current, &mut result);
    let holes: Vec<bool> = (0..result.len())
        .map(|i| {
            let (px, py, _) = result[i][0];
            result.iter().enumerate().filter(|(j, other)| *j != i && inside(other, px as f64 + 0.01, py as f64 + 0.01)).count() % 2 == 1
        })
        .collect();
    for (contour, hole) in result.iter_mut().zip(holes) {
        // The shoelace sum is positive for a counterclockwise contour, with y up.
        let area: i64 = (0..contour.len()).map(|i| {
            let (a, b) = (contour[i], contour[(i + 1) % contour.len()]);
            a.0 as i64 * b.1 as i64 - b.0 as i64 * a.1 as i64
        }).sum();
        if (area > 0) != hole {
            contour.reverse();
        }
    }
    result
}

fn inside(contour: &[OutlinePoint], x: f64, y: f64) -> bool {
    let mut result = false;
    for i in 0..contour.len() {
        let (a, b) = (contour[i], contour[(i + 1) % contour.len()]);
        let (ax, ay, bx, by) = (a.0 as f64, a.1 as f64, b.0 as f64, b.1 as f64);
        if (ay > y) != (by > y) && x < ax + (y - ay) * (bx - ax) / (by - ay) {
            result = !result;
        }
    }
    result
}

fn outline_bounds(outline: &[Vec<OutlinePoint>]) -> Option<(i32, i32, i32, i32)> {
    let mut points = outline.iter().flatten();
    let first = points.next()?;
    Some(points.fold((first.0, first.1, first.0, first.1), |(l, b, r, t), p| (l.min(p.0), b.min(p.1), r.max(p.0), t.max(p.1))))
}

fn write_glyph(glyf: &mut Vec<u8>, outline: &[Vec<OutlinePoint>], bounds: (i32, i32, i32, i32)) {
    put16(glyf, outline.len() as u16);
    for v in [bounds.0, bounds.1, bounds.2, bounds.3] {
        put16(glyf, v as i16 as u16);
    }
    let mut end = 0usize;
    for contour in outline {
        end += contour.len();
        put16(glyf, (end - 1) as u16);
    }
    put16(glyf, 0); // no instructions
    let points: Vec<&OutlinePoint> = outline.iter().flatten().collect();
    glyf.extend(points.iter().map(|p| p.2 as u8));
    let (mut x, mut y) = (0, 0);
    for p in &points {
        put16(glyf, (p.0 - x) as i16 as u16);
        x = p.0;
    }
    for p in &points {
        put16(glyf, (p.1 - y) as i16 as u16);
        y = p.1;
    }
    while glyf.len() % 4 != 0 {
        glyf.push(0);
    }
}

/// A cmap table of format 4, for Unicode on Windows and on other platforms.
fn cmap(codes: &[u16]) -> Vec<u8> {
    let mut map: Vec<(u16, u16)> = codes.iter().enumerate().map(|(i, &c)| (c, i as u16 + 1)).filter(|(c, _)| *c != 0xFFFF).collect();
    map.sort();
    map.dedup_by_key(|m| m.0);
    let segments = map.len() as u16 + 1;
    let mut sub = Vec::new();
    put16(&mut sub, 4);
    put16(&mut sub, 16 + 8 * segments);
    put16(&mut sub, 0);
    put16(&mut sub, segments * 2);
    let range = 2 * (1u16 << (15 - segments.leading_zeros()));
    put16(&mut sub, range);
    put16(&mut sub, range.trailing_zeros() as u16 - 1);
    put16(&mut sub, segments * 2 - range);
    for &(c, _) in &map {
        put16(&mut sub, c);
    }
    put16(&mut sub, 0xFFFF);
    put16(&mut sub, 0);
    for &(c, _) in &map {
        put16(&mut sub, c);
    }
    put16(&mut sub, 0xFFFF);
    for &(c, g) in &map {
        put16(&mut sub, g.wrapping_sub(c));
    }
    put16(&mut sub, 1);
    for _ in 0..segments {
        put16(&mut sub, 0);
    }
    let mut table = Vec::new();
    put16(&mut table, 0);
    put16(&mut table, 2);
    for (platform, encoding) in [(0u16, 3u16), (3, 1)] {
        put16(&mut table, platform);
        put16(&mut table, encoding);
        put32(&mut table, 4 + 8 * 2);
    }
    table.extend(sub);
    table
}

fn name_table(family: &str, style: &str) -> Vec<u8> {
    let full = format!("{family} {style}");
    let postscript: String = full.chars().filter(|c| c.is_ascii_alphanumeric()).collect();
    let names = [(1u16, family.to_string()), (2, style.to_string()), (4, full), (6, postscript)];
    let mut strings = Vec::new();
    let mut table = Vec::new();
    put16(&mut table, 0);
    put16(&mut table, names.len() as u16);
    put16(&mut table, 6 + 12 * names.len() as u16);
    for (id, text) in &names {
        let bytes: Vec<u8> = text.encode_utf16().flat_map(|u| u.to_be_bytes()).collect();
        for v in [3u16, 1, 0x409, *id, bytes.len() as u16, strings.len() as u16] {
            put16(&mut table, v);
        }
        strings.extend(bytes);
    }
    table.extend(strings);
    table
}

fn checksum(data: &[u8]) -> u32 {
    data.chunks(4).fold(0u32, |sum, chunk| {
        let mut word = [0u8; 4];
        word[..chunk.len()].copy_from_slice(chunk);
        sum.wrapping_add(u32::from_be_bytes(word))
    })
}

fn put16(out: &mut Vec<u8>, v: u16) {
    out.extend(v.to_be_bytes());
}

fn put32(out: &mut Vec<u8>, v: u32) {
    out.extend(v.to_be_bytes());
}
