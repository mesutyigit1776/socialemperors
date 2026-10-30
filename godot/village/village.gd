class_name Village
extends VillageUnits
## One map of a village save, in the format that the server stores in saves/<USERID>.save.json.
##
## The village keeps the whole save document. It changes only the values that
## an operation changes, so that the server and the original client can still
## load the save. The server command handlers in op.py are the reference for
## these changes.
##
## GDScript has no partial classes, so the village is in three layers, and each
## layer uses only the layers below it: VillageMap (the save, the map and the
## placement rules), VillageUnits (production, units and training) and Village
## (special buildings and collections). Other code uses Village.
##
## This layer: the special buildings (nests, Rider Academy, Dragon Riding,
## graveyards, Soul Mixer), the free buildings of the client, the collections,
## the item store, and the save changes of the campaign quests.

## Collections give decorations even when the player has one; see _reward_allowed().
const SUBCAT_DECORATION := 411
## The nests grow their units, one after the other, in NEST_STEPS steps of care.
## After each step the player waits NEST_STEP_SECONDS or pays cash: "wait_cash"
## is [cash for the 1st, 3rd, ... unit, cash for the 2nd, 4th, ... unit]. "keys"
## are the values of the nest in privateState: active, unit number, step and
## the time of the last step. The client contains these values, not the configuration.
const DRAGON_NEST := 1233
const MONSTERS_NEST := 1255
const NESTS := {
	DRAGON_NEST: {"units": [638, 649, 651, 684, 698, 695], "wait_cash": [3, 15], "keys": ["dragonNestActive", "dragonNumber", "stepNumber", "timeStampTakeCare"]},
	MONSTERS_NEST: {"units": [717, 713, 742, 653], "wait_cash": [7, 7], "keys": ["monsterNestActive", "monsterNumber", "stepMonsterNumber", "timeStampTakeCareMonster"]},
}
const NEST_STEPS := 10
const NEST_STEP_SECONDS := 21600
## The Rider Academy trains the rider of type n as RIDER_UNITS[n - 1], in steps
## (GameConfig.dragon_riders). After each step the player waits
## RIDER_STEP_SECONDS. The save keeps the rider type, step and time of the last
## step in RIDER_KEYS of privateState.
const RIDER_ACADEMY := 1345
const RIDER_STEP_SECONDS := 54000
const RIDER_KEYS: Array[String] = ["riderNumber", "riderStepNumber", "riderTimeStamp"]
## The graveyard brings units back for potions; the Heroes Grave brings heroes
## back for their cost_unit_cash times RESURRECT_GOLD_PER_CASH gold.
const GRAVEYARD := 486
const HEROES_GRAVE := 239
const RESURRECT_GOLD_PER_CASH := 500
## After a battle the server puts the units that died in the graveyard, except
## villagers, animals and troll units, and the heroes in the Heroes Grave. The
## limits are the defaults of "graveyard_max_slots" and
## "graveyard_max_each_unit" in the server_config.json of the server.
const NOT_BURIED_UNITS: Array[int] = [500, 501]
const NOT_BURIED_SUBCATS: Array[int] = [74, 75, 88, 90]
const HEROES: Array[int] = [535, 533, 534, 550, 554, 555, 556, 557]
const GRAVEYARD_MAX_UNITS := 10000
const GRAVEYARD_MAX_EACH := 100
## Units of these kinds stay in the village during a quest: villagers,
## settlers, cows, sheep, carts, horses and boars.
const QUEST_HOME_SUBCATS: Array[int] = [71, 73, 74, 75, 76, 88, 90]
## The Soul Mixer makes a new unit from the power ("breeding order") of two
## units, which come back out after it. The result has the power
## SOUL_MIX_STRONG_SHARE of the stronger unit plus the rest of the weaker one,
## at least SOUL_MIX_MIN_POWER, plus a random part below SOUL_MIX_RANDOM_POWER.
## A result above SOUL_MIX_TOP_POWER is a random unit of the top powers.
const SOUL_MIX_STRONG_SHARE := 0.7
const SOUL_MIX_MIN_POWER := 10
const SOUL_MIX_RANDOM_POWER := 12
const SOUL_MIX_TOP_POWER := 400
## Below this level, the Soul Mixer does not mix these dragons of other games.
const SOUL_MIX_PROMOTION_LEVEL := 20
const SOUL_MIX_PROMOTION_UNITS: Array[int] = [2048, 2037, 777, 758]
## The client gives a free dragon nest, and a free Soul Mixer from
## GameConfig.soul_mixer_min_level, at the free place nearest to these tiles.
const FREE_BUILDING_TILES := {DRAGON_NEST: Vector2i(30, 59), SOUL_MIXER: Vector2i(59, 59)}

# The result that the Soul Mixer will make, see soul_mix_result(): Village.PlacedItem ->
# {"inside": unit ids, "unit": result id, "level": power-ups, "excluded": unit ids}.
var _soul_mixes: Dictionary = {}


## Returns null and reports an error when the file is missing or not a valid save.
static func load_from_file(path: String, config: GameConfig, map_index: int = 0) -> Village:
	var village := Village.new()
	return village if village._read(path, config, map_index) else null


## The number of items of the collection that the player has; index is 1 to
## Collections.ITEMS_PER_COLLECTION.
func collected(collection: int, index: int) -> int:
	return int(_collection(collection)[index])


## The player finds an item of a collection, as the client does after a
## harvest and after a collection from the Treasure Mine, with the server
## command "add_collectable". Trolls find nothing. Returns Vector2i(collection,
## item index), or Vector2i.ZERO.
func find_collectible(from_treasure_mine: bool, rng: RandomNumberGenerator) -> Vector2i:
	if race != "h":
		return Vector2i.ZERO
	var source := rng.randi_range(0, Collections.Source.size() - 1) if from_treasure_mine else Collections.Source.HARVEST
	var roll := rng.randf() * (Collections.TREASURE_ROLL if from_treasure_mine else Collections.HARVEST_ROLL)
	var found := Collections.loot(source, roll, rng)
	if found != Vector2i.ZERO:
		var counts := _collection(found.x)
		counts[found.y] = int(counts[found.y]) + 1
	return found


## True when the player has each item of the collection, and the client allows
## its reward: a unit or building reward only when the player does not have one
## yet, on the map or in the item store.
func can_complete_collection(collection: int) -> bool:
	for index in range(1, Collections.ITEMS_PER_COLLECTION + 1):
		if collected(collection, index) <= 0:
			return false
	return _reward_allowed(collection)


## The cash that completes the collection without all its items, or 0 when the
## player cannot buy it.
func collection_cash_price(collection: int) -> int:
	if collection in Collections.NO_CASH_COLLECTIONS or not _reward_allowed(collection):
		return 0
	var price := Collections.CASH_PRICES[collection]
	if collection in Collections.FIXED_PRICE_COLLECTIONS:
		return price
	for index in range(1, Collections.ITEMS_PER_COLLECTION + 1):
		if collected(collection, index) > 0:
			price -= 1
	return maxi(price, 1)


## Completes the collection, as the server command "finish_collection" does: it
## uses one of each item, or with_cash it pays collection_cash_price() and
## keeps the items. The reward goes into the item store of the map, see
## place_stored(). Changes nothing when the result is not OK.
func complete_collection(collection: int, with_cash: bool) -> Placement:
	if collection < 1 or collection > Collections.count():
		return Placement.NOT_ALLOWED
	var counts := _collection(collection)
	if with_cash:
		var price := collection_cash_price(collection)
		if price == 0:
			return Placement.NOT_ALLOWED
		if get_resource("c") < price:
			return Placement.NOT_ENOUGH_RESOURCES
		_add_resource("c", -price)
	else:
		if not can_complete_collection(collection):
			return Placement.NOT_ALLOWED
		for index in range(1, Collections.ITEMS_PER_COLLECTION + 1):
			counts[index] = int(counts[index]) - 1
	counts[0] = 1
	if not _document["privateState"].get("collectionsCompleted") is Array:
		_document["privateState"]["collectionsCompleted"] = []
	var completed: Array = _document["privateState"]["collectionsCompleted"]
	if not completed.has(collection) and not completed.has(float(collection)):
		completed.append(collection)
	var reward := _config.collection_rewards[collection]
	_stored()[str(reward)] = int(_stored().get(str(reward), 0)) + 1
	_register_unit(reward)
	return Placement.OK


## The items in the item store of the map: item id -> number.
func stored_items() -> Dictionary:
	var result := {}
	for key: Variant in _stored():
		var item := _config.get_item(int(str(key))) if str(key).is_valid_int() else null
		var count: Variant = _stored()[key]
		if item != null and (count is int or count is float) and int(count) > 0:
			result[item.id] = int(count)
	return result


## Places an item from the item store, as the server command
## "place_stored_item" does. It checks the same location and limits as buy(),
## but costs nothing and gives no experience. Changes nothing when the result
## is not OK.
func place_stored(item: GameConfig.ItemDef, tile: Vector2i, now: int, frame: int = 0) -> Placement:
	if not stored_items().has(item.id) or frame < 0 or frame >= item.max_frame:
		return Placement.NOT_ALLOWED
	var location := check_location(item, tile)
	if location != Placement.OK:
		return location
	var limit := check_limits(item, tile)
	if limit != Placement.OK:
		return limit
	var stored := _stored()
	for key: Variant in stored.keys():
		if str(key) == str(item.id):
			stored[key] = int(stored[key]) - 1
			if int(stored[key]) <= 0:
				stored.erase(key)
			break
	_register_unit(item.id)
	if item.is_unit():
		_add_player_unit(item, tile, frame, now)
	else:
		_add_entry(item, tile, frame, now, _new_item_attributes(item))
	return Placement.OK


## Places a free dragon nest, and from GameConfig.soul_mixer_min_level a free
## Soul Mixer, when the map and the item store have none, as the client does
## when it loads the map and at a new level. It sends "buy" without cost, which
## gives the experience of the item. Returns the new buildings.
func add_free_buildings(now: int) -> Array[PlacedItem]:
	var added: Array[PlacedItem] = []
	for id: int in FREE_BUILDING_TILES:
		if id == SOUL_MIXER and get_level() < _config.soul_mixer_min_level:
			continue
		if items.any(func(placed: PlacedItem) -> bool: return placed.item_id == id) or stored_items().has(id) or _gifted(id):
			continue
		var item := _config.get_item(id)
		var tile := _free_place_near(item, FREE_BUILDING_TILES[id])
		if tile == ANY_TILE:
			continue
		_add_xp(item.xp)
		added.append(_add_entry(item, tile, 0, now, _new_item_attributes(item)))
	return added


## True when the nest grows units now; the player starts it with activate_nest().
func is_nest_active(nest: PlacedItem) -> bool:
	return NESTS.has(nest.item_id) and _private_int(NESTS[nest.item_id]["keys"][0]) == 1


## The unit that grows in the nest now.
func nest_unit(nest: PlacedItem) -> GameConfig.ItemDef:
	var units: Array = NESTS[nest.item_id]["units"]
	return _config.get_item(units[clampi(_private_int(NESTS[nest.item_id]["keys"][1]), 0, units.size() - 1)])


## The steps of care that are over, from 0 to NEST_STEPS. A step counts when its wait is over.
func nest_steps_done(nest: PlacedItem, now: float) -> int:
	return _private_int(NESTS[nest.item_id]["keys"][2]) - (1 if nest_wait_seconds(nest, now) > 0 else 0)


## Seconds until the player can care for the nest again, or 0.
func nest_wait_seconds(nest: PlacedItem, now: float) -> float:
	var last_step := _private_int(NESTS[nest.item_id]["keys"][3])
	return maxf(NEST_STEP_SECONDS - (now - last_step), 0) if last_step != 0 else 0.0


## The cash that ends the wait of the nest at once.
func nest_wait_cash(nest: PlacedItem) -> int:
	return NESTS[nest.item_id]["wait_cash"][_private_int(NESTS[nest.item_id]["keys"][1]) % 2]


## Starts the nest for gold ("g") or cash ("c"), as the server commands
## "activate_dragon" and "activate_monster" do.
func activate_nest(nest: PlacedItem, code: String) -> Placement:
	var costs: Dictionary = _config.dragon_nest_costs if nest.item_id == DRAGON_NEST else _config.monster_nest_costs
	if not NESTS.has(nest.item_id) or is_nest_active(nest) or not costs.has(code):
		return Placement.NOT_ALLOWED
	if get_resource(code) < costs[code]:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource(code, -costs[code])
	_set_private(NESTS[nest.item_id]["keys"], [1, 0, 0, 0])
	return Placement.OK


## Cares for the unit in the nest: one more step, then a wait. The server
## commands are "next_step" and "next_monster_step".
func care_for_nest(nest: PlacedItem, now: int) -> Placement:
	if not is_nest_active(nest) or nest_wait_seconds(nest, now) > 0 or nest_steps_done(nest, now) >= NEST_STEPS:
		return Placement.NOT_ALLOWED
	var keys: Array = NESTS[nest.item_id]["keys"]
	_set_private([keys[2], keys[3]], [_private_int(keys[2]) + 1, now])
	return Placement.OK


## Pays nest_wait_cash() to end the wait, as the server commands
## "buy_step_cash" and "buy_monster_step_cash" do.
func end_nest_wait(nest: PlacedItem, now: int) -> Placement:
	if not is_nest_active(nest) or nest_wait_seconds(nest, now) == 0:
		return Placement.NOT_ALLOWED
	if get_resource("c") < nest_wait_cash(nest):
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -nest_wait_cash(nest))
	_set_private([NESTS[nest.item_id]["keys"][3]], [0])
	return Placement.OK


## Takes the grown unit out of the nest to the free tile nearest to it, with
## "buy" without cost, and starts the next unit with "next_dragon" or
## "next_monster". After the last unit, the nest stops, as the client does with
## "desactivate_dragon" or "desactivate_monster".
func take_nest_unit(nest: PlacedItem, now: int) -> Placement:
	if not is_nest_active(nest) or nest_steps_done(nest, now) < NEST_STEPS:
		return Placement.NOT_ALLOWED
	var tile := free_tile_around(_covered_tiles(nest))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	var unit := nest_unit(nest)
	_add_xp(unit.xp)
	_add_player_unit(unit, tile, 0, now)
	var keys: Array = NESTS[nest.item_id]["keys"]
	var next := _private_int(keys[1]) + 1
	_set_private(keys, [1, next, 0, 0] if next < NESTS[nest.item_id]["units"].size() else [0, 0, 0, 0])
	return Placement.OK


## The rider type that the Rider Academy trains, from 1, or 0.
func rider_type() -> int:
	return clampi(_private_int(RIDER_KEYS[0]), 0, RIDER_UNITS.size())


func rider_steps_done(now: float) -> int:
	return _private_int(RIDER_KEYS[1]) - (1 if rider_wait_seconds(now) > 0 else 0)


func rider_wait_seconds(now: float) -> float:
	var last_step := _private_int(RIDER_KEYS[2])
	return maxf(RIDER_STEP_SECONDS - (now - last_step), 0) if last_step != 0 else 0.0


## Chooses the rider that the Rider Academy trains, as the server command "rider_select" does.
func select_rider(new_type: int) -> Placement:
	if rider_type() != 0 or new_type < 1 or new_type > RIDER_UNITS.size():
		return Placement.NOT_ALLOWED
	if get_level() < _config.dragon_riders[new_type - 1]["level"]:
		return Placement.LEVEL_TOO_LOW
	_set_private(RIDER_KEYS, [new_type, 0, 0])
	return Placement.OK


## One training step of the rider, as the server command "rider_next_step"
## does. In the client the player must win a mini-game first; the port does
## not have the mini-game.
func train_rider(now: int) -> Placement:
	if rider_type() == 0 or rider_wait_seconds(now) > 0 or _private_int(RIDER_KEYS[1]) >= _config.dragon_riders[rider_type() - 1]["steps"]:
		return Placement.NOT_ALLOWED
	_set_private([RIDER_KEYS[1], RIDER_KEYS[2]], [_private_int(RIDER_KEYS[1]) + 1, now])
	return Placement.OK


## Pays the cash of the rider type to end the wait, as "rider_buy_step_cash" does.
func end_rider_wait(now: int) -> Placement:
	if rider_type() == 0 or rider_wait_seconds(now) == 0:
		return Placement.NOT_ALLOWED
	var cash: int = _config.dragon_riders[rider_type() - 1]["cash"]
	if get_resource("c") < cash:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -cash)
	_set_private([RIDER_KEYS[2]], [0])
	return Placement.OK


## Puts the trained rider next to the academy with "buy" without cost, then
## clears the academy with "rider_select" 0.
func take_rider(academy: PlacedItem, now: int) -> Placement:
	if academy.item_id != RIDER_ACADEMY or rider_type() == 0 or rider_steps_done(now) < _config.dragon_riders[rider_type() - 1]["steps"]:
		return Placement.NOT_ALLOWED
	var tile := free_tile_around(_covered_tiles(academy))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	var rider := _config.get_item(RIDER_UNITS[rider_type() - 1])
	_add_xp(rider.xp)
	_add_player_unit(rider, tile, 0, now)
	_set_private(RIDER_KEYS, [0, 0, 0])
	return Placement.OK


## The rider and the dragon in Dragon Riding become the tamed dragon next to the
## building, as the client does with "pop_unit" without a tile for both and
## "buy" without cost. The dragon must be of the rider's type. In the client the
## player must win a mini-game first; the port does not have the mini-game.
func tame(building: PlacedItem, now: int) -> Placement:
	var inside := units_in(building)
	if building.item_id != DRAGON_RIDING or inside.size() != 2:
		return Placement.NOT_ALLOWED
	var dragon := inside[0] if _config.dragons.has(inside[0]) else inside[1]
	var rider := inside[1] if dragon == inside[0] else inside[0]
	if not _config.dragons.has(dragon) or RIDER_UNITS.find(rider) + 1 != _config.dragons[dragon][0]:
		return Placement.NOT_ALLOWED
	var tile := free_tile_around(_covered_tiles(building))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	_take_unit(building, 1)
	_take_unit(building, 0)
	var tamed := _config.get_item(_config.dragons[dragon][1])
	_add_xp(tamed.xp)
	_add_player_unit(tamed, tile, 0, now)
	return Placement.OK


## The units in the graveyard, which the server adds after battles: item id -> number.
func graveyard_units() -> Dictionary:
	var result := {}
	var listed: Variant = _document["privateState"].get("resurrectableUnits")
	for id: Variant in listed if listed is Array else []:
		if (id is int or id is float) and _config.get_item(int(id)) != null:
			result[int(id)] = int(result.get(int(id), 0)) + 1
	return result


## The dead heroes of the Heroes Grave: item id -> number.
func dead_heroes() -> Dictionary:
	var result := {}
	var dead: Variant = _document["privateState"].get("deadHeroes")
	for key: Variant in dead if dead is Dictionary else {}:
		var hero := _config.get_item(int(str(key))) if str(key).is_valid_int() else null
		if hero != null and (dead[key] is int or dead[key] is float) and int(dead[key]) > 0:
			result[hero.id] = int(dead[key])
	return result


## Brings a unit back from the graveyard for its potions, next to the
## graveyard, as the server command "resurrect_hero" does. The unit must fit
## in the population and the unit limit.
func resurrect(graveyard: PlacedItem, unit_id: int, now: int) -> Placement:
	if graveyard.item_id != GRAVEYARD or not graveyard_units().has(unit_id):
		return Placement.NOT_ALLOWED
	var unit := _config.get_item(unit_id)
	if population() + unit.population > max_population():
		return Placement.POPULATION_FULL
	if unit.units_limit > 0 and _unit_count(unit_id) >= unit.units_limit:
		return Placement.UNIT_LIMIT_REACHED
	if get_resource("p") < unit.potion:
		return Placement.NOT_ENOUGH_RESOURCES
	var tile := free_tile_around(_covered_tiles(graveyard))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	_add_resource("p", -unit.potion)
	var listed: Array = _document["privateState"]["resurrectableUnits"]
	for i in listed.size():
		if int(listed[i]) == unit_id:
			listed.remove_at(i)
			break
	_add_player_unit(unit, tile, 0, now)
	return Placement.OK


## Buys GameConfig.graveyard_potions potions, as "graveyard_buy_potions" does.
func buy_potions() -> Placement:
	if get_resource("c") < _config.graveyard_potions_price:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -_config.graveyard_potions_price)
	_add_resource("p", _config.graveyard_potions)
	return Placement.OK


## Brings a dead hero back for gold, next to the Heroes Grave, as the server
## command "resurrect_hero" does for the grave.
func resurrect_hero(grave: PlacedItem, hero_id: int, now: int) -> Placement:
	if grave.item_id != HEROES_GRAVE or not dead_heroes().has(hero_id):
		return Placement.NOT_ALLOWED
	var hero := _config.get_item(hero_id)
	var gold := hero.cost_unit_cash * RESURRECT_GOLD_PER_CASH
	if get_resource("g") < gold:
		return Placement.NOT_ENOUGH_RESOURCES
	var tile := free_tile_around(_covered_tiles(grave))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	_add_resource("g", -gold)
	var dead: Dictionary = _document["privateState"]["deadHeroes"]
	for key: Variant in dead.keys():
		if str(key) == str(hero_id):
			dead[key] = int(dead[key]) - 1
			if int(dead[key]) <= 0:
				dead.erase(key)
			break
	_add_player_unit(hero, tile, 0, now)
	return Placement.OK


## The unit that the Soul Mixer makes from its two units, or null when it does
## not have two units or already mixes. The client chooses it at random when
## the second unit goes in and keeps it until it mixes; it does not save it.
func soul_mix_result(mixer: PlacedItem, rng: RandomNumberGenerator) -> GameConfig.ItemDef:
	var inside := units_in(mixer)
	if mixer.item_id != SOUL_MIXER or inside.size() != 2 or not _queue(mixer).is_empty():
		_soul_mixes.erase(mixer)
		return null
	var mix: Dictionary = _soul_mixes.get(mixer, {})
	if mix.get("inside") != inside:
		var powers := [_config.get_item(inside[0]).breeding_order, _config.get_item(inside[1]).breeding_order]
		var power := maxi(ceili(powers.min() * (1.0 - SOUL_MIX_STRONG_SHARE) + powers.max() * SOUL_MIX_STRONG_SHARE), SOUL_MIX_MIN_POWER)
		power += rng.randi_range(0, SOUL_MIX_RANDOM_POWER - 1)
		if power == powers.max():
			power += 1
		mix = {"inside": inside, "excluded": inside.duplicate(), "level": 0}
		mix["unit"] = _soul_unit_by_power(power, mix["excluded"], rng)
		_soul_mixes[mixer] = mix
	return _config.get_item(mix["unit"])


## The cash of the next power-up of the Soul Mixer.
func soul_power_up_cash(mixer: PlacedItem) -> int:
	var level: int = _soul_mixes.get(mixer, {}).get("level", 0)
	return _config.soul_mixer_powerups[mini(level, _config.soul_mixer_powerups.size() - 1)][0]


## The cash of the power-ups that the player chose; mix_souls() pays it.
func soul_power_ups_cash(mixer: PlacedItem) -> int:
	var total := 0
	for level in _soul_mixes.get(mixer, {}).get("level", 0):
		total += _config.soul_mixer_powerups[mini(level, _config.soul_mixer_powerups.size() - 1)][0]
	return total


## Makes the result of the Soul Mixer stronger: a unit some places higher in
## the order of power. The client sends the "buy_powerups" commands, and the
## server takes the cash, only when the player mixes.
func power_up_soul_mix(mixer: PlacedItem, rng: RandomNumberGenerator) -> Placement:
	var result := soul_mix_result(mixer, rng)
	if result == null:
		return Placement.NOT_ALLOWED
	if _soul_promotion_blocked(mixer):
		return Placement.LEVEL_TOO_LOW
	if get_resource("c") < soul_power_ups_cash(mixer) + soul_power_up_cash(mixer):
		return Placement.NOT_ENOUGH_RESOURCES
	var mix: Dictionary = _soul_mixes[mixer]
	var increment: int = _config.soul_mixer_powerups[mini(mix["level"], _config.soul_mixer_powerups.size() - 1)][1]
	mix["level"] += 1
	mix["excluded"].append(result.id)
	var order := _soul_order()
	var index: int
	if result.breeding_order >= SOUL_MIX_TOP_POWER:
		index = order.find(_soul_unit_by_power(_top_soul_power(rng), mix["excluded"], rng))
	else:
		index = mini(order.find(_soul_unit_by_power(result.breeding_order, mix["excluded"], rng)) + increment, order.size() - 1)
		while order[index] in mix["excluded"] and index < order.size() - 1:
			index += 1
	mix["unit"] = order[index]
	mix["excluded"].append(order[index])
	return Placement.OK


## Pays the power-ups and starts to make the result, as the client does with
## "buy_powerups" and "push_queue_unit" without cost. The Soul Mixer needs the
## sm_training_time of the unit; speed_up_training() can end it with cash.
func mix_souls(mixer: PlacedItem, now: int, rng: RandomNumberGenerator) -> Placement:
	var result := soul_mix_result(mixer, rng)
	if result == null:
		return Placement.NOT_ALLOWED
	if _soul_promotion_blocked(mixer):
		return Placement.LEVEL_TOO_LOW
	if result.units_limit > 0 and _unit_count(result.id) >= result.units_limit:
		return Placement.UNIT_LIMIT_REACHED
	var cash := soul_power_ups_cash(mixer)
	if get_resource("c") < cash:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -cash)
	var id := str(_next_queue_id())
	mixer._entry[7]["bq"] = id
	_queues()[id] = {"ts": now, "amount": 1, "unit": result.id, "r": {"1": null}}
	_soul_mixes.erase(mixer)
	return Placement.OK


## The unit that the Soul Mixer makes now, or 0 when it does not mix.
func soul_mix_unit_id(mixer: PlacedItem) -> int:
	return int(_queue(mixer).get("unit", 0)) if mixer.item_id == SOUL_MIXER else 0


## Puts the mixed unit next to the Soul Mixer, without experience, and takes
## the two units out, as the client does with "pop_queue_unit" and "pop_unit".
## The unit must fit in the population.
func take_soul_mix(mixer: PlacedItem, now: int) -> Placement:
	if mixer.item_id != SOUL_MIXER or seconds_to_trained(mixer, now) != 0:
		return Placement.NOT_ALLOWED
	var unit := _config.get_item(int(_queue(mixer)["unit"]))
	if population() + unit.population > max_population():
		return Placement.POPULATION_FULL
	var tile := free_tile_around(_covered_tiles(mixer))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	_drop_last_queued(mixer)
	_add_player_unit(unit, tile, 0, now)
	_pop_all(mixer, now)
	return Placement.OK


## The stars that the player won on the island of the quest: 0 to 3.
func quest_rank(quest_id: String) -> int:
	var ranks: Variant = _document["privateState"].get("questsRank")
	var rank: Variant = ranks.get(quest_id) if ranks is Dictionary else null
	return int(rank) if rank is int or rank is float else 0


## The place in GameConfig.quest_order of the last island that the player can
## start, as the server keeps it.
func unlocked_quest_index() -> int:
	return _private_int("unlockedQuestIndex")


## The times at which the player started quests on this map, as the server
## keeps them. The server removes the times that are older than its setting
## "quests_reset_hours" when it loads the save.
func quest_start_times() -> Array[int]:
	var times: Array[int] = []
	var listed: Variant = _map.get("lastQuestTimes")
	for time: Variant in listed if listed is Array else []:
		if time is int or time is float:
			times.append(int(time))
	return times


## The units that go on a quest: unit id -> number. The client takes all units
## of the player on the map, except villagers, animals, settlers and carts.
func quest_army() -> Dictionary:
	var army := {}
	for placed in items:
		var item := _config.get_item(placed.item_id)
		if is_own_unit(placed) and not item.subcat_functional in QUEST_HOME_SUBCATS:
			army[item.id] = int(army.get(item.id, 0)) + 1
	return army


## Records the start of a quest, as the client commands "start_quest" and
## "start_quest_new" do on the server.
func start_quest(quest_id: String, now: int) -> void:
	if not _map.get("questTimes") is Dictionary:
		_map["questTimes"] = {}
	_map["questTimes"][quest_id] = now
	if not _map.get("lastQuestTimes") is Array:
		_map["lastQuestTimes"] = []
	_map["lastQuestTimes"].append(now)


## The honour that the result of a quest gives: more for the first win with
## these stars, and GameConfig.quest_honour_lost without a win.
func quest_honour(quest_id: String, difficulty: int, won: bool) -> int:
	if not won:
		return _config.quest_honour_lost
	return (_config.quest_honour_first if difficulty > quest_rank(quest_id) else _config.quest_honour)[difficulty - 1]


## Applies the result of a quest, as the server command "end_quest" does.
## result has the fields that the client sends, see QuestBattle.result():
## quest_id, difficulty, win, resources {"g", "x"} and units, a list of
## [unit id, number that went, number that died, number that came back].
##
## - A win opens the next island in GameConfig.quest_order, keeps the highest
##   stars of the island, and gives honour: more for the first win with these
##   stars. A loss gives GameConfig.quest_honour_lost.
## - The gold and the experience go to the map. The server only adds the
##   experience; the port also raises the level, as the client does when it
##   gets experience.
## - The units that died and did not come back leave the map. The graveyard
##   takes them, see _bury().
func end_quest(result: Dictionary) -> void:
	var quest_id := str(result["quest_id"])
	var difficulty := int(result["difficulty"])
	var player: Dictionary = _document["playerInfo"]
	var won := int(result["win"]) == 1
	var honour := quest_honour(quest_id, difficulty, won)
	if won:
		var next_index := _config.quest_order.find(quest_id) + 1
		var old_index := unlocked_quest_index() if _document["privateState"].get("unlockedQuestIndex") != null else -1
		if next_index > 0 and next_index - old_index <= 1:
			_set_private(["unlockedQuestIndex"], [maxi(next_index, old_index)])
		var rank := quest_rank(quest_id)
		if not _document["privateState"].get("questsRank") is Dictionary:
			_document["privateState"]["questsRank"] = {}
		_document["privateState"]["questsRank"][quest_id] = maxi(difficulty, rank)
	player["honor_points"] = int(player.get("honor_points", 0)) + honour
	_add_resource("g", int(result["resources"]["g"]))
	_add_xp(int(result["resources"]["x"]))
	for entry: Array in result["units"]:
		var lost := int(entry[2]) - int(entry[3])
		for placed in items.filter(func(placed: PlacedItem) -> bool: return placed.item_id == int(entry[0])).slice(0, maxi(lost, 0)):
			_remove(placed)
			_bury(placed.item_id)


## Puts a unit that died in the graveyard, as the server does after a battle:
## heroes go to the Heroes Grave; villagers, animals and troll units go nowhere.
## The graveyard holds at most GRAVEYARD_MAX_UNITS units, GRAVEYARD_MAX_EACH of a kind.
func _bury(unit_id: int) -> void:
	var unit := _config.get_item(unit_id)
	if unit_id in NOT_BURIED_UNITS or unit.subcat_functional in NOT_BURIED_SUBCATS or unit.race == "t":
		return
	var private: Dictionary = _document["privateState"]
	if unit_id in HEROES:
		if not private.get("deadHeroes") is Dictionary:
			private["deadHeroes"] = {}
		private["deadHeroes"][str(unit_id)] = int(private["deadHeroes"].get(str(unit_id), 0)) + 1
		return
	if not private.get("resurrectableUnits") is Array:
		private["resurrectableUnits"] = []
	var buried: Array = private["resurrectableUnits"]
	if buried.size() >= maxi(GRAVEYARD_MAX_UNITS, _private_int("graveyardCapacity")) or graveyard_units().get(unit_id, 0) >= GRAVEYARD_MAX_EACH:
		return
	buried.append(unit_id)


## The client does not mix some dragons of other games below SOUL_MIX_PROMOTION_LEVEL.
func _soul_promotion_blocked(mixer: PlacedItem) -> bool:
	return get_level() < SOUL_MIX_PROMOTION_LEVEL and units_in(mixer).any(func(id: int) -> bool: return id in SOUL_MIX_PROMOTION_UNITS)


## The units that the Soul Mixer can make, in the order of their power.
func _soul_order() -> Array[int]:
	var units := _config.items().filter(func(item: GameConfig.ItemDef) -> bool: return item.breeding_order > 0)
	units.sort_custom(func(a: GameConfig.ItemDef, b: GameConfig.ItemDef) -> bool: return a.breeding_order < b.breeding_order)
	var order: Array[int] = []
	order.assign(units.map(func(item: GameConfig.ItemDef) -> int: return item.id))
	return order


func _top_soul_power(rng: RandomNumberGenerator) -> int:
	var highest := 0
	for item in _config.items():
		highest = maxi(highest, item.breeding_order)
	return rng.randi_range(SOUL_MIX_TOP_POWER, maxi(highest - 1, SOUL_MIX_TOP_POWER))


## The first unit in the order of power with at least the power, which is not
## excluded, or the strongest unit. Above SOUL_MIX_TOP_POWER, a random top power.
func _soul_unit_by_power(power: int, excluded: Array, rng: RandomNumberGenerator) -> int:
	if power > SOUL_MIX_TOP_POWER:
		power = _top_soul_power(rng)
	var order := _soul_order()
	for id in order:
		if not id in excluded and _config.get_item(id).breeding_order >= power:
			return id
	return order.back()


## The counts of a collection in the save: [completed, item 1, ..., item 5].
## The server keeps one list for each collection, by collection number.
func _collection(collection: int) -> Array:
	if not _document["privateState"].get("collections") is Array:
		_document["privateState"]["collections"] = [[]]
	var lists: Array = _document["privateState"]["collections"]
	while lists.size() <= collection:
		lists.append([0, 0, 0, 0, 0, 0])
	if not lists[collection] is Array or lists[collection].size() < Collections.ITEMS_PER_COLLECTION + 1:
		lists[collection] = [0, 0, 0, 0, 0, 0]
	return lists[collection]


## The client gives a unit or building reward only when the player has none
## yet, and the rewards of Collections.UNIQUE_COLLECTIONS only while the item
## store has none. Decorations it always gives.
func _reward_allowed(collection: int) -> bool:
	var reward := _config.get_item(_config.collection_rewards[collection])
	if reward == null:
		return false
	var owned := stored_items().has(reward.id) or _gifted(reward.id)
	if collection in Collections.UNIQUE_COLLECTIONS:
		return not owned
	if reward.subcat_functional == SUBCAT_DECORATION:
		return true
	return not owned and not items.any(func(placed: PlacedItem) -> bool: return placed.item_id == reward.id)


func _gifted(item_id: int) -> bool:
	var gifts: Variant = _document["privateState"].get("gifts")
	return gifts is Dictionary and gifts.keys().any(func(key: Variant) -> bool: return str(key) == str(item_id))


## The item store of the map, as the server keeps it: item id (text) -> number.
func _stored() -> Dictionary:
	if not _map.get("store") is Dictionary:
		_map["store"] = {}
	return _map["store"]
