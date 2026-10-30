class_name VillageMap
extends RefCounted
## The lowest layer of Village, which describes the save rules and the layers.
##
## This layer: the save document, the items and the land, resources and
## experience, placement, buying, moving, turning and selling, and saving.

enum Placement {
	OK,
	OUTSIDE_MAP,
	NOT_OWNED_LAND,
	OCCUPIED,
	MAX_COUNT_REACHED,
	HOUSE_LIMIT_REACHED,
	TOWER_LIMIT_REACHED,
	LAND_AREA_TOWER_LIMIT_REACHED,
	LEVEL_TOO_LOW,
	NOT_ENOUGH_RESOURCES,
	UNKNOWN_RESOURCE,
	NOT_ALLOWED,  ## The player cannot move, turn or sell this item.
	POPULATION_FULL,
	UNIT_LIMIT_REACHED,
}

## Buildings for which the server's "buy" hires no workers, in addition to
## GameConfig.allies_item_ids.
const ROUND_TABLE := 389
const TROLL_ALLIES_BUILDING := 361
## The Great Church has no place for the player's own villager.
const GREAT_CHURCH := 470

## For check_limits(): the location is not known yet.
const ANY_TILE := Vector2i(-1, -1)

## Trees and stone and gold deposits. The player collects them, but cannot move or sell them.
const NEUTRAL_RESOURCE_SUBCATS: Array[int] = [125, 126, 127, 128]
const CATEGORY_TERRAIN := 6
## A sold item gives back its cost divided by this number, in the resource of
## the cost. Items that cost cash give nothing back.
const SELL_DIVISOR := 20

## Resource codes in item costs and level rewards, and where the save keeps each
## resource. "map" values are in the map, "player" values in playerInfo and
## "private" values in privateState.
const RESOURCE_KEYS := {
	"g": ["map", "coins"],
	"w": ["map", "wood"],
	"s": ["map", "stone"],
	"f": ["map", "food"],
	"c": ["player", "cash"],
	"m": ["private", "mana"],
	"p": ["private", "potion"],
}


class PlacedItem:
	var item_id: int
	var tile: Vector2i
	var frame: int  ## 0-based graphic frame; the client uses it for orientation and state.
	var _entry: Array  # The item entry in the save; move() and sell() change it.


var items: Array[PlacedItem] = []
var owned_land: PackedInt32Array = []  ## Land area numbers, see IsoGrid.land_area_number().
var skin: int = 0  ## Map style; selects the land item 1000 + skin.
var race: String  ## "h" (human) or "t" (troll).

var _document: Dictionary  # The whole save.
var _map: Dictionary  # The map in _document that this village shows.
var _config: GameConfig
var _occupied := PackedByteArray()  # Number of items that cover each tile, row by row.
func get_level() -> int:
	return int(_map["level"])


func get_xp() -> int:
	return int(_map["xp"])


## The experience that the next level needs, or -1 at the highest level.
func get_next_level_xp() -> int:
	if get_level() >= _config.levels.size():
		return -1
	return _config.levels[get_level()].exp_required


## Returns -1 for a resource code that the save does not keep.
func get_resource(code: String) -> int:
	if not RESOURCE_KEYS.has(code):
		return -1
	return int(_resource_holder(code).get(RESOURCE_KEYS[code][1], 0))


## Checks only the location: the map edges, the owned land and the other items.
## The item ignored does not block the location; use it for the item that moves.
func check_location(item: GameConfig.ItemDef, tile: Vector2i, ignored: PlacedItem = null) -> Placement:
	var covered := footprint(item, tile)
	var ignored_tiles := _covered_tiles(ignored) if ignored != null else Rect2i()
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).encloses(covered):
		return Placement.OUTSIDE_MAP
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			var area := Vector2i(x, y) / IsoGrid.LAND_TILES
			if not IsoGrid.land_area_number(area) in owned_land:
				return Placement.NOT_OWNED_LAND
			var others := _occupied[y * IsoGrid.MAP_TILES + x] - (1 if ignored_tiles.has_point(Vector2i(x, y)) else 0)
			if others != 0:
				return Placement.OCCUPIED
	return Placement.OK


## Checks the limits on the number of buildings of a type. With ANY_TILE, it does
## not check the limit of towers in the land area of the location. The item
## ignored does not count; use it for the item that moves.
func check_limits(item: GameConfig.ItemDef, tile: Vector2i = ANY_TILE, ignored: PlacedItem = null) -> Placement:
	var same_item := 0
	var same_subcat := 0
	var houses := 0
	var towers := 0
	var townhall_id := -1
	var groups := ConstructionLimits.ONE_PER_GROUP.filter(func(group: Array) -> bool: return item.id in group)
	var in_group := 0
	for placed in items:
		var placed_item := _config.get_item(placed.item_id)
		if placed_item == null or placed == ignored:
			continue
		if placed.item_id == item.id:
			same_item += 1
		if placed_item.subcat_functional == item.subcat_functional:
			same_subcat += 1
		match placed_item.subcat_functional:
			ConstructionLimits.SUBCAT_HOUSE:
				if placed.item_id != ConstructionLimits.BATHS:
					houses += 1
			ConstructionLimits.SUBCAT_TOWER:
				towers += 1
			ConstructionLimits.SUBCAT_TOWNHALL:
				townhall_id = placed.item_id
		if not groups.is_empty() and placed.item_id in groups[0]:
			in_group += 1

	if item.subcat_functional == ConstructionLimits.SUBCAT_TOWER:
		if towers >= owned_land.size() * ConstructionLimits.MAX_TOWERS_PER_LAND_AREA:
			return Placement.TOWER_LIMIT_REACHED
		if tile != ANY_TILE and _tower_tiles_in_land_area(tile, ignored) >= ConstructionLimits.MAX_TOWERS_PER_LAND_AREA:
			return Placement.LAND_AREA_TOWER_LIMIT_REACHED
	if item.subcat_functional == ConstructionLimits.SUBCAT_HOUSE and item.id != ConstructionLimits.BATHS:
		if houses >= _config.townhall_house_limit.get(townhall_id, 0):
			return Placement.HOUSE_LIMIT_REACHED
	if item.subcat_functional in ConstructionLimits.ONE_PER_SUBCAT and same_subcat >= 1:
		return Placement.MAX_COUNT_REACHED
	if ConstructionLimits.MAX_PER_ITEM.has(item.id) and same_item >= ConstructionLimits.MAX_PER_ITEM[item.id]:
		return Placement.MAX_COUNT_REACHED
	if in_group >= 1:
		return Placement.MAX_COUNT_REACHED
	return Placement.OK


## Buys an item from the store and places it, as the server command "buy" does.
## frame is the direction, from 0 to item.max_frame - 1. Changes nothing when the result is not OK.
func buy(item: GameConfig.ItemDef, tile: Vector2i, timestamp: int, frame: int = 0) -> Placement:
	if frame < 0 or frame >= item.max_frame:
		return Placement.NOT_ALLOWED
	var location := check_location(item, tile)
	if location != Placement.OK:
		return location
	var limit := check_limits(item, tile)
	if limit != Placement.OK:
		return limit
	if get_level() < item.min_level:
		return Placement.LEVEL_TOO_LOW
	var available := get_resource(item.cost_type)
	if available < 0:
		return Placement.UNKNOWN_RESOURCE
	if available < item.cost:
		return Placement.NOT_ENOUGH_RESOURCES

	_resource_holder(item.cost_type)[RESOURCE_KEYS[item.cost_type][1]] = available - item.cost
	_add_xp(item.xp)
	_register_unit(item.id)
	_add_entry(item, tile, frame, timestamp, _new_item_attributes(item))
	return Placement.OK


## The item that covers the tile, or null. When items overlap, the item added last.
func item_at(tile: Vector2i) -> PlacedItem:
	for i in range(items.size() - 1, -1, -1):
		if _config.get_item(items[i].item_id) != null and _covered_tiles(items[i]).has_point(tile):
			return items[i]
	return null


## Reads map map_index of the save at path. Returns false and reports an error
## when the file is missing or not a valid save. Village.load_from_file() calls it.
func _read(path: String, config: GameConfig, map_index: int) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read village '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("maps") is Array and data.get("playerInfo") is Dictionary and data.get("privateState") is Dictionary):
		push_error("Village '%s' is not a save: it has no maps, playerInfo or privateState." % path)
		return false
	var maps: Array = data["maps"]
	if map_index < 0 or map_index >= maps.size() or not maps[map_index] is Dictionary:
		push_error("Village '%s' has no map %d." % [path, map_index])
		return false
	var game_map: Dictionary = maps[map_index]
	if not game_map.get("items") is Array:
		push_error("Map %d of village '%s' has no item list." % [map_index, path])
		return false
	for key in ["level", "xp", "coins", "wood", "stone", "food"]:
		if not (game_map.get(key) is float or game_map.get(key) is int):
			push_error("Map %d of village '%s' has no number '%s'." % [map_index, path, key])
			return false
	if int(game_map["level"]) < 1:
		push_error("Map %d of village '%s' has level %d. The lowest level is 1." % [map_index, path, int(game_map["level"])])
		return false

	if not game_map.get("race") in ["h", "t"]:
		push_error("Map %d of village '%s' has no race \"h\" or \"t\"." % [map_index, path])
		return false

	_document = data
	_map = game_map
	_config = config
	_occupied.resize(IsoGrid.MAP_TILES * IsoGrid.MAP_TILES)
	skin = int(game_map.get("skin", 0))
	race = game_map["race"]
	for area: Variant in game_map.get("expansions", []):
		if (area is int or area is float) and int(area) >= 1 and int(area) <= IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS:
			owned_land.append(int(area))
	for entry: Variant in game_map["items"]:
		var placed := _parse_item(entry)
		if placed == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		_add(placed)
	return true


## The player can move the own buildings and decorations, also the town hall.
func can_move(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and not item.is_unit() and item.category_id != CATEGORY_TERRAIN \
			and not item.subcat_functional in NEUTRAL_RESOURCE_SUBCATS


## The player can sell the items that they can move, except the town hall.
func can_sell(placed: PlacedItem) -> bool:
	return can_move(placed) and _config.get_item(placed.item_id).subcat_functional != ConstructionLimits.SUBCAT_TOWNHALL


## The amount that selling the item gives back, in the resource of its cost.
static func sell_refund(item: GameConfig.ItemDef) -> int:
	return 0 if item.cost_type == "c" else item.cost / SELL_DIVISOR


## Checks a move of the item to the tile. The client removes the item from the
## map while it moves, so the item does not block its own location or count for the limits.
func check_move(placed: PlacedItem, tile: Vector2i) -> Placement:
	if not can_move(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var location := check_location(item, tile, placed)
	if location != Placement.OK:
		return location
	return check_limits(item, tile, placed)


## Moves the item and gives it the direction frame, as the server command "move"
## does. frame -1 keeps the direction. Changes nothing when the result is not OK.
func move(placed: PlacedItem, tile: Vector2i, frame: int = -1) -> Placement:
	var result := check_move(placed, tile)
	if result != Placement.OK:
		return result
	if frame == -1:
		frame = placed.frame
	elif frame < 0 or frame >= _config.get_item(placed.item_id).max_frame:
		return Placement.NOT_ALLOWED
	_mark_occupied(placed, -1)
	placed.tile = tile
	placed._entry[1] = tile.x
	placed._entry[2] = tile.y
	_set_frame(placed, frame)
	_mark_occupied(placed, 1)
	return Placement.OK


## The player can turn the items that they can move and that have more than one direction.
func can_rotate(placed: PlacedItem) -> bool:
	return can_move(placed) and _config.get_item(placed.item_id).max_frame > 1


## Turns the item to its next direction, as the server command "orient" does.
func rotate(placed: PlacedItem) -> Placement:
	if not can_rotate(placed):
		return Placement.NOT_ALLOWED
	_set_frame(placed, (placed.frame + 1) % _config.get_item(placed.item_id).max_frame)
	return Placement.OK


## Sells the item, as the server command "sell" does. VillageUnits first takes
## the units out of the building. Changes nothing when the result is not OK.
func sell(placed: PlacedItem, now: int) -> Placement:
	if not can_sell(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var refund := sell_refund(item)
	if refund > 0:
		_add_resource(item.cost_type, refund)
	_remove(placed)
	return Placement.OK


## A tile that a unit can stand on: in the map and with no other item on it.
func is_free(tile: Vector2i, ignored: PlacedItem = null) -> bool:
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile):
		return false
	var others := _occupied[tile.y * IsoGrid.MAP_TILES + tile.x]
	if ignored != null and _covered_tiles(ignored).has_point(tile):
		others -= 1
	return others == 0


## The free tile nearest to the area, in rings around it, or ANY_TILE.
func free_tile_around(area: Rect2i) -> Vector2i:
	for ring in range(1, IsoGrid.MAP_TILES):
		var tiles := _free_tiles_in_ring(area, ring)
		if not tiles.is_empty():
			return tiles[0]
	return ANY_TILE


## A free tile at random from the nearest ring around the tile that has one,
## or ANY_TILE when the first max_rings rings have none.
func random_free_tile_near(tile: Vector2i, max_rings: int, rng: RandomNumberGenerator) -> Vector2i:
	for ring in range(1, max_rings + 1):
		var tiles := _free_tiles_in_ring(Rect2i(tile, Vector2i.ONE), ring)
		if not tiles.is_empty():
			return tiles[rng.randi_range(0, tiles.size() - 1)]
	return ANY_TILE


## The free tiles on the ring around the area, row by row.
func _free_tiles_in_ring(area: Rect2i, ring: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var around := area.grow(ring)
	for y in range(around.position.y, around.end.y):
		for x in range(around.position.x, around.end.x):
			var on_edge := x == around.position.x or x == around.end.x - 1 or y == around.position.y or y == around.end.y - 1
			if on_edge and is_free(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles


## The free place for the item nearest to the tile, in rings around it, as the
## client finds a place for a free building, or ANY_TILE.
func _free_place_near(item: GameConfig.ItemDef, center: Vector2i) -> Vector2i:
	for ring in IsoGrid.MAP_TILES:
		var best := ANY_TILE
		var around := Rect2i(center, Vector2i.ONE).grow(ring)
		for y in range(around.position.y, around.end.y):
			for x in range(around.position.x, around.end.x):
				var on_edge := x == around.position.x or x == around.end.x - 1 or y == around.position.y or y == around.end.y - 1
				var tile := Vector2i(x, y)
				if on_edge and check_location(item, tile) == Placement.OK \
						and (best == ANY_TILE or (tile - center).length_squared() < (best - center).length_squared()):
					best = tile
		if best != ANY_TILE:
			return best
	return ANY_TILE


func _private_int(key: String) -> int:
	var value: Variant = _document["privateState"].get(key, 0)
	return int(value) if value is int or value is float else 0


func _set_private(keys: Array, values: Array) -> void:
	for i in keys.size():
		_document["privateState"][keys[i]] = values[i]


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


## Raises the level while the experience reaches the next level, one level at a
## time, as the client does when the player gets experience. The client then
## sends "rt_level_up" for each level, and the server gives the reward of that
## level and, from a configured level, mana. The client does not check the level
## when it loads a save, so a save can keep more experience than its level needs.
func _add_xp(amount: int) -> void:
	_map["xp"] = get_xp() + amount
	while get_next_level_xp() >= 0 and get_xp() >= get_next_level_xp():
		var new_level := get_level() + 1
		var reached := _config.levels[new_level - 1]
		_add_resource(reached.reward_type, reached.reward_amount)
		if new_level >= _config.start_level_mana_reward:
			_add_resource("m", _config.mana_reward_per_level)
		_map["level"] = new_level


func _add_resource(code: String, amount: int) -> void:
	if not RESOURCE_KEYS.has(code):
		# The levels in the configuration give only g, w, s, f and c. The server
		# also knows "all"; the port does not need it yet.
		push_warning("Ignored a reward of %d with the unknown resource code '%s'." % [amount, code])
		return
	var key: String = RESOURCE_KEYS[code][1]
	var holder := _resource_holder(code)
	holder[key] = int(holder.get(key, 0)) + amount


func _resource_holder(code: String) -> Dictionary:
	match RESOURCE_KEYS[code][0]:
		"map":
			return _map
		"player":
			return _document["playerInfo"]
		_:
			return _document["privateState"]


## The server's "buy" gives a building that needs workers a list of hired
## workers ("si"): the player's own villager ("0"), then neighbours from the
## other saves on the server. The port cannot see these saves, so it hires only
## the villager, as the server does when it does not know the player. The
## player can hire the other workers in the game.
func _new_item_attributes(item: GameConfig.ItemDef) -> Dictionary:
	if not _config.worker_item_ids.has(item.id):
		return {}
	if item.id == ROUND_TABLE:
		return {"si": [], "sif": {}}
	if item.id == TROLL_ALLIES_BUILDING or item.id in _config.allies_item_ids or item.id == GREAT_CHURCH:
		return {"si": []}
	return {"si": ["0"]}


## The client counts each tile that a tower covers, not each tower.
func _tower_tiles_in_land_area(tile: Vector2i, ignored: PlacedItem) -> int:
	var area := Rect2i(tile / IsoGrid.LAND_TILES * IsoGrid.LAND_TILES, Vector2i.ONE * IsoGrid.LAND_TILES)
	var count := 0
	for placed in items:
		var placed_item := _config.get_item(placed.item_id)
		if placed_item != null and placed != ignored and placed_item.subcat_functional == ConstructionLimits.SUBCAT_TOWER:
			count += footprint(placed_item, placed.tile).intersection(area).get_area()
	return count


## The server keeps a list of the units of the player's race that the player
## had. It ignores buildings, which collection rewards and stored items can be.
func _register_unit(unit_id: int) -> void:
	var item := _config.get_item(unit_id)
	if not item.is_unit() or item.race == ("h" if race == "t" else "t"):
		return
	if not _document["privateState"].get("boughtUnits") is Array:
		_document["privateState"]["boughtUnits"] = []
	var bought: Array = _document["privateState"]["boughtUnits"]
	if not bought.has(unit_id) and not bought.has(float(unit_id)):
		bought.append(unit_id)


## Adds an item entry in the server format and puts the item on the map.
func _add_entry(item: GameConfig.ItemDef, tile: Vector2i, frame: int, timestamp: int, attributes: Dictionary) -> PlacedItem:
	# Entry format of the server: [item_id, x, y, orientation, timestamp, level, units, attributes].
	var entry := [item.id, tile.x, tile.y, frame, timestamp, 0, [], attributes]
	_map["items"].append(entry)
	var placed := PlacedItem.new()
	placed.item_id = item.id
	placed.tile = tile
	placed.frame = frame
	placed._entry = entry
	_add(placed)
	return placed


func _set_frame(placed: PlacedItem, frame: int) -> void:
	placed.frame = frame
	placed._entry[3] = frame


func _remove(placed: PlacedItem) -> void:
	_mark_occupied(placed, -1)
	items.erase(placed)
	_map["items"].erase(placed._entry)


func _add(placed: PlacedItem) -> void:
	items.append(placed)
	if _config.get_item(placed.item_id) == null:
		push_warning("The village contains item %d, which is not in the configuration." % placed.item_id)
		return
	_mark_occupied(placed, 1)


## change is 1 when the item comes on the map and -1 when it goes away.
## Units also occupy their tile in the client.
func _mark_occupied(placed: PlacedItem, change: int) -> void:
	var covered := _covered_tiles(placed)
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			_occupied[y * IsoGrid.MAP_TILES + x] += change


## The tiles of the map that a placed item covers.
func _covered_tiles(placed: PlacedItem) -> Rect2i:
	return footprint(_config.get_item(placed.item_id), placed.tile).intersection(Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES))


## The tiles that an item covers. tile is the front tile; the item extends up and to the left of it.
static func footprint(item: GameConfig.ItemDef, tile: Vector2i) -> Rect2i:
	return Rect2i(tile.x - item.width + 1, tile.y - item.height + 1, item.width, item.height)


## An item entry is [item_id, x, y, frame, timestamp, level, units, attributes].
static func _parse_item(entry: Variant) -> PlacedItem:
	if not (entry is Array and entry.size() >= 8 and entry[6] is Array and entry[7] is Dictionary):
		return null
	for i in 5:
		if not (entry[i] is int or entry[i] is float):
			return null
	var placed := PlacedItem.new()
	placed.item_id = int(entry[0])
	placed.tile = Vector2i(int(entry[1]), int(entry[2]))
	placed.frame = int(entry[3])
	placed._entry = entry
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
