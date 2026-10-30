extends SceneTree
## Checks the village rules, the store and the save format without a window.
##
##   godot --headless --path godot --script res://checks/village_check.gd -- --data <data folder>
##
## It needs config.json, shop.json and villages/initial.json from an import of
## the unchanged socialemperors files: the tiles and the expected values below
## come from them. It writes its files to user://checks/. The exit code is the number
## of failed checks.

const YELLOW_TREE := 100  # 225 gold, 23 XP
const BLUE_TREE := 101  # needs level 2
const GREEN_TREE := 108  # 60 gold, 6 XP
const HOUSE := 1
const BATHS := 230
const TOWER := 29
const MARKET := 23
const MARKET_III := 189
const GOLD_MINE_I := 13
const GOLD_MINE_II := 14
const SHEEP_RANCH_I := 11
const SHEEP_RANCH_II := 190
const NURSERY := 226
const ALLIES_BUILDING := 234
const ROUND_TABLE := 389
const PUMPKIN_CROP := 8  # farm: 32.4 s, 25 food for 8 wood, 2 XP
const VILLAGER := 500
const SHEEP := 505
## Free tiles in land area 12 for the units of the fixtures, away from the
## first tiles where _buy_free puts buildings.
const UNIT_TILES: Array[Vector2i] = [Vector2i(21, 58), Vector2i(22, 58), Vector2i(23, 58), Vector2i(24, 58), Vector2i(25, 58)]
const RESTAURANT := 232  # collect building: 8 h, 570 gold
const CHICHEN_ITZA := 52  # wonder without population: 6 h, 600 gold
const SAINT_BASIL := 261  # wonder that does not produce
const DRAGONS_STATUE := 1456  # decoration that the store shows from level 20
const DIAMOND_CASTLE := 1234  # only for gold members
const CASH_WONDER := 1299  # in the "New" category, not in the rotation
const COW_RANCH := 12
const KNIGHT := 512
const GOLD_DEPOSIT := 73  # 10 gold, times 3 at level 20
const GOLD_REGROWTH := 80  # grows into a gold deposit after 3 hours
const TOWN_HALL := 26  # trains villagers: 50 food, 5 seconds, 5 XP
const CHURCH := 24  # trains healers; a map can have 5
const HEALER := 502
const BLACKSMITH := 22
const SPEARMAN := 509  # 30 gold
const HIGHEST_LEVEL_XP := 2016089205
const TOWN_HALL_TILE := Vector2i(52, 52)
const TREE_TILE := Vector2i(50, 58)
const KNIGHT_TILE := Vector2i(50, 44)
const HOUSE_TILE := Vector2i(44, 50)
const TOWER_TILE := Vector2i(51, 47)

var _config: GameConfig
var _data_dir: String
var _initial: Dictionary
var _failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--data")
	if index < 0 or index + 1 >= args.size():
		push_error("Give the data folder: -- --data <folder>")
		quit(1)
		return
	var data_dir := args[index + 1]
	_data_dir = data_dir
	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	var initial: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join("villages/initial.json")))
	if _config == null or not initial is Dictionary:
		push_error("Cannot read the imported data in '%s'." % data_dir)
		quit(1)
		return
	_initial = initial
	DirAccess.make_dir_recursive_absolute("user://checks")

	# A script error stops only the function in which it occurs, so a scenario
	# that does not return true has stopped before its end.
	for scenario: Callable in [_check_placement_and_save, _check_several_levels, _check_mana_reward, _check_highest_level, _check_construction_limits, _check_move_and_sell, _check_rotation, _check_production, _check_hurry, _check_store, _check_units, _check_training]:
		_check(scenario.call() == true, "%s runs to its end" % scenario.get_method())
	print("%d failed" % _failures if _failures > 0 else "all passed")
	quit(_failures)


## The placement rules in order, then the save that the purchases wrote.
func _check_placement_and_save() -> bool:
	var path := _write_fixture("placement", 1, 4, 500)
	var before := FileAccess.get_file_as_string(path)
	var village := Village.load_from_file(path, _config)
	_buy(village, BLUE_TREE, Vector2i(55, 48), Village.Placement.LEVEL_TOO_LOW)
	_buy(village, GREEN_TREE, Vector2i(52, 52), Village.Placement.OCCUPIED)  # town hall
	_buy(village, GREEN_TREE, Vector2i(55, 60), Village.Placement.NOT_OWNED_LAND)
	_buy(village, GREEN_TREE, Vector2i(-1, 50), Village.Placement.OUTSIDE_MAP)
	_buy(village, YELLOW_TREE, Vector2i(53, 46), Village.Placement.OK)
	_expect("after the yellow tree", village, {"level": 1, "xp": 27, "g": 275, "w": 850})
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	# 33 XP reaches level 2 (29 XP), which gives 50 wood.
	_expect("after the green tree", village, {"level": 2, "xp": 33, "g": 215, "w": 900})
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OCCUPIED)
	_buy(village, YELLOW_TREE, Vector2i(57, 46), Village.Placement.NOT_ENOUGH_RESOURCES)
	_expect("after the failed purchases", village, {"level": 2, "xp": 33, "g": 215, "w": 900})

	_check(village.save_to_file(path) == OK, "the village saves")
	_check(FileAccess.get_file_as_string(path + ".bak") == before, "the .bak file contains the previous save")
	var text := FileAccess.get_file_as_string(path)
	_check(RegEx.create_from_string("[0-9]\\.0[^0-9]").search(text) == null, "the save has no whole numbers written as decimals")
	var saved: Dictionary = JSON.parse_string(text)
	var expected: Dictionary = JSON.parse_string(before)
	var expected_map: Dictionary = expected["maps"][0]
	expected_map.merge({"level": 2, "xp": 33, "coins": 215, "wood": 900}, true)
	var saved_items: Array = saved["maps"][0]["items"]
	var new_items := saved_items.slice(saved_items.size() - 2)
	for i in 2:
		var entry: Array = new_items[i]
		_check(entry.size() == 8 and entry[4] is float and entry[4] > 0, "new item %d has the server entry format" % i)
		# The timestamp is the time of the purchase.
		entry[4] = 0.0
	expected_map["items"].append_array([[YELLOW_TREE, 53, 46, 0, 0, 0, [], {}], [GREEN_TREE, 56, 47, 0, 0, 0, [], {}]])
	# JSON reads every number as a float, so compare two parsed documents.
	expected = JSON.parse_string(JSON.stringify(expected))
	_check(saved == expected, "the save changes only the resources, the XP, the level and the new items")
	_check(_keys(text) == _keys(before), "the save keeps the key order")
	var reloaded := Village.load_from_file(path, _config)
	_check(reloaded != null and reloaded.get_level() == 2 and reloaded.items.size() == village.items.size(), "the saved village loads again")
	return true


## One purchase can reach more than one level. Each level gives its own reward.
func _check_several_levels() -> bool:
	var village := Village.load_from_file(_write_fixture("levels", 1, 95, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	# 101 XP: level 2 (+50 wood), level 3 (+50 food), level 4 (+400 wood). Level 5 needs 200.
	_expect("after several levels", village, {"level": 4, "xp": 101, "w": 1300, "f": 750, "c": 20})
	return true


## From level 36, a new level also gives 2 mana.
func _check_mana_reward() -> bool:
	var village := Village.load_from_file(_write_fixture("mana", 35, 80150 - 6, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	_expect("after level 36", village, {"level": 36, "c": 21, "m": 2})
	return true


func _check_highest_level() -> bool:
	var village := Village.load_from_file(_write_fixture("highest", 100, 2016089205, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	_expect("at the highest level", village, {"level": 100, "xp": 2016089211, "c": 20, "m": 0})
	return true


## The initial village has a town hall that allows 14 houses, 2 houses, 2 towers
## and one land area (13). This check also gives it land area 12, so that the
## limit of towers in one land area is different from the total limit (20).
func _check_construction_limits() -> bool:
	var plenty := {"wood": 1000000, "stone": 1000000, "food": 1000000, "expansions": [13, 12]}
	var path := _write_fixture("limits", 100, HIGHEST_LEVEL_XP, 1000000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_13 := Rect2i(40, 40, 20, 20)
	var area_12 := Rect2i(20, 40, 20, 20)

	_buy_free(village, MARKET, area_13, Village.Placement.OK)
	_buy_free(village, MARKET_III, area_13, Village.Placement.MAX_COUNT_REACHED)  # one market of any level
	_buy_free(village, GOLD_MINE_I, area_13, Village.Placement.OK)
	_buy_free(village, GOLD_MINE_I, area_13, Village.Placement.MAX_COUNT_REACHED)
	_buy_free(village, GOLD_MINE_II, area_13, Village.Placement.OK)  # each mine level is a different item
	_buy_free(village, SHEEP_RANCH_I, area_12, Village.Placement.OK)
	_buy_free(village, SHEEP_RANCH_II, area_12, Village.Placement.MAX_COUNT_REACHED)  # one sheep ranch of any level
	for i in 3:
		_buy_free(village, NURSERY, area_12, Village.Placement.OK)
	_buy_free(village, NURSERY, area_12, Village.Placement.MAX_COUNT_REACHED)
	_check(village.check_limits(_config.get_item(NURSERY)) == Village.Placement.MAX_COUNT_REACHED, "the store limit check without a location")

	for i in 12:
		_buy_free(village, HOUSE, area_12, Village.Placement.OK)
	_buy_free(village, HOUSE, area_12, Village.Placement.HOUSE_LIMIT_REACHED)
	_buy_free(village, BATHS, area_12, Village.Placement.OK)  # the baths do not count as a house

	for i in 8:
		_buy_free(village, TOWER, area_13, Village.Placement.OK)
	_buy_free(village, TOWER, area_13, Village.Placement.LAND_AREA_TOWER_LIMIT_REACHED)
	_check(village.check_limits(_config.get_item(TOWER)) == Village.Placement.OK, "towers are possible in another land area")
	for i in 10:
		_buy_free(village, TOWER, area_12, Village.Placement.OK)
	_buy_free(village, TOWER, area_12, Village.Placement.TOWER_LIMIT_REACHED)

	# The workers that the server "buy" gives when it does not know the player.
	_buy_free(village, ALLIES_BUILDING, area_12, Village.Placement.OK)
	_buy_free(village, ROUND_TABLE, area_12, Village.Placement.OK)
	_check(village.save_to_file(path) == OK, "the village with the limits saves")
	var attributes := {}
	for entry: Array in JSON.parse_string(FileAccess.get_file_as_string(path))["maps"][0]["items"]:
		attributes[int(entry[0])] = entry[7]
	_check(attributes[MARKET] == {"si": ["0"]}, "a new market has the player's villager as worker")
	_check(attributes[ALLIES_BUILDING] == {"si": []}, "a new allies building has no workers")
	_check(attributes[ROUND_TABLE] == {"si": [], "sif": {}}, "a new round table has no workers")
	_check(attributes[GOLD_MINE_II] == {}, "a building without workers has no attributes")
	return true


## Moving and selling: which items the player can move or sell, the location
## and limit checks of a move, and the amounts that a sale gives back.
func _check_move_and_sell() -> bool:
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12]}
	var path := _write_fixture("move_sell", 100, HIGHEST_LEVEL_XP, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_13 := Rect2i(40, 40, 20, 20)
	var area_12 := Rect2i(20, 40, 20, 20)

	var town_hall := village.item_at(TOWN_HALL_TILE)
	_check(village.can_move(town_hall) and not village.can_sell(town_hall), "the town hall can move but cannot be sold")
	_check(village.sell(town_hall) == Village.Placement.NOT_ALLOWED, "selling the town hall is not allowed")
	var tree := village.item_at(TREE_TILE)
	_check(village.move(tree, Vector2i(41, 41)) == Village.Placement.NOT_ALLOWED, "a tree cannot move")
	_check(village.sell(tree) == Village.Placement.NOT_ALLOWED, "a tree cannot be sold")
	var knight := village.item_at(KNIGHT_TILE)
	_check(village.move(knight, Vector2i(41, 41)) == Village.Placement.NOT_ALLOWED, "a unit cannot move with the move tool")

	var house := village.item_at(HOUSE_TILE)
	_check(village.move(house, HOUSE_TILE) == Village.Placement.OK, "an item does not block its own location")
	_check(village.move(house, TOWN_HALL_TILE) == Village.Placement.OCCUPIED, "an item cannot move onto another item")
	_check(village.move(house, Vector2i(55, 65)) == Village.Placement.NOT_OWNED_LAND, "an item cannot move to land that is not owned")
	_check(house.tile == HOUSE_TILE, "a failed move does not change the item")

	# Area 13 has 2 towers. 8 more fill it; a tower in it can still move inside it.
	for i in 8:
		_buy_free(village, TOWER, area_13, Village.Placement.OK)
	_buy_free(village, TOWER, area_12, Village.Placement.OK)
	var tower_12: Village.PlacedItem = village.items.back()
	var tower_13 := village.item_at(TOWER_TILE)
	var free_13 := _free_tile(village, TOWER, area_13)
	_check(village.move(tower_12, free_13) == Village.Placement.LAND_AREA_TOWER_LIMIT_REACHED, "a tower cannot move into a full land area")
	_check(village.move(tower_13, free_13) == Village.Placement.OK, "a tower can move inside its full land area")
	_check(village.item_at(TOWER_TILE) == null and village.item_at(free_13) == tower_13, "the moved tower is only at its new tile")

	var wood := village.get_resource("w")
	_check(village.sell(house) == Village.Placement.OK, "a house can be sold")
	_expect("after selling a house (30 wood)", village, {"w": wood + 1})
	_check(village.check_location(_config.get_item(GREEN_TREE), HOUSE_TILE) == Village.Placement.OK, "the tile of a sold item is free")
	_buy_free(village, MARKET, area_12, Village.Placement.OK)
	wood = village.get_resource("w")
	_check(village.sell(village.items.back()) == Village.Placement.OK, "a market can be sold")
	_expect("after selling a market (350 wood)", village, {"w": wood + 17})
	_buy_free(village, BATHS, area_12, Village.Placement.OK)
	var cash := village.get_resource("c")
	_check(village.sell(village.items.back()) == Village.Placement.OK, "the baths can be sold")
	_expect("after selling the baths (6 cash)", village, {"c": cash})

	_check(village.save_to_file(path) == OK, "the village after moves and sales saves")
	var saved: Array = JSON.parse_string(FileAccess.get_file_as_string(path))["maps"][0]["items"]
	var at := func(id: int, tile: Vector2i) -> int:
		return saved.filter(func(entry: Array) -> bool: return int(entry[0]) == id and Vector2i(int(entry[1]), int(entry[2])) == tile).size()
	_check(at.call(TOWER, free_13) == 1 and at.call(TOWER, TOWER_TILE) == 0, "the save has the tower at its new tile")
	_check(at.call(HOUSE, HOUSE_TILE) == 0 and saved.size() == village.items.size(), "the save does not have the sold items")
	return true


## Turning: which items can turn, the direction of new and moved items, and the save.
func _check_rotation() -> bool:
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000}
	var path := _write_fixture("rotation", 100, HIGHEST_LEVEL_XP, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_13 := Rect2i(40, 40, 20, 20)

	var town_hall := village.item_at(TOWN_HALL_TILE)
	_check(village.rotate(town_hall) == Village.Placement.OK and town_hall.frame == 1, "the town hall turns to its second direction")
	_check(village.rotate(town_hall) == Village.Placement.OK and town_hall.frame == 0, "the town hall turns back to its first direction")
	_check(village.rotate(village.item_at(TREE_TILE)) == Village.Placement.NOT_ALLOWED, "a tree cannot turn")
	_check(village.rotate(village.item_at(KNIGHT_TILE)) == Village.Placement.NOT_ALLOWED, "a unit cannot turn with the turn tool")

	var house := village.item_at(HOUSE_TILE)
	_check(village.rotate(house) == Village.Placement.OK, "a house turns")
	var tower := village.item_at(TOWER_TILE)
	var free := _free_tile(village, TOWER, area_13)
	_check(village.move(tower, free, 1) == Village.Placement.OK and tower.frame == 1, "a moved item gets the direction of the move")
	_check(village.move(tower, TOWER_TILE) == Village.Placement.OK and tower.frame == 1, "a move without a direction keeps the direction")
	var green_tree := _config.get_item(GREEN_TREE)
	_check(village.buy(green_tree, _free_tile(village, GREEN_TREE, area_13), 1, 2) == Village.Placement.NOT_ALLOWED, "a new item cannot have a direction that it does not have")
	_check(village.buy(green_tree, _free_tile(village, GREEN_TREE, area_13), 1, 1) == Village.Placement.OK, "a new item can have its second direction")
	var new_tree: Village.PlacedItem = village.items.back()

	_check(village.save_to_file(path) == OK, "the village after turns saves")
	var reloaded := Village.load_from_file(path, _config)
	_check(reloaded.item_at(HOUSE_TILE).frame == 1 and reloaded.item_at(TOWER_TILE).frame == 1 and reloaded.item_at(new_tree.tile).frame == 1, "the save keeps the directions")
	_check(reloaded.item_at(TOWN_HALL_TILE).frame == 0, "the save keeps the first direction of the town hall")
	return true


## Collection: the production time, the work time of mines, the workers, the
## wood of farms, and the items that do not produce. Mines, ranches and farms
## work only with units in them.
func _check_production() -> bool:
	const T := 1800000000
	var units: Array = _initial["maps"][0]["items"].duplicate(true)
	for i in UNIT_TILES.size():
		units.append([VILLAGER if i < 3 else SHEEP, UNIT_TILES[i].x, UNIT_TILES[i].y, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": units}
	var path := _write_fixture("production", 100, HIGHEST_LEVEL_XP, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_12 := Rect2i(20, 40, 20, 20)
	_check(village.collect(village.item_at(HOUSE_TILE), T) == Village.Production.NOT_PRODUCER, "a house does not produce")
	_check(village.collect(village.item_at(TREE_TILE), T) == Village.Production.NOT_PRODUCER, "units collect trees, not the player")

	# A gold mine works only after the player chooses a work time.
	var mine_tile := _free_tile(village, GOLD_MINE_I, area_12)
	_check(village.buy(_config.get_item(GOLD_MINE_I), mine_tile, T) == Village.Placement.OK, "a gold mine is bought")
	var mine: Village.PlacedItem = village.items.back()
	_check(village.seconds_to_ready(mine, T + 100000) == -1, "a new mine does not work")
	_check(village.collect(mine, T + 100000) == Village.Production.NO_UNITS, "a mine without a unit cannot be collected")
	_check(village.start_work(mine, 0, T) == Village.Production.NO_UNITS, "a mine without a unit cannot start to work")
	_check(village.push_unit(village.item_at(UNIT_TILES[0]), mine, T) == Village.Placement.OK, "a villager goes into the mine")
	_check(village.collect(mine, T + 100000) == Village.Production.NOT_STARTED, "a mine without a work time cannot be collected")
	_check(village.start_work(mine, 0, T + 10) == Village.Production.OK, "the mine starts to work for 5 minutes")
	_check(village.start_work(mine, 1, T + 10) == Village.Production.ALREADY_STARTED, "a working mine cannot start again")
	_check(village.seconds_to_ready(mine, T + 10 + 299) == 1, "the mine is ready after 5 minutes")
	_check(village.collect(mine, T + 10 + 299) == Village.Production.NOT_READY, "the mine cannot be collected before it is ready")
	var coins := village.get_resource("g")
	var xp := village.get_xp()
	_check(village.collect(mine, T + 10 + 300) == Village.Production.OK, "the ready mine is collected")
	_expect("after 5 minutes of the mine (200 gold x 0.5, 7 XP)", village, {"g": coins + 100, "xp": xp + 7})
	_check(village.seconds_to_ready(mine, T + 100000) == -1, "the mine stops after the collection")

	# A ranch produces without a work time.
	var ranch_tile := _free_tile(village, SHEEP_RANCH_I, area_12)
	_check(village.buy(_config.get_item(SHEEP_RANCH_I), ranch_tile, T) == Village.Placement.OK, "a sheep ranch is bought")
	var ranch: Village.PlacedItem = village.items.back()
	_check(village.collect(ranch, T + 90) == Village.Production.NO_UNITS, "a ranch without animals does not produce")
	_check(not village.can_enter(village.item_at(UNIT_TILES[3]), ranch), "the player cannot send a wild sheep into the ranch")

	# A farm costs a third of its amount in wood.
	var farm_tile := _free_tile(village, PUMPKIN_CROP, area_12)
	_check(village.buy(_config.get_item(PUMPKIN_CROP), farm_tile, T) == Village.Placement.OK, "a pumpkin crop is bought")
	var farm: Village.PlacedItem = village.items.back()
	_check(village.push_unit(village.item_at(UNIT_TILES[1]), farm, T) == Village.Placement.OK, "a villager goes into the farm")
	_check(village.seconds_to_ready(farm, T + 32) > 0 and village.seconds_to_ready(farm, T + 33) == 0, "the farm is ready after 32.4 seconds")
	var wood := village.get_resource("w")
	var food := village.get_resource("f")
	_check(village.collect(farm, T + 33) == Village.Production.OK, "the farm is collected")
	_expect("after the farm", village, {"w": wood - 8, "f": food + 25})

	_check(village.sell(ranch) == Village.Placement.OK, "a producing building can be sold")
	_check(village.save_to_file(path) == OK, "the village after the collections saves")
	var saved := {}
	for entry: Array in JSON.parse_string(FileAccess.get_file_as_string(path))["maps"][0]["items"]:
		saved[int(entry[0])] = entry
	_check(saved[GOLD_MINE_I][4] == T + 310 and saved[GOLD_MINE_I][7] == {}, "the save has the time of the collection and no work time for the mine")
	_check(saved[PUMPKIN_CROP][4] == T + 33, "the save has the time of the collection for the farm")

	# Each unit in a building after the first one adds a fifth. The house in
	# the units is not a unit. The work time of 4 hours doubles the amount.
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([GOLD_MINE_I, 25, 45, 0, T, 0, [VILLAGER, VILLAGER, HOUSE], {"cp": 3}])
	items.append([PUMPKIN_CROP, 30, 45, 0, T, 0, [VILLAGER], {}])
	items.append([SHEEP_RANCH_I, 37, 55, 0, T, 0, [SHEEP, SHEEP], {}])
	var workers_path := _write_fixture("workers", 100, HIGHEST_LEVEL_XP, 100000, {"wood": 7, "expansions": [13, 12], "items": items})
	village = Village.load_from_file(workers_path, _config)
	mine = village.item_at(Vector2i(25, 45))
	farm = village.item_at(Vector2i(30, 45))
	_check(village.seconds_to_ready(mine, T + 4 * 3600 - 1) == 1, "the mine with 4 hours of work is ready after 4 hours")
	coins = village.get_resource("g")
	_check(village.collect_amount(mine) == 480 and village.collect(mine, T + 4 * 3600) == Village.Production.OK, "the mine with 2 workers and 4 hours of work gives 480 gold")
	_expect("after the mine with workers", village, {"g": coins + 480})
	# A ranch with animals produces without a work time, and uses one animal for each collection.
	ranch = village.item_at(Vector2i(37, 55))
	_check(village.collect(ranch, T + 89) == Village.Production.NOT_READY, "the ranch is not ready after 89 seconds")
	food = village.get_resource("f")
	_check(village.collect(ranch, T + 90) == Village.Production.OK, "the ranch is ready after 90 seconds")
	_expect("after the ranch (100 food and a fifth more for the second sheep)", village, {"f": food + 120})
	_check(village.seconds_to_ready(ranch, T + 90) == 90, "the ranch starts again after the collection")
	_check(village.units_in(ranch) == [SHEEP], "the ranch used one sheep for the collection")
	var count := village.items.size()
	_check(village.collect(farm, T + 100) == Village.Production.FARM_REMOVED, "a farm without enough wood is removed")
	_check(village.items.size() == count - 1 and village.item_at(Vector2i(30, 45)) == null, "the removed farm is not on the map")
	_expect("after the removed farm", village, {"w": 7})
	return true


## Paying cash to collect before a building is ready.
func _check_hurry() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([CHICHEN_ITZA, 25, 45, 0, T, 0, [], {}])
	items.append([SAINT_BASIL, 30, 45, 0, T, 0, [], {}])
	items.append([PUMPKIN_CROP, 33, 45, 0, T, 0, [VILLAGER], {}])
	items.append([VILLAGER, UNIT_TILES[0].x, UNIT_TILES[0].y, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("hurry", 100, HIGHEST_LEVEL_XP, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_12 := Rect2i(20, 40, 20, 20)
	var wonder := village.item_at(Vector2i(25, 45))
	var cash := village.get_resource("c")
	var coins := village.get_resource("g")
	_check(village.can_hurry(wonder, T + 10) and village.hurry(wonder, T + 10) == Village.Production.OK, "a wonder without population can finish with cash")
	_expect("after the wonder finished with cash", village, {"c": cash - 2, "g": coins + 600})
	_check(village.seconds_to_ready(wonder, T + 10) == 21600, "the wonder starts again after the cash collection")
	_check(village.hurry(village.item_at(Vector2i(30, 45)), T + 10) == Village.Production.NOT_PRODUCER, "a wonder that does not produce cannot finish with cash")
	_check(village.hurry(village.item_at(Vector2i(33, 45)), T + 10) == Village.Production.CANNOT_HURRY, "a farm cannot finish with cash")
	_check(village.hurry(village.item_at(HOUSE_TILE), T + 10) == Village.Production.NOT_PRODUCER, "a house cannot finish with cash")

	_buy_free(village, GOLD_MINE_I, area_12, Village.Placement.OK)
	var mine: Village.PlacedItem = village.items.back()
	_check(village.push_unit(village.item_at(UNIT_TILES[0]), mine, T) == Village.Placement.OK, "a villager goes into the mine")
	_check(village.hurry(mine, T + 10) == Village.Production.NOT_STARTED, "a mine without a work time cannot finish with cash")
	cash = village.get_resource("c")
	for i in cash / 2:
		village.start_work(mine, 1, T + 20)
		_check(village.hurry(mine, T + 30) == Village.Production.OK, "the mine finishes with cash, time %d" % (i + 1))
	village.start_work(mine, 1, T + 20)
	_check(village.hurry(mine, T + 30) == Village.Production.NOT_ENOUGH_CASH, "the mine does not finish without enough cash")
	_expect("after the cash collections", village, {"c": cash % 2})
	_check(village.hurry(mine, T + 20 + 3600) == Village.Production.OK and village.get_resource("c") == cash % 2, "a ready building needs no cash")
	_check(village.save_to_file(path) == OK, "the village after the cash collections saves")
	return true


## Units: walking, going into buildings and out, and harvesting.
func _check_units() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	for tile in UNIT_TILES.slice(0, 3):
		items.append([VILLAGER, tile.x, tile.y, 0, T, 0, [], {}])
	items.append([SHEEP, UNIT_TILES[3].x, UNIT_TILES[3].y, 0, T, 0, [], {}])
	items.append([GOLD_DEPOSIT, 30, 50, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("units", 20, _config.levels[19].exp_required, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_12 := Rect2i(20, 40, 20, 20)
	var villager := village.item_at(UNIT_TILES[0])
	var sheep := village.item_at(UNIT_TILES[3])

	var gold := village.get_resource("g")
	var regrowth := village.harvest(village.item_at(Vector2i(30, 50)), 1, T + 50)
	_expect("after the gold deposit at level 20 (10 gold x 3)", village, {"level": 20, "g": gold + 30})
	_check(village.move_unit(villager, Vector2i(26, 57), 4) == Village.Placement.OK and village.item_at(Vector2i(26, 57)) == villager, "a villager walks to a free tile")
	_check(villager.frame == 4 and village.item_at(UNIT_TILES[0]) == null, "the villager keeps its direction and leaves its old tile")
	_check(village.move_unit(villager, TOWN_HALL_TILE, 4) == Village.Placement.OCCUPIED, "a unit cannot stand on a building")
	_check(village.move_unit(village.item_at(HOUSE_TILE), Vector2i(26, 56), 4) == Village.Placement.NOT_ALLOWED, "move_unit does not move buildings")
	var blocked := [Vector2i(1, 0), Vector2i(0, 1)]
	var in_grid := func(tile: Vector2i) -> bool: return Rect2i(0, 0, 3, 3).has_point(tile) and not tile in blocked
	_check(Pathfinder.find_path(Vector2i(0, 0), func(tile: Vector2i) -> bool: return tile == Vector2i(2, 2), in_grid).is_empty(), "a unit does not cut the corners of items")
	var to_hall := Pathfinder.find_path(UNIT_TILES[1], func(tile: Vector2i) -> bool: return tile == Vector2i(53, 53), village.is_free)
	_check(not to_hall.is_empty() and to_hall.all(func(tile: Vector2i) -> bool: return village.is_free(tile)), "a path goes around the items")

	_buy_free(village, GOLD_MINE_I, area_12, Village.Placement.OK)
	var mine: Village.PlacedItem = village.items.back()
	_buy_free(village, SHEEP_RANCH_I, area_12, Village.Placement.OK)
	var ranch: Village.PlacedItem = village.items.back()
	_buy_free(village, COW_RANCH, area_12, Village.Placement.OK)
	var cow_ranch: Village.PlacedItem = village.items.back()
	_check(village.can_enter(villager, mine) and not village.can_enter(villager, ranch), "a villager can work in a mine, not in a ranch")
	_check(not village.is_own_unit(sheep) and not village.can_enter(sheep, ranch) and not village.can_enter(sheep, cow_ranch), "a wild sheep is not a unit of the player")
	_check(not village.can_enter(village.item_at(KNIGHT_TILE), mine), "a knight cannot work in a mine")
	var troll := village.item_at(Vector2i(40, 40))
	_check(village.is_own_unit(villager) and not village.is_own_unit(troll), "a troll unit on a human map is not a unit of the player")
	_check(village.move_unit(troll, Vector2i(26, 56), 4) == Village.Placement.NOT_ALLOWED, "the player cannot move a troll unit on a human map")
	var population := village.population()
	_check(village.push_unit(villager, mine, T + 5) == Village.Placement.OK and not villager in village.items, "a villager goes into the mine and leaves the map")
	_check(village.units_in(mine) == [VILLAGER] and village.seconds_to_ready(mine, T + 5) == -1 and village.population() == population, "the mine has the villager, needs a work time, and the population is the same")
	_check(village.push_unit(village.item_at(UNIT_TILES[1]), mine, T + 6) == Village.Placement.OK, "a second villager goes into the mine")
	_check(not village.can_enter(village.item_at(UNIT_TILES[2]), mine), "the mine has room for 2 villagers")
	_check(village.start_work(mine, 1, T + 10) == Village.Production.OK, "the mine with villagers starts to work")
	var out := village.pop_unit(mine, 0, T + 20)
	_check(out != null and out.item_id == VILLAGER and village.units_in(mine) == [VILLAGER], "a villager comes out of the mine")
	_check(Village.footprint(_config.get_item(GOLD_MINE_I), mine.tile).grow(1).has_point(out.tile), "the villager comes out next to the mine")
	_check(village.seconds_to_ready(mine, T + 20) > 0, "the mine works with one villager")
	village.pop_unit(mine, 0, T + 30)
	_check(village.needs_units(mine) and village.seconds_to_ready(mine, T + 100000) == -1, "the mine stops when the last villager comes out")

	var tree := village.item_at(TREE_TILE)
	var wood := village.get_resource("w")
	var xp := village.get_xp()
	_check(village.can_harvest(out, tree) and not village.can_harvest(village.item_at(KNIGHT_TILE), tree), "a villager can harvest a tree, a knight cannot")
	_check(village.harvest_seconds(tree) == 3.24 and village.harvest(tree, 2, T + 40) == null, "two villagers harvest a tree in 3.24 seconds")
	_expect("after the tree (20 wood and a fifth more for the second villager, 1 XP)", village, {"w": wood + 24, "xp": xp + 1})
	_check(not tree in village.items and village.item_at(TREE_TILE) == null, "the tree is gone")
	_check(regrowth != null and regrowth.item_id == GOLD_REGROWTH and regrowth.tile == Vector2i(30, 50) and regrowth.frame == 1, "the gold deposit leaves a regrowth item")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_check(village.regrow(T + 50 + 10799, rng).is_empty(), "the regrowth item does not change before 3 hours")
	var changes := village.regrow(T + 50 + 10800, rng)
	_check(changes.size() == 1 and changes[0][0] == regrowth and changes[0][1].item_id in [73, 74, 75, 76] and changes[0][1].tile == Vector2i(30, 50), "a new gold deposit grows after 3 hours")

	_check(village.save_to_file(path) == OK, "the village with the units saves")
	var reloaded := Village.load_from_file(path, _config)
	_check(reloaded.units_in(reloaded.item_at(mine.tile)).is_empty() and reloaded.item_at(Vector2i(26, 57)) == null, "the save has the units at their new places")
	var bought: Array = JSON.parse_string(FileAccess.get_file_as_string(path))["privateState"]["boughtUnits"]
	_check(bought.has(float(VILLAGER)), "the save lists the villager as a unit of the player")
	return true


## Training: costs, the queue, the population and the unit limit.
func _check_training() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	for i in 6:
		items.append([HOUSE, 21 + 2 * i, 41, 0, T, 0, [], {}])
	items.append([CHURCH, 35, 44, 0, T, 0, [], {}])
	for i in 4:
		items.append([HEALER, 21 + i, 50, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("training", 20, 20000, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var town_hall := village.item_at(TOWN_HALL_TILE)
	# The 2 small trolls of the human map are not units of the player, as in the client.
	_check(village.max_population() == 11 + 18 and village.population() == 6 + 4, "the population is 10 of 29")
	_check(village.trained_unit(town_hall).id == VILLAGER and village.trained_unit(village.item_at(HOUSE_TILE)) == null, "the town hall trains villagers, a house trains nothing")
	_check(village.training_costs(_config.get_item(VILLAGER)) == {"f": 50}, "a villager costs 50 food")
	_check(village.training_costs(_config.get_item(SPEARMAN)) == {"g": 30, "f": 60}, "a spearman costs 30 gold and twice that in food")

	var food := village.get_resource("f")
	_check(village.train(town_hall, T) == Village.Training.OK and village.queued_units(town_hall) == 1, "a villager is in training")
	_expect("after the training starts", village, {"f": food - 50})
	_check(village.population() == 11, "a unit in training counts for the population")
	_check(village.seconds_to_trained(town_hall, T) == 5 and village.complete_training(town_hall, T + 4) == null, "the villager is not ready before 5 seconds")
	for i in 4:
		village.train(town_hall, T + 1)
	_check(village.train(town_hall, T + 1) == Village.Training.QUEUE_FULL, "the queue has room for 5 units")
	var xp := village.get_xp()
	var first := village.complete_training(town_hall, T + 5)
	_check(first != null and first.item_id == VILLAGER and village.queued_units(town_hall) == 4, "the first villager comes out after 5 seconds")
	_check(Village.footprint(_config.get_item(TOWN_HALL), town_hall.tile).grow(1).has_point(first.tile), "the villager comes out next to the town hall")
	_expect("after the first villager", village, {"xp": xp + 5})
	_check(village.complete_training(town_hall, T + 9) == null and village.complete_training(town_hall, T + 10) != null, "the next villager comes out 5 seconds later")
	for i in 3:
		village.complete_training(town_hall, T + 100)
	_check(village.queued_units(town_hall) == 0 and not village.complete_training(town_hall, T + 200), "all villagers are out")

	var church := village.item_at(Vector2i(35, 44))
	_check(village.train(church, T) == Village.Training.OK, "the fifth healer is in training")
	_check(village.train(church, T) == Village.Training.UNIT_LIMIT_REACHED, "a map can have 5 healers")
	while village.population() + 1 <= village.max_population():
		if village.train(town_hall, T + 300) != Village.Training.OK:
			for i in Village.MAX_QUEUE:
				village.complete_training(town_hall, T + 1000 + i * 10)
	_check(village.train(town_hall, T + 2000) == Village.Training.POPULATION_FULL, "the training stops when the population is full")

	_check(village.save_to_file(path) == OK, "the village with the training saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var queues: Dictionary = saved["privateState"]["barracksQueues"]
	var church_entry: Array = saved["maps"][0]["items"].filter(func(entry: Array) -> bool: return int(entry[0]) == CHURCH)[0]
	_check(queues.has(church_entry[7]["bq"]) and int(queues[church_entry[7]["bq"]]["unit"]) == HEALER, "the save has the queue of the church")
	var poor := _write_fixture("training_poor", 20, 20000, 100000, {"food": 49})
	village = Village.load_from_file(poor, _config)
	_check(village.train(village.item_at(TOWN_HALL_TILE), T) == Village.Training.NOT_ENOUGH_RESOURCES, "training needs the resources")
	return true


## The store categories and the "New" rotation, with the shop settings of the
## unchanged server: 2 groups for 48 hours, and the Halloween group on 31 October.
func _check_store() -> bool:
	var store := Store.load_from_file(_data_dir.path_join("shop.json"), _config)
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_data_dir.path_join("shop.json")))
	var groups: Dictionary = shop["factions"]
	var ids := func(category: int, race: String, level: int, now: int) -> Array:
		return store.items(category, race, level, now).map(func(item: GameConfig.ItemDef) -> int: return item.id)
	var bias: int = Time.get_time_zone_from_system()["bias"] * 60
	var local := func(year: int, month: int, day: int) -> int:
		return Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0}) - bias
	# The groups that are on sale completely, and the items on sale that are in no such group.
	var chosen := func(on_sale: Dictionary) -> Array:
		var names := groups.keys().filter(func(name: String) -> bool: return groups[name].all(func(id: float) -> bool: return on_sale.has(int(id))))
		var covered := {}
		for name: String in names:
			for id: float in groups[name]:
				covered[int(id)] = true
		return [names, on_sale.keys().filter(func(id: int) -> bool: return not covered.has(id))]

	var day: int = local.call(2027, 1, 15)
	var on_sale := store.rotation(day)
	var result: Array = chosen.call(on_sale)
	_check(result[0].size() == 2 and result[1].is_empty() and not "Halloween" in result[0], "the rotation offers 2 complete groups: %s" % [result[0]])
	_check(store.rotation(store.rotation_end(day) - 1) == on_sale, "the rotation stays the same until the end of its period")
	var changed := false
	for period in range(1, 6):
		changed = changed or store.rotation(day + period * 48 * 3600) != on_sale
	_check(changed, "the rotation changes in later periods")
	result = chosen.call(store.rotation(local.call(2027, 10, 31)))
	_check(result[0].size() == 2 and "Halloween" in result[0] and result[1].is_empty(), "on 31 October the rotation offers the Halloween group and one other group: %s" % [result[0]])
	_check(not "Halloween" in chosen.call(store.rotation(local.call(2027, 10, 30)))[0], "on 30 October the rotation does not offer the Halloween group")

	var offered_new: Array = ids.call(Store.CATEGORY_NEW, "h", 100, day)
	var rotation_ids := {}
	for name: String in groups:
		for id: float in groups[name]:
			rotation_ids[int(id)] = true
	_check(offered_new.all(func(id: int) -> bool: return on_sale.has(id) or not rotation_ids.has(id)), "the \"New\" category offers only the rotation items on sale from the groups")
	_check(CASH_WONDER in offered_new, "the \"New\" category also offers the items that are not in the groups")
	var offered_to_trolls: Array = []
	for category in Store.CATEGORIES:
		offered_to_trolls.append_array(ids.call(category, "t", 100, day))
	_check(not offered_to_trolls.any(func(id: int) -> bool: return rotation_ids.has(id)), "the rotation items are only for humans")
	_check(CHICHEN_ITZA in ids.call(5, "h", 1, day) and not CHICHEN_ITZA in ids.call(5, "t", 1, day), "the wonders are in the store for humans")
	_check(not DRAGONS_STATUE in ids.call(4, "h", 19, day) and DRAGONS_STATUE in ids.call(4, "h", 20, day), "the store shows an item from its store level")
	_check(not DIAMOND_CASTLE in ids.call(2, "h", 100, day), "the store does not offer the items for gold members")
	return true


## The first tile in area where the item fits.
func _free_tile(village: Village, item_id: int, area: Rect2i) -> Vector2i:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if village.check_location(_config.get_item(item_id), Vector2i(x, y)) == Village.Placement.OK:
				return Vector2i(x, y)
	return Village.ANY_TILE


## Buys the item on the first tile in area where it fits.
func _buy_free(village: Village, item_id: int, area: Rect2i, expected: Village.Placement) -> void:
	var item := _config.get_item(item_id)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if village.check_location(item, Vector2i(x, y)) == Village.Placement.OK:
				_buy(village, item_id, Vector2i(x, y), expected)
				return
	_check(false, "item %d fits in %s" % [item_id, area])


## Writes initial.json with a changed level, XP and gold, and other changed map
## values, as the start of a check.
func _write_fixture(check_name: String, level: int, xp: int, coins: int, map_values: Dictionary = {}) -> String:
	var document: Dictionary = _initial.duplicate(true)
	document["maps"][0].merge({"level": level, "xp": xp, "coins": coins}, true)
	document["maps"][0].merge(map_values, true)
	var path := "user://checks/%s.json" % check_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t", false))
	file.close()
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	return path


func _buy(village: Village, item_id: int, tile: Vector2i, expected: Village.Placement) -> void:
	var result := village.buy(_config.get_item(item_id), tile, int(Time.get_unix_time_from_system()))
	_check(result == expected, "item %d on %s: %s, expected %s" % [item_id, tile, Village.Placement.find_key(result), Village.Placement.find_key(expected)])


## values: "level", "xp" or a resource code, with the expected number.
func _expect(label: String, village: Village, values: Dictionary) -> void:
	for key: String in values:
		var actual := village.get_level() if key == "level" else village.get_xp() if key == "xp" else village.get_resource(key)
		_check(actual == values[key], "%s: %s is %d, expected %d" % [label, key, actual, values[key]])


## Every key in the document, in the order of the text.
func _keys(text: String) -> Array:
	return RegEx.create_from_string("\"([^\"]+)\":").search_all(text).map(func(m: RegExMatch) -> String: return m.get_string(1))


func _check(passed: bool, description: String) -> void:
	if not passed:
		_failures += 1
	print("%s  %s" % ["ok  " if passed else "FAIL", description])
