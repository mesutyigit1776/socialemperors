class_name SaveMigration
extends RefCounted
## The repairs that the server's save migration (version.py
## migrate_loaded_save) makes on each save that it loads, for the values that
## the port reads.
##
## The migration of the server also adds each missing value with its default.
## The port does not: the code that reads a value uses the same default when
## the value is missing (for example time_packets() and start_daily_bonus()).
## Other parts of the server's migration are elsewhere in the port: the troll
## town is added when the player buys it (VillageMap.buy_second_town()), and
## GoalBook completes the land goals that the player already has. The port
## does not use the darts values, the removal of the banned units (the list of
## the server is empty) and the clean up of old fields.


## Repairs the save document in place. heroes are the units of the Heroes
## Grave. now is the time that very old saves give to their items.
static func migrate(save: Dictionary, config: GameConfig, heroes: Array[int], now: int) -> void:
	var private: Dictionary = save["privateState"]
	# Saves of old versions of the server have the key "version" and items of
	# five values.
	var very_old := save.has("version")
	if very_old:
		_complete_items(save["maps"], now)
	if not private.get("resurrectableUnits") is Array:
		private["resurrectableUnits"] = []
		_remove_dead_non_heroes(private, heroes)
	if private.get("gifts") is Array:
		private["gifts"] = _gift_counts(private["gifts"])
	if not private.get("collectionsCompleted") is Array or private["collectionsCompleted"].is_empty():
		private["collectionsCompleted"] = _completed_collections(private.get("collections"))
	if not private.get("boughtUnits") is Array or private["boughtUnits"].is_empty():
		private["boughtUnits"] = _bought_units(save, config)
	if very_old:
		_add_level_mana(save, config)
		private["monsterNestActive"] = 1
		private["deadHeroes"] = {}
		private["resurrectableUnits"] = []
		save.erase("version")


## The rule of the server for "boughtUnits" (engine.py register_bought_unit):
## units count, except the units of the other race than the race of the map.
## With map_race "" all units count.
static func counts_as_bought(item: GameConfig.ItemDef, map_race: String) -> bool:
	var ignored: String = {"h": "t", "t": "h"}.get(map_race, "")
	return item != null and item.is_unit() and item.race != ignored


## The list of the server's fix_bought_units: the units on the maps, in their
## buildings, in the item stores and the warehouses, then the gifts and the
## dead heroes. The server compares instead of assigns in the line that sets
## the race of a troll map, so it counts the human units there; the port uses
## the rule of counts_as_bought(). The server adds the troll town to each save
## that it loads, also when the player did not buy it; the port reads only the
## towns that the player has (privateState.maps).
static func _bought_units(save: Dictionary, config: GameConfig) -> Array:
	var bought := []
	var private: Dictionary = save["privateState"]
	var towns: Variant = private.get("maps")
	var town_count: int = towns.size() if towns is Array and not towns.is_empty() else 1
	var maps: Array = save["maps"]
	for index in mini(town_count, maps.size()):
		var map: Variant = maps[index]
		if not map is Dictionary:
			continue
		var map_race := str(map.get("race", ""))
		var entries: Variant = map.get("items")
		for entry: Variant in entries if entries is Array else []:
			if not entry is Array or entry.is_empty():
				continue
			_add_bought(bought, entry[0], map_race, config)
			var inside: Variant = entry[6] if entry.size() > 6 else null
			for id: Variant in inside if inside is Array else []:
				_add_bought(bought, id, map_race, config)
		for key in ["store", "warehousedUnits"]:
			var stored: Variant = map.get(key)
			for id: Variant in stored if stored is Dictionary else {}:
				_add_bought(bought, id, map_race, config)
	for key in ["gifts", "deadHeroes"]:
		var listed: Variant = private.get(key)
		for id: Variant in listed if listed is Dictionary else {}:
			_add_bought(bought, id, "", config)
	return bought


static func _add_bought(bought: Array, id: Variant, map_race: String, config: GameConfig) -> void:
	var number: Variant = GameConfig.to_int(id)
	if number == null or not counts_as_bought(config.get_item(number), map_race):
		return
	if not bought.has(number):
		bought.append(number)


## The server's _fix_map_items: each item gets the time now and the values
## that old saves do not have (level, units inside, attributes).
static func _complete_items(maps: Array, now: int) -> void:
	for map: Variant in maps:
		var entries: Variant = map.get("items") if map is Dictionary else null
		for entry: Variant in entries if entries is Array else []:
			if not entry is Array or entry.size() < 4:
				continue
			entry.resize(maxi(entry.size(), 8))
			entry[4] = now
			if not (entry[5] is int or entry[5] is float):
				entry[5] = 0
			if not entry[6] is Array:
				entry[6] = []
			if not entry[7] is Dictionary:
				entry[7] = {}


## Old saves keep the gifts as a list of counts by item id; the server makes a
## dictionary without the zeros (array_to_dict).
static func _gift_counts(counts: Array) -> Dictionary:
	var gifts := {}
	for id in counts.size():
		if counts[id] != 0 and counts[id] != null:
			gifts[str(id)] = counts[id]
	return gifts


## The collections with the completed flag (element 0 of each list), from 1 to
## Collections.count().
static func _completed_collections(lists: Variant) -> Array:
	var completed := []
	if not lists is Array:
		return completed
	for collection in range(1, mini(lists.size(), Collections.count() + 1)):
		var counts: Variant = lists[collection]
		var flag: Variant = counts[0] if counts is Array and not counts.is_empty() else null
		if (flag is bool and flag) or GameConfig.to_int(flag) not in [null, 0]:
			completed.append(collection)
	return completed


## The server removes the units that are not heroes from the Heroes Grave of
## saves without the graveyard list.
static func _remove_dead_non_heroes(private: Dictionary, heroes: Array[int]) -> void:
	var dead: Variant = private.get("deadHeroes")
	if not dead is Dictionary:
		return
	for key: Variant in dead.keys():
		var id: Variant = GameConfig.to_int(key)
		if id == null or not heroes.has(id):
			dead.erase(key)


## Old servers gave no mana for levels; the server's _fix_level_mana gives the
## mana of the levels of the first town.
static func _add_level_mana(save: Dictionary, config: GameConfig) -> void:
	var first: Variant = save["maps"][0] if not save["maps"].is_empty() else null
	var level: Variant = GameConfig.to_int(first.get("level")) if first is Dictionary else null
	if level == null:
		return
	var gain := maxi(0, 1 + mini(100, level) - config.start_level_mana_reward) * config.mana_reward_per_level
	var private: Dictionary = save["privateState"]
	var mana: Variant = GameConfig.to_int(private.get("mana"))
	private["mana"] = (mana if mana != null else 0) + gain
