class_name Village
extends RefCounted
## One map of a village save, in the format that the server stores in saves/<USERID>.save.json.
##
## The village keeps the whole save document. It changes only the values that
## an operation changes, so that the server and the original client can still
## load the save. The server command handlers in op.py are the reference for
## these changes.

enum Placement {
	OK,
	OUTSIDE_MAP,
	NOT_OWNED_LAND,
	OCCUPIED,
	LEVEL_TOO_LOW,
	NOT_ENOUGH_RESOURCES,
	UNKNOWN_RESOURCE,
}

## Resource codes in item costs and where the save keeps each resource.
## "map" values are in the map; "player" values are in playerInfo.
const RESOURCE_KEYS := {
	"g": ["map", "coins"],
	"w": ["map", "wood"],
	"s": ["map", "stone"],
	"f": ["map", "food"],
	"c": ["player", "cash"],
}


class PlacedItem:
	var item_id: int
	var tile: Vector2i
	var frame: int  ## 0-based graphic frame; the client uses it for orientation and state.


var items: Array[PlacedItem] = []
var owned_land: PackedInt32Array = []  ## Land area numbers, see IsoGrid.land_area_number().
var skin: int = 0  ## Map style; selects the land item 1000 + skin.

var _document: Dictionary  # The whole save.
var _map: Dictionary  # The map in _document that this village shows.
var _config: GameConfig
var _occupied := PackedByteArray()  # 1 for each tile that an item covers, row by row.


## Returns null and reports an error when the file is missing or not a valid save.
static func load_from_file(path: String, config: GameConfig, map_index: int = 0) -> Village:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read village '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("maps") is Array and data.get("playerInfo") is Dictionary):
		push_error("Village '%s' is not a save: it has no maps or no playerInfo." % path)
		return null
	var maps: Array = data["maps"]
	if map_index < 0 or map_index >= maps.size() or not maps[map_index] is Dictionary:
		push_error("Village '%s' has no map %d." % [path, map_index])
		return null
	var game_map: Dictionary = maps[map_index]
	if not game_map.get("items") is Array:
		push_error("Map %d of village '%s' has no item list." % [map_index, path])
		return null
	for key in ["level", "xp", "coins", "wood", "stone", "food"]:
		if not (game_map.get(key) is float or game_map.get(key) is int):
			push_error("Map %d of village '%s' has no number '%s'." % [map_index, path, key])
			return null

	var village := Village.new()
	village._document = data
	village._map = game_map
	village._config = config
	village._occupied.resize(IsoGrid.MAP_TILES * IsoGrid.MAP_TILES)
	village.skin = int(game_map.get("skin", 0))
	for area: Variant in game_map.get("expansions", []):
		if (area is int or area is float) and int(area) >= 1 and int(area) <= IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS:
			village.owned_land.append(int(area))
	for entry: Variant in game_map["items"]:
		var placed := _parse_item(entry)
		if placed == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		village._add(placed)
	return village


func get_level() -> int:
	return int(_map["level"])


func get_xp() -> int:
	return int(_map["xp"])


## Returns -1 for a resource code that the save does not keep.
func get_resource(code: String) -> int:
	if not RESOURCE_KEYS.has(code):
		return -1
	var place: Array = RESOURCE_KEYS[code]
	var source: Dictionary = _map if place[0] == "map" else _document["playerInfo"]
	return int(source.get(place[1], 0))


## Checks only the location: the map edges, the owned land and the other items.
func check_location(item: GameConfig.ItemDef, tile: Vector2i) -> Placement:
	var covered := footprint(item, tile)
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).encloses(covered):
		return Placement.OUTSIDE_MAP
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			var area := Vector2i(x, y) / IsoGrid.LAND_TILES
			if not IsoGrid.land_area_number(area) in owned_land:
				return Placement.NOT_OWNED_LAND
			if _occupied[y * IsoGrid.MAP_TILES + x] != 0:
				return Placement.OCCUPIED
	return Placement.OK


## Buys an item from the store and places it, as the server command "buy" does.
## Changes nothing when the result is not OK.
func buy(item: GameConfig.ItemDef, tile: Vector2i, timestamp: int) -> Placement:
	var location := check_location(item, tile)
	if location != Placement.OK:
		return location
	if get_level() < item.min_level:
		return Placement.LEVEL_TOO_LOW
	var available := get_resource(item.cost_type)
	if available < 0:
		return Placement.UNKNOWN_RESOURCE
	if available < item.cost:
		return Placement.NOT_ENOUGH_RESOURCES

	var place: Array = RESOURCE_KEYS[item.cost_type]
	var source: Dictionary = _map if place[0] == "map" else _document["playerInfo"]
	source[place[1]] = available - item.cost
	_map["xp"] = get_xp() + item.xp
	# Entry format of the server: [item_id, x, y, orientation, timestamp, level, store, attributes].
	_map["items"].append([item.id, tile.x, tile.y, 0, timestamp, 0, [], {}])
	var placed := PlacedItem.new()
	placed.item_id = item.id
	placed.tile = tile
	_add(placed)
	return Placement.OK


## Writes the save to a temporary file, keeps the old file as <path>.bak, then
## puts the new file in its place, as the server does.
func save_to_file(save_path: String) -> Error:
	var path := ProjectSettings.globalize_path(save_path)
	var temp_path := path.get_base_dir().path_join(".%s.tmp" % path.get_file())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_whole_numbers_as_int(_document), "\t", false))
	file.close()
	var error := file.get_error()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp_path, path)


func _add(placed: PlacedItem) -> void:
	items.append(placed)
	var item := _config.get_item(placed.item_id)
	if item == null:
		push_warning("The village contains item %d, which is not in the configuration." % placed.item_id)
		return
	# Units also mark their tile as occupied in the client.
	var covered := footprint(item, placed.tile).intersection(Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES))
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			_occupied[y * IsoGrid.MAP_TILES + x] = 1


## The tiles that an item covers. tile is the front tile; the item extends up and to the left of it.
static func footprint(item: GameConfig.ItemDef, tile: Vector2i) -> Rect2i:
	return Rect2i(tile.x - item.width + 1, tile.y - item.height + 1, item.width, item.height)


## An item entry is [item_id, x, y, frame, timestamp, ...].
static func _parse_item(entry: Variant) -> PlacedItem:
	if not (entry is Array and entry.size() >= 4):
		return null
	for i in 4:
		if not (entry[i] is int or entry[i] is float):
			return null
	var placed := PlacedItem.new()
	placed.item_id = int(entry[0])
	placed.tile = Vector2i(int(entry[1]), int(entry[2]))
	placed.frame = int(entry[3])
	var inside := Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(placed.tile)
	if not inside or placed.frame < 0:
		return null
	return placed


## Godot reads every JSON number as a float and writes it with ".0". The server
## uses some numbers as list indexes, which must be integers. Saves contain
## whole numbers, except some timestamps with a fraction.
static func _whole_numbers_as_int(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Array:
		var result := []
		for element: Variant in value:
			result.append(_whole_numbers_as_int(element))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _whole_numbers_as_int(value[key])
		return result
	return value
