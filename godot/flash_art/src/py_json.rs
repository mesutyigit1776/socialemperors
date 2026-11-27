//! Writes JSON as Python's `json.dump` does (ensure_ascii, the separators
//! ", " and ": ", or the indent "\t", and the float format of `repr`), so
//! that the files of the import are equal to those of the server code and
//! of the Python importer. The values are `serde_json::Value`, which keeps
//! the order of the keys and whether a number is an int or a float.

use serde_json::Value;

/// `json.dumps(value)` with `indent=None`, or with `indent="\t"` when indent is true.
pub fn to_string(value: &Value, indent: bool) -> String {
    let mut out = String::new();
    write_value(&mut out, value, if indent { Some(0) } else { None });
    out
}

fn write_value(out: &mut String, value: &Value, level: Option<usize>) {
    match value {
        Value::Null => out.push_str("null"),
        Value::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                out.push_str(&i.to_string());
            } else if let Some(u) = n.as_u64() {
                out.push_str(&u.to_string());
            } else {
                out.push_str(&float_repr(n.as_f64().unwrap_or(f64::NAN)));
            }
        }
        Value::String(s) => write_string(out, s),
        Value::Array(items) => {
            if items.is_empty() {
                out.push_str("[]");
                return;
            }
            out.push('[');
            for (i, item) in items.iter().enumerate() {
                separator(out, i, level);
                write_value(out, item, level.map(|l| l + 1));
            }
            close(out, level);
            out.push(']');
        }
        Value::Object(map) => {
            if map.is_empty() {
                out.push_str("{}");
                return;
            }
            out.push('{');
            for (i, (key, item)) in map.iter().enumerate() {
                separator(out, i, level);
                write_string(out, key);
                out.push_str(": ");
                write_value(out, item, level.map(|l| l + 1));
            }
            close(out, level);
            out.push('}');
        }
    }
}

fn separator(out: &mut String, index: usize, level: Option<usize>) {
    match level {
        Some(level) => {
            if index > 0 {
                out.push(',');
            }
            out.push('\n');
            out.extend(std::iter::repeat_n('\t', level + 1));
        }
        None => {
            if index > 0 {
                out.push_str(", ");
            }
        }
    }
}

fn close(out: &mut String, level: Option<usize>) {
    if let Some(level) = level {
        out.push('\n');
        out.extend(std::iter::repeat_n('\t', level));
    }
}

fn write_string(out: &mut String, s: &str) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            ' '..='~' => out.push(c),
            _ => {
                let mut units = [0u16; 2];
                for unit in c.encode_utf16(&mut units) {
                    out.push_str(&format!("\\u{:04x}", unit));
                }
            }
        }
    }
    out.push('"');
}

/// `repr(x)` of a Python float, as `json.dump` writes it.
pub fn float_repr(x: f64) -> String {
    if x.is_nan() {
        return "NaN".into();
    }
    if x.is_infinite() {
        return if x > 0.0 { "Infinity".into() } else { "-Infinity".into() };
    }
    // Python writes the fewest digits that read back as x, rounded from the
    // exact value of x. Rust finds the fewest digits, but for a value
    // exactly between two such numbers it can choose the other one, so the
    // digits are rounded again from the exact value.
    let shortest = format!("{:e}", x.abs());
    let count = shortest.split_once('e').unwrap().0.chars().filter(char::is_ascii_digit).count();
    let text = format!("{:.*e}", count - 1, x.abs());
    let (mantissa, exponent) = text.split_once('e').unwrap();
    let exponent: i32 = exponent.parse().unwrap();
    let digits: String = mantissa.chars().filter(|c| *c != '.').collect();
    let sign = if x.is_sign_negative() { "-" } else { "" };
    if (-4..16).contains(&exponent) {
        let point = exponent + 1;
        if point <= 0 {
            format!("{sign}0.{}{digits}", "0".repeat((-point) as usize))
        } else if digits.len() as i32 <= point {
            format!("{sign}{digits}{}.0", "0".repeat((point - digits.len() as i32) as usize))
        } else {
            let (whole, fraction) = digits.split_at(point as usize);
            format!("{sign}{whole}.{fraction}")
        }
    } else {
        let fraction = if digits.len() > 1 { format!(".{}", &digits[1..]) } else { String::new() };
        let exponent_sign = if exponent < 0 { "-" } else { "+" };
        format!("{sign}{}{fraction}e{exponent_sign}{:02}", &digits[..1], exponent.abs())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn floats_as_python() {
        let cases = [
            (1.0, "1.0"), (0.1, "0.1"), (-3.5, "-3.5"), (1e16, "1e+16"), (1e15, "1000000000000000.0"),
            (0.0001, "0.0001"), (0.00001, "1e-05"), (1.5e-7, "1.5e-07"), (123456789.123, "123456789.123"),
            (1.2345678901234568e17, "1.2345678901234568e+17"), (-92.397125244140625, "-92.39712524414062"), (-0.0, "-0.0"), (0.0, "0.0"), (1e100, "1e+100"),
        ];
        for (x, text) in cases {
            assert_eq!(float_repr(x), text);
        }
    }

    #[test]
    fn layout_as_python() {
        let value: Value = serde_json::from_str(r#"{"a": [1, 2.0, {}], "b": [], "é": "x\u0001😀"}"#).unwrap();
        assert_eq!(to_string(&value, false), r#"{"a": [1, 2.0, {}], "b": [], "\u00e9": "x\u0001\ud83d\ude00"}"#);
        assert_eq!(to_string(&value, true), "{\n\t\"a\": [\n\t\t1,\n\t\t2.0,\n\t\t{}\n\t],\n\t\"b\": [],\n\t\"\\u00e9\": \"x\\u0001\\ud83d\\ude00\"\n}");
    }
}
