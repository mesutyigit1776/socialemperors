class_name GameConfig
extends RefCounted
## Item and level definitions from the game configuration that the importer writes (config.json).


const CATEGORY_DECORATIONS := 4


class ItemDef:
	var id: int
	var name: String
	var type: String  ## "u" is a unit; other types are buildings and decorations.
	var img_name: String
	var width: int  ## Footprint in tiles.
	var height: int
	var category_id: int
	var in_store: bool
	var cost: int
	var cost_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var xp: int  ## Experience that the player gets when buying the item.
	var min_level: int

	func is_unit() -> bool:
		return type == "u"


class LevelDef:
	var name: String
	var exp_required: int  ## Total experience that the player needs for this level.
	var reward_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var reward_amount: int


var levels: Array[LevelDef] = []  ## levels[n - 1] is level n.
var start_level_mana_reward: int  ## From this level, each new level also gives mana.
var mana_reward_per_level: int

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
	# A level cannot be skipped like an item, because the list index is the level.
	for entry: Variant in data.get("levels", []):
		var level := _parse_level(entry)
		if level == null:
			push_error("Game configuration '%s' has an incorrect level: %s" % [path, str(entry).left(200)])
			return null
		config.levels.append(level)
	if config.levels.is_empty():
		push_error("Game configuration '%s' has no levels." % path)
		return null
	var globals: Variant = data.get("globals")
	var start_mana: Variant = _to_int(globals.get("START_LEVEL_MANA_REWARD")) if globals is Dictionary else null
	var mana_per_level: Variant = _to_int(globals.get("MANA_REWARD_PER_LEVEL")) if globals is Dictionary else null
	if start_mana == null or mana_per_level == null:
		push_error("Game configuration '%s' has no level mana reward in globals." % path)
		return null
	config.start_level_mana_reward = start_mana
	config.mana_reward_per_level = mana_per_level
	return config


func get_item(id: int) -> ItemDef:
	return _items.get(id)


## Items that the store sells in a category, in configuration order.
func store_items(category_id: int) -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	for item: ItemDef in _items.values():
		if item.in_store and item.category_id == category_id:
			result.append(item)
	return result


static func _parse_item(entry: Variant) -> ItemDef:
	if not entry is Dictionary:
		return null
	var numbers := {}
	for key: String in ["id", "width", "height", "category_id", "in_store", "cost", "xp", "min_level"]:
		numbers[key] = _to_int(entry.get(key, 1 if key in ["width", "height"] else 0))
		if numbers[key] == null:
			return null
	if numbers["width"] < 1 or numbers["height"] < 1 or numbers["cost"] < 0:
		return null
	var item := ItemDef.new()
	item.id = numbers["id"]
	item.name = str(entry.get("name", ""))
	item.type = str(entry.get("type", ""))
	item.img_name = str(entry.get("img_name", ""))
	item.width = numbers["width"]
	item.height = numbers["height"]
	item.category_id = numbers["category_id"]
	item.in_store = numbers["in_store"] == 1
	item.cost = numbers["cost"]
	item.cost_type = str(entry.get("cost_type", ""))
	item.xp = numbers["xp"]
	item.min_level = numbers["min_level"]
	return item


static func _parse_level(entry: Variant) -> LevelDef:
	if not entry is Dictionary:
		return null
	var exp_required: Variant = _to_int(entry.get("exp_required"))
	var reward_amount: Variant = _to_int(entry.get("reward_amount"))
	if exp_required == null or reward_amount == null:
		return null
	var level := LevelDef.new()
	level.name = str(entry.get("name", ""))
	level.exp_required = exp_required
	level.reward_type = str(entry.get("reward_type", ""))
	level.reward_amount = reward_amount
	return level


## The configuration stores most numbers as strings, but patches add JSON numbers,
## which Godot reads as floats. Returns null when the value is not a whole number.
static func _to_int(value: Variant) -> Variant:
	if value is String and value.is_valid_int():
		return value.to_int()
	if (value is float or value is int) and value == floorf(value):
		return int(value)
	return null
