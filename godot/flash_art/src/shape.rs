//! Converts the edges of a SWF shape to closed paths, one for each fill style.
//!
//! A SWF shape stores edges, and each edge names the fill on its left side
//! (fill style 0) and on its right side (fill style 1). The edges of one fill
//! are joined end to start into closed contours, which are filled with the
//! even-odd rule. Strokes follow the edges in the order of the file.

use std::collections::HashMap;

use swf::{FillStyle, LineStyle, ShapeRecord, ShapeStyles};
use tiny_skia::{Path, PathBuilder};

/// The edges drawn with one set of styles. A shape gets a new layer when it
/// changes its style lists; the layers draw in order.
pub struct ShapeLayer {
    pub fills: Vec<(FillStyle, Path)>,
    pub strokes: Vec<(LineStyle, Path)>,
}

type Point = (i32, i32);

#[derive(Clone, Copy)]
struct Edge {
    from: Point,
    control: Option<Point>,
    to: Point,
}

impl Edge {
    fn reversed(self) -> Edge {
        Edge { from: self.to, control: self.control, to: self.from }
    }
}

struct Builder {
    fill_styles: Vec<FillStyle>,
    line_styles: Vec<LineStyle>,
    fill_edges: Vec<Vec<Edge>>,
    /// For each line style, the lines: runs of connected edges.
    line_edges: Vec<Vec<Vec<Edge>>>,
    layers: Vec<ShapeLayer>,
}

impl Builder {
    fn new_styles(&mut self, styles: &ShapeStyles) {
        self.flush();
        self.fill_styles = styles.fill_styles.clone();
        self.line_styles = styles.line_styles.clone();
        self.fill_edges = vec![Vec::new(); self.fill_styles.len()];
        self.line_edges = vec![Vec::new(); self.line_styles.len()];
    }

    fn flush(&mut self) {
        let mut layer = ShapeLayer { fills: Vec::new(), strokes: Vec::new() };
        for (style, edges) in self.fill_styles.iter().zip(self.fill_edges.drain(..)) {
            if let Some(path) = closed_path(edges) {
                layer.fills.push((style.clone(), path));
            }
        }
        for (style, lines) in self.line_styles.iter().zip(self.line_edges.drain(..)) {
            if let Some(path) = open_path(lines) {
                layer.strokes.push((style.clone(), path));
            }
        }
        if !layer.fills.is_empty() || !layer.strokes.is_empty() {
            self.layers.push(layer);
        }
    }
}

pub fn convert(styles: &ShapeStyles, records: &[ShapeRecord]) -> Vec<ShapeLayer> {
    let mut builder = Builder { fill_styles: Vec::new(), line_styles: Vec::new(), fill_edges: Vec::new(), line_edges: Vec::new(), layers: Vec::new() };
    builder.new_styles(styles);
    let (mut fill0, mut fill1, mut line) = (0usize, 0usize, 0usize);
    let mut position: Point = (0, 0);
    // A new line starts after a move or a change of the line style.
    let mut line_open = false;
    for record in records {
        let edge = match record {
            ShapeRecord::StyleChange(change) => {
                if let Some(new_styles) = &change.new_styles {
                    builder.new_styles(new_styles);
                    (fill0, fill1, line) = (0, 0, 0);
                }
                if let Some(to) = change.move_to {
                    position = (to.x.get(), to.y.get());
                    line_open = false;
                }
                if let Some(style) = change.fill_style_0 {
                    fill0 = style as usize;
                }
                if let Some(style) = change.fill_style_1 {
                    fill1 = style as usize;
                }
                if let Some(style) = change.line_style {
                    line = style as usize;
                    line_open = false;
                }
                continue;
            }
            ShapeRecord::StraightEdge { delta } => {
                let to = (position.0 + delta.dx.get(), position.1 + delta.dy.get());
                Edge { from: position, control: None, to }
            }
            ShapeRecord::CurvedEdge { control_delta, anchor_delta } => {
                let control = (position.0 + control_delta.dx.get(), position.1 + control_delta.dy.get());
                let to = (control.0 + anchor_delta.dx.get(), control.1 + anchor_delta.dy.get());
                Edge { from: position, control: Some(control), to }
            }
        };
        position = edge.to;
        // Fill style 1 is on the right of the edge in the direction of the
        // edge; fill style 0 on the left, so its contour runs the other way.
        if fill1 > 0 && fill1 <= builder.fill_edges.len() {
            builder.fill_edges[fill1 - 1].push(edge);
        }
        if fill0 > 0 && fill0 <= builder.fill_edges.len() {
            builder.fill_edges[fill0 - 1].push(edge.reversed());
        }
        if line > 0 && line <= builder.line_edges.len() {
            let lines = &mut builder.line_edges[line - 1];
            if line_open && lines.last().and_then(|l| l.last()).is_some_and(|last| last.to == edge.from) {
                lines.last_mut().unwrap().push(edge);
            } else {
                lines.push(vec![edge]);
            }
            line_open = true;
        }
    }
    builder.flush();
    builder.layers
}

/// Joins the edges into closed contours.
fn closed_path(edges: Vec<Edge>) -> Option<Path> {
    if edges.is_empty() {
        return None;
    }
    let mut starting_at: HashMap<Point, Vec<usize>> = HashMap::new();
    for (i, edge) in edges.iter().enumerate().rev() {
        starting_at.entry(edge.from).or_default().push(i);
    }
    let mut used = vec![false; edges.len()];
    let mut path = PathBuilder::new();
    for first in 0..edges.len() {
        if used[first] {
            continue;
        }
        used[first] = true;
        let start = edges[first].from;
        path.move_to(start.0 as f32, start.1 as f32);
        add_edge(&mut path, &edges[first]);
        let mut at = edges[first].to;
        while at != start {
            let next = starting_at.get_mut(&at).and_then(|list| {
                while let Some(i) = list.pop() {
                    if !used[i] {
                        return Some(i);
                    }
                }
                None
            });
            let Some(next) = next else { break };
            used[next] = true;
            add_edge(&mut path, &edges[next]);
            at = edges[next].to;
        }
        path.close();
    }
    path.finish()
}

fn open_path(lines: Vec<Vec<Edge>>) -> Option<Path> {
    let mut path = PathBuilder::new();
    for line in lines {
        let start = line[0].from;
        path.move_to(start.0 as f32, start.1 as f32);
        for edge in &line {
            add_edge(&mut path, edge);
        }
        if line.last().unwrap().to == start && line.len() > 1 {
            path.close();
        }
    }
    path.finish()
}

fn add_edge(path: &mut PathBuilder, edge: &Edge) {
    match edge.control {
        Some(c) => path.quad_to(c.0 as f32, c.1 as f32, edge.to.0 as f32, edge.to.1 as f32),
        None => path.line_to(edge.to.0 as f32, edge.to.1 as f32),
    }
}

/// The records of a morph shape at ratio (0: start, 1: end), as the records of a shape.
pub fn morph_records(start: &[ShapeRecord], end: &[ShapeRecord], ratio: f32) -> Vec<ShapeRecord> {
    use swf::{Point as SwfPoint, PointDelta, StyleChangeData, Twips};
    let lerp = |a: i32, b: i32| Twips::new((a as f32 + (b - a) as f32 * ratio).round() as i32);
    let mut result = Vec::with_capacity(start.len());
    let mut ends = end.iter();
    // The positions in both shapes, so that the deltas of the result stay exact after rounding.
    let (mut a, mut b, mut out): (Point, Point, Point) = ((0, 0), (0, 0), (0, 0));
    for record in start {
        match record {
            ShapeRecord::StyleChange(change) => {
                let mut change: StyleChangeData = (**change).clone();
                if let Some(to) = change.move_to {
                    a = (to.x.get(), to.y.get());
                    // The end shape has a move for each move of the start shape.
                    let end_move = loop {
                        match ends.clone().next() {
                            Some(ShapeRecord::StyleChange(e)) => {
                                ends.next();
                                if let Some(m) = e.move_to {
                                    break Some(m);
                                }
                            }
                            _ => break None,
                        }
                    };
                    if let Some(m) = end_move {
                        b = (m.x.get(), m.y.get());
                    } else {
                        b = a;
                    }
                    out = (lerp(a.0, b.0).get(), lerp(a.1, b.1).get());
                    change.move_to = Some(SwfPoint::new(Twips::new(out.0), Twips::new(out.1)));
                }
                result.push(ShapeRecord::StyleChange(Box::new(change)));
            }
            edge => {
                let end_edge = loop {
                    match ends.next() {
                        Some(ShapeRecord::StyleChange(e)) => {
                            if let Some(m) = e.move_to {
                                b = (m.x.get(), m.y.get());
                            }
                        }
                        Some(e) => break Some(e),
                        None => break None,
                    }
                };
                let (ac, at) = edge_points(a, edge);
                let (bc, bt) = match end_edge {
                    Some(e) => edge_points(b, e),
                    None => (ac, at),
                };
                a = at;
                b = bt;
                let to = (lerp(at.0, bt.0).get(), lerp(at.1, bt.1).get());
                let straight = matches!(edge, ShapeRecord::StraightEdge { .. }) && matches!(end_edge, Some(ShapeRecord::StraightEdge { .. }) | None);
                if straight {
                    result.push(ShapeRecord::StraightEdge { delta: PointDelta::new(Twips::new(to.0 - out.0), Twips::new(to.1 - out.1)) });
                } else {
                    let control = (lerp(ac.0, bc.0).get(), lerp(ac.1, bc.1).get());
                    result.push(ShapeRecord::CurvedEdge {
                        control_delta: PointDelta::new(Twips::new(control.0 - out.0), Twips::new(control.1 - out.1)),
                        anchor_delta: PointDelta::new(Twips::new(to.0 - control.0), Twips::new(to.1 - control.1)),
                    });
                }
                out = to;
            }
        }
    }
    result
}

/// The control point and the end of an edge that starts at from. A straight
/// edge gets its middle as control point, so that it can morph into a curve.
fn edge_points(from: Point, edge: &ShapeRecord) -> (Point, Point) {
    match edge {
        ShapeRecord::StraightEdge { delta } => {
            let to = (from.0 + delta.dx.get(), from.1 + delta.dy.get());
            (((from.0 + to.0) / 2, (from.1 + to.1) / 2), to)
        }
        ShapeRecord::CurvedEdge { control_delta, anchor_delta } => {
            let control = (from.0 + control_delta.dx.get(), from.1 + control_delta.dy.get());
            (control, (control.0 + anchor_delta.dx.get(), control.1 + anchor_delta.dy.get()))
        }
        ShapeRecord::StyleChange(_) => (from, from),
    }
}
