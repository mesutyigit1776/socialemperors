class_name VillageUnits
extends VillageMap
## The production of buildings, the units, the wild animals, the buildings that
## take units, the unit warehouse, harvests and training. The middle layer of
## Village; see Village.

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
## Peasants walk at a speed (pixels per frame) that comes from the level of the
## town hall (0 when there is none), not from their velocity. A fitness centre
## or a troll coliseum adds FITNESS_SPEED.
const PEASANT_SPEEDS: Array[int] = [3, 5, 5, 6, 6, 7]
const TOWN_HALL_LEVELS := {26: 1, 289: 1, 139: 2, 321: 2, 140: 3, 322: 3, 141: 4, 412: 5}
const FITNESS_BUILDINGS: Array[int] = [221, 325]
const FITNESS_SPEED := 2
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

## A collection from the Treasure Mine gives an item of a collection, see
## find_collectible(), instead of a resource.
const TREASURE_MINE := 218
## The dragon riders, by rider type from 1. A rider goes into Dragon Riding
## with a dragon of its type; the Rider Academy trains them.
const RIDER_UNITS: Array[int] = [822, 823, 824]
## A rider and a dragon of the rider's type go into Dragon Riding and become a
## tamed dragon, see GameConfig.dragons.
const DRAGON_RIDING := 1346
## The Soul Mixer takes two units with a soul power ("breeding order") and
## makes a new unit in its queue; see Village.mix_souls().
const SOUL_MIXER := 1529
# Wild animals that belong to the player: Village.PlacedItem -> true. The save
# does not keep this. The client gives the player the animals on the owned
# land when it loads the map, the animals that units capture, and the animals
# that come out of buildings.
var _captured: Dictionary = {}
## Wild animals on the owned land belong to the player when the client loads the map.
func _read(path: String, config: GameConfig, map_index: int) -> bool:
	if not super(path, config, map_index):
		return false
	for placed in items:
		if _is_animal(placed) and IsoGrid.land_area_number(placed.tile / IsoGrid.LAND_TILES) in owned_land:
			_captured[placed] = true
	return true


## The client first takes the units out of the building that the player sells, see _pop_all().
func sell(placed: PlacedItem, now: int) -> Placement:
	if can_sell(placed):
		_pop_all(placed, now)
	return super(placed, now)


func _remove(placed: PlacedItem) -> void:
	_captured.erase(placed)
	super(placed)


## Buildings that produce a resource for the player, the nursery, which
## produces an animal, and the Treasure Mine. Trees and deposits are not
## included: units collect them.
func is_producer(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and not item.is_unit() and item.activation > 0 and item.collect > 0 \
			and (RESOURCE_KEYS.has(item.collect_type) or placed.item_id in [NURSERY, TREASURE_MINE]) \
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
	# The server gives nothing for the Treasure Mine; the client then calls find_collectible().
	if born == null and placed.item_id != TREASURE_MINE:
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


## A unit that the player commands, as the client decides it from the race.
## Wild animals belong to the player after a capture, see _captured.
func is_own_unit(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and item.is_unit() and (item.race == race or item.race == RACE_ALL or _captured.has(placed))


## The pixels per frame that a unit walks, see IsoGrid.step_toward().
func walking_speed(placed: PlacedItem) -> int:
	var item := _config.get_item(placed.item_id)
	if item.subcat_functional != SUBCAT_PEASANT:
		return item.velocity
	var hall := town_hall()
	var speed: int = PEASANT_SPEEDS[TOWN_HALL_LEVELS.get(hall.item_id, 0) if hall != null else 0]
	for other in items:
		if other.item_id in FITNESS_BUILDINGS:
			return speed + FITNESS_SPEED
	return speed


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
	if building.item_id == DRAGON_RIDING:
		# A rider and a dragon; the client checks their types when they tame, see tame().
		var kind := func(id: int) -> int: return 1 if _config.dragons.has(id) else 2 if id in RIDER_UNITS else 0
		return kind.call(unit.item_id) != 0 and (inside.is_empty() or kind.call(unit.item_id) != kind.call(inside[0]))
	if building.item_id == SOUL_MIXER:
		return unit_item.breeding_order > 0 and _queue(building).is_empty()
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
	# The unit that the Soul Mixer makes counts only when it comes out.
	for placed in items:
		var queue := _queue(placed)
		var unit := _config.get_item(int(queue.get("unit", 0)))
		if unit != null and placed.item_id != SOUL_MIXER:
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


## Takes the last unit out of the training queue of the building and gives
## back what the player paid for it, as the server command "unqueue_unit" does.
## The client also takes the last unit. The server refunds the costs that the
## queue keeps for the unit, or the current costs when the queue has none.
func unqueue_unit(building: PlacedItem) -> Training:
	if trained_unit(building) == null:
		return Training.NOT_TRAINER
	var queue := _queue(building)
	if queue.is_empty() or int(queue["amount"]) <= 0:
		return Training.NOTHING_TO_FINISH
	var unit := _config.get_item(int(queue["unit"]))
	var paid: Variant = queue["r"].get(str(queue["amount"]))
	var costs: Dictionary = paid if paid is Dictionary else training_costs(unit)
	for code: String in costs:
		_add_resource(code, int(costs[code]))
	_drop_last_queued(building)
	return Training.OK


## Seconds until the next unit of the queue is ready, or -1 when the queue is empty.
func seconds_to_trained(building: PlacedItem, now: float) -> float:
	var queue := _queue(building)
	if queue.is_empty():
		return -1
	return maxf(float(queue["ts"]) + _unit_seconds(building) - now, 0)


## Seconds until the last unit of the queue is ready, or 0 when the queue is empty.
func seconds_to_queue_end(building: PlacedItem, now: float) -> float:
	var first := seconds_to_trained(building, now)
	if first < 0:
		return 0
	return first + (queued_units(building) - 1) * _unit_seconds(building)


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
	if seconds_to_trained(building, now) != 0 or building.item_id == SOUL_MIXER:
		return null
	var tile := free_tile_around(_covered_tiles(building))
	if tile == ANY_TILE:
		return null
	var queue := _queue(building)
	var unit := _config.get_item(int(queue["unit"]))
	queue["ts"] = float(queue["ts"]) + _unit_seconds(building)
	_drop_last_queued(building)
	_add_xp(unit.xp)
	return _add_player_unit(unit, tile, 0, now)


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


## Seconds to make one unit of the queue of the building.
func _unit_seconds(building: PlacedItem) -> int:
	var unit := _config.get_item(int(_queue(building)["unit"]))
	return unit.sm_training_time if building.item_id == SOUL_MIXER else unit.training_time


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


## Removes the last unit of the training queue of the building, and the queue
## when it is empty. The queue keeps the costs of each unit by its place.
func _drop_last_queued(building: PlacedItem) -> void:
	var queue := _queue(building)
	queue["r"].erase(str(queue["amount"]))
	queue["amount"] = int(queue["amount"]) - 1
	if int(queue["amount"]) <= 0:
		_queues().erase(building._entry[7]["bq"])
		building._entry[7].erase("bq")


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
