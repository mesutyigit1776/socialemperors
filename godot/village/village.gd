class_name Village
extends VillageSocial
## One map of a village save, in the format that the server stores in saves/<USERID>.save.json.
##
## The village keeps the whole save document. It changes only the values that
## an operation changes, so that the server and the original client can still
## load the save. The server command handlers in op.py are the reference for
## these changes.
##
## GDScript has no partial classes, so the village is in four layers, and each
## layer uses only the layers below it: VillageMap (the save, the map and the
## placement rules), VillageUnits (production, units and training),
## VillageSocial (neighbours and attacks on other players) and Village
## (special buildings and collections). Other code uses Village.
##
## This layer: the special buildings (nests, Rider Academy, Dragon Riding,
## graveyards, Soul Mixer, Time Machine, Weather Machine, Supreme Dragon
## Temple), the free buildings of the client, the collections,
## the item store and unit packs, the save changes of the campaign quests and
## the spells, the goals in the save and the tutorial step.

## Collections give decorations even when the player has one; see _reward_allowed().
const SUBCAT_DECORATION := 411
## The wait after the end of a quest in the town (TIMER_OGRES_VILLAGE).
const TOWN_QUEST_WAIT := 4 * 3600
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
const KILL_GOLD := 5  ## The server gives this gold for each enemy unit that the player kills in the village.
const SURVIVAL_LIVES := 3
const SURVIVAL_MAPS_OPEN := 3
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
const WIZARDRY_TILE := Vector2i(59, 59)
const TUTORIAL_NEST_TILE := Vector2i(50, 60)
## The Time Machine sells packets of time (GameConfig.time_packets). A used
## packet moves the times of the save back, as the server command "time_ff"
## does; the save keeps the packets in privateState "countTimePacket".
const TIME_MACHINE := 1463
## The Weather Machine changes the style of the map (the save's "skin"), in the
## order of its window. Style 0 is free; the others need an unlock for
## GameConfig.unlock_skin_cash cash, which privateState "unlockedSkins" keeps.
const WEATHER_MACHINE := 373
const SKINS: Array[int] = [0, 1, 2, 4, 5, 6]
const SKIN_TEXTS: Array[String] = ["POPUP_METEO_PRADERA", "POPUP_METEO_DESIERTO", "POPUP_METEO_ESTEPA", "POPUP_METEO_MONTANYA", "POPUP_METEO_JUNGLA", "POPUP_METEO_NUBES"]
## The Supreme Dragon Temple gives the Supreme Bahamut Dragon after
## TEMPLE_STEPS steps, in any order. After each step the player waits
## TEMPLE_STEP_SECONDS or pays TEMPLE_WAIT_CASH cash. Steps 0 to 5 offer
## TEMPLE_OFFERINGS, steps 6 to 10 sacrifice a unit of TEMPLE_SACRIFICES from
## the map, and the last step offers the reward of the collection
## TEMPLE_HEART_COLLECTION, which stays in the item store until the dragon
## comes. privateState keeps the done steps in "templeStep" and the time of
## the last step in "timeStampTemple". The client contains these values.
const BAHAMUT_TEMPLE := 1394
const SUPREME_BAHAMUT := 2003
const TEMPLE_OFFERINGS: Array[Array] = [["g", 100000], ["s", 100000], ["w", 100000], ["f", 100000], ["m", 50], ["c", 50]]
const TEMPLE_SACRIFICES: Array[int] = [649, 684, 695, 853, 875]
const TEMPLE_HEART_COLLECTION := 23
const TEMPLE_STEPS := 12
const TEMPLE_STEP_SECONDS := 172800
const TEMPLE_WAIT_CASH := 5

const GOAL_KEYS := {"completed": "completedMissions", "rewarded": "rewardedMissions"}
## The town hall cannot go into the item store.
const SUBCAT_TOWN_HALL := 135
## The store of the client shows one unit pack on each of PACK_SLOTS places.
## Buying 2 or more packs, and 8 or more, gives the discounts of PACK_DISCOUNTS.
const PACK_SLOTS := 8
const PACK_DISCOUNTS: Array[Array] = [[8, 0.85], [2, 0.9]]

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
		add_collectible(found)
	return found


## Adds one item of a collection: Vector2i(collection, item index), as the
## server command "add_collectable" does.
func add_collectible(found: Vector2i) -> void:
	var counts := _collection(found.x)
	counts[found.y] = int(counts[found.y]) + 1


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
		happened.emit(VillageEvent.Kind.BUILT, {"item": item.id})
	return Placement.OK


## Places a free dragon nest, and from GameConfig.soul_mixer_min_level a free
## Soul Mixer, when the map and the item store have none, as the client does
## when it loads the map and at a new level. It sends "buy" without cost, which
## gives the experience of the item. Also places the Wizardry Academy when the
## player reached SPELL_BOOK_LEVEL in the village since the last call; the
## client gives it then even when the map has one. Returns the new buildings.
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
		happened.emit(VillageEvent.Kind.BUILT, {"item": item.id})
	# After the other buildings, whose experience can bring the level.
	if _wizardry_due:
		_wizardry_due = false
		var wizardry := _config.get_item(WIZARDRY)
		var place := _free_place_near(wizardry, WIZARDRY_TILE)
		if place != ANY_TILE:
			_add_xp(wizardry.xp)
			added.append(_add_entry(wizardry, place, 0, now, _new_item_attributes(wizardry)))
			happened.emit(VillageEvent.Kind.BUILT, {"item": WIZARDRY})
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
	if nest.item_id == DRAGON_NEST:
		happened.emit(VillageEvent.Kind.NEST_FED, {})
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
	happened.emit(VillageEvent.Kind.SOULS_MIXED, {})
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
## - The items of "item_rewards" (item id -> number), which some islands give
##   for a win, go to the store. The client puts them in the store itself; the
##   server of this project does not read the field.
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
		happened.emit(VillageEvent.Kind.QUEST_WON, {"quest": quest_id, "stars": difficulty})
	player["honor_points"] = int(player.get("honor_points", 0)) + honour
	_add_resource("g", int(result["resources"]["g"]))
	# The client adds this experience during the quest, outside its normal mode.
	_add_xp(int(result["resources"]["x"]), false)
	var rewards: Variant = result.get("item_rewards", {})
	for key: Variant in rewards if rewards is Dictionary else {}:
		for i in int(rewards[key]):
			_add_stored(int(key))
	_lose_dead_units(result["units"])


## Applies the end of an attack of the player on another player: the units
## that died and did not come back leave the map for the graveyard, as the
## server command "end_attack" does, and the rest as _count_pvp_result()
## describes. result["units"] has the form of the units of end_quest().
func end_pvp_attack(result: Dictionary) -> void:
	_lose_dead_units(result["units"])
	_count_pvp_result(result)


## units: [unit id, number that went, number that died, number that came
## back] for each kind of unit. The units that did not come back leave the
## map; the graveyard takes them.
func _lose_dead_units(units: Array) -> void:
	for entry: Array in units:
		var lost := int(entry[2]) - int(entry[3])
		for placed in items.filter(func(placed: PlacedItem) -> bool: return placed.item_id == int(entry[0])).slice(0, maxi(lost, 0)):
			_remove(placed)
			_bury(placed.item_id)


## The spells that the player bought: spell id -> number of casts. The server
## keeps them in privateState "magics" with the id as text.
func spell_uses() -> Dictionary:
	var uses := {}
	var learned: Variant = _document["privateState"].get("magics")
	for key: Variant in learned if learned is Dictionary else {}:
		var id: Variant = GameConfig.to_int(key)
		var count: Variant = learned[key]
		if id != null and (count is int or count is float):
			uses[id] = int(count)
	return uses


## Buys GameConfig.mana_per_purchase mana for gold or cash, as "buy_mana_new" does.
func buy_mana(with_cash: bool) -> Placement:
	var code := "c" if with_cash else "g"
	var price := _config.mana_price_cash if with_cash else _config.mana_price_gold
	if get_resource(code) < price:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource(code, -price)
	_add_resource("m", _config.mana_per_purchase)
	return Placement.OK


## Buys a spell for gold or cash, as "buy_magic" does. The spell also gives
## its mana of one cast. The server does not check the level; the client
## offers a spell only from its level, so the port checks it here.
func buy_spell(spell: GameConfig.SpellDef, with_cash: bool) -> Placement:
	if spell_uses().has(spell.id):
		return Placement.NOT_ALLOWED
	if get_level() < spell.level:
		return Placement.LEVEL_TOO_LOW
	var code := "c" if with_cash else "g"
	var price := spell.cash if with_cash else spell.gold
	if get_resource(code) < price:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource(code, -price)
	if not _document["privateState"].get("magics") is Dictionary:
		_document["privateState"]["magics"] = {}
	_document["privateState"]["magics"][str(spell.id)] = 0
	_add_resource("m", spell.mana)
	return Placement.OK


## Pays the mana of a cast and counts the cast, as "use_magic" does. Returns
## the level of the spell for this cast: the client counts the cast first, so
## the cast that reaches GameConfig.spell_uses_level2 already has level 2.
## Returns 0 when the player does not have the spell or the mana.
func use_spell(spell: GameConfig.SpellDef) -> int:
	var uses := spell_uses()
	if not uses.has(spell.id) or get_resource("m") < spell.mana:
		return 0
	_add_resource("m", -spell.mana)
	var count: int = uses[spell.id] + 1
	_document["privateState"]["magics"][str(spell.id)] = count
	return _config.spell_level(count)


## A unit on the map that fights the player: not a unit of the player and not a wild animal.
func is_enemy_unit(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and item.is_unit() and not is_own_unit(placed) and not is_wild_animal(placed)


## Puts an enemy unit on the map, as the client does when it spawns the idle
## enemies around the village: the command "buy" without cost, for which the
## server also gives the experience of the item and lists the unit as bought
## when it is not of the other race of the player.
func add_enemy(item: GameConfig.ItemDef, tile: Vector2i, now: int) -> PlacedItem:
	_add_xp(item.xp)
	_register_unit(item.id)
	return _add_entry(item, tile, 0, now, {})


## Puts an item of a quest in the town on the map with the server command
## "place_stored_item", which adds it without cost and without experience,
## also when the item store does not have it. The client sent "buy" without
## cost, which gives the experience of each item: more than 800 for the walls
## of some camps, three levels for a new player.
func place_quest_item(item: GameConfig.ItemDef, tile: Vector2i, now: int) -> PlacedItem:
	_register_unit(item.id)
	return _add_entry(item, tile, 0, now, {})


## Takes an item off the map with the command "sell" without resources, as the
## client does when it cleans an area for a quest or removes a quest item.
func remove_free_item(placed: PlacedItem) -> void:
	_remove(placed)


## An enemy item died in a battle in the village: the client sends "kill". The
## server removes the item from the map when the save has it (placed), and for
## a unit it gives the collect_xp of the unit and KILL_GOLD gold, also when the
## save does not have the unit.
func kill_enemy(item: GameConfig.ItemDef, placed: PlacedItem = null) -> void:
	if item.is_unit():
		_add_xp(item.collect_xp)
		_add_resource("g", KILL_GOLD)
		happened.emit(VillageEvent.Kind.KILLED, {"unit": item.id})
	if placed != null:
		_remove(placed)


## A unit of the player died in a battle in the village. The client sends
## "sell" with the reason KILL: the unit leaves the map and the server puts it
## in the graveyard, see _bury().
func lose_unit(placed: PlacedItem) -> void:
	_remove(placed)
	_bury(placed.item_id)


## The name of the player.
func player_name() -> String:
	return str(_document["playerInfo"].get("name", ""))


## The team that the player chose last for "quest" or "tournament": the unit
## ids of the 20 places, 0 for an empty place. The save keeps it in
## privateState "teams".
func attack_team(team_name: String) -> Array[int]:
	var places: Array[int] = []
	var teams: Variant = _document["privateState"].get("teams")
	var saved: Variant = teams.get(team_name) if teams is Dictionary else null
	for id: Variant in saved if saved is Array else []:
		places.append(int(id) if id is int or id is float else 0)
	return places


## The formation of the tournament team that the player chose last (0 to 3).
func tournament_formation() -> int:
	return _private_int("tournamentFormation")


## Keeps the team and the formation, as the server command "set_attack_team" does.
func set_attack_team(team_name: String, places: Array[int], formation: int) -> void:
	var private: Dictionary = _document["privateState"]
	if not private.get("teams") is Dictionary:
		private["teams"] = {}
	private["teams"][team_name] = places.duplicate()
	# The server keeps the formation only when it is not 0.
	if formation != 0:
		private["tournamentFormation"] = formation


## The lives for survival maps: SURVIVAL_LIVES, which come back
## GameConfig.survival_life_hours after their use, and the lives that the
## player bought. The save keeps the times of use in privateState
## "survivalVidaTimeStamp" and the bought lives in "survivalVidasExtra".
func survival_lives(now: int) -> int:
	var lives := SURVIVAL_LIVES - _survival_uses().size() + _private_int("survivalVidasExtra")
	for used in _survival_uses():
		if used + _config.survival_life_hours * 3600 <= now:
			lives += 1
	return lives


## Seconds until the next used life comes back, or -1 when no life is used.
func survival_life_wait(now: int) -> int:
	var wait := -1
	for used in _survival_uses():
		var back := used + _config.survival_life_hours * 3600 - now
		if back > 0 and (wait < 0 or back < wait):
			wait = back
	return wait


## Uses a life for a survival map, as the server command "start_survival"
## does: a bought life first, else a life that is back. Returns false without
## a life.
func start_survival(now: int) -> bool:
	var private: Dictionary = _document["privateState"]
	if _private_int("survivalVidasExtra") > 0:
		private["survivalVidasExtra"] = _private_int("survivalVidasExtra") - 1
		return true
	var uses := _survival_uses().filter(func(used: int) -> bool: return now - used < _config.survival_life_hours * 3600)
	if SURVIVAL_LIVES - mini(uses.size(), SURVIVAL_LIVES) == 0:
		return false
	uses.append(now)
	private["survivalVidaTimeStamp"] = uses
	return true


## Buys one more survival life with cash ("add_survival_vida_extra").
func buy_survival_life() -> Placement:
	if get_resource("c") < _config.survival_life_cash:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -_config.survival_life_cash)
	_document["privateState"]["survivalVidasExtra"] = _private_int("survivalVidasExtra") + 1
	return Placement.OK


## The best time on a survival map in seconds, or -1 when the map is not open.
## The server opens the first SURVIVAL_MAPS_OPEN maps when it loads a save.
func survival_best_time(map_id: String) -> int:
	var record: Variant = _survival_record(map_id)
	return int(record.get("tp", 0)) if record is Dictionary else -1


## The end of a survival, as the server command "end_survival" does: the time
## of the last play and the best time of the map, and the reward unit
## (0 for none) in the store.
func end_survival(map_id: String, seconds: int, reward: int, now: int) -> void:
	var record: Variant = _survival_record(map_id)
	if not record is Dictionary:
		return
	record["ts"] = now
	record["tp"] = maxi(seconds, int(record.get("tp", 0)))
	if reward != 0:
		_stored()[str(reward)] = int(_stored().get(str(reward), 0)) + 1


## The packets of each size that the player has, in the order of
## GameConfig.time_packets.
func time_packets() -> Array[int]:
	var counts: Array[int] = []
	var saved: Variant = _document["privateState"].get("countTimePacket")
	for i in _config.time_packets.size():
		var count: Variant = saved[i] if saved is Array and i < saved.size() else 0
		counts.append(int(count) if count is int or count is float else 0)
	return counts


## Buys a packet of the Time Machine for its cash price ("buy_time_packet").
func buy_time_packet(index: int) -> Placement:
	if index < 0 or index >= _config.time_packets.size():
		return Placement.NOT_ALLOWED
	var price: int = _config.time_packets[index][1]
	if get_resource("c") < price:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -price)
	_set_time_packets(index, 1)
	return Placement.OK


## Uses a packet of the Time Machine ("time_ff"): all times of the save move
## back by the hours of the packet, see _fast_forward(). The client then loads
## the map again.
func use_time_packet(index: int) -> Placement:
	if index < 0 or index >= _config.time_packets.size() or time_packets()[index] <= 0:
		return Placement.NOT_ALLOWED
	_set_time_packets(index, -1)
	_fast_forward(int(_config.time_packets[index][0] * 3600))
	return Placement.OK


func is_skin_unlocked(new_skin: int) -> bool:
	var unlocked: Variant = _document["privateState"].get("unlockedSkins")
	# The server writes true; the client compares the value with "true".
	return new_skin == 0 or (unlocked is Dictionary and unlocked.get(str(new_skin)) in [true, "true"])


## Unlocks a style of the map for GameConfig.unlock_skin_cash cash
## ("unlock_skin") and uses it, as the client does after the unlock.
func unlock_skin(new_skin: int) -> Placement:
	if not new_skin in SKINS or is_skin_unlocked(new_skin):
		return Placement.NOT_ALLOWED
	if get_resource("c") < _config.unlock_skin_cash:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -_config.unlock_skin_cash)
	if not _document["privateState"].get("unlockedSkins") is Dictionary:
		_document["privateState"]["unlockedSkins"] = {}
	_document["privateState"]["unlockedSkins"][str(new_skin)] = true
	return set_skin(new_skin)


## Uses an unlocked style of the map ("set_skin"). The client then loads the map again.
func set_skin(new_skin: int) -> Placement:
	if not new_skin in SKINS or new_skin == skin or not is_skin_unlocked(new_skin):
		return Placement.NOT_ALLOWED
	# The server stores the style as text.
	_map["skin"] = str(new_skin)
	skin = new_skin
	return Placement.OK


## The steps of the temple that the player did, from 0 to TEMPLE_STEPS - 1.
func temple_steps_done() -> Array[int]:
	var steps: Array[int] = []
	var saved: Variant = _document["privateState"].get("templeStep")
	for step: Variant in saved if saved is Array else []:
		if (step is int or step is float) and not int(step) in steps:
			steps.append(int(step))
	return steps


## Seconds until the player can do the next step of the temple, or 0.
func temple_wait_seconds(now: int) -> int:
	var last_step := _private_int("timeStampTemple")
	return maxi(last_step + TEMPLE_STEP_SECONDS - now, 0) if last_step > 0 else 0


## True when the player has what the step needs: the resources, the unit on
## the map or the reward of the heart collection in the item store.
func has_temple_offering(step: int) -> bool:
	if step < TEMPLE_OFFERINGS.size():
		return get_resource(TEMPLE_OFFERINGS[step][0]) >= TEMPLE_OFFERINGS[step][1]
	if step < TEMPLE_OFFERINGS.size() + TEMPLE_SACRIFICES.size():
		return _temple_sacrifice(step) != null
	return stored_items().has(_config.collection_rewards[TEMPLE_HEART_COLLECTION])


## Does a step of the temple ("next_temple_step"): it pays the resources, or
## removes the unit from the map without the graveyard (the client sends
## "sell" without resources), or keeps the heart. Then the wait starts.
func do_temple_step(step: int, now: int) -> Placement:
	if step < 0 or step >= TEMPLE_STEPS or step in temple_steps_done() or temple_wait_seconds(now) > 0:
		return Placement.NOT_ALLOWED
	if not has_temple_offering(step):
		return Placement.NOT_ENOUGH_RESOURCES if step < TEMPLE_OFFERINGS.size() else Placement.NOT_ALLOWED
	if step < TEMPLE_OFFERINGS.size():
		_add_resource(TEMPLE_OFFERINGS[step][0], -TEMPLE_OFFERINGS[step][1])
	elif step < TEMPLE_OFFERINGS.size() + TEMPLE_SACRIFICES.size():
		_remove(_temple_sacrifice(step))
	var steps: Array = temple_steps_done()
	steps.append(step)
	_set_private(["templeStep", "timeStampTemple"], [steps, now])
	return Placement.OK


## Pays TEMPLE_WAIT_CASH to end the wait of the temple ("buy_temple_step_cash").
func end_temple_wait(now: int) -> Placement:
	if temple_wait_seconds(now) == 0:
		return Placement.NOT_ALLOWED
	if get_resource("c") < TEMPLE_WAIT_CASH:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -TEMPLE_WAIT_CASH)
	_set_private(["timeStampTemple"], [0])
	return Placement.OK


## After all steps and the last wait, the Supreme Bahamut Dragon comes to the
## free tile nearest to the temple, with "buy" without cost. The client then
## sells the heart from the item store and starts the temple again ("reset_temple").
func take_supreme_bahamut(temple: PlacedItem, now: int) -> Placement:
	if temple_steps_done().size() < TEMPLE_STEPS or temple_wait_seconds(now) > 0:
		return Placement.NOT_ALLOWED
	var tile := free_tile_around(_covered_tiles(temple))
	if tile == ANY_TILE:
		return Placement.OCCUPIED
	var dragon := _config.get_item(SUPREME_BAHAMUT)
	_add_xp(dragon.xp)
	_add_player_unit(dragon, tile, 0, now)
	var heart := _config.get_item(_config.collection_rewards[TEMPLE_HEART_COLLECTION])
	if stored_items().has(heart.id):
		_sell_stored(heart)
	_set_private(["templeStep", "timeStampTemple"], [[], 0])
	return Placement.OK


## The allies buildings keep their list of workers ("si"), which neighbours
## join when they help the village (autohire_ignore_buildings of the server).
## The player can also hire workers for cash, see hire_worker(); the
## Recruitment Prize costs nothing for each recruit. The Round Table takes only
## neighbours, so it needs other players.
## - The Allies Building (and the troll one): with all workers, opening it
##   brings SUMMIT_KNIGHTS Alliance Knights, as the client's
##   spawnAlliedTroops(); the list starts again.
## - The Allies Market: the player chooses a resource; after the activation
##   time of the building it gives GameConfig.allies_market_collect of it and
##   more for each worker ("finish_si"), and the list starts again.
## - The Recruitment Prize: each prize of GameConfig.recruitment_prizes needs
##   a number of recruits; the units of the prize go to the item store
##   ("finish_si_recruitment").
const SUMMITS: Array[int] = [234, 361]
const ALLIES_MARKETS: Array[int] = [266, 352]
const RECRUITMENT_PRIZE := 387
const ALLIANCE_KNIGHT := 576
const SUMMIT_KNIGHTS := 9
const ALLIES_RESOURCES: Array[String] = ["g", "w", "f", "s"]
const RECRUITS_KEPT := 4  ## The server keeps at most this number of recruits.


## Opens a full Allies Building: the Alliance Knights come next to it. Needs
## room for them in the population.
func open_allies_building(placed: PlacedItem, now: int) -> Array[PlacedItem]:
	var knights: Array[PlacedItem] = []
	var counts := workers(placed)
	if not placed.item_id in SUMMITS or counts[0] < counts[1] or population() + SUMMIT_KNIGHTS > max_population():
		return knights
	var knight := _config.get_item(ALLIANCE_KNIGHT)
	var area := VillageMap.footprint(_config.get_item(placed.item_id), placed.tile)
	for i in SUMMIT_KNIGHTS:
		var tile := free_tile_around(area)
		if tile == ANY_TILE:
			break
		# The client buys each knight without cost ("buy" with is_free).
		_add_xp(knight.xp)
		knights.append(_add_player_unit(knight, tile, 0, now))
	placed._entry[7]["si"] = []
	happened.emit(VillageEvent.Kind.SOCIAL_BUILDING_OPENED, {"item": placed.item_id})
	return knights


## The resource that the Allies Market of the map collects ("g", "w", "f" or
## "s"), or "n" when the player did not choose one.
func allies_market_resource() -> String:
	var code: Variant = _map.get("resourceAlliesMarket", "n")
	return code if code in ALLIES_RESOURCES else "n"


## Chooses the resource, as the server command "set_resource_allies" does:
## the time starts again, and the workers leave.
func set_allies_market_resource(placed: PlacedItem, code: String, now: int) -> Placement:
	if not placed.item_id in ALLIES_MARKETS or not code in ALLIES_RESOURCES:
		return Placement.NOT_ALLOWED
	_map["resourceAlliesMarket"] = code
	placed._entry[4] = now
	placed._entry[7]["si"] = []
	return Placement.OK


## Seconds until the Allies Market can be collected, or -1 without a resource.
func allies_market_seconds(placed: PlacedItem, now: float) -> float:
	if allies_market_resource() == "n":
		return -1
	return maxf(0, _config.get_item(placed.item_id).activation - (now - float(placed._entry[4])))


## The amount that the Allies Market gives now.
func allies_market_amount(placed: PlacedItem) -> int:
	var code := allies_market_resource()
	return int(_config.allies_market_collect.get(code, 0)) + int(_config.allies_market_per_worker.get(code, 0)) * workers(placed)[0]


## Collects from the Allies Market ("finish_si"); the client then chooses no resource.
func collect_allies_market(placed: PlacedItem, now: int) -> Placement:
	if not placed.item_id in ALLIES_MARKETS or allies_market_seconds(placed, now) != 0:
		return Placement.NOT_ALLOWED
	_add_resource(allies_market_resource(), allies_market_amount(placed))
	placed._entry[7]["si"] = []
	_map["resourceAlliesMarket"] = "n"
	happened.emit(VillageEvent.Kind.SOCIAL_BUILDING_OPENED, {"item": placed.item_id})
	return Placement.OK


## The prizes of the Recruitment Prize that the player did not take yet.
func open_recruitment_prizes() -> Array[Dictionary]:
	var taken: Variant = _document["privateState"].get("recruitmentPrices")
	return _config.recruitment_prizes.filter(func(prize: Dictionary) -> bool: return not (taken is Array and (taken.has(prize["id"]) or taken.has(float(prize["id"])))))


## Takes the prize, as the server command "finish_si_recruitment" does: it
## needs its recruits, and the level of the prize unless all earlier prizes
## were taken. The recruits that it needs leave; at most RECRUITS_KEPT stay.
func take_recruitment_prize(placed: PlacedItem, prize: Dictionary) -> Placement:
	if placed.item_id != RECRUITMENT_PRIZE or not open_recruitment_prizes().any(func(other: Dictionary) -> bool: return other["id"] == prize["id"]) \
			or workers(placed)[0] < prize["recruits"]:
		return Placement.NOT_ALLOWED
	if get_level() < prize["level"] and open_recruitment_prizes().any(func(other: Dictionary) -> bool: return other["id"] < prize["id"]):
		return Placement.LEVEL_TOO_LOW
	for unit_id: int in prize["units"]:
		_add_stored(unit_id)
	var kept := maxi(0, mini(RECRUITS_KEPT, workers(placed)[0]) - prize["recruits"])
	placed._entry[7]["si"] = placed._entry[7]["si"].slice(0, kept)
	if not _document["privateState"].get("recruitmentPrices") is Array:
		_document["privateState"]["recruitmentPrices"] = []
	_document["privateState"]["recruitmentPrices"].append(prize["id"])
	return Placement.OK


## The unit of the player on the map that the sacrifice step needs, or null.
## The player can put the own buildings and decorations into the item store,
## except the town hall and a building that trains units.
func can_store(placed: PlacedItem) -> bool:
	return can_move(placed) and _config.get_item(placed.item_id).subcat_functional != SUBCAT_TOWN_HALL and queued_units(placed) == 0


## Puts the item into the item store, as the server command "store_item"
## does. Its units come out first.
func store_item(placed: PlacedItem, now: int) -> Placement:
	if not can_store(placed):
		return Placement.NOT_ALLOWED
	_pop_all(placed, now)
	_remove(placed)
	_add_stored(placed.item_id)
	return Placement.OK


## The unit pack on the place slot (1 to PACK_SLOTS) of the store, or {}.
func unit_pack_for_slot(slot: int, now: int) -> Dictionary:
	var packs := _config.unit_packs.filter(func(pack: Dictionary) -> bool:
		var bought := unit_packs_bought([int(pack["id"])])
		var start := int(GameConfig.to_int(pack.get("starts_at")) if GameConfig.to_int(pack.get("starts_at")) != null else 0)
		var duration := int(GameConfig.to_int(pack.get("duration")) if GameConfig.to_int(pack.get("duration")) != null else 0)
		var min_level := int(GameConfig.to_int(pack.get("min_level")) if GameConfig.to_int(pack.get("min_level")) != null else 0)
		var max_level := int(GameConfig.to_int(pack.get("max_level")) if GameConfig.to_int(pack.get("max_level")) != null else 0)
		return int(GameConfig.to_int(pack.get("in_store"))) == 1 and int(pack["store_order"]) == slot \
				and (duration == 0 or (now >= start and now <= start + duration)) \
				and (int(pack["max_purchable"]) == 0 or bought < int(pack["max_purchable"])) \
				and (min_level == 0 or get_level() >= min_level) and (max_level == 0 or get_level() <= max_level))
	packs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("slot_priority", 0)) < float(b.get("slot_priority", 0)))
	return packs[0] if not packs.is_empty() else {}


## The number of packs that the player can buy at once, as the client allows.
func max_unit_packs(pack: Dictionary) -> int:
	var code: String = unit_pack_cost(pack, 1)[0]
	var price := int(unit_pack_cost(pack, 1)[1])
	var count := mini(get_resource(code) / maxi(price, 1), _config.max_packs_per_purchase)
	var limit := int(pack["max_purchable"])
	return count if limit == 0 else clampi(mini(count, limit - unit_packs_bought([int(pack["id"])])), 0, count)


## [resource code, amount] of count packs, with the discount, as the server takes it.
func unit_pack_cost(pack: Dictionary, count: int) -> Array:
	var code := "c" if pack["price"].has("c") else "g"
	var discount := 1.0
	for entry: Array in PACK_DISCOUNTS:
		if count >= entry[0]:
			discount = entry[1]
			break
	return [code, ceili(int(pack["price"][code]) * count * discount)]


## Buys count unit packs, as the server command "buy_unit_pack" does, and
## chooses their units as the client does with the random numbers of the
## server. The units go to the item store ("store_add_items"). Returns the
## units, or [] when the player cannot buy them.
func buy_unit_packs(pack: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var units: Array[int] = []
	if count < 1 or count > max_unit_packs(pack):
		return units
	var cost := unit_pack_cost(pack, count)
	_add_resource(cost[0], -cost[1])
	var bought: Variant = _document["privateState"].get("unitPacks")
	if not bought is Dictionary:
		bought = {}
		_document["privateState"]["unitPacks"] = bought
	var key := str(int(pack["id"]))
	bought[key] = int(bought.get(key, 0)) + count
	happened.emit(VillageEvent.Kind.PACK_BOUGHT, {"amount": unit_packs_bought([])})
	for i in count * int(pack["units_given"]):
		var unit := _pack_unit(pack, units, rng)
		if unit != 0:
			units.append(unit)
			_register_unit(unit)
			_add_stored(unit)
	return units


## One unit of a pack, which this purchase did not give yet: first the kind
## of the pack (pack_num), then for kind 1 the category (pack_category, or
## "custom" for the units of the pack), then a unit by its chance.
func _pack_unit(pack: Dictionary, given: Array[int], rng: RandomNumberGenerator) -> int:
	var kind := int(_weighted_key(pack["pack_num"], rng.randf() * 100))
	var category := String(_weighted_key(pack["pack_category"], rng.randf() * 100)) if kind == 1 else ""
	var chances := []  # [unit id, chance]
	if category == "custom":
		for entry: Variant in pack.get("custom", []) if pack.get("custom") is Array else []:
			chances.append([int(entry["id"]), int(entry.get("chances", 0))])
	else:
		for item in _config.items():
			if item.pack_num == kind and (kind != 1 or item.pack_category == category.to_int()):
				chances.append([item.id, item.pack_chance])
	var total: int = chances.reduce(func(sum: int, entry: Array) -> int: return sum + entry[1], 0)
	var left := chances.filter(func(entry: Array) -> bool: return not entry[0] in given and entry[1] > 0)
	if total <= 0 or left.is_empty():
		return 0
	# The client draws again until it finds a unit that this purchase did not give.
	while true:
		var winner: float = rng.randf() * total
		var sum := 0
		for entry: Array in chances:
			sum += entry[1]
			if sum >= winner:
				if not entry[0] in given:
					return entry[0]
				break
	return 0


## The key whose share of the weights reaches value (0 to 100), in the order of the configuration.
static func _weighted_key(weights: Dictionary, value: float) -> Variant:
	var total := 0.0
	for key: Variant in weights:
		total += float(weights[key])
	var sum := 0.0
	for key: Variant in weights:
		sum += float(weights[key]) * 100.0 / maxf(total, 0.001)
		if value <= sum:
			return key
	return weights.keys().back()


func _add_stored(item_id: int) -> void:
	_stored()[str(item_id)] = int(_stored().get(str(item_id), 0)) + 1
	happened.emit(VillageEvent.Kind.STORED, {"item": item_id})


## The last tutorial step that the player reached (playerInfo
## "completed_tutorial"). The tutorial runs while it is 0 on the first map.
func tutorial_step() -> int:
	var value: Variant = _document["playerInfo"].get("completed_tutorial", 0)
	return GameConfig.to_int(value) if GameConfig.to_int(value) != null else 0


## As the server command "complete_tutorial" does, which keeps the step as text.
func set_tutorial_step(step: int) -> void:
	_document["playerInfo"]["completed_tutorial"] = str(step)


func is_first_map() -> bool:
	return _map_index == 0


## The dragon nest that the client gives at the end of the tutorial, at the
## free place nearest to TUTORIAL_NEST_TILE, with "buy" without cost. The
## client then sends 9 care steps, which the server refuses because the nest
## is not active. Returns the nest, or null when no place is free.
func add_tutorial_nest(now: int) -> PlacedItem:
	var nest := _config.get_item(DRAGON_NEST)
	var tile := _free_place_near(nest, TUTORIAL_NEST_TILE)
	if tile == ANY_TILE:
		return null
	_add_xp(nest.xp)
	var placed := _add_entry(nest, tile, 0, now, _new_item_attributes(nest))
	happened.emit(VillageEvent.Kind.BUILT, {"item": DRAGON_NEST})
	return placed


## Moves the start of the production of the building back by seconds. In the
## tutorial, the client makes the farm produce 11 times faster.
func advance_production(placed: PlacedItem, seconds: int) -> void:
	placed._entry[4] = float(placed._entry[4]) - seconds


## The goals in privateState "completedMissions" (key "completed") or
## "rewardedMissions" (key "rewarded").
func goal_ids(key: String) -> Array[int]:
	var ids: Array[int] = []
	var list: Variant = _document["privateState"].get(GOAL_KEYS[key])
	for id: Variant in list if list is Array else []:
		if id is int or id is float:
			ids.append(int(id))
	return ids


## The unit packs that the player bought (privateState "unitPacks"), of
## these pack ids or, when ids is empty, of all packs.
func unit_packs_bought(ids: Array[int]) -> int:
	var bought: Variant = _document["privateState"].get("unitPacks")
	var count := 0
	for key: Variant in bought if bought is Dictionary else {}:
		if str(key).is_valid_int() and (ids.is_empty() or str(key).to_int() in ids):
			count += int(bought[key])
	return count


## Rewards and completes the goal, as the client's commands "reward_mission"
## and "complete_mission" do on the server: the goal goes into both lists, and
## its gold comes once.
func reward_goal(goal: GameConfig.GoalDef) -> void:
	var rewarded := goal.id in goal_ids("rewarded")
	for key: String in ["rewarded", "completed"]:
		if not _document["privateState"].get(GOAL_KEYS[key]) is Array:
			_document["privateState"][GOAL_KEYS[key]] = []
		if not goal.id in goal_ids(key):
			_document["privateState"][GOAL_KEYS[key]].append(goal.id)
	if not rewarded:
		_add_resource("g", goal.reward)


func _temple_sacrifice(step: int) -> PlacedItem:
	var unit_id := TEMPLE_SACRIFICES[step - TEMPLE_OFFERINGS.size()]
	for placed in items:
		if placed.item_id == unit_id and is_own_unit(placed):
			return placed
	return null


## Sells one item from the item store, as the server command
## "sell_stored_item" does: it gives back sell_refund() of the cost.
func _sell_stored(item: GameConfig.ItemDef) -> void:
	var stored := _stored()
	for key: Variant in stored.keys():
		if str(key) == str(item.id):
			stored[key] = int(stored[key]) - 1
			if int(stored[key]) <= 0:
				stored.erase(key)
			break
	var refund := sell_refund(item)
	if refund > 0:
		_add_resource(item.cost_type, refund)


func _set_time_packets(index: int, change: int) -> void:
	var counts := time_packets()
	counts[index] += change
	_document["privateState"]["countTimePacket"] = counts


## Moves the times of the save back by seconds, as the server function
## player_fast_forward() does for the Time Machine: the quests, the items, the
## market, the nests, the Rider Academy, the temple, survival, the training
## queues and the events. The shields, the help of the neighbours and the
## daily bonus keep their times. A missing time becomes 0, as on the server.
func _fast_forward(seconds: int) -> void:
	var private: Dictionary = _document["privateState"]
	for game_map: Variant in _document["maps"]:
		if not game_map is Dictionary:
			continue
		var quest_times: Variant = game_map.get("questTimes")
		for quest: Variant in quest_times if quest_times is Dictionary else {}:
			_move_time(quest_times, quest, seconds)
		var last_times: Variant = game_map.get("lastQuestTimes")
		for i in last_times.size() if last_times is Array else 0:
			_move_time(last_times, i, seconds)
		for entry: Variant in game_map.get("items", []):
			if not entry is Array or entry.size() < 8:
				continue
			_move_time(entry, 4, seconds)
			var sif: Variant = entry[7].get("sif") if int(entry[0]) == ROUND_TABLE and entry[7] is Dictionary else null
			for user: Variant in sif if sif is Dictionary else {}:
				_move_time(sif, user, seconds)
		_move_time(game_map, "timestampLastTrade", seconds)
		_move_time(game_map, "timestampLastTreasure", seconds)
	for key in ["kompuLastTimeStamp", "timestampLastBonus", "timeStampHeavySiegePeriod", "timeStampHeavySiegeAttack", "timeStampDartsReset", "timeStampDartsNewFree"]:
		_move_time(private, key, seconds)
	for nest: Dictionary in NESTS.values():
		_move_time(private, nest["keys"][3], seconds)
	_move_time(private, RIDER_KEYS[2], seconds)
	_move_time(private, "timeStampTemple", seconds)
	var uses: Variant = private.get("survivalVidaTimeStamp")
	for i in uses.size() if uses is Array else 0:
		_move_time(uses, i, seconds)
	for holder_key: String in ["survivalMaps", "barracksQueues", "collectGame"]:
		var holders: Variant = private.get(holder_key)
		for key: Variant in holders if holders is Dictionary else {}:
			if holders[key] is Dictionary:
				_move_time(holders[key], "timestamp" if holder_key == "collectGame" else "ts", seconds)


## One time of _fast_forward(): never below 0. A missing value or null becomes 0.
static func _move_time(holder: Variant, key: Variant, seconds: int) -> void:
	var value: Variant = holder.get(key) if holder is Dictionary else holder[key]
	holder[key] = maxf(value - seconds, 0) if value is int or value is float else 0


func _survival_uses() -> Array[int]:
	var uses: Array[int] = []
	var saved: Variant = _document["privateState"].get("survivalVidaTimeStamp")
	for used: Variant in saved if saved is Array else []:
		if used is int or used is float:
			uses.append(int(used))
	return uses


func _survival_record(map_id: String) -> Variant:
	var private: Dictionary = _document["privateState"]
	if not private.get("survivalMaps") is Dictionary:
		private["survivalMaps"] = {}
	var maps: Dictionary = private["survivalMaps"]
	for open_id in SurvivalMap.IDS.slice(0, SURVIVAL_MAPS_OPEN):
		if not maps.has(open_id):
			maps[open_id] = {"ts": 0, "tp": 0}
	return maps.get(map_id)


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


## The quest in the town (TownQuests): its number in the chain of 30 quests
## ("idCurrentTreasure"), the time when the last one ended
## ("timestampLastTreasure") and its state ("currentQuestVars").
func town_quest_id() -> int:
	return int(_map.get("idCurrentTreasure", 0))


func town_quest_time() -> int:
	return int(_map.get("timestampLastTreasure", 0))


func town_quest_vars() -> Dictionary:
	var vars: Variant = _map.get("currentQuestVars")
	return vars if vars is Dictionary else {}


## Keeps a value of the state of the quest, as the server command
## "set_quest_var" does. The server ignores the command in the
## TOWN_QUEST_WAIT after the end of a quest. Some old saves have a list
## instead of the dictionary; the port replaces it.
func set_town_quest_var(key: String, value: Variant, now: int) -> void:
	if absi(now - town_quest_time()) <= TOWN_QUEST_WAIT:
		return
	if not _map.get("currentQuestVars") is Dictionary:
		_map["currentQuestVars"] = {}
	_map["currentQuestVars"][key] = value


## Ends the quest as the server command "collect_treasure" does: the rewards,
## the number of the next quest, the time of the end and an empty state. The
## server refuses it in the TOWN_QUEST_WAIT after the end of the last quest.
func finish_town_quest(gold: int, xp: int, next_id: int, food: int, stone: int, now: int) -> Placement:
	if absi(now - town_quest_time()) < TOWN_QUEST_WAIT:
		return Placement.NOT_ALLOWED
	_map["timestampLastTreasure"] = now
	_map["idCurrentTreasure"] = next_id
	_map["currentQuestVars"] = {}
	_add_resource("g", gold)
	_add_xp(xp)
	_add_resource("f", food)
	_add_resource("s", stone)
	return Placement.OK


## The player collects the open treasure of a quest: the client sends "sell"
## with resources, so the server gives back the sell value of the item.
func collect_quest_treasure(placed: PlacedItem) -> void:
	var refund := sell_refund(_config.get_item(placed.item_id))
	if refund > 0:
		_add_resource(_config.get_item(placed.item_id).cost_type, refund)
	_remove(placed)


## A building that a quest gives goes to the item store, as the client does
## with "store_add_items".
func store_quest_reward(item_id: int) -> void:
	_add_stored(item_id)
