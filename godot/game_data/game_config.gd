class_name GameConfig
extends RefCounted
## Item and level definitions from the game configuration that the importer writes (config.json).


class ItemDef:
	var id: int
	var name: String
	var type: String  ## "u" is a unit; other types are buildings and decorations.
	var race: String  ## "h", "t" or another value for items of all races.
	var img_name: String
	var width: int  ## Footprint in tiles.
	var height: int
	var category_id: int
	var in_store: int  ## 0: not sold. 1 or 3: sold to humans. 2 or 4: sold to trolls.
	var subcat_functional: int  ## Function of the building, for example 111 for a house.
	var cost: int
	var cost_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var xp: int  ## Experience that the player gets when buying the item.
	var min_level: int
	## Number of directions. Turning an item shows the next frame. Every item
	## that can turn is square, so turning does not change its footprint.
	var max_frame: int
	## Seconds of production before the player can collect, or 0 when the item
	## does not produce. Mills and mines use a work time instead, see
	## variable_collect_ids.
	var activation: float
	var collect: int  ## Amount of the resource collect_type that a collection gives.
	var collect_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var collect_xp: int
	var population: int  ## Population that the building gives. Wonders with population cannot hurry.
	var store_level: int  ## The store shows the item from this level. 0: from the start.
	var unit_capacity: int  ## Number of units that can be in the building.
	var trains: int  ## The unit that the building trains, or 0.
	var units_limit: int  ## Maximum number of this unit on a map, or 0 for no limit.
	var training_time: int  ## Seconds to train this unit.
	var velocity: int  ## Walking speed of a unit.
	var attack_range: int  ## Tiles; 1 for units that fight next to the enemy.
	var breeding_order: int  ## Power of a unit in the Soul Mixer, or 0 when the unit cannot go into it.
	var sm_training_time: int  ## Seconds that the Soul Mixer needs to make this unit.
	var potion: int  ## Potions that bring this unit back from the graveyard.
	var cost_unit_cash: int  ## The Heroes Grave brings a hero back for this value times Village.RESURRECT_GOLD_PER_CASH gold.

	func is_unit() -> bool:
		return type == "u"

	## race is the race of the map: "h" (human) or "t" (troll).
	func is_sold_to(race: String) -> bool:
		match race:
			"h":
				return in_store == 1 or in_store == 3
			"t":
				return in_store == 2 or in_store == 4
		return false


class LevelDef:
	var name: String
	var exp_required: int  ## Total experience that the player needs for this level.
	var reward_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var reward_amount: int


var levels: Array[LevelDef] = []  ## levels[n - 1] is level n.
var start_level_mana_reward: int  ## From this level, each new level also gives mana.
var mana_reward_per_level: int
var townhall_house_limit: Dictionary = {}  ## Town hall item id -> number of houses that it allows.
var worker_item_ids: Dictionary = {}  ## Item id -> true for the buildings that need workers ("social items").
var allies_item_ids: Array[int] = []  ## Allies buildings and markets, and the recruitment prize.
var category_names: Dictionary = {}  ## Store category id -> name.
## Buildings that work only after the player chooses a work time, see Village.WORK_MINUTES.
var variable_collect_ids: Array[int] = []
## The client spawns wild animals at each start until the player has this number
## of each kind for the day, see Village.spawn_animals().
var animals_per_day: int
## The Unit Warehouse holds this number of units at first. The player can buy
## one more place for warehouse_slot_price cash, up to warehouse_max_capacity.
var warehouse_start_capacity: int
var warehouse_slot_price: int
var warehouse_max_capacity: int
## Cost of starting the dragon nest and the monster nest: resource code -> amount.
var dragon_nest_costs: Dictionary = {}
var monster_nest_costs: Dictionary = {}
## Riders of the Rider Academy, for rider types 1 to 3: {"level": unlock level,
## "steps": training steps, "cash": cash that ends the wait after a step}.
var dragon_riders: Array[Dictionary] = []
## Dragons that a rider can tame: dragon id -> [rider type, id of the tamed dragon].
var dragons: Dictionary = {}
## The graveyard sells graveyard_potions potions for graveyard_potions_price cash.
var graveyard_potions: int
var graveyard_potions_price: int
## Power-ups of the Soul Mixer, in order: [cash, steps up in the list of units].
var soul_mixer_powerups: Array[Array] = []
var soul_mixer_min_level: int  ## The client gives a free Soul Mixer from this level.
## collection_rewards[n] is the item that collection n gives; index 0 is not used.
var collection_rewards: Array[int] = []
var _texts: Dictionary = {}  # Language text name, for example "COLECCION_ROSA_ROJA" -> text.

var _items: Dictionary = {}  # int -> ItemDef


## Returns null and reports an error when the file is missing or not valid.
static func load_from_file(path: String) -> GameConfig:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read game configuration '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return null
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("items") is Array):
		push_error("Game configuration '%s' has no item list." % path)
		return null
	var config := GameConfig.new()
	for entry: Variant in data["items"]:
		var item := _parse_item(entry)
		if item == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		config._items[item.id] = item
	# A level cannot be skipped like an item, because the list index is the level.
	for entry: Variant in data.get("levels", []):
		var level := _parse_level(entry)
		if level == null:
			push_error("Game configuration '%s' has an incorrect level: %s" % [path, str(entry).left(200)])
			return null
		config.levels.append(level)
	if config.levels.is_empty():
		push_error("Game configuration '%s' has no levels." % path)
		return null
	var globals: Variant = data.get("globals")
	var start_mana: Variant = to_int(globals.get("START_LEVEL_MANA_REWARD")) if globals is Dictionary else null
	var mana_per_level: Variant = to_int(globals.get("MANA_REWARD_PER_LEVEL")) if globals is Dictionary else null
	if start_mana == null or mana_per_level == null:
		push_error("Game configuration '%s' has no level mana reward in globals." % path)
		return null
	config.start_level_mana_reward = start_mana
	config.mana_reward_per_level = mana_per_level

	var house_limits: Variant = globals.get("TOWNHALL_HOUSE_LIMIT")
	if not house_limits is Dictionary:
		push_error("Game configuration '%s' has no TOWNHALL_HOUSE_LIMIT in globals." % path)
		return null
	for key: Variant in house_limits:
		var townhall_id: Variant = to_int(key)
		var limit: Variant = to_int(house_limits[key])
		if townhall_id == null or limit == null:
			push_error("Game configuration '%s' has an incorrect TOWNHALL_HOUSE_LIMIT." % path)
			return null
		config.townhall_house_limit[townhall_id] = limit
	for key in ["ALLIES_BUILDING", "ALLIES_MARKET", "ALLIES_MARKET_TROLLS", "RECRUITMENT_PRIZE"]:
		var id: Variant = to_int(globals.get(key))
		if id == null:
			push_error("Game configuration '%s' has no %s in globals." % [path, key])
			return null
		config.allies_item_ids.append(id)
	for entry: Variant in data.get("social_items", []):
		var id: Variant = to_int(entry.get("id")) if entry is Dictionary else null
		if id == null:
			push_error("Game configuration '%s' has an incorrect social item: %s" % [path, str(entry).left(200)])
			return null
		config.worker_item_ids[id] = true
	var variable_ids: Variant = globals.get("COLLECT_VARIABLE_IDS")
	if not variable_ids is Array:
		push_error("Game configuration '%s' has no COLLECT_VARIABLE_IDS in globals." % path)
		return null
	for entry: Variant in variable_ids:
		var id: Variant = to_int(entry)
		if id == null:
			push_error("Game configuration '%s' has an incorrect COLLECT_VARIABLE_IDS." % path)
			return null
		config.variable_collect_ids.append(id)
	var capacities: Variant = globals.get("WAREHOUSE_CAPACITIES")
	var start_capacity: Variant = to_int(capacities[0]) if capacities is Array and not capacities.is_empty() else null
	var numbers := [to_int(globals.get("ANIMALS_PER_DAY")), start_capacity, to_int(globals.get("WAREHOUSE_CAPACITY_INCREASE_PRICE_SINGLE")), to_int(globals.get("WAREHOUSE_MAX_CAPACITY"))]
	if null in numbers:
		push_error("Game configuration '%s' has no ANIMALS_PER_DAY or unit warehouse settings in globals." % path)
		return null
	config.animals_per_day = numbers[0]
	config.warehouse_start_capacity = numbers[1]
	config.warehouse_slot_price = numbers[2]
	config.warehouse_max_capacity = numbers[3]
	if not _parse_special_globals(config, globals):
		push_error("Game configuration '%s' has no correct nest, rider, dragon, graveyard, Soul Mixer or collection settings in globals." % path)
		return null
	for entry: Variant in data.get("localization_strings", []):
		if entry is Dictionary and entry.get("name") is String:
			config._texts[entry["name"]] = str(entry.get("text", ""))
	var categories: Variant = data.get("categories", {})
	if categories is Dictionary:
		for entry: Variant in categories.values():
			if entry is Dictionary and to_int(entry.get("id")) != null:
				config.category_names[to_int(entry["id"])] = str(entry.get("name", ""))
	return config


func get_item(id: int) -> ItemDef:
	return _items.get(id)


## The language text with this name, or the name when the configuration has no such text.
func text(name: String) -> String:
	return _texts.get(name, name)


## All items in configuration order.
func items() -> Array[ItemDef]:
	var result: Array[ItemDef] = []
	result.assign(_items.values())
	return result


static func _parse_item(entry: Variant) -> ItemDef:
	if not entry is Dictionary:
		return null
	var numbers := {}
	for key: String in ["id", "width", "height", "category_id", "in_store", "subcat_functional", "cost", "xp", "min_level", "max_frame", "collect", "collect_xp", "population", "store_level", "unit_capacity", "trains", "units_limit", "training_time", "velocity", "attack_range", "breeding_order", "sm_training_time", "potion", "cost_unit_cash"]:
		numbers[key] = to_int(entry.get(key, 1 if key in ["width", "height", "max_frame"] else 0))
		if numbers[key] == null:
			return null
	if numbers["width"] < 1 or numbers["height"] < 1 or numbers["max_frame"] < 1 or numbers["cost"] < 0 or numbers["collect"] < 0:
		return null
	var activation := str(entry.get("activation", "0"))
	if not activation.is_valid_float() or activation.to_float() < 0:
		return null
	var item := ItemDef.new()
	item.id = numbers["id"]
	item.name = str(entry.get("name", ""))
	item.type = str(entry.get("type", ""))
	item.race = str(entry.get("race", ""))
	item.img_name = str(entry.get("img_name", ""))
	item.width = numbers["width"]
	item.height = numbers["height"]
	item.category_id = numbers["category_id"]
	item.in_store = numbers["in_store"]
	item.subcat_functional = numbers["subcat_functional"]
	item.cost = numbers["cost"]
	item.cost_type = str(entry.get("cost_type", ""))
	item.xp = numbers["xp"]
	item.min_level = numbers["min_level"]
	item.max_frame = numbers["max_frame"]
	item.activation = activation.to_float()
	item.collect = numbers["collect"]
	item.collect_type = str(entry.get("collect_type", ""))
	item.collect_xp = numbers["collect_xp"]
	item.population = numbers["population"]
	item.store_level = numbers["store_level"]
	item.unit_capacity = numbers["unit_capacity"]
	item.trains = numbers["trains"]
	item.units_limit = numbers["units_limit"]
	item.training_time = numbers["training_time"]
	item.velocity = numbers["velocity"]
	item.attack_range = numbers["attack_range"]
	item.breeding_order = numbers["breeding_order"]
	item.sm_training_time = numbers["sm_training_time"]
	item.potion = numbers["potion"]
	item.cost_unit_cash = numbers["cost_unit_cash"]
	return item


## Reads the globals of the nests, the riders, the graveyard, the Soul Mixer
## and the collections. Returns false when one is missing or not correct.
static func _parse_special_globals(config: GameConfig, globals: Dictionary) -> bool:
	for pair: Array in [[config.dragon_nest_costs, "DRAGON"], [config.monster_nest_costs, "MONSTER"]]:
		for code: String in ["g", "c"]:
			var cost: Variant = to_int(globals.get("ACTIVATE_%s_NEST_%s" % [pair[1], "GOLD" if code == "g" else "CASH"]))
			if cost == null:
				return false
			pair[0][code] = cost
	var riders: Variant = globals.get("DRAGON_RIDERS")
	for rider_type in range(1, 4):
		var rider: Variant = riders.get(str(rider_type)) if riders is Dictionary else null
		var values := [to_int(rider.get("unlockLevel")), to_int(rider.get("steps")), to_int(rider.get("stepCost"))] if rider is Dictionary else [null]
		if null in values:
			return false
		config.dragon_riders.append({"level": values[0], "steps": values[1], "cash": values[2]})
	var dragons: Variant = globals.get("DRAGONS")
	if not dragons is Dictionary:
		return false
	for key: Variant in dragons:
		var values := [to_int(key), to_int(dragons[key].get("rider")), to_int(dragons[key].get("tamedId"))] if dragons[key] is Dictionary else [null]
		if null in values:
			return false
		config.dragons[values[0]] = [values[1], values[2]]
	var potions: Variant = globals.get("GRAVEYARD_POTIONS")
	var potion_values := [to_int(potions.get("amount")), to_int(potions["price"].get("c"))] if potions is Dictionary and potions.get("price") is Dictionary else [null]
	if null in potion_values:
		return false
	config.graveyard_potions = potion_values[0]
	config.graveyard_potions_price = potion_values[1]
	var powerups: Variant = globals.get("SOUL_MIXER_POWERUPS_LEVELS")
	if not powerups is Array or powerups.is_empty():
		return false
	for powerup: Variant in powerups:
		var values := [to_int(powerup.get("cash_cost")), to_int(powerup.get("order_increment"))] if powerup is Dictionary else [null]
		if null in values:
			return false
		config.soul_mixer_powerups.append(values)
	var min_level: Variant = to_int(globals.get("SOUL_MIXER_MIN_LEVEL"))
	var rewards: Variant = globals.get("COLLECTION_REWARDS")
	if min_level == null or not rewards is Array:
		return false
	config.soul_mixer_min_level = min_level
	for reward: Variant in rewards:
		if to_int(reward) == null:
			return false
		config.collection_rewards.append(to_int(reward))
	return config.collection_rewards.size() > Collections.count()


static func _parse_level(entry: Variant) -> LevelDef:
	if not entry is Dictionary:
		return null
	var exp_required: Variant = to_int(entry.get("exp_required"))
	var reward_amount: Variant = to_int(entry.get("reward_amount"))
	if exp_required == null or reward_amount == null:
		return null
	var level := LevelDef.new()
	level.name = str(entry.get("name", ""))
	level.exp_required = exp_required
	level.reward_type = str(entry.get("reward_type", ""))
	level.reward_amount = reward_amount
	return level


## The configuration stores most numbers as strings, but patches add JSON numbers,
## which Godot reads as floats. Returns null when the value is not a whole number.
static func to_int(value: Variant) -> Variant:
	if value is String and value.is_valid_int():
		return value.to_int()
	if (value is float or value is int) and value == floorf(value):
		return int(value)
	return null
