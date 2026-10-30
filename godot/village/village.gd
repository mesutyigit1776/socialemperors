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
	POPULATION_FULL,
	UNIT_LIMIT_REACHED,
}

enum Training {
	OK,
	NOT_TRAINER,  ## The building does not train units.
	QUEUE_FULL,
	POPULATION_FULL,
	UNIT_LIMIT_REACHED,
	NOT_ENOUGH_RESOURCES,
	NOTHING_TO_FINISH,  ## The queue is empty, or all its units are trained.
	NOT_ENOUGH_CASH,
}

enum Production {
	OK,
	NOT_PRODUCER,  ## The item does not produce a resource that the port supports.
	NO_UNITS,  ## The building works only with a unit in it.
	NOT_STARTED,  ## The building needs a work time first, see WORK_MINUTES.
	ALREADY_STARTED,
	NOT_READY,
	CANNOT_HURRY,  ## The building is not one that the player can finish with cash.
	NOT_ENOUGH_CASH,
	FARM_REMOVED,  ## The player did not have the wood for the farm, so the farm is gone.
	NO_FREE_TILE,  ## No free tile for the animal that the nursery breeds.
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

## Units of this race belong to the player on any map. Units of the map race
## also belong to the player; units of other races are enemies or neutral.
const RACE_ALL := "a"

## Units that work in mines, mills and farms, and harvest trees and deposits.
const SUBCAT_PEASANT := 71
const PEASANT_BUILDING_SUBCATS: Array[int] = [121, 122, 124]
const SUBCAT_RANCH := 123
## Trees, stone and gold. A peasant harvests them, and then they go away.
const HARVEST_SUBCATS: Array[int] = [125, 126, 127]
const SUBCAT_GOLD := 127
## The item that takes the place of a harvested stone or gold deposit, and the
## first of the 4 deposits that can grow from it.
const REGROWTH := {126: [81, 69], 127: [80, 73]}
const DEPOSIT_KINDS := 4
## Gold deposits give more gold at higher levels: [highest level, multiplier].
const GOLD_MULTIPLIERS: Array[Array] = [[10, 1], [15, 2], [20, 3], [25, 4]]
const GOLD_MULTIPLIER_MAX := 5

## Training: the queue of a building holds this number of units. A unit that
## does not cost food also costs food: its cost times FOOD_PER_COST.
const MAX_QUEUE := 5
const FOOD_PER_COST := 2
const MAX_POPULATION := 175
const CATEGORY_WONDER := 5
## A blacksmith makes footmen, cavalry and archers cheaper; a university makes siege units cheaper.
const TRAINING_DISCOUNT := 0.9
const SUBCAT_BLACKSMITH := 131
const SUBCAT_UNIVERSITY := 134
const BLACKSMITH_UNIT_SUBCATS: Array[int] = [78, 79, 80]
const UNIVERSITY_UNIT_SUBCATS: Array[int] = [81]
const SUBCAT_SIEGE := 81
## Cash for each started hour of training time that is left in a queue. The
## client and the server both have this value; the configuration does not.
const SPEED_UP_COST_PER_HOUR := 1
## The client looks this many rings around a crowded unit for a free tile, see is_crowded().
const CROWD_SEARCH_RINGS := 5

## Wild animals, by unit subcat: the unit that the client spawns, how many it
## keeps on the map, the level from which it spawns, the map race, and the
## buildings that the animal goes into. A captured horse goes into the training
## stables, the other animals go into their ranch.
const WILD_ANIMALS := {
	74: {"id": 504, "count": 7, "level": 0, "race": "h", "homes": [12, 192, 193]},
	75: {"id": 505, "count": 7, "level": 0, "race": "h", "homes": [11, 190, 191]},
	88: {"id": 571, "count": 6, "level": 11, "race": "h", "homes": [227]},
	90: {"id": 584, "count": 7, "level": 0, "race": "t", "homes": [340, 341, 342]},
}
## A unit of the player captures a wild animal at this distance in tiles or nearer.
const CAPTURE_RANGE := 4
## The server counts the animals of these kinds at each load of the save
## (version.check_animals). It does not count boars.
const COUNTED_ANIMAL_SUBCATS: Array[int] = [74, 75, 88]

## A footman or archer that goes into the training stables takes a horse and
## becomes this mounted unit.
const TRAINING_STABLES := 227
const MOUNTED_UNITS := {509: 512, 510: 513, 511: 514, 539: 541, 516: 572, 517: 515, 518: 573, 540: 574}
## The nursery breeds a new animal from two animals of the same kind.
const NURSERY := 226
const NURSERY_PAIR := 2
## The altar sacrifices a unit for 1/SELL_DIVISOR of its cost.
const SACRIFICE_ALTAR := 225
## Refuges and the fortress keep units. Units in the fortress shoot in battles,
## which the port does not have yet.
const SUBCAT_REFUGE := 1311
const FORTRESS := 469
## The unit warehouse keeps units outside the map and outside the population.
const UNIT_WAREHOUSE := 1284

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
# Wild animals that belong to the player: Village.PlacedItem -> true. The save
# does not keep this. The client gives the player the animals on the owned
# land when it loads the map, the animals that units capture, and the animals
# that come out of buildings.
var _captured: Dictionary = {}


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
		if village._is_animal(placed) and IsoGrid.land_area_number(placed.tile / IsoGrid.LAND_TILES) in village.owned_land:
			village._captured[placed] = true
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
	_add_entry(item, tile, frame, timestamp, _new_item_attributes(item))
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


## Sells the item, as the server command "sell" does. The client first takes
## the units out of the building, see _pop_all(). Changes nothing when the
## result is not OK.
func sell(placed: PlacedItem, now: int) -> Placement:
	if not can_sell(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var refund := sell_refund(item)
	if refund > 0:
		_add_resource(item.cost_type, refund)
	_pop_all(placed, now)
	_remove(placed)
	return Placement.OK


## Buildings that produce a resource for the player, and the nursery, which
## produces an animal. Trees and deposits are not included: units collect them.
## Items that produce potions or other special resources are not included yet.
func is_producer(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and not item.is_unit() and item.activation > 0 and item.collect > 0 \
			and (RESOURCE_KEYS.has(item.collect_type) or placed.item_id == NURSERY) \
			and not item.subcat_functional in NEUTRAL_RESOURCE_SUBCATS


## A mill or mine that works only after the player chooses a work time.
func needs_work_time(placed: PlacedItem) -> bool:
	return is_producer(placed) and placed.item_id in _config.variable_collect_ids


## A building with room for units produces only with a unit in it, the nursery
## only with two animals.
func needs_units(placed: PlacedItem) -> bool:
	var needed := NURSERY_PAIR if placed.item_id == NURSERY else 1
	return is_producer(placed) and _config.get_item(placed.item_id).unit_capacity > 0 and units_in(placed).size() < needed


## Seconds until the player can collect: 0 when the building is ready, -1 when it
## does not produce, has no unit or has no work time.
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
	var workers := units_in(placed).size()
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
	if needs_units(placed):
		return Production.NO_UNITS
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
	if needs_units(placed):
		return Production.NO_UNITS
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
	if needs_units(placed):
		return Production.NO_UNITS
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
		_pop_all(placed, now)
		_remove(placed)
		return Production.FARM_REMOVED
	var item := _config.get_item(placed.item_id)
	var born := bred_unit(placed)
	var tile := free_tile_around(_covered_tiles(placed)) if born != null else ANY_TILE
	if born != null and tile == ANY_TILE:
		return Production.NO_FREE_TILE
	_add_resource("w", -cost)
	if born == null:
		_add_resource(item.collect_type, collect_amount(placed))
	_add_xp(item.collect_xp)
	placed._entry[4] = now
	# The client sends "buy" for the new animal, which costs nothing, then "collect_new".
	if born != null:
		_add_player_unit(born, tile, 1, now)
	# The client then sends "activate" with 0, so that the mill or mine stops.
	placed._entry[7].erase("cp")
	# A ranch uses one animal for each collection; the client sends "pop_unit"
	# without a tile, and the animal goes away.
	if item.subcat_functional == SUBCAT_RANCH and placed.item_id != NURSERY:
		_take_unit(placed, 0)
	return Production.OK


## The units in a building, as item ids.
func units_in(placed: PlacedItem) -> Array[int]:
	var result: Array[int] = []
	for id: Variant in placed._entry[6]:
		var unit := _config.get_item(int(id)) if id is int or id is float else null
		if unit != null and unit.is_unit():
			result.append(unit.id)
	return result


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


## True when the unit stands on a building other than a farm, or on a unit that
## is before it in the item list. The client then moves the unit to a free tile
## near it, see CROWD_SEARCH_RINGS. Saves from the server or the client can have
## such units; the port does not put units on occupied tiles.
func is_crowded(unit: PlacedItem) -> bool:
	if is_free(unit.tile, unit):
		return false
	var before := true
	for placed in items:
		var item := _config.get_item(placed.item_id)
		if placed == unit:
			before = false
		elif item != null and _covered_tiles(placed).has_point(unit.tile) \
				and ((item.is_unit() and before) or (not item.is_unit() and item.subcat_functional != SUBCAT_FARM)):
			return true
	return false


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


## A unit that the player commands, as the client decides it from the race.
## Wild animals belong to the player after a capture, see _captured.
func is_own_unit(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and item.is_unit() and (item.race == race or item.race == RACE_ALL or _captured.has(placed))


## An animal that does not belong to the player yet.
func is_wild_animal(placed: PlacedItem) -> bool:
	return _is_animal(placed) and not _captured.has(placed)


## The unit of the player, at unit_tile, captures the wild animal when it is
## near, as the client checks for each wild animal. unit_tile is the tile where
## the unit is now; it can be on its way.
func can_capture(unit: PlacedItem, unit_tile: Vector2i, animal: PlacedItem) -> bool:
	return is_own_unit(unit) and unit != animal and is_wild_animal(animal) \
			and (unit_tile - animal.tile).length_squared() <= CAPTURE_RANGE * CAPTURE_RANGE


## The animal belongs to the player from now on. The save does not change.
func capture(animal: PlacedItem) -> void:
	if is_wild_animal(animal):
		_captured[animal] = true


## The building nearest to the animal that animals of its kind go into, or null.
## The client chooses it also when it is full.
func animal_home(animal: PlacedItem) -> PlacedItem:
	if not _is_animal(animal):
		return null
	var homes: Array = WILD_ANIMALS[_config.get_item(animal.item_id).subcat_functional]["homes"]
	var nearest: PlacedItem = null
	for placed in items:
		if placed.item_id in homes and (nearest == null or (placed.tile - animal.tile).length_squared() < (nearest.tile - animal.tile).length_squared()):
			nearest = placed
	return nearest


## The town hall, or null.
func town_hall() -> PlacedItem:
	for placed in items:
		var item := _config.get_item(placed.item_id)
		if item != null and item.subcat_functional == ConstructionLimits.SUBCAT_TOWNHALL:
			return placed
	return null


## Adds the wild animals that the map needs, as the client does when it loads
## the map. The server first counts the animals of the save into
## privateState.arrayAnimals. The client then spawns each kind until the map
## has its number, but only up to GameConfig.animals_per_day minus that count.
## It sends "buy" without cost for each animal and "admin_add_animal", which
## adds to the count. The animals spawn on land that the player does not own.
## Returns the new animals.
func spawn_animals(now: int, rng: RandomNumberGenerator) -> Array[PlacedItem]:
	var counts := {}
	for subcat in COUNTED_ANIMAL_SUBCATS:
		counts[str(subcat)] = 0
	for game_map: Variant in _document["maps"]:
		for entry: Variant in game_map.get("items", []) if game_map is Dictionary else []:
			if not (entry is Array and entry.size() >= 7 and entry[6] is Array):
				continue
			for id: Variant in [entry[0]] + entry[6]:
				var item := _config.get_item(int(id)) if id is int or id is float else null
				if item != null and item.subcat_functional in COUNTED_ANIMAL_SUBCATS:
					counts[str(item.subcat_functional)] += 1
	_document["privateState"]["arrayAnimals"] = counts
	var areas: Array[int] = []
	for number in range(1, IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS + 1):
		if not number in owned_land:
			areas.append(number)
	var result: Array[PlacedItem] = []
	for subcat: int in WILD_ANIMALS:
		var kind: Dictionary = WILD_ANIMALS[subcat]
		var animal := _config.get_item(kind["id"])
		if kind["race"] != race or get_level() < kind["level"] or animal == null or areas.is_empty():
			continue
		var on_map := items.filter(func(placed: PlacedItem) -> bool: return placed.item_id == animal.id).size()
		var amount := mini(maxi(kind["count"] - on_map, 0), _config.animals_per_day - int(counts.get(str(subcat), 0)))
		for i in amount:
			var number := areas[rng.randi_range(0, areas.size() - 1)]
			var area := Vector2i((number - 1) % IsoGrid.LAND_AREAS, (number - 1) / IsoGrid.LAND_AREAS)
			var tile := area * IsoGrid.LAND_TILES + Vector2i(rng.randi_range(0, IsoGrid.LAND_TILES - 1), rng.randi_range(0, IsoGrid.LAND_TILES - 1))
			if not is_free(tile):
				tile = free_tile_around(Rect2i(tile, Vector2i.ONE))
			if tile == ANY_TILE:
				break
			_add_xp(animal.xp)
			_register_unit(animal.id)
			result.append(_add_entry(animal, tile, 0, now, {}))
			counts[str(subcat)] = int(counts.get(str(subcat), 0)) + 1
	return result


## Moves a unit to a free tile and gives it the direction frame (1 to 8), as the
## server command "move" does. The view finds the path.
func move_unit(unit: PlacedItem, tile: Vector2i, frame: int) -> Placement:
	if not is_own_unit(unit):
		return Placement.NOT_ALLOWED
	if not is_free(tile, unit):
		return Placement.OCCUPIED
	_mark_occupied(unit, -1)
	unit.tile = tile
	unit._entry[1] = tile.x
	unit._entry[2] = tile.y
	_set_frame(unit, frame)
	_mark_occupied(unit, 1)
	return Placement.OK


## The units that go into a building of the player, in the order in which the
## client checks them. The building must have room, except for mounting (see
## can_mount). Any unit goes into a refuge or the unit warehouse; peasants go
## into mines, mills and farms; captured animals go into their ranch or, for
## horses, the training stables; the nursery takes two animals of one kind; the
## altar takes all units except siege units; the fortress takes units that
## shoot.
func can_enter(unit: PlacedItem, building: PlacedItem) -> bool:
	var unit_item := _config.get_item(unit.item_id)
	var building_item := _config.get_item(building.item_id)
	if not is_own_unit(unit) or building_item == null or building_item.is_unit():
		return false
	if can_mount(unit, building):
		return true
	# The units in the warehouse are not in the building entry; the warehouse has its own capacity.
	if building.item_id == UNIT_WAREHOUSE:
		return warehoused_count() < warehouse_capacity()
	var inside := units_in(building)
	if inside.size() >= building_item.unit_capacity:
		return false
	if building_item.subcat_functional == SUBCAT_REFUGE:
		return true
	if building.item_id == NURSERY:
		return _is_animal(unit) and (inside.is_empty() or inside[0] == unit.item_id)
	if building.item_id == SACRIFICE_ALTAR:
		return unit_item.subcat_functional != SUBCAT_SIEGE
	if unit_item.subcat_functional == SUBCAT_PEASANT:
		return building_item.subcat_functional in PEASANT_BUILDING_SUBCATS
	if _is_animal(unit):
		return building.item_id in WILD_ANIMALS[unit_item.subcat_functional]["homes"]
	if building.item_id == FORTRESS:
		return unit_item.attack_range > 1 and unit_item.subcat_functional != SUBCAT_SIEGE
	return false


## Puts the unit into the building, as the server command "push_unit" does, or
## into the unit warehouse, as "add_unit_warehouse" does. The client starts the
## time of a building when the first unit comes in (in the nursery, the second),
## so the port sets the time of the building then. The server does not change it.
func push_unit(unit: PlacedItem, building: PlacedItem, now: int) -> Placement:
	if not can_enter(unit, building) or can_mount(unit, building):
		return Placement.NOT_ALLOWED
	if building.item_id == UNIT_WAREHOUSE:
		var stored := _warehoused()
		stored[str(unit.item_id)] = int(stored.get(str(unit.item_id), 0)) + 1
		_remove(unit)
		return Placement.OK
	var starting_count := NURSERY_PAIR - 1 if building.item_id == NURSERY else 0
	if _config.get_item(building.item_id).activation > 0 and units_in(building).size() == starting_count:
		building._entry[4] = now
	building._entry[6].append(unit.item_id)
	_remove(unit)
	return Placement.OK


## A footman or archer of the player mounts a horse in the training stables.
func can_mount(unit: PlacedItem, building: PlacedItem) -> bool:
	return building.item_id == TRAINING_STABLES and is_own_unit(unit) and MOUNTED_UNITS.has(unit.item_id) \
			and not units_in(building).is_empty()


## The unit takes the first horse of the training stables and becomes a mounted
## unit on the tile, as the client does with the server commands "pop_unit"
## without a tile (the horse goes away), "sell" without refund (the unit) and
## "buy" without cost (the mounted unit). Returns the mounted unit, or null.
func mount(unit: PlacedItem, stables: PlacedItem, tile: Vector2i, now: int) -> PlacedItem:
	if not can_mount(unit, stables) or not is_free(tile, unit):
		return null
	var horse := _take_unit(stables, 0)
	_register_unit(horse)
	_remove(unit)
	var mounted := _config.get_item(MOUNTED_UNITS[unit.item_id])
	_add_xp(mounted.xp)
	return _add_player_unit(mounted, tile, 1, now)


## Takes the unit units_in(building)[index] out of the building to the nearest
## free tile, as the server command "pop_unit" does. Returns the unit on the map,
## or null when there is no free tile. When the last unit leaves a mill or mine,
## its work time stops, as with the server command "activate" with 0.
func pop_unit(building: PlacedItem, index: int, now: int) -> PlacedItem:
	var tile := free_tile_around(_covered_tiles(building))
	if tile == ANY_TILE or index < 0 or index >= units_in(building).size():
		return null
	var unit_id := _take_unit(building, index)
	if units_in(building).is_empty() and _work_time(building) > 0:
		building._entry[7].erase("cp")
		building._entry[4] = now
	return _add_player_unit(_config.get_item(unit_id), tile, 0, now)


## The animal that the nursery breeds when it is ready, or null for other buildings.
func bred_unit(building: PlacedItem) -> GameConfig.ItemDef:
	var inside := units_in(building)
	return _config.get_item(inside[0]) if building.item_id == NURSERY and inside.size() >= NURSERY_PAIR else null


## Sacrifices the unit in the altar when the time of the altar is over, as the
## client does with the server command "pop_sell": the unit goes away and gives
## back what selling it gives. Returns the unit, or null.
func complete_sacrifice(altar: PlacedItem, now: int) -> GameConfig.ItemDef:
	if altar.item_id != SACRIFICE_ALTAR or units_in(altar).is_empty() \
			or now - float(altar._entry[4]) < _config.get_item(altar.item_id).activation:
		return null
	var unit := _config.get_item(_take_unit(altar, 0))
	var refund := sell_refund(unit)
	if refund > 0:
		_add_resource(unit.cost_type, refund)
	return unit


## The units in the unit warehouse of the map: item id -> number.
func warehoused_units() -> Dictionary:
	var result := {}
	for key: Variant in _warehoused():
		var unit := _config.get_item(int(str(key))) if str(key).is_valid_int() else null
		var count: Variant = _warehoused()[key]
		if unit != null and unit.is_unit() and (count is int or count is float) and int(count) > 0:
			result[unit.id] = int(count)
	return result


func warehoused_count() -> int:
	var total := 0
	for count: int in warehoused_units().values():
		total += count
	return total


## The number of units that the warehouse holds. The server keeps it in "warehouseAditionalCapacitySingle".
func warehouse_capacity() -> int:
	var capacity: Variant = _map.get("warehouseAditionalCapacitySingle")
	return int(capacity) if capacity is int or capacity is float else _config.warehouse_start_capacity


## Pays GameConfig.warehouse_slot_price cash for one more place in the
## warehouse, as the server command "buy_warehouse_capacity_single" does.
func buy_warehouse_slot() -> Placement:
	if warehouse_capacity() >= _config.warehouse_max_capacity:
		return Placement.MAX_COUNT_REACHED
	if get_resource("c") < _config.warehouse_slot_price:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -_config.warehouse_slot_price)
	_map["warehouseAditionalCapacitySingle"] = warehouse_capacity() + 1
	return Placement.OK


## Takes a unit out of the unit warehouse to the free tile nearest to the
## warehouse building, as the server command "place_warehoused_item" does. The
## unit must fit in the population and the unit limit. Changes nothing when the
## result is not OK.
func place_warehoused(warehouse: PlacedItem, unit_id: int, now: int) -> Placement:
	if warehouse.item_id != UNIT_WAREHOUSE or not warehoused_units().has(unit_id):
		return Placement.NOT_ALLOWED
	var unit := _config.get_item(unit_id)
	if unit.units_limit > 0 and _unit_count(unit_id) >= unit.units_limit:
		return Placement.UNIT_LIMIT_REACHED
	if population() + unit.population > max_population():
		return Placement.POPULATION_FULL
	var tile := free_tile_around(_covered_tiles(warehouse))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	var stored := _warehoused()
	for key: Variant in stored.keys():
		if str(key) == str(unit_id):
			stored[key] = int(stored[key]) - 1
			if int(stored[key]) <= 0:
				stored.erase(key)
			break
	_add_player_unit(unit, tile, 0, now)
	return Placement.OK


## A peasant can harvest trees, stone and gold.
func can_harvest(unit: PlacedItem, resource: PlacedItem) -> bool:
	var unit_item := _config.get_item(unit.item_id)
	var resource_item := _config.get_item(resource.item_id)
	return is_own_unit(unit) and resource_item != null and unit_item.subcat_functional == SUBCAT_PEASANT \
			and resource_item.subcat_functional in HARVEST_SUBCATS


## The seconds that the peasants need to harvest the resource.
func harvest_seconds(resource: PlacedItem) -> float:
	return _config.get_item(resource.item_id).activation


## The amount that a harvest gives, as the server command "collect_new" computes
## it. Gold deposits give more at higher levels.
func harvest_amount(resource: PlacedItem, harvesters: int) -> int:
	var item := _config.get_item(resource.item_id)
	var amount: float = item.collect
	if harvesters > 1:
		amount *= 1.0 + (harvesters - 1) * WORKER_BONUS
	var multiplier := GOLD_MULTIPLIER_MAX if item.subcat_functional == SUBCAT_GOLD else 1
	if item.subcat_functional == SUBCAT_GOLD:
		for step: Array in GOLD_MULTIPLIERS:
			if get_level() <= step[0]:
				multiplier = step[1]
				break
	return int(amount * multiplier)


## Gives the resource and the experience of a harvest by the number of
## peasants, then removes the resource, as the client does with the server
## commands "collect_new" and "sell". A stone or gold deposit leaves an item that
## grows into a new deposit, see regrow(). Returns that item, or null.
func harvest(resource: PlacedItem, harvesters: int, now: int) -> PlacedItem:
	var item := _config.get_item(resource.item_id)
	if item == null or not item.subcat_functional in HARVEST_SUBCATS or harvesters < 1 or harvesters > item.unit_capacity:
		push_error("Item %d cannot be harvested by %d units." % [resource.item_id, harvesters])
		return null
	_add_resource(item.collect_type, harvest_amount(resource, harvesters))
	_add_xp(item.collect_xp)
	_remove(resource)
	if not REGROWTH.has(item.subcat_functional):
		return null
	# The client sends "buy" with direction 1 for the new item.
	return _add_entry(_config.get_item(REGROWTH[item.subcat_functional][0]), resource.tile, 1, now, {})


## Replaces each regrowth item whose time is over with a deposit of one of the
## DEPOSIT_KINDS kinds, as the client does with the server commands "sell" and
## "buy". Returns [old item, new item] for each change.
func regrow(now: int, rng: RandomNumberGenerator) -> Array:
	var changes := []
	for placed: PlacedItem in items.duplicate():
		var item := _config.get_item(placed.item_id)
		if item == null or now - float(placed._entry[4]) < item.activation:
			continue
		for subcat: int in REGROWTH:
			if REGROWTH[subcat][0] == placed.item_id:
				_remove(placed)
				var deposit := _config.get_item(REGROWTH[subcat][1] + rng.randi_range(0, DEPOSIT_KINDS - 1))
				changes.append([placed, _add_entry(deposit, placed.tile, 1, now, {})])
	return changes


## The unit that the building trains, or null.
func trained_unit(building: PlacedItem) -> GameConfig.ItemDef:
	var item := _config.get_item(building.item_id)
	var unit := _config.get_item(item.trains) if item != null and item.trains > 0 else null
	return unit if unit != null and unit.is_unit() else null


## The population of all units of the player: on the map, in buildings and in training queues.
func population() -> int:
	var total := 0
	for placed in items:
		var item := _config.get_item(placed.item_id)
		if item == null:
			continue
		if is_own_unit(placed):
			total += item.population
		for id in units_in(placed):
			total += _config.get_item(id).population
	for queue: Dictionary in _queues().values():
		var unit := _config.get_item(int(queue.get("unit", 0)))
		if unit != null:
			total += unit.population * int(queue.get("amount", 0))
	return total


## The population that the buildings allow, up to MAX_POPULATION. Wonders add
## their population also above that limit.
func max_population() -> int:
	var total := 0
	var wonders := 0
	for placed in items:
		var item := _config.get_item(placed.item_id)
		if item != null and not item.is_unit():
			total += item.population
			if item.category_id == CATEGORY_WONDER:
				wonders += item.population
	return mini(total, MAX_POPULATION) + wonders


## The costs of training the unit, as the server command "push_queue_unit" computes them.
func training_costs(unit: GameConfig.ItemDef) -> Dictionary:
	var cost := unit.cost
	var discount_subcat := SUBCAT_BLACKSMITH if unit.subcat_functional in BLACKSMITH_UNIT_SUBCATS \
			else SUBCAT_UNIVERSITY if unit.subcat_functional in UNIVERSITY_UNIT_SUBCATS else -1
	if discount_subcat >= 0:
		for placed in items:
			var item := _config.get_item(placed.item_id)
			if item != null and item.subcat_functional == discount_subcat:
				cost = ceili(cost * TRAINING_DISCOUNT)
				break
	var costs := {unit.cost_type: cost}
	if unit.cost_type != "f":
		costs["f"] = cost * FOOD_PER_COST
	return costs


## Units in the training queue of the building.
func queued_units(building: PlacedItem) -> int:
	return int(_queue(building).get("amount", 0))


## Pays for a unit and adds it to the training queue of the building, as the
## server command "push_queue_unit" does.
func train(building: PlacedItem, now: int) -> Training:
	var unit := trained_unit(building)
	if unit == null:
		return Training.NOT_TRAINER
	var queue := _queue(building)
	if queued_units(building) >= MAX_QUEUE:
		return Training.QUEUE_FULL
	if population() + unit.population > max_population():
		return Training.POPULATION_FULL
	if unit.units_limit > 0 and _unit_count(unit.id) >= unit.units_limit:
		return Training.UNIT_LIMIT_REACHED
	var costs := training_costs(unit)
	for code: String in costs:
		if get_resource(code) < costs[code]:
			return Training.NOT_ENOUGH_RESOURCES
	for code: String in costs:
		_add_resource(code, -costs[code])
	if queue.is_empty():
		var id := str(_next_queue_id())
		building._entry[7]["bq"] = id
		_queues()[id] = {"ts": now, "amount": 1, "unit": unit.id, "r": {"1": costs}}
	else:
		queue["amount"] = int(queue["amount"]) + 1
		queue["r"][str(queue["amount"])] = costs
	return Training.OK


## Seconds until the next unit of the queue is ready, or -1 when the queue is empty.
func seconds_to_trained(building: PlacedItem, now: float) -> float:
	var queue := _queue(building)
	if queue.is_empty():
		return -1
	return maxf(float(queue["ts"]) + _config.get_item(int(queue["unit"])).training_time - now, 0)


## Seconds until the last unit of the queue is ready, or 0 when the queue is empty.
func seconds_to_queue_end(building: PlacedItem, now: float) -> float:
	var first := seconds_to_trained(building, now)
	if first < 0:
		return 0
	return first + (queued_units(building) - 1) * _config.get_item(int(_queue(building)["unit"])).training_time


## The cash that finishes the whole training queue at once.
func speed_up_cost(building: PlacedItem, now: float) -> int:
	return ceili(seconds_to_queue_end(building, now) / 3600.0) * SPEED_UP_COST_PER_HOUR


## Pays cash so that all units of the queue are ready, as the command
## "speed_up_queue" does. The server sets the time of the queue to 0, and then
## complete_training() gives the units. The server charges only for the time of
## the next unit; the port charges the price that the client shows and takes
## from the player, which counts the whole queue.
func speed_up_training(building: PlacedItem, now: int) -> Training:
	if seconds_to_queue_end(building, now) == 0:
		return Training.NOTHING_TO_FINISH
	var cost := speed_up_cost(building, now)
	if get_resource("c") < cost:
		return Training.NOT_ENOUGH_CASH
	_add_resource("c", -cost)
	_queue(building)["ts"] = 0
	return Training.OK


## Puts the next trained unit on the free tile nearest to the building, as the
## server command "pop_queue_unit" does, and gives its experience. Returns the
## unit, or null when it is not ready or no tile is free. The server does not
## change the time of the queue, so after a reload all units of a queue are
## ready after the time of one. The port moves the time to the next unit.
func complete_training(building: PlacedItem, now: int) -> PlacedItem:
	if seconds_to_trained(building, now) != 0:
		return null
	var tile := free_tile_around(_covered_tiles(building))
	if tile == ANY_TILE:
		return null
	var queue := _queue(building)
	var unit := _config.get_item(int(queue["unit"]))
	queue["r"].erase(str(queue["amount"]))
	queue["amount"] = int(queue["amount"]) - 1
	queue["ts"] = float(queue["ts"]) + unit.training_time
	if int(queue["amount"]) <= 0:
		_queues().erase(building._entry[7]["bq"])
		building._entry[7].erase("bq")
	_add_xp(unit.xp)
	return _add_player_unit(unit, tile, 0, now)


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
	if not is_producer(placed) or needs_units(placed):
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


## Removes the unit units_in(building)[index] from the building. Returns its id.
func _take_unit(building: PlacedItem, index: int) -> int:
	var unit_id := units_in(building)[index]
	var seen := -1
	for i in building._entry[6].size():
		var id: Variant = building._entry[6][i]
		var item := _config.get_item(int(id)) if id is int or id is float else null
		if item != null and item.is_unit():
			seen += 1
			if seen == index:
				building._entry[6].remove_at(i)
				break
	return unit_id


## The units of this kind on the map and in training queues, for the unit limit.
func _unit_count(unit_id: int) -> int:
	var count := items.filter(func(placed: PlacedItem) -> bool: return placed.item_id == unit_id).size()
	for queue: Dictionary in _queues().values():
		if int(queue.get("unit", 0)) == unit_id:
			count += int(queue.get("amount", 0))
	return count


## Takes all units out of the building, as the client does before it removes a
## building. A unit for which no tile is free goes away with the building.
func _pop_all(building: PlacedItem, now: int) -> void:
	while not units_in(building).is_empty() and pop_unit(building, 0, now) != null:
		pass


func _is_animal(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and item.is_unit() and WILD_ANIMALS.has(item.subcat_functional)


## The unit warehouse of the map, as the server keeps it: item id (text) -> number.
func _warehoused() -> Dictionary:
	if not _map.get("warehousedUnits") is Dictionary:
		_map["warehousedUnits"] = {}
	return _map["warehousedUnits"]


## Adds a unit that comes to the player: trained, out of a building, bred or
## mounted. The server registers it, and the client gives it to the player,
## also when it is an animal.
func _add_player_unit(unit: GameConfig.ItemDef, tile: Vector2i, frame: int, now: int) -> PlacedItem:
	_register_unit(unit.id)
	var placed := _add_entry(unit, tile, frame, now, {})
	if _is_animal(placed):
		_captured[placed] = true
	return placed


## The server keeps a list of the units of the player's race that the player had.
func _register_unit(unit_id: int) -> void:
	if _config.get_item(unit_id).race == ("h" if race == "t" else "t"):
		return
	if not _document["privateState"].get("boughtUnits") is Array:
		_document["privateState"]["boughtUnits"] = []
	var bought: Array = _document["privateState"]["boughtUnits"]
	if not bought.has(unit_id) and not bought.has(float(unit_id)):
		bought.append(unit_id)


## The training queues of the save, by queue id.
func _queues() -> Dictionary:
	if not _document["privateState"].get("barracksQueues") is Dictionary:
		_document["privateState"]["barracksQueues"] = {}
	return _document["privateState"]["barracksQueues"]


## The training queue of the building, or an empty dictionary.
func _queue(building: PlacedItem) -> Dictionary:
	var id: Variant = building._entry[7].get("bq")
	var queue: Variant = _queues().get(str(id)) if id != null else null
	return queue if queue is Dictionary and queue.get("r") is Dictionary else {}


## The client numbers the queues from the highest number in use.
func _next_queue_id() -> int:
	var highest := 0
	for id: Variant in _queues():
		highest = maxi(highest, int(str(id)) if str(id).is_valid_int() else 0)
	for placed in items:
		var bq: Variant = placed._entry[7].get("bq")
		if bq != null and str(bq).is_valid_int():
			highest = maxi(highest, int(str(bq)))
	return highest + 1


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
	_captured.erase(placed)
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
