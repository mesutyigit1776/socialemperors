//! The classes SwfImport and PythonRandom that the import of the game files
//! (godot/importer/) uses. Paths are absolute paths of the file system.
//!
//! A function that can fail returns {"value": result} or {"error": text}.

use std::panic::{AssertUnwindSafe, catch_unwind};

use godot::prelude::*;
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};

use crate::py_json;
use crate::py_random;
use crate::swf_import::{self, SwfFile};

/// The source of the Rust part of the import, for SwfImport.version().
const SOURCES: [&str; 4] = [include_str!("swf_import.rs"), include_str!("py_json.rs"), include_str!("py_random.rs"), include_str!("import_api.rs")];

#[derive(GodotClass)]
#[class(base = RefCounted, no_init)]
pub struct SwfImport;

#[godot_api]
impl SwfImport {
    /// A hash of the Rust code of the import. The import of a graphic is done
    /// again when it changes.
    #[func]
    fn version() -> GString {
        let mut digest = Sha256::new();
        for source in SOURCES {
            digest.update(source.as_bytes());
        }
        GString::from(&hex(&digest.finalize())[..16])
    }

    /// Reads JSON as Python's json.load does: an int stays an int (Godot's
    /// JSON class makes it a float), and the keys keep their order.
    #[func]
    fn parse_json(text: GString) -> VarDictionary {
        outcome(serde_json::from_str::<Value>(&text.to_string()).map(|value| to_variant(&value)).map_err(|e| e.to_string()))
    }

    /// Writes JSON as Python's json.dump does, with indent "\t" when indent is
    /// true. An error when the value has a type that JSON does not have.
    #[func]
    fn to_json(value: Variant, indent: bool) -> VarDictionary {
        outcome(from_variant(&value).map(|json| py_json::to_string(&json, indent).to_variant()))
    }

    /// An error when the symbol is not an exported sprite of the file, which the port can draw.
    #[func]
    fn check_sprite(path: GString, symbol: GString) -> VarDictionary {
        guarded(|| SwfFile::open(&path.to_string())?.check_sprite(&symbol.to_string()).map(|_| Variant::nil()))
    }

    /// How a spell graphic plays: {"labels": {label: frame}, "loop_from": frame or null}.
    #[func]
    fn spell_graphic(path: GString, symbol: GString) -> VarDictionary {
        guarded(|| swf_import::spell_graphic(&SwfFile::open(&path.to_string())?, &symbol.to_string()).map(|v| to_variant(&v)))
    }

    /// For each frame of an exported sprite, the matrix [a, b, c, d, x, y]
    /// (x and y in pixels) of each placed character.
    #[func]
    fn frame_matrices(path: GString, symbol: GString) -> VarDictionary {
        guarded(|| {
            let frames = SwfFile::open(&path.to_string())?.frame_matrices(&symbol.to_string())?;
            Ok(to_variant(&serde_json::to_value(frames).map_err(|e| e.to_string())?))
        })
    }

    /// The sounds with a class name: {class name: bytes of an MP3 file}.
    #[func]
    fn sounds(path: GString) -> VarDictionary {
        guarded(|| {
            let swf = SwfFile::open(&path.to_string())?;
            let mut sounds = VarDictionary::new();
            for (name, mp3) in swf.mp3_sounds()? {
                sounds.set(name.as_str(), &PackedByteArray::from(mp3));
            }
            Ok(sounds.to_variant())
        })
    }

    /// The windows of the symbols of one SWF file: {"swf": bytes of
    /// windows.swf, "layout": text of layout.json, "count": number of
    /// sprites and buttons}, see godot/importer/ui_import.gd.
    #[func]
    fn windows(path: GString, symbols: PackedStringArray) -> VarDictionary {
        guarded(|| {
            let names: Vec<String> = symbols.as_slice().iter().map(|s| s.to_string()).collect();
            let windows = swf_import::import_windows(&mut SwfFile::open(&path.to_string())?, &names)?;
            let mut result = VarDictionary::new();
            result.set("swf", &PackedByteArray::from(windows.swf));
            result.set("layout", py_json::to_string(&windows.layout, true).as_str());
            result.set("count", windows.count as i64);
            Ok(result.to_variant())
        })
    }
}

/// The random generator of Python, see py_random.rs.
#[derive(GodotClass)]
#[class(base = RefCounted, no_init)]
pub struct PythonRandom {
    random: py_random::PyRandom,
}

#[godot_api]
impl PythonRandom {
    /// random.seed(seed) for an int.
    #[func]
    fn from_int(seed: i64) -> Gd<PythonRandom> {
        Gd::from_object(PythonRandom { random: py_random::PyRandom::from_int(seed) })
    }

    /// random.Random(seed) for a str.
    #[func]
    fn from_text(seed: GString) -> Gd<PythonRandom> {
        Gd::from_object(PythonRandom { random: py_random::PyRandom::from_text(&seed.to_string()) })
    }

    /// random.random()
    #[func]
    fn random(&mut self) -> f64 {
        self.random.random()
    }

    /// random.randrange(n): an int in [0, n); n must be above 0.
    #[func]
    fn randrange(&mut self, n: i64) -> i64 {
        assert!(n > 0, "empty range for randrange()");
        self.random.randbelow(n as u64) as i64
    }

    /// random.shuffle(array)
    #[func]
    fn shuffle(&mut self, mut array: VarArray) {
        for i in (1..array.len()).rev() {
            let j = self.random.randbelow(i as u64 + 1) as usize;
            let (a, b) = (array.at(i), array.at(j));
            array.set(i, &b);
            array.set(j, &a);
        }
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn outcome(result: Result<Variant, String>) -> VarDictionary {
    let mut dictionary = VarDictionary::new();
    match result {
        Ok(value) => dictionary.set("value", &value),
        Err(error) => dictionary.set("error", error.as_str()),
    }
    dictionary
}

/// outcome() of a function that reads a SWF file. A damaged file can make
/// the reading go out of the data; this is an error of the import, not of the game.
fn guarded(work: impl FnOnce() -> Result<Variant, String>) -> VarDictionary {
    outcome(catch_unwind(AssertUnwindSafe(work)).unwrap_or_else(|_| Err("the SWF file is damaged".into())))
}

fn to_variant(value: &Value) -> Variant {
    match value {
        Value::Null => Variant::nil(),
        Value::Bool(b) => b.to_variant(),
        Value::Number(n) => n.as_i64().map_or_else(|| n.as_f64().unwrap_or(f64::NAN).to_variant(), |i| i.to_variant()),
        Value::String(s) => s.as_str().to_variant(),
        Value::Array(items) => items.iter().map(to_variant).collect::<VarArray>().to_variant(),
        Value::Object(map) => {
            let mut dictionary = VarDictionary::new();
            for (key, item) in map {
                dictionary.set(key.as_str(), &to_variant(item));
            }
            dictionary.to_variant()
        }
    }
}

fn from_variant(value: &Variant) -> Result<Value, String> {
    Ok(match value.get_type() {
        VariantType::NIL => Value::Null,
        VariantType::BOOL => Value::Bool(value.to()),
        VariantType::INT => Value::from(value.to::<i64>()),
        VariantType::FLOAT => float_value(value.to()),
        VariantType::STRING | VariantType::STRING_NAME => Value::String(value.to::<GString>().to_string()),
        VariantType::ARRAY => Value::Array(value.to::<VarArray>().iter_shared().map(|item| from_variant(&item)).collect::<Result<_, _>>()?),
        VariantType::PACKED_INT32_ARRAY => Value::from(value.to::<PackedInt32Array>().to_vec()),
        VariantType::PACKED_INT64_ARRAY => Value::from(value.to::<PackedInt64Array>().to_vec()),
        VariantType::PACKED_FLOAT64_ARRAY => Value::Array(value.to::<PackedFloat64Array>().to_vec().into_iter().map(float_value).collect()),
        VariantType::PACKED_STRING_ARRAY => Value::from(value.to::<PackedStringArray>().as_slice().iter().map(|s| s.to_string()).collect::<Vec<_>>()),
        VariantType::DICTIONARY => {
            let mut map = Map::new();
            for (key, item) in value.to::<VarDictionary>().iter_shared() {
                map.insert(key_text(&key)?, from_variant(&item)?);
            }
            Value::Object(map)
        }
        other => return Err(format!("JSON has no value of the type {other:?}")),
    })
}

fn float_value(x: f64) -> Value {
    serde_json::Number::from_f64(x).map_or(Value::Null, Value::Number)
}

/// The text of a key, as Python's json.dump writes keys that are not str.
fn key_text(key: &Variant) -> Result<String, String> {
    Ok(match key.get_type() {
        VariantType::STRING | VariantType::STRING_NAME => key.to::<GString>().to_string(),
        VariantType::INT => key.to::<i64>().to_string(),
        VariantType::FLOAT => py_json::float_repr(key.to()),
        VariantType::BOOL => if key.to::<bool>() { "true" } else { "false" }.into(),
        VariantType::NIL => "null".into(),
        other => return Err(format!("JSON has no key of the type {other:?}")),
    })
}
