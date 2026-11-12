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
	var subcategory_id: int  ## The subcategory of the store, for example 11 (Houses) in category 1.
	var display_order: int  ## The order in the store.
	var new_item: bool  ## The store marks the item as new.
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
	var velocity: int  ## Walking speed of a unit, in pixels per frame.
	var attack_range: int  ## Tiles; 1 for units that fight next to the enemy.
	var life: int
	var attack: int  ## Damage of one attack, or healing for healers.
	var defense: int
	var attack_interval: int  ## Frames between two attacks, at 30 frames per second.
	var flying: bool  ## Flying units walk over buildings.
	var elevation: int  ## 0 for flat items, for example roads, on which units can stand.
	var size: int  ## 2 for large units, which keep the tiles around them free in a formation; else 0.
	var breeding_order: int  ## Power of a unit in the Soul Mixer, or 0 when the unit cannot go into it.
	var sm_training_time: int  ## Seconds that the Soul Mixer needs to make this unit.
	var potion: int  ## Potions that bring this unit back from the graveyard.
	var cost_unit_cash: int  ## The Heroes Grave brings a hero back for this value times Village.RESURRECT_GOLD_PER_CASH gold.
	var groups: String  ## The group of a unit, for example "god" or "dragon"; some quests ask for units of a group.
	## Unit packs choose units by these values, see Village.buy_unit_packs():
	## the kind of pack, the category in it and the chance in the category.
	var pack_num: int
	var pack_category: int
	var pack_chance: int

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


const SPELL_LEVELS := 3

## A spell of the spell book ("magics" in the configuration).
class SpellDef:
	var id: int
	var name: String
	var description: String
	var mana: int  ## Mana of one cast. Buying the spell also gives this mana.
	var areas: Array[int] = []  ## Side of the square area in tiles, for spell levels 1 to 3.
	var level: int  ## The player can buy the spell from this level.
	var gold: int  ## Price in gold or in cash.
	var cash: int
	var img_name: String  ## Graphic of the spell, and of its picture in the spell book.
	var target: int  ## The side that the area marks: 0 none, 1 the player, 2 the enemy.


## A goal of the goal list ("goals" of the configuration). See GoalBook.
class GoalDef:
	var id: int
	var type: String  ## For example "built_id"; GoalBook knows the types of the configuration.
	var reward: int  ## Gold.
	var title: String  ## "#0#" in the texts is the name of the host, see GoalBook.text().
	var description: String
	var image: String  ## Pictures in assets/images_new, or "none".
	var character: String
	var params: Dictionary  ## The values of the type, for example {"ids": [38], "ammount": 1}.


class LevelDef:
	var name: String
	var exp_required: int  ## Total experience that the player needs for this level.
	var reward_type: String  ## Resource code, see Village.RESOURCE_KEYS.
	var reward_amount: int


var levels: Array[LevelDef] = []  ## levels[n - 1] is level n.
var start_level_mana_reward: int  ## From this level, each new level also gives mana.
var mana_reward_per_level: int
var townhall_house_limit: Dictionary = {}  ## Town hall item id -> number of houses that it allows.
## The buildings that need workers ("social items"): item id -> [cash for one
## worker, number of workers].
var worker_item_ids: Dictionary = {}
## The prices of land ("expansion_prices"), for a map with 1, 2, ... areas:
## {"coins", "cash", "neighbors"}.
var land_prices: Array[Dictionary] = []
## The unit packs ("unit_packs") as the configuration has them: id, price
## ({"g": gold} or {"c": cash}), store_order (the place in the store, 1 to 8),
## slot_priority, in_store, min_level, max_level, starts_at, duration,
## max_purchable, units_given, pack_num, pack_category, custom.
var unit_packs: Array[Dictionary] = []
var max_packs_per_purchase: int  ## MAX_PACKS_ALLOWED_TO_BUY
var allies_item_ids: Array[int] = []  ## Allies buildings and markets, and the recruitment prize.
var subcategories: Dictionary = {}  ## Store category id -> [[subcategory id, name], ...] in store order.
## Buildings that work only after the player chooses a work time, see Village.WORK_MINUTES.
var variable_collect_ids: Array[int] = []
## The client spawns wild animals at each start until the player has this number
## of each kind for the day, see Village.spawn_animals().
var animals_per_day: int
## The rewards of the login bonus ("daily_bonus"), by day from 1: {"day",
## "reward" (resource code or "u" -> amount or unit id), "img"}.
var daily_bonus: Array[Dictionary] = []
## The first purchase offer (FirstOfferButton and PopupFirstBuy of the client):
## {"cost": cash, "seconds": the time after the first opening, "reward":
## {resource code or "exp": amount}, "units": [3 unit ids]}. Empty when the
## viral icon "FirstOfferButton" is off or the globals have no offer.
var first_offer: Dictionary = {}
## The unit collections of the unit list ("units_collections_categories"), in
## the order of "position": {"id", "name", "units": Array[int], "reward"}.
## "name" is the text of "category_lang_id". The configuration also has a cash
## price for each unit, but the client of 1.4.07 does not sell them.
var unit_collections: Array[Dictionary] = []
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
## Survival: the cash for one more life, and the hours after which a used life comes back.
var survival_life_cash: int
var survival_life_hours: int
## The packets of the Time Machine, in the order of the client: [hours, cash price].
var time_packets: Array[Array] = []
var unlock_skin_cash: int  ## The cash that unlocks a style of the map in the Weather Machine.
## The weekly tournament: its map, its bots ({"id", "name", "picture", "team"}
## with the 20 places of the team), the units that cannot take part, the
## number of dragons, gods and colossi that a team can have, and the texts of
## the formations ([tip, description] text keys).
var tournament_map := ""
var tournament_bots: Array[Dictionary] = []
var tournament_units_not_allowed: Array[int] = []
var tournament_max_complex_units := 0
var tournament_formations: Array[Array] = []
## The campaign quests, see QuestBook and QuestBattle. Quest ids are text, as
## in the configuration and the save.
var quest_order: Array[String] = []  ## The islands in the order in which they open.
var quest_min_levels: Dictionary = {}  ## Quest id -> the level that the island needs.
var quests_always_open: Array[String] = []
var quest_gold: Dictionary = {}  ## Gold key of a quest, for example "QUEST_ISLA_TROLLS_1" -> gold.
var quest_gold_multipliers: Array[float] = []  ## For 1, 2 and 3 stars.
var quest_gold_replayed: float  ## Multiplies the gold when the island already has these stars.
var quest_max_xp: int  ## The experience of one quest is at most this.
var quest_max_xp_god: int  ## The same for the god islands.
var quest_units_back_percent: int  ## The part of the dead units that come back after a quest.
var quest_units_back_boss: int  ## The same after a quest on a boss island.
var quest_units_back_hardcore: int  ## The same after a quest on a hard or god island.
var quest_honour: Array[int] = []  ## For a win with 1, 2 and 3 stars.
var quest_honour_first: Array[int] = []  ## For the first win with these stars.
var quest_honour_lost: int
## Neighbours and the attacks on other players (PvP), see VillageSocial and PvpBattle.
var honour_help_friend: int  ## For 5 assists in one visit.
var honour_pvp_win: int
var honour_pvp_lost: int  ## For each tenth of the loot that the attacker did not take.
var pvp_seconds: int  ## The time of an attack.
var pvp_search_costs: Array[Array] = []  ## [from level, gold], in the order of the levels.
var pvp_max_loot: Array[Array] = []  ## [from level, gold]: the most of each resource that an attack can take.
var pvp_units_back: Array[int] = []  ## The part of the dead units of the attacker that come back, in percent: up to level 9, 10 to 15, from 16.
var pvp_shields: Array[Dictionary] = []  ## {"id", "name", "price", "price_type", "protection_time", "cooldown"}.
## The Allies Market gives allies_market_collect[code] of the resource, and
## allies_market_per_worker[code] more for each hired worker.
var allies_market_collect: Dictionary = {}
var allies_market_per_worker: Dictionary = {}
## The prizes of the Recruitment Prize building: {"id", "units" (Array[int]),
## "recruits", "level"}, in configuration order.
var recruitment_prizes: Array[Dictionary] = []
var spells: Array[SpellDef] = []  ## In configuration order.
## The goals in configuration order. The client sorts them by their order
## value, which is 1 for all of them, and leaves out the goals of order 0.
var goals: Array[GoalDef] = []
## The mana that the player buys: mana_per_purchase for mana_price_gold gold or mana_price_cash cash.
var mana_per_purchase: int
var mana_price_gold: int
var mana_price_cash: int
## A spell gets level 2 and level 3 after this number of casts.
var spell_uses_level2: int
var spell_uses_level3: int
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
		var cost: Variant = to_int(entry.get("worker_cost")) if entry is Dictionary else null
		if id == null or cost == null:
			push_error("Game configuration '%s' has an incorrect social item: %s" % [path, str(entry).left(200)])
			return null
		config.worker_item_ids[id] = [cost, str(entry.get("workers", "")).split(",", false).size()]
	for entry: Variant in data.get("expansion_prices", []):
		var numbers := [to_int(entry.get("coins")), to_int(entry.get("cash")), to_int(entry.get("neighbors"))] if entry is Dictionary else [null]
		if null in numbers:
			push_error("Game configuration '%s' has an incorrect land price: %s" % [path, str(entry).left(200)])
			return null
		config.land_prices.append({"coins": numbers[0], "cash": numbers[1], "neighbors": numbers[2]})
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
	if not _parse_quest_globals(config, globals):
		push_error("Game configuration '%s' has no correct quest settings in globals (ISLE_ORDER, QUEST_GOLD_REWARD, HONOR_POINT_QUEST and others)." % path)
		return null
	if not _parse_social(config, data, globals):
		push_error("Game configuration '%s' has no correct neighbour or PvP settings (HONOR_POINT_HELP_FRIEND, PVP_SEARCH_ENEMY_COST, pvp_shields and others)." % path)
		return null
	var survival := [to_int(globals.get("SURVIVAL_BUY_LIVE_CASH")), to_int(globals.get("SURVIVAL_HOURS_LIVE_REGENERATE"))]
	if null in survival:
		push_error("Game configuration '%s' has no SURVIVAL_BUY_LIVE_CASH or SURVIVAL_HOURS_LIVE_REGENERATE in globals." % path)
		return null
	config.survival_life_cash = survival[0]
	config.survival_life_hours = survival[1]
	if not _parse_time_packets(config, globals.get("TIME_MACHINE")) or to_int(globals.get("COST_UNLOCK_SKIN")) == null:
		push_error("Game configuration '%s' has no correct TIME_MACHINE or COST_UNLOCK_SKIN in globals." % path)
		return null
	config.unlock_skin_cash = to_int(globals["COST_UNLOCK_SKIN"])
	if not _parse_tournament(config, data, globals):
		push_error("Game configuration '%s' has no correct weekly tournament (tournament_type, tournament_formations, TOURNAMENT_UNITS_NOT_ALLOWED)." % path)
		return null
	if not _parse_spells(config, data.get("magics"), globals):
		push_error("Game configuration '%s' has no correct spells (magics) or mana settings in globals." % path)
		return null
	for entry: Variant in data.get("daily_bonus", []):
		if entry is Dictionary and to_int(entry.get("reward_day")) != null and entry.get("reward") is Dictionary:
			config.daily_bonus.append({"day": to_int(entry["reward_day"]), "reward": entry["reward"], "img": str(entry.get("img", ""))})
	config.daily_bonus.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["day"] < b["day"])
	config.first_offer = _parse_first_offer(data.get("viral_icons"), globals)
	config.unit_packs.assign(data.get("unit_packs", []).filter(func(pack: Variant) -> bool:
		return pack is Dictionary and pack.get("price") is Dictionary and pack.get("pack_num") is Dictionary and pack.get("pack_category") is Dictionary \
				and [pack.get("id"), pack.get("store_order"), pack.get("units_given"), pack.get("max_purchable")].all(func(value: Variant) -> bool: return to_int(value) != null)))
	config.max_packs_per_purchase = maxi(int(to_int(globals.get("MAX_PACKS_ALLOWED_TO_BUY")) if to_int(globals.get("MAX_PACKS_ALLOWED_TO_BUY")) != null else 1), 1)
	if not _parse_goals(config, data.get("goals")):
		push_error("Game configuration '%s' has no correct goal list (goals)." % path)
		return null
	var texts_by_id := {}
	for entry: Variant in data.get("localization_strings", []):
		if entry is Dictionary and entry.get("name") is String:
			config._texts[entry["name"]] = str(entry.get("text", ""))
			texts_by_id[to_int(entry.get("id"))] = str(entry.get("text", ""))
	config.unit_collections = _parse_unit_collections(data.get("units_collections_categories"), texts_by_id)
	var categories: Variant = data.get("categories", {})
	if categories is Dictionary:
		for entry: Variant in categories.values():
			if entry is Dictionary and to_int(entry.get("id")) != null:
				var subs: Array = []
				for sub: Variant in entry.get("sub", []) if entry.get("sub") is Array else []:
					if sub is Dictionary and to_int(sub.get("id")) != null:
						subs.append([to_int(sub["id"]), str(sub.get("name", ""))])
				config.subcategories[to_int(entry["id"])] = subs
	return config


func get_item(id: int) -> ItemDef:
	return _items.get(id)


## The spell with this id, or null.
func get_spell(id: int) -> SpellDef:
	for spell in spells:
		if spell.id == id:
			return spell
	return null


## The level of a spell that the player cast this number of times: 1 to SPELL_LEVELS.
func spell_level(uses: int) -> int:
	if uses >= spell_uses_level3:
		return 3
	return 2 if uses >= spell_uses_level2 else 1


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
	for key: String in ["id", "width", "height", "category_id", "in_store", "subcat_functional", "subcategory_id", "display_order", "new_item", "cost", "xp", "min_level", "max_frame", "collect", "collect_xp", "population", "store_level", "unit_capacity", "trains", "units_limit", "training_time", "velocity", "attack_range", "life", "attack", "defense", "attack_interval", "flying", "elevation", "size", "breeding_order", "sm_training_time", "potion", "cost_unit_cash"]:
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
	item.groups = str(entry.get("groups", ""))
	item.width = numbers["width"]
	item.height = numbers["height"]
	item.category_id = numbers["category_id"]
	item.in_store = numbers["in_store"]
	item.subcat_functional = numbers["subcat_functional"]
	item.subcategory_id = numbers["subcategory_id"]
	item.display_order = numbers["display_order"]
	item.new_item = numbers["new_item"] == 1
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
	item.life = numbers["life"]
	item.attack = numbers["attack"]
	item.defense = numbers["defense"]
	item.attack_interval = numbers["attack_interval"]
	item.flying = numbers["flying"] == 1
	item.elevation = numbers["elevation"]
	item.size = numbers["size"]
	item.breeding_order = numbers["breeding_order"]
	item.sm_training_time = numbers["sm_training_time"]
	item.potion = numbers["potion"]
	item.cost_unit_cash = numbers["cost_unit_cash"]
	# Most items do not have these values, or have them empty.
	for key: String in ["pack_num", "pack_category", "pack_chance"]:
		var value: Variant = to_int(entry.get(key))
		item.set(key, value if value != null else 0)
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


## Reads the first weekly tournament of tournament_type and the tournament
## settings. Returns false when one is missing or not correct.
static func _parse_tournament(config: GameConfig, data: Dictionary, globals: Dictionary) -> bool:
	var types: Variant = data.get("tournament_type")
	var formations: Variant = data.get("tournament_formations")
	var not_allowed: Variant = globals.get("TOURNAMENT_UNITS_NOT_ALLOWED")
	var complex: Variant = to_int(globals.get("TOURNAMENT_MAX_NUMBER_COMPLEX_UNITS"))
	if not (types is Dictionary and formations is Array and not_allowed is Array) or complex == null:
		return false
	config.tournament_max_complex_units = complex
	for id: Variant in not_allowed:
		if to_int(id) == null:
			return false
		config.tournament_units_not_allowed.append(to_int(id))
	for formation: Variant in formations:
		if not formation is Dictionary:
			return false
		config.tournament_formations.append([str(formation.get("tip", "")), str(formation.get("description", ""))])
	var keys: Array = types.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(str(a)) < int(str(b)))
	for key: Variant in keys:
		var type: Variant = types[key]
		if not type is Dictionary or to_int(type.get("weekly_tournaments", 0)) < 1 or not type.get("weekly_opponent") is Dictionary:
			continue
		config.tournament_map = str(to_int(type.get("map_id")))
		var bot_ids: Array = type["weekly_opponent"].keys()
		bot_ids.sort()
		for bot_id: Variant in bot_ids:
			var bot: Variant = type["weekly_opponent"][bot_id]
			var team: Array[int] = []
			for id: Variant in bot.get("team", []) if bot is Dictionary else []:
				if to_int(id) == null:
					return false
				team.append(to_int(id))
			if team.is_empty():
				return false
			config.tournament_bots.append({"id": str(bot_id), "name": str(bot.get("user_name", "")), "picture": str(bot.get("picture", "")), "team": team})
		return true
	return false


## Reads the globals of the campaign quests. The server adds some of them with
## the patch config/patch/1-mega_patch.json. Returns false when one is missing
## or not correct.
static func _parse_social(config: GameConfig, data: Dictionary, globals: Dictionary) -> bool:
	var numbers := [to_int(globals.get("HONOR_POINT_HELP_FRIEND")), to_int(globals.get("HONOR_POINT_PVP_WIN_ATTACK")), to_int(globals.get("HONOR_POINT_PVP_LOSE_ATTACK")),
			to_int(globals.get("PVP_TIMER_SECONDS")), to_int(globals.get("PERCENT_UNITS_RECOVERED_ATTACKER_L9")),
			to_int(globals.get("PERCENT_UNITS_RECOVERED_ATTACKER_L10_L15")), to_int(globals.get("PERCENT_UNITS_RECOVERED_ATTACKER_L16"))]
	if null in numbers:
		return false
	config.honour_help_friend = numbers[0]
	config.honour_pvp_win = numbers[1]
	config.honour_pvp_lost = numbers[2]
	config.pvp_seconds = numbers[3]
	config.pvp_units_back.assign(numbers.slice(4))
	for pair: Array in [[config.pvp_search_costs, "PVP_SEARCH_ENEMY_COST"], [config.pvp_max_loot, "PVP_MAX_RESOURCES"]]:
		var table: Variant = globals.get(pair[1])
		if not table is Dictionary:
			return false
		for key: Variant in table:
			var gold: Variant = to_int(table[key].get("g")) if table[key] is Dictionary else null
			if to_int(key) == null or gold == null:
				return false
			pair[0].append([to_int(key), gold])
		pair[0].sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair: Array in [[config.allies_market_collect, "ALLIES_MARKET_INITIAL_COLLECT"], [config.allies_market_per_worker, "ALLIES_MARKET_INCREMENTAL_COLLECT"]]:
		var table: Variant = globals.get(pair[1])
		if not table is Dictionary:
			return false
		for code: Variant in table:
			if to_int(table[code]) == null:
				return false
			pair[0][str(code)] = to_int(table[code])
	var prizes: Variant = data.get("recruitment_prices")
	if not prizes is Array:
		return false
	for entry: Variant in prizes:
		var values := [to_int(entry.get("id")), to_int(entry.get("num_recruitments")), to_int(entry.get("unlock_level"))] if entry is Dictionary else [null]
		if null in values:
			return false
		var units: Array[int] = []
		for id in str(entry.get("units", "")).split(",", false):
			if to_int(id) == null:
				return false
			units.append(to_int(id))
		config.recruitment_prizes.append({"id": values[0], "units": units, "recruits": values[1], "level": values[2]})
	var shields: Variant = data.get("pvp_shields")
	if not shields is Array:
		return false
	for entry: Variant in shields:
		var values := [to_int(entry.get("id")), to_int(entry.get("price")), to_int(entry.get("protection_time")), to_int(entry.get("cooldown"))] if entry is Dictionary else [null]
		if null in values:
			return false
		config.pvp_shields.append({"id": values[0], "name": str(entry.get("name", "")), "price": values[1], "price_type": str(entry.get("price_type")), "protection_time": values[2], "cooldown": values[3]})
	return true


## The value of a table of PVP_SEARCH_ENEMY_COST or PVP_MAX_RESOURCES for the
## level: the entry of the highest "from level" that the level reaches.
static func value_for_level(table: Array[Array], level: int) -> int:
	var value := 0
	for entry in table:
		if level < entry[0]:
			break
		value = entry[1]
	return value


static func _parse_quest_globals(config: GameConfig, globals: Dictionary) -> bool:
	for pair: Array in [[config.quest_order, "ISLE_ORDER"], [config.quests_always_open, "UNLOCKED_FOREVER_QUESTS"]]:
		var ids: Variant = globals.get(pair[1])
		if not ids is Array:
			return false
		for id: Variant in ids:
			if to_int(id) == null:
				return false
			pair[0].append(str(to_int(id)))
	var min_levels: Variant = globals.get("QUESTS_MIN_LEVELS")
	var gold: Variant = globals.get("QUEST_GOLD_REWARD")
	if not (min_levels is Dictionary and gold is Dictionary):
		return false
	for id: Variant in min_levels:
		if to_int(min_levels[id]) == null:
			return false
		config.quest_min_levels[str(id)] = to_int(min_levels[id])
	for key: Variant in gold:
		var amount: Variant = to_int(gold[key].get("g")) if gold[key] is Dictionary else null
		if amount == null:
			return false
		config.quest_gold[str(key)] = amount
	var multipliers: Variant = globals.get("QUEST_GOLD_REWARD_MULTYPLIERS")
	var honour: Variant = globals.get("HONOR_POINT_QUEST")
	var honour_first: Variant = globals.get("HONOR_POINT_QUEST_FIRST_TIME")
	if not (multipliers is Array and honour is Array and honour_first is Array):
		return false
	for value: Variant in multipliers:
		if not (value is float or value is int or (value is String and value.is_valid_float())):
			return false
		config.quest_gold_multipliers.append(float(value))
	for pair: Array in [[config.quest_honour, honour], [config.quest_honour_first, honour_first]]:
		for value: Variant in pair[1]:
			if to_int(value) == null:
				return false
			pair[0].append(to_int(value))
	var replayed: Variant = globals.get("QUEST_GOLD_REWARD_REPLAYED")
	var numbers := [to_int(globals.get("MAX_XP_QUEST")), to_int(globals.get("PERCENT_UNITS_RECOVERED_ISLE")), to_int(globals.get("HONOR_POINT_QUEST_LOSE")),
			to_int(globals.get("MAX_XP_GOD_QUEST")), to_int(globals.get("PERCENT_UNITS_RECOVERED_BOSS")), to_int(globals.get("PERCENT_UNITS_RECOVERED_HARDCORE_ISLAND"))]
	if null in numbers or not (replayed is float or replayed is int or (replayed is String and replayed.is_valid_float())):
		return false
	config.quest_gold_replayed = float(replayed)
	config.quest_max_xp = numbers[0]
	config.quest_units_back_percent = numbers[1]
	config.quest_honour_lost = numbers[2]
	config.quest_max_xp_god = numbers[3]
	config.quest_units_back_boss = numbers[4]
	config.quest_units_back_hardcore = numbers[5]
	return config.quest_gold_multipliers.size() == QuestBook.MAX_STARS and config.quest_honour.size() == QuestBook.MAX_STARS and config.quest_honour_first.size() == QuestBook.MAX_STARS


## Reads the spells and the mana globals. Returns false when one is missing or not correct.
static func _parse_spells(config: GameConfig, entries: Variant, globals: Dictionary) -> bool:
	var numbers := [to_int(globals.get("MANA_PER_PURCHASE")), to_int(globals.get("COST_MANA_GOLD")), to_int(globals.get("COST_MANA_CASH")), to_int(globals.get("NUM_SPELL_USES_LVL2")), to_int(globals.get("NUM_SPELL_USES_LVL3"))]
	if null in numbers or not entries is Array:
		return false
	config.mana_per_purchase = numbers[0]
	config.mana_price_gold = numbers[1]
	config.mana_price_cash = numbers[2]
	config.spell_uses_level2 = numbers[3]
	config.spell_uses_level3 = numbers[4]
	for entry: Variant in entries:
		if not entry is Dictionary:
			return false
		var values := [to_int(entry.get("id")), to_int(entry.get("mana")), to_int(entry.get("level")), to_int(entry.get("gold")), to_int(entry.get("cash")), to_int(entry.get("target"))]
		# The configuration stores the areas as JSON text, for example "[5,7,9]".
		var areas: Variant = JSON.parse_string(str(entry.get("area", "")))
		if null in values or not areas is Array or areas.size() != SPELL_LEVELS:
			return false
		var spell := SpellDef.new()
		for area: Variant in areas:
			if to_int(area) == null or to_int(area) < 1:
				return false
			spell.areas.append(to_int(area))
		spell.id = values[0]
		spell.mana = values[1]
		spell.level = values[2]
		spell.gold = values[3]
		spell.cash = values[4]
		spell.target = values[5]
		spell.name = str(entry.get("name", ""))
		spell.description = str(entry.get("description", ""))
		spell.img_name = str(entry.get("img_name", ""))
		config.spells.append(spell)
	return not config.spells.is_empty()


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
static func _parse_time_packets(config: GameConfig, packets: Variant) -> bool:
	if not packets is Array or packets.is_empty():
		return false
	for packet: Variant in packets:
		var hours: Variant = packet.get("hours") if packet is Dictionary else null
		var price: Variant = to_int(packet.get("price")) if packet is Dictionary else null
		if not (hours is float or hours is int) or hours <= 0 or price == null:
			return false
		config.time_packets.append([float(hours), price])
	return true


static func _parse_goals(config: GameConfig, entries: Variant) -> bool:
	if not entries is Array:
		return false
	for entry: Variant in entries:
		if not entry is Dictionary:
			return false
		var numbers := [to_int(entry.get("id")), to_int(entry.get("orders")), to_int(entry.get("reward"))]
		var params: Variant = JSON.parse_string(str(entry.get("params", "{}")))
		if null in numbers or not params is Dictionary:
			return false
		if numbers[1] == 0:
			continue
		var goal := GoalDef.new()
		goal.id = numbers[0]
		goal.reward = numbers[2]
		goal.type = str(entry.get("types", ""))
		goal.title = str(entry.get("title", ""))
		goal.description = str(entry.get("description", ""))
		goal.image = str(entry.get("image", "none"))
		goal.character = str(entry.get("characters", "none"))
		goal.params = params
		config.goals.append(goal)
	return true


static func _parse_first_offer(icons: Variant, globals: Dictionary) -> Dictionary:
	var active := false
	for icon: Variant in icons if icons is Array else []:
		if icon is Dictionary and icon.get("asclass") == "FirstOfferButton" and to_int(icon.get("active")) == 1:
			active = true
	var reward: Variant = globals.get("POPUP_FIRST_PURCHASE_OFFER_REWARD")
	var cost: Variant = to_int(globals.get("POPUP_FIRST_PURCHASE_OFFER_COST"))
	var seconds: Variant = to_int(globals.get("POPUP_FIRST_PURCHASE_OFFER_TIME"))
	if not active or not reward is Dictionary or not reward.get("units") is Array or cost == null or seconds == null:
		return {}
	var offer := {"cost": cost, "seconds": seconds, "reward": {}, "units": []}
	for key: String in reward:
		if key == "units":
			for id: Variant in reward["units"]:
				if to_int(id) != null:
					offer["units"].append(to_int(id))
		elif to_int(reward[key]) != null:
			offer["reward"][key] = to_int(reward[key])
	return offer


## Leaves out the groups with values that are not correct.
static func _parse_unit_collections(groups: Variant, texts_by_id: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var config_groups: Array = groups.values() if groups is Dictionary else groups if groups is Array else []
	for group: Variant in config_groups:
		if not group is Dictionary or not group.get("units") is Array:
			continue
		var numbers := [to_int(group.get("category_id")), to_int(group.get("rewards")), to_int(group.get("position")), to_int(group.get("category_lang_id"))]
		var units: Array[int] = []
		for id: Variant in group["units"]:
			units.append(to_int(id) if to_int(id) != null else -1)
		if null in numbers or -1 in units or units.is_empty():
			continue
		result.append({"id": numbers[0], "reward": numbers[1], "position": numbers[2], "name": texts_by_id.get(numbers[3], ""), "units": units})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["position"] < b["position"])
	return result


static func to_int(value: Variant) -> Variant:
	if value is String and value.is_valid_int():
		return value.to_int()
	if (value is float or value is int) and value == floorf(value):
		return int(value)
	return null
