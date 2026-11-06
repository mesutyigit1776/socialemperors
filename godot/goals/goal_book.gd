class_name GoalBook
extends RefCounted
## The goal list of the client (GoalsManager and its goal classes).
##
## Each goal counts the events of its type (VillageEvent) in the current
## session; the save keeps only the completed and rewarded goals. A goal
## counts also while it is not active, but it completes only while it is one
## of the first MAX_ACTIVE goals that are not rewarded. When it completes, the
## player gets its gold at once (Village.reward_goal()), and the next goal
## becomes active; that goal completes at once when its count is already
## enough. The client shows the first SHOWN active goals in its goal box.
##
## The counts of the building goals start again when the map loads, and then
## each building on the map counts as built, as in the client. Some goals take
## their value from the save instead of counting: the population, the land
## areas, the unit packs and the attacks on other players.

signal goal_completed(goal: GameConfig.GoalDef)

const OTHER_PLAYERS_TEXT := "This goal needs other players. The port does not have them yet."
const MAX_ACTIVE := 15
const SHOWN := 2
## The goal types that count minutes and show hours.
const TIME_TYPES: Array[String] = ["select_time_subcatfunc", "select_time_id"]
const BUILD_TYPES: Array[String] = ["built_subcatfunc", "built_id"]
## The types that are not in the port: they need other players or neighbours.
## They stay open, as in a client without these features.
const OTHER_PLAYER_TYPES: Array[String] = ["attack_player", "assaults_won", "help_friend_id", "recruit_market_friend", "assist_neighbour_buildings"]
## A scorpion that destroys a tower counts in all battles, as in the client.
const SCORPION := 520
const SUBCAT_TOWER := 211
## The units that the client selects for a goal that kills enemies: footmen,
## then mounted units, then archers.
const FIGHTER_SUBCATS: Array[int] = [78, 79, 80]

var _village: Village
var _config: GameConfig
var _steps: Dictionary  # Goal id -> count of this session. The owner keeps it when the scene starts again.
var _active: Array[GameConfig.GoalDef] = []
var _updating := false  # The gold of a completed goal is an event too.


## steps: the counts of the session, which the caller keeps; it can be empty.
func _init(village: Village, config: GameConfig, steps: Dictionary) -> void:
	_village = village
	_config = config
	_steps = steps
	_village.happened.connect(record)


## The goals that the player works on now, in order.
func active_goals() -> Array[GameConfig.GoalDef]:
	return _active.duplicate()


## The goals of the goal box.
func shown_goals() -> Array[GameConfig.GoalDef]:
	return _active.slice(0, SHOWN)


func steps_needed(goal: GameConfig.GoalDef) -> int:
	if goal.type in ["complete_quest", "complete_social_id", "complete_social_subcat"]:
		return 1
	var amount: Variant = goal.params.get("ammount", 1)
	return maxi(absi(int(amount)), 1) if amount is int or amount is float else 1


func steps_done(goal: GameConfig.GoalDef) -> int:
	return int(_steps.get(goal.id, 0))


## The progress as the client shows it, for example "1/3". Time goals show hours.
func progress_text(goal: GameConfig.GoalDef) -> String:
	if goal.type in TIME_TYPES:
		return "%d/%d" % [steps_done(goal) / 60, maxi(1, steps_needed(goal) / 60)]
	return "%d/%d" % [mini(steps_done(goal), steps_needed(goal)), steps_needed(goal)]


## The title or description with the name of the host for "#0#". The client
## takes the name for the gender of the player, which the save does not keep.
func text(value: String) -> String:
	return value.replace("#0#", _config.text("TUTORIAL_HOST_NAME_MALE"))


## The client loaded the map: the building goals count the buildings on it.
## Also sets the goals that read the save, and completes the goals whose count
## is already enough. Call it after each load of the village map.
func on_map_loaded() -> bool:
	for goal in _config.goals:
		if goal.type in BUILD_TYPES:
			_steps.erase(goal.id)
	for placed in _village.items:
		var item := _config.get_item(placed.item_id)
		if item != null and not item.is_unit():
			_count(VillageEvent.Kind.BUILT, {"item": item.id})
	_count(VillageEvent.Kind.PACK_BOUGHT, {"amount": 0})
	var rewarded := _village.goal_ids("rewarded").size()
	# The client counts land only when the player buys it. The server
	# completes these goals when it loads a save whose land is enough.
	for goal in _config.goals:
		if goal.type == "own_big_tiles" and _village.owned_land.size() >= steps_needed(goal) and not goal.id in _village.goal_ids("rewarded"):
			_village.reward_goal(goal)
			goal_completed.emit(goal)
	_update()
	return _village.goal_ids("rewarded").size() != rewarded


## Counts the goal events of a battle: a scorpion destroys a tower, and a
## monk converts a unit to the player's side.
func watch_battle(sim: BattleSim) -> void:
	sim.died.connect(func(fighter: BattleFighter, killer: BattleFighter) -> void:
		if killer != null and killer.def.id == SCORPION and fighter.def.subcat_functional == SUBCAT_TOWER:
			record(VillageEvent.Kind.TOWER_KILLED_BY_SCORPION, {}))
	sim.converted.connect(func(_unit: BattleFighter, new_team: BattleFighter.Team) -> void:
		if new_team == BattleFighter.Team.PLAYER:
			record(VillageEvent.Kind.CONVERTED, {}))


## What the "DO IT" button of the client does for the goal, as a dictionary
## with one key: "build" (an item of the build menu), "select" (an item of the
## map), "open" ("quests", "collections", "packs" or "rename"), or "text" (a
## message, for example the client's alert when the item is missing).
func hint(goal: GameConfig.GoalDef) -> Dictionary:
	var p := goal.params
	match goal.type:
		"built_subcatfunc":
			var items := _config.items().filter(func(item: GameConfig.ItemDef) -> bool: return item.subcat_functional == _int(p, "id") and item.is_sold_to(_village.race))
			return {"build": items.front()} if not items.is_empty() else {}
		"built_id":
			return {"build": _config.get_item(_ids(p, "ids")[0])} if not _ids(p, "ids").is_empty() else {}
		"trained_id", "select_time_id", "collected_id", "complete_social_id":
			var ids: Array[int] = _ids(p, "ids")
			if goal.type == "trained_id" or not p.has("ids"):
				ids = [_int(p, "building_id" if goal.type == "trained_id" else "id")]
			var building := _nearest(func(placed: Village.PlacedItem) -> bool: return placed.item_id in ids)
			return {"select": building} if building != null else {"text": _config.text("GOALS_BUILDING_NOT_FOUND").replace("#0#", _config.get_item(ids[0]).name)}
		"subcatfunc_count":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _config.get_item(placed.item_id).trains != 0 and _subcat(_config.get_item(_config.get_item(placed.item_id).trains)) == _int(p, "id"), "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"train_ids_in_id":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return placed.item_id in _ids(p, "ids") and _village.is_own_unit(placed), "GOALS_GENERAL_UNIT_NOT_FOUND")
		"contained_subcatfunc", "contained_id", "sacrifice_unit":
			var subcat := _int(p, "unit_subcat")
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _village.is_own_unit(placed) and (subcat == -1 or _subcat(_config.get_item(placed.item_id)) == subcat), "GOALS_GENERAL_UNIT_NOT_FOUND")
		"pop_unit_subcatfunc":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _subcat(_config.get_item(placed.item_id)) == _int(p, "id") and not _village.units_in(placed).is_empty(), "GOALS_NO_UNITS_IN_BUILDING")
		"collected_subcatfunc", "select_time_subcatfunc", "move_subcatfunc_building", "complete_social_subcat":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _subcat(_config.get_item(placed.item_id)) == _int(p, "id"), "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"store_subcatfuncs":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _has_id(p, "ids", _subcat(_config.get_item(placed.item_id))) and _village.can_store(placed), "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"captured_subcatfunc":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _village.is_wild_animal(placed) and _subcat(_config.get_item(placed.item_id)) == _int(p, "id"), "GOALS_CAPTURED_UNIT_NOT_FOUND")
		"killed_enemy":
			for subcat in FIGHTER_SUBCATS:
				var unit := _nearest(func(placed: Village.PlacedItem) -> bool: return _village.is_own_unit(placed) and _subcat(_config.get_item(placed.item_id)) == subcat)
				if unit != null:
					return {"select": unit}
			return {"text": _config.text("GOALS_GENERAL_UNIT_NOT_FOUND")}
		"market_trade":
			return {"select": _village.market()} if _village.market() != null else {"text": _config.text("GOALS_BUILDING_NOT_FOUND").replace("#0#", _config.get_item(23).name)}
		"repair_building":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return not _config.get_item(placed.item_id).is_unit() and _village.is_damaged(placed), "GOALS_BUILDING_ON_FLAMES_NOT_FOUND")
		"dragons_nest_feed":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Village.DRAGON_NEST, "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"soulmixer_mix_unit":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Village.SOUL_MIXER, "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"heal_units_with_healing_spring":
			return _select_or(func(placed: Village.PlacedItem) -> bool: return _subcat(_config.get_item(placed.item_id)) == Village.SUBCAT_HEALING, "GOALS_GENERAL_BUILDING_NOT_FOUND")
		"complete_quest", "popup_opened_quests":
			return {"open": "quests"}
		"popup_opened_collections":
			return {"open": "collections"} if p.get("name") == "popups.popupCollections" else {"text": OTHER_PLAYERS_TEXT}
		"buy_unit_pack":
			return {"open": "packs"}
		"rename_empire":
			return {"open": "rename"}
		"own_big_tiles":
			return {"text": "Click a land area next to your land to buy it."}
		"zoom":
			return {"text": "Turn the mouse wheel over the map."}
		"double_click":
			return {"text": "Click a unit two times quickly: the units of its kind near it are selected."}
		"use_selection_tool":
			return {"text": "Press the space bar or the Select units button, then drag a box over your units."}
	if goal.type in OTHER_PLAYER_TYPES:
		return {"text": OTHER_PLAYERS_TEXT}
	return {}


func _select_or(test: Callable, missing_text: String) -> Dictionary:
	var found := _nearest(test)
	return {"select": found} if found != null else {"text": _config.text(missing_text)}


## The item nearest to the centre of the map that passes the test, as the client searches.
func _nearest(test: Callable) -> Village.PlacedItem:
	var center := Vector2.ONE * IsoGrid.MAP_TILES / 2.0
	var best: Village.PlacedItem = null
	for placed in _village.items:
		if _config.get_item(placed.item_id) != null and test.call(placed) \
				and (best == null or center.distance_squared_to(Vector2(placed.tile)) < center.distance_squared_to(Vector2(best.tile))):
			best = placed
	return best


## Counts an event for all goals of its type. Most events come from the
## village; the screens send the others.
func record(kind: VillageEvent.Kind, data: Dictionary) -> void:
	_count(kind, data)
	if not _updating:
		_update()


func _count(kind: VillageEvent.Kind, data: Dictionary) -> void:
	for goal in _config.goals:
		var step: Variant = _new_step(goal, kind, data)
		if step != null:
			_steps[goal.id] = step


## The count of the goal after the event, or null when the event does not count for it.
func _new_step(goal: GameConfig.GoalDef, kind: VillageEvent.Kind, data: Dictionary) -> Variant:
	var p := goal.params
	var step := steps_done(goal)
	var item := _item(data, "item")
	var building := _item(data, "building")
	var unit := _item(data, "unit")
	match goal.type:
		"built_subcatfunc":
			return step + 1 if kind == VillageEvent.Kind.BUILT and _subcat(item) == _int(p, "id") else null
		"built_id":
			return step + 1 if kind == VillageEvent.Kind.BUILT and _has_id(p, "ids", data.get("item")) else null
		"subcatfunc_count":
			return step + 1 if kind == VillageEvent.Kind.TRAINED and _subcat(unit) == _int(p, "id") else null
		"trained_id":
			return step + 1 if kind == VillageEvent.Kind.TRAINED and _has_id(p, "ids", data.get("unit")) and data.get("building") == _int(p, "building_id") else null
		"train_ids_in_id":
			return step + 1 if kind == VillageEvent.Kind.TRAINED and data.get("building") == _int(p, "id") else null
		"contained_subcatfunc":
			return step + 1 if kind == VillageEvent.Kind.PUSHED and _subcat(building) == _int(p, "building_subcat") and _subcat(unit) == _int(p, "unit_subcat") else null
		"contained_id":
			return step + 1 if kind == VillageEvent.Kind.PUSHED and _has_id(p, "ids", data.get("building")) and _subcat(unit) == _int(p, "unit_subcat") else null
		"pop_unit_subcatfunc":
			return step + 1 if kind == VillageEvent.Kind.PULLED and _subcat(building) == _int(p, "id") else null
		"collected_subcatfunc":
			return step + 1 if kind == VillageEvent.Kind.COLLECTED and _subcat(item) == _int(p, "id") else null
		"collected_id":
			return step + 1 if kind == VillageEvent.Kind.COLLECTED and _has_id(p, "ids", data.get("item")) else null
		"select_time_subcatfunc":
			return step + int(data["amount"]) if kind == VillageEvent.Kind.TIME_SELECTED and _subcat(building) == _int(p, "id") else null
		"select_time_id":
			return step + int(data["amount"]) if kind == VillageEvent.Kind.TIME_SELECTED and _has_id(p, "ids", data.get("building")) else null
		"captured_subcatfunc":
			return step + 1 if kind == VillageEvent.Kind.CAPTURED and _subcat(unit) == _int(p, "id") else null
		"killed_enemy":
			return step + 1 if kind == VillageEvent.Kind.KILLED and (_int(p, "id") == -1 or data.get("unit") == _int(p, "id")) else null
		"complete_quest":
			return step + 1 if kind == VillageEvent.Kind.QUEST_WON and str(data.get("quest")) == str(p.get("id")) and int(data.get("stars", 0)) >= _int(p, "difficulty") else null
		"store_subcatfuncs":
			return step + 1 if kind == VillageEvent.Kind.STORED and _has_id(p, "ids", _subcat(item)) else null
		"move_subcatfunc_building":
			return step + 1 if kind == VillageEvent.Kind.MOVED and _subcat(item) == _int(p, "id") else null
		"complete_social_id":
			return step + 1 if kind == VillageEvent.Kind.SOCIAL_BUILDING_OPENED and data.get("item") == _int(p, "id") else null
		"complete_social_subcat":
			return step + 1 if kind == VillageEvent.Kind.SOCIAL_BUILDING_OPENED and _subcat(item) == _int(p, "id") else null
		"own_big_tiles":
			return int(data["amount"]) if kind == VillageEvent.Kind.LAND_BOUGHT else null
		"market_trade":
			return _added_amount(goal, kind == VillageEvent.Kind.MARKET_TRADED, data)
		"player_stats_modified":
			return _added_amount(goal, kind == VillageEvent.Kind.RESOURCE_CHANGED, data)
		"popup_opened_collections", "popup_opened_quests":
			return step + 1 if kind == VillageEvent.Kind.WINDOW_OPENED and data.get("window") == p.get("name") else null
		"buy_unit_pack":
			return _village.unit_packs_bought(_ids(p, "ids")) if kind == VillageEvent.Kind.PACK_BOUGHT else null
	var simple := {
		"zoom": VillageEvent.Kind.ZOOMED, "dragons_nest_feed": VillageEvent.Kind.NEST_FED,
		"double_click": VillageEvent.Kind.DOUBLE_CLICKED, "rename_empire": VillageEvent.Kind.RENAMED,
		"soulmixer_mix_unit": VillageEvent.Kind.SOULS_MIXED, "use_selection_tool": VillageEvent.Kind.SELECTION_TOOL_USED,
		"repair_building": VillageEvent.Kind.FIRE_PUT_OUT, "kill_tower_with_scorpion": VillageEvent.Kind.TOWER_KILLED_BY_SCORPION,
		"sacrifice_unit": VillageEvent.Kind.SACRIFICED, "convert_unit": VillageEvent.Kind.CONVERTED,
		"heal_units_with_healing_spring": VillageEvent.Kind.HEALED,
	}
	return step + 1 if simple.get(goal.type, -1) == kind else null


## Market and resource goals add the amounts in the direction of their sign.
func _added_amount(goal: GameConfig.GoalDef, matches: bool, data: Dictionary) -> Variant:
	var wanted := _int(goal.params, "ammount")
	if not matches or data.get("code") != goal.params.get("cost_type") or int(data["amount"]) * signi(wanted) <= 0:
		return null
	return steps_done(goal) + absi(int(data["amount"]))


## Completes the active goals with enough count, then chooses the active goals
## again, as the client's checkAllGoals() does.
##
## The population goals read the population each time: the client sets them
## at each change of the population.
func _update() -> void:
	_updating = true
	for goal in _config.goals:
		if goal.type == "population":
			_steps[goal.id] = _village.population()
	var rewarded := _village.goal_ids("rewarded")
	var completed := _village.goal_ids("completed")
	_active.clear()
	for goal in _config.goals:
		if _active.size() >= MAX_ACTIVE:
			break
		if goal.id in rewarded:
			continue
		if steps_done(goal) >= steps_needed(goal) or goal.id in completed:
			_village.reward_goal(goal)
			goal_completed.emit(goal)
			continue
		_active.append(goal)
	_updating = false


func _item(data: Dictionary, key: String) -> GameConfig.ItemDef:
	return _config.get_item(int(data[key])) if data.get(key) is int else null


static func _subcat(item: GameConfig.ItemDef) -> int:
	return item.subcat_functional if item != null else -1


static func _int(params: Dictionary, key: String) -> int:
	var value: Variant = GameConfig.to_int(params.get(key))
	return value if value != null else -1


static func _ids(params: Dictionary, key: String) -> Array[int]:
	var ids: Array[int] = []
	var list: Variant = params.get(key)
	for value: Variant in list if list is Array else []:
		if GameConfig.to_int(value) != null:
			ids.append(GameConfig.to_int(value))
	return ids


static func _has_id(params: Dictionary, key: String, id: Variant) -> bool:
	return id is int and id in _ids(params, key)
