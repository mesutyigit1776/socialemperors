class_name Store
extends RefCounted
## The items that the store offers: the store categories of the client and the
## "New" rotation of the server.
##
## The server offers some groups of items from config/shop_rotation.json at a
## time, and chooses other groups at the end of each period
## (get_game_config.apply_shop_rotation). The port chooses the groups with the
## same settings and rules, but with its own random numbers, so it can offer
## other groups than the server in the same period.

## The rotation items are in this category, and some in the other categories.
const CATEGORY_NEW := 12
const CATEGORIES: Array[int] = [1, 2, 3, 4, 5, CATEGORY_NEW]
## The client offers these items only to gold members. The server starts the
## client without gold membership.
const GOLD_MEMBER_ITEMS: Array[int] = [1234, 1426]
## The server offers this group only on 31 October when "spooktober" is on.
const HALLOWEEN := "Halloween"

var _config: GameConfig
var _factions: Dictionary = {}  # group name -> Array[int] of item ids
var _rotation_items: Dictionary = {}  # item id -> true, for all items of all groups
var _rotation_seconds: int
var _max_factions: int
var _full_random: bool
var _max_items_full_random: int
var _spooktober: bool
var _always_enabled: Array[String] = []


## Reads shop.json that the importer writes. Returns null and reports an error
## when the file is missing or not valid.
static func load_from_file(path: String, config: GameConfig) -> Store:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var settings: Variant = data.get("settings") if data is Dictionary else null
	if not (data is Dictionary and data.get("factions") is Dictionary and settings is Dictionary):
		push_error("Store rotation '%s' is missing or not valid. Import the game files again; see godot/README.md." % path)
		return null
	var store := Store.new()
	store._config = config
	for name: Variant in data["factions"]:
		var group: Variant = data["factions"][name]
		var ids: Array[int] = []
		for entry: Variant in group if group is Array else []:
			var id: Variant = GameConfig.to_int(entry)
			if id == null:
				push_error("Store rotation '%s' has an incorrect item in group '%s'." % [path, name])
				return null
			ids.append(id)
			store._rotation_items[id] = true
		if not group is Array:
			push_error("Store rotation '%s' has no item list for group '%s'." % [path, name])
			return null
		store._factions[str(name)] = ids
	var hours: Variant = settings.get("rotation_hours")
	var max_factions: Variant = GameConfig.to_int(settings.get("max_factions"))
	var max_items: Variant = GameConfig.to_int(settings.get("max_items_full_random"))
	if not (hours is float or hours is int) or hours * 3600 < 1 or max_factions == null or max_items == null \
			or not settings.get("full_random") is bool or not settings.get("spooktober") is bool:
		push_error("Store rotation '%s' has incorrect shop settings." % path)
		return null
	store._rotation_seconds = int(hours * 3600)
	store._max_factions = max_factions
	store._max_items_full_random = max_items
	store._full_random = settings["full_random"]
	store._spooktober = settings["spooktober"]
	for name: Variant in settings.get("always_enabled", []):
		store._always_enabled.append(str(name))
	return store


## The buildings that the store offers in a category to the race of the map
## ("h" or "t") at a level, at the time now (Unix seconds), in configuration order.
func items(category_id: int, race: String, level: int, now: int) -> Array[GameConfig.ItemDef]:
	var on_sale := rotation(now)
	var result: Array[GameConfig.ItemDef] = []
	for item: GameConfig.ItemDef in _config.items():
		if item.is_unit() or item.category_id != category_id or item.id in GOLD_MEMBER_ITEMS:
			continue
		if item.store_level > level:
			continue
		# The server sells the items of the rotation only to humans: it sets their in_store to 1.
		var sold := (race == "h" and on_sale.has(item.id)) if _rotation_items.has(item.id) else item.is_sold_to(race)
		if sold:
			result.append(item)
	return result


## The ids of the rotation items on sale at the time now.
func rotation(now: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = now / _rotation_seconds
	var halloween := _spooktober and _is_halloween(now)
	var chosen: Array[String] = []
	var result := {}
	if _full_random:
		var ids: Array[int] = []
		for name: String in _factions:
			if not (_spooktober and name == HALLOWEEN):
				ids.append_array(_factions[name])
		_shuffle(ids, rng)
		for id in ids.slice(0, _max_items_full_random):
			result[id] = true
		if halloween:
			chosen.append(HALLOWEEN)
	else:
		var names: Array[String] = []
		names.assign(_factions.keys())
		_shuffle(names, rng)
		if _spooktober:
			names.erase(HALLOWEEN)
		var count := mini(_max_factions, names.size())
		if halloween:
			count -= 1
			chosen.append(HALLOWEEN)
		chosen.append_array(names.slice(0, maxi(count, 0)))
	chosen.append_array(_always_enabled)
	for name in chosen:
		for id: int in _factions.get(name, []):
			result[id] = true
	return result


## The end of the rotation period that contains the time now.
func rotation_end(now: int) -> int:
	return (now / _rotation_seconds + 1) * _rotation_seconds


## The server checks the date in the local time of the computer.
static func _is_halloween(now: int) -> bool:
	var date := Time.get_datetime_dict_from_unix_time(now + Time.get_time_zone_from_system()["bias"] * 60)
	return date["month"] == 10 and date["day"] == 31


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value: Variant = values[i]
		values[i] = values[j]
		values[j] = value
