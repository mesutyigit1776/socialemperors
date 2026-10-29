class_name GameConfig
extends RefCounted
## Item definitions from the game configuration that the importer writes (config.json).


class ItemDef:
	var id: int
	var name: String
	var type: String  ## "u" is a unit; other types are buildings and decorations.
	var img_name: String
	var width: int  ## Footprint in tiles.
	var height: int

	func is_unit() -> bool:
		return type == "u"


var _items: Dictionary = {}  # int -> ItemDef


## Returns null and reports an error when the file is missing or not valid.
static func load_from_file(path: String) -> GameConfig:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read game configuration '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("items") is Array):
		push_error("Game configuration '%s' has no item list." % path)
		return null
	var config := GameConfig.new()
	for entry: Variant in data["items"]:
		var item := _parse_item(entry)
		if item == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		config._items[item.id] = item
	return config


func get_item(id: int) -> ItemDef:
	return _items.get(id)


static func _parse_item(entry: Variant) -> ItemDef:
	if not entry is Dictionary:
		return null
	var id: Variant = _to_int(entry.get("id"))
	var width: Variant = _to_int(entry.get("width", 1))
	var height: Variant = _to_int(entry.get("height", 1))
	if id == null or width == null or height == null or width < 1 or height < 1:
		return null
	var item := ItemDef.new()
	item.id = id
	item.name = str(entry.get("name", ""))
	item.type = str(entry.get("type", ""))
	item.img_name = str(entry.get("img_name", ""))
	item.width = width
	item.height = height
	return item


## The configuration stores most numbers as strings, but patches add JSON numbers,
## which Godot reads as floats. Returns null when the value is not a whole number.
static func _to_int(value: Variant) -> Variant:
	if value is String and value.is_valid_int():
		return value.to_int()
	if (value is float or value is int) and value == floorf(value):
		return int(value)
	return null
