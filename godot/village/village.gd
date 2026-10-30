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
	MAX_COUNT_REACHED,
	HOUSE_LIMIT_REACHED,
	TOWER_LIMIT_REACHED,
	LAND_AREA_TOWER_LIMIT_REACHED,
	LEVEL_TOO_LOW,
	NOT_ENOUGH_RESOURCES,
	UNKNOWN_RESOURCE,
	NOT_ALLOWED,  ## The player cannot move, turn or sell this item.
}

enum Production {
	OK,
	NOT_PRODUCER,  ## The item does not produce a resource that the port supports.
	NOT_STARTED,  ## The building needs a work time first, see WORK_MINUTES.
	ALREADY_STARTED,
	NOT_READY,
	CANNOT_HURRY,  ## The building is not one that the player can finish with cash.
	NOT_ENOUGH_CASH,
	FARM_REMOVED,  ## The player did not have the wood for the farm, so the farm is gone.
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

## Work times in minutes that the player chooses for the buildings in
## GameConfig.variable_collect_ids, and the multiplier of the amount for each.
## The save keeps the choice in the attribute "cp": 1 for the first work time,
## 0 or no attribute when the building does not work.
const WORK_MINUTES: Array[int] = [5, 60, 240, 480]
const WORK_MULTIPLIERS: Array[float] = [0.5, 1.0, 2.0, 3.0]
## A farm costs wood at each collection: its amount divided by this number.
const SUBCAT_FARM := 122
const FARM_WOOD_DIVISOR := 3.0
## Each unit in a building after the first one adds this part of the amount.
const WORKER_BONUS := 0.2
## The player can pay this cash to collect at once from mills, mines, other
## collect buildings and wonders without population.
const HURRY_COST := 2
const HURRY_SUBCATS: Array[int] = [121, 124, 138]
const SUBCAT_WONDER := 511

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


## Returns null and reports an error when the file is missing or not a valid save.
static func load_from_file(path: String, config: GameConfig, map_index: int = 0) -> Village:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read village '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("maps") is Array and data.get("playerInfo") is Dictionary and data.get("privateState") is Dictionary):
		push_error("Village '%s' is not a save: it has no maps, playerInfo or privateState." % path)
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
	if int(game_map["level"]) < 1:
		push_error("Map %d of village '%s' has level %d. The lowest level is 1." % [map_index, path, int(game_map["level"])])
		return null

	if not game_map.get("race") in ["h", "t"]:
		push_error("Map %d of village '%s' has no race \"h\" or \"t\"." % [map_index, path])
		return null

	var village := Village.new()
	village._document = data
	village._map = game_map
	village._config = config
	village._occupied.resize(IsoGrid.MAP_TILES * IsoGrid.MAP_TILES)
	village.skin = int(game_map.get("skin", 0))
	village.race = game_map["race"]
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
	# Entry format of the server: [item_id, x, y, orientation, timestamp, level, store, attributes].
	var entry := [item.id, tile.x, tile.y, frame, timestamp, 0, [], _new_item_attributes(item)]
	_map["items"].append(entry)
	var placed := PlacedItem.new()
	placed.item_id = item.id
	placed.tile = tile
	placed.frame = frame
	placed._entry = entry
	_add(placed)
	return Placement.OK


## The item that covers the tile, or null. When items overlap, the item added last.
func item_at(tile: Vector2i) -> PlacedItem:
	for i in range(items.size() - 1, -1, -1):
		if _config.get_item(items[i].item_id) != null and _covered_tiles(items[i]).has_point(tile):
			return items[i]
	return null


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


## Sells the item, as the server command "sell" does. Changes nothing when the result is not OK.
func sell(placed: PlacedItem) -> Placement:
	if not can_sell(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var refund := sell_refund(item)
	if refund > 0:
		_add_resource(item.cost_type, refund)
	_remove(placed)
	return Placement.OK


## Buildings that produce a resource for the player. Trees and deposits are not
## included: units collect them. Items that produce potions, units or other
## special resources are not included yet.
func is_producer(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and not item.is_unit() and item.activation > 0 and item.collect > 0 \
			and RESOURCE_KEYS.has(item.collect_type) and not item.subcat_functional in NEUTRAL_RESOURCE_SUBCATS


## A mill or mine that works only after the player chooses a work time.
func needs_work_time(placed: PlacedItem) -> bool:
	return is_producer(placed) and placed.item_id in _config.variable_collect_ids


## Seconds until the player can collect: 0 when the building is ready, -1 when it
## does not produce or has no work time.
func seconds_to_ready(placed: PlacedItem, now: float) -> float:
	var duration := _production_seconds(placed)
	if duration < 0:
		return -1
	return maxf(duration - (now - float(placed._entry[4])), 0)


## The amount that collect() gives, as the server command "collect_new" computes it.
## The server is the reference because it writes the save.
func collect_amount(placed: PlacedItem) -> int:
	var item := _config.get_item(placed.item_id)
	var amount: float = item.collect
	if item.subcat_functional != SUBCAT_FARM and _work_time(placed) > 0:
		amount *= WORK_MULTIPLIERS[_work_time(placed) - 1]
	var workers := 0
	for id: Variant in placed._entry[6]:
		var unit := _config.get_item(int(id)) if id is int or id is float else null
		if unit != null and unit.is_unit():
			workers += 1
	if workers > 1:
		amount *= 1.0 + (workers - 1) * WORKER_BONUS
	return int(amount)


## The wood that a collection costs: farms only.
func collect_cost(placed: PlacedItem) -> int:
	var item := _config.get_item(placed.item_id)
	return roundi(item.collect / FARM_WOOD_DIVISOR) if item.subcat_functional == SUBCAT_FARM else 0


## Starts a mill or mine with the work time WORK_MINUTES[work_time], as the server
## command "activate" does.
func start_work(placed: PlacedItem, work_time: int, now: int) -> Production:
	if not needs_work_time(placed) or work_time < 0 or work_time >= WORK_MINUTES.size():
		return Production.NOT_PRODUCER
	if _work_time(placed) > 0:
		return Production.ALREADY_STARTED
	placed._entry[7]["cp"] = work_time + 1
	placed._entry[4] = now
	return Production.OK


## Collects the resource of a ready building, as the client and the server
## command "collect_new" do. A farm needs wood for each collection. When the
## player does not have it, the client removes the farm and the server command
## "kill" removes it from the save.
func collect(placed: PlacedItem, now: int) -> Production:
	if not is_producer(placed):
		return Production.NOT_PRODUCER
	var remaining := seconds_to_ready(placed, now)
	if remaining < 0:
		return Production.NOT_STARTED
	if remaining > 0:
		return Production.NOT_READY
	return _collect_now(placed, now)


## A working building that the player can finish with cash: it is not ready yet.
func can_hurry(placed: PlacedItem, now: float) -> bool:
	if not is_producer(placed) or seconds_to_ready(placed, now) <= 0:
		return false
	var item := _config.get_item(placed.item_id)
	return item.subcat_functional in HURRY_SUBCATS or (item.subcat_functional == SUBCAT_WONDER and item.population == 0)


## Pays HURRY_COST cash and collects at once, as the client does with the server
## command "collect_new" and its cash argument. A ready building needs no cash.
func hurry(placed: PlacedItem, now: int) -> Production:
	if not is_producer(placed):
		return Production.NOT_PRODUCER
	var remaining := seconds_to_ready(placed, now)
	if remaining < 0:
		return Production.NOT_STARTED
	if remaining == 0:
		return _collect_now(placed, now)
	if not can_hurry(placed, now):
		return Production.CANNOT_HURRY
	if get_resource("c") < HURRY_COST:
		return Production.NOT_ENOUGH_CASH
	_add_resource("c", -HURRY_COST)
	return _collect_now(placed, now)


func _collect_now(placed: PlacedItem, now: int) -> Production:
	var cost := collect_cost(placed)
	if cost > get_resource("w"):
		_remove(placed)
		return Production.FARM_REMOVED
	var item := _config.get_item(placed.item_id)
	_add_resource("w", -cost)
	_add_resource(item.collect_type, collect_amount(placed))
	_add_xp(item.collect_xp)
	placed._entry[4] = now
	# The client then sends "activate" with 0, so that the mill or mine stops.
	placed._entry[7].erase("cp")
	return Production.OK


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
		# also knows "p" (potions) and "all"; the port does not need them yet.
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


## The production time of the building in seconds, or -1 when it does not produce.
func _production_seconds(placed: PlacedItem) -> float:
	if not is_producer(placed):
		return -1
	if needs_work_time(placed):
		return WORK_MINUTES[_work_time(placed) - 1] * 60.0 if _work_time(placed) > 0 else -1.0
	return _config.get_item(placed.item_id).activation


## The work time that the player chose for a mill or mine, from 1, or 0 when it does not work.
func _work_time(placed: PlacedItem) -> int:
	var choice: Variant = placed._entry[7].get("cp", 0)
	if (choice is int or choice is float) and int(choice) >= 1 and int(choice) <= WORK_MINUTES.size():
		return int(choice)
	return 0


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
