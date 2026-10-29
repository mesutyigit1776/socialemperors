class_name Village
extends RefCounted
## One map of a village save, in the format that the server stores in saves/<USERID>.save.json.


class PlacedItem:
	var item_id: int
	var tile: Vector2i
	var frame: int  ## 0-based graphic frame; the client uses it for orientation and state.


var items: Array[PlacedItem] = []
var owned_land: PackedInt32Array = []  ## Land area numbers, see IsoGrid.land_area_number().
var skin: int = 0  ## Map style; selects the land item 1000 + skin.


## Returns null and reports an error when the file is missing or not a valid save.
static func load_from_file(path: String, map_index: int = 0) -> Village:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read village '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("maps") is Array):
		push_error("Village '%s' has no maps." % path)
		return null
	var maps: Array = data["maps"]
	if map_index < 0 or map_index >= maps.size() or not maps[map_index] is Dictionary:
		push_error("Village '%s' has no map %d." % [path, map_index])
		return null
	return _parse_map(maps[map_index], path)


static func _parse_map(game_map: Dictionary, path: String) -> Village:
	var village := Village.new()
	village.skin = int(game_map.get("skin", 0))
	for area: Variant in game_map.get("expansions", []):
		if (area is int or area is float) and int(area) >= 1 and int(area) <= IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS:
			village.owned_land.append(int(area))
	for entry: Variant in game_map.get("items", []):
		var placed := _parse_item(entry)
		if placed == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		village.items.append(placed)
	return village


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
