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
## A free tile in land area 14, which the fixtures do not own. An animal there is
## wild; the client gives the animals on owned land to the player.
const WILD_TILE := Vector2i(65, 58)
const RESTAURANT := 232  # collect building: 8 h, 570 gold
const CHICHEN_ITZA := 52  # wonder without population: 6 h, 600 gold
const SAINT_BASIL := 261  # wonder that does not produce
const DRAGONS_STATUE := 1456  # decoration that the store shows from level 20
const DIAMOND_CASTLE := 1234  # only for gold members
const CASH_WONDER := 1299  # in the "New" category, not in the rotation
const COW_RANCH := 12
const KNIGHT := 512
const FITNESS_CENTRE := 221
const GOLD_DEPOSIT := 73  # 10 gold, times 3 at level 20
const GOLD_REGROWTH := 80  # grows into a gold deposit after 3 hours
const TOWN_HALL := 26  # trains villagers: 50 food, 5 seconds, 5 XP
const CHURCH := 24  # trains healers; a map can have 5
const HEALER := 502
const BLACKSMITH := 22
const SPEARMAN := 509  # 30 gold
const LIGHT_ARCHER := 516  # shoots at 5 tiles
const LIGHT_KNIGHT := 512  # a spearman on a horse; 8 XP
const CATAPULT := 521  # siege unit
const COW := 504
const HORSE := 571
const BOAR := 584
const TRAINING_STABLES := 227
const SACRIFICE_ALTAR := 225  # 1.08 seconds
const SMALL_REFUGE := 151  # 2 units
const FORTRESS := 469
const UNIT_WAREHOUSE := 1284
const GHOST_BARRACKS := 1246  # 3x3; trains ghosts: 5 cash and 10 food, 25 seconds
const GHOST := 734
const RAM_BARRACKS := 1491  # 3x3; trains orc battering rams: 1500 seconds
const HIGHEST_LEVEL_XP := 2016089205
const TREASURE_MINE := 218  # 24 hours, gives an item of a collection
const GARDEN := 178  # 3x3 decoration; the reward of collection 3
const DRAGON_NEST := 1233  # 4x4
const DRAGGY := 638  # the first dragon of the nest; Soul Mixer power 68
const FURIOUS_DRAGON := 649  # the second dragon of the nest; tamed by Dragon Rider I
const RIDER_ACADEMY := 1345
const DRAGON_RIDING := 1346
const DRAGON_RIDER_I := 822  # 5 training steps, 15 cash for each wait
const FURIOUS_DRAGON_RIDER := 832
const EPIC_TWO_HEAD_DRAGON := 736  # tamed by Dragon Rider II
const GRAVEYARD := 486  # 4x4
const HEROES_GRAVE := 239  # 3x3
const SOUL_MIXER := 1529  # 3x3
const TOWN_HALL_TILE := Vector2i(52, 52)
const TREE_TILE := Vector2i(50, 58)
const KNIGHT_TILE := Vector2i(50, 44)
const FITNESS_TILE := Vector2i(42, 58)
const HOUSE_TILE := Vector2i(44, 50)
const TOWER_TILE := Vector2i(51, 47)
## The time for the units that come out of sold buildings, where the time does not matter.
const NOW := 1800000000
const SMALL_TROLL := 525
const SUPREME_TEMPLE := 1394  # 4x4, from level 40
const SUPREME_BAHAMUT := 2003  # 1 XP
const BAHAMUT_HEART := 1410  # the reward of the Supreme Heart collection; costs 0 cash
const MONK := 569

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
	for scenario: Callable in [_check_placement_and_save, _check_several_levels, _check_mana_reward, _check_highest_level, _check_construction_limits, _check_move_and_sell, _check_rotation, _check_production, _check_hurry, _check_store, _check_units, _check_training, _check_cash_training, _check_crowded_units, _check_animals, _check_unit_buildings, _check_collections, _check_nests, _check_riders, _check_graveyards, _check_soul_mixer, _check_time_machine, _check_weather_machine, _check_temple, _check_village_enemies, _check_map_start, _check_daily_bonus, _check_goals, _check_village_actions, _check_tutorial, _check_neighbours, _check_allies_buildings, _check_pvp, _check_second_town, _check_town_quests, _check_save_migration, _check_first_offer, _check_unit_collections]:
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
	# The load fills the empty list of bought units, as the server's save migration does.
	expected["privateState"]["boughtUnits"] = [512, 516]
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
	_check(village.sell(town_hall, NOW) == Village.Placement.NOT_ALLOWED, "selling the town hall is not allowed")
	var tree := village.item_at(TREE_TILE)
	_check(village.move(tree, Vector2i(41, 41)) == Village.Placement.NOT_ALLOWED, "a tree cannot move")
	_check(village.sell(tree, NOW) == Village.Placement.NOT_ALLOWED, "a tree cannot be sold")
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
	_check(village.sell(house, NOW) == Village.Placement.OK, "a house can be sold")
	_expect("after selling a house (30 wood)", village, {"w": wood + 1})
	_check(village.check_location(_config.get_item(GREEN_TREE), HOUSE_TILE) == Village.Placement.OK, "the tile of a sold item is free")
	_buy_free(village, MARKET, area_12, Village.Placement.OK)
	wood = village.get_resource("w")
	_check(village.sell(village.items.back(), NOW) == Village.Placement.OK, "a market can be sold")
	_expect("after selling a market (350 wood)", village, {"w": wood + 17})
	_buy_free(village, BATHS, area_12, Village.Placement.OK)
	var cash := village.get_resource("c")
	_check(village.sell(village.items.back(), NOW) == Village.Placement.OK, "the baths can be sold")
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
	for i in 3:
		units.append([VILLAGER, UNIT_TILES[i].x, UNIT_TILES[i].y, 0, T, 0, [], {}])
	units.append([SHEEP, WILD_TILE.x, WILD_TILE.y, 0, T, 0, [], {}])
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
	_check(not village.can_enter(village.item_at(WILD_TILE), ranch), "the player cannot send a wild sheep into the ranch")

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

	_check(village.sell(ranch, T) == Village.Placement.OK, "a producing building can be sold")
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
	# The client takes the farmer out before it removes the farm.
	_check(village.items.size() == count and village.item_at(Vector2i(30, 45)) == null, "the removed farm is not on the map")
	_check(village.items.back().item_id == VILLAGER and village.is_own_unit(village.items.back()), "the farmer of the removed farm comes out")
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
	items.append([SHEEP, WILD_TILE.x, WILD_TILE.y, 0, T, 0, [], {}])
	items.append([GOLD_DEPOSIT, 30, 50, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("units", 20, _config.levels[19].exp_required, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var area_12 := Rect2i(20, 40, 20, 20)
	var villager := village.item_at(UNIT_TILES[0])
	var sheep := village.item_at(WILD_TILE)

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


## Units that cost cash, and cash that finishes a training queue.
func _check_cash_training() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	for i in 6:
		items.append([HOUSE, 21 + 2 * i, 41, 0, T, 0, [], {}])
	items.append([GHOST_BARRACKS, 25, 45, 0, T, 0, [], {}])
	items.append([RAM_BARRACKS, 30, 45, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("cash_training", 100, HIGHEST_LEVEL_XP, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var ghost_barracks := village.item_at(Vector2i(25, 45))
	var ram_barracks := village.item_at(Vector2i(30, 45))
	_check(village.training_costs(_config.get_item(GHOST)) == {"c": 5, "f": 10}, "a ghost costs 5 cash and 10 food")
	var cash := village.get_resource("c")
	var food := village.get_resource("f")
	_check(village.speed_up_training(ghost_barracks, T) == Village.Training.NOTHING_TO_FINISH and village.speed_up_cost(ghost_barracks, T) == 0, "an empty queue has nothing to finish")
	_check(village.train(ghost_barracks, T) == Village.Training.OK, "a ghost is in training")
	_expect("after the ghost training starts", village, {"c": cash - 5, "f": food - 10})
	_check(village.speed_up_cost(ghost_barracks, T + 10) == 1, "1 cash finishes a queue of 15 seconds")
	_check(village.speed_up_training(ghost_barracks, T + 10) == Village.Training.OK, "the ghost training finishes with cash")
	_expect("after the speed-up", village, {"c": cash - 6})
	var ghost := village.complete_training(ghost_barracks, T + 10)
	_check(ghost != null and ghost.item_id == GHOST and village.queued_units(ghost_barracks) == 0, "the ghost comes out at once")
	_check(village.speed_up_training(ghost_barracks, T + 10) == Village.Training.NOTHING_TO_FINISH, "a finished queue has nothing to finish")

	for i in 3:
		village.train(ram_barracks, T)
	# The server charges only for the next unit, 1 cash; the client shows and takes 2.
	_check(village.speed_up_cost(ram_barracks, T) == 2, "2 cash finish 3 rams (75 minutes)")
	_check(village.speed_up_cost(ram_barracks, T + 1000) == 1, "1 cash finishes the rams after 1000 seconds")
	_check(village.speed_up_training(ram_barracks, T + 1000) == Village.Training.OK, "the ram training finishes with cash")
	for i in 3:
		_check(village.complete_training(ram_barracks, T + 1000) != null, "ram %d comes out at once" % (i + 1))
	_check(village.save_to_file(path) == OK, "the village after the speed-ups saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["privateState"]["barracksQueues"].is_empty(), "the save has no training queues")

	saved["playerInfo"]["cash"] = 5
	saved["maps"][0]["food"] = 100000  # for the rams of the cancel check
	var poor := "user://checks/cash_training_poor.json"
	var file := FileAccess.open(poor, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved, "\t", false))
	file.close()
	village = Village.load_from_file(poor, _config)
	ghost_barracks = village.item_at(Vector2i(25, 45))
	_check(village.train(ghost_barracks, T) == Village.Training.OK and village.train(ghost_barracks, T) == Village.Training.NOT_ENOUGH_RESOURCES, "the second ghost needs 5 more cash")
	_check(village.speed_up_training(ghost_barracks, T) == Village.Training.NOT_ENOUGH_CASH and village.queued_units(ghost_barracks) == 1, "the speed-up needs the cash")

	# Cancel: the last unit leaves the queue, and its costs come back.
	food = village.get_resource("f")
	_check(village.unqueue_unit(ghost_barracks) == Village.Training.OK, "the ghost leaves the training queue")
	_expect("after the ghost leaves the queue", village, {"c": 5, "f": food + 10})
	_check(village.queued_units(ghost_barracks) == 0 and not ghost_barracks._entry[7].has("bq"), "the empty queue is removed")
	_check(village.unqueue_unit(ghost_barracks) == Village.Training.NOTHING_TO_FINISH, "an empty queue has no unit to cancel")
	ram_barracks = village.item_at(Vector2i(30, 45))
	village.train(ram_barracks, T)
	var after_one := [village.get_resource("g"), village.get_resource("f")]
	var population := village.population()
	village.train(ram_barracks, T + 100)
	_check(village.unqueue_unit(ram_barracks) == Village.Training.OK and village.queued_units(ram_barracks) == 1, "the second ram leaves the queue, the first stays")
	_check([village.get_resource("g"), village.get_resource("f")] == after_one and village.population() == population, "the second ram's costs and population come back")
	_check(is_equal_approx(village.seconds_to_trained(ram_barracks, T), village.trained_unit(ram_barracks).training_time), "the first ram keeps its training time")
	_check(village.save_to_file(poor) == OK, "the village after the cancels saves")
	return true


## Units that stand on a building or on another unit, which the client moves away.
func _check_crowded_units() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([PUMPKIN_CROP, 33, 45, 0, T, 0, [], {}])
	for tile: Vector2i in [UNIT_TILES[0], UNIT_TILES[0], UNIT_TILES[1], HOUSE_TILE, Vector2i(33, 45)]:
		items.append([VILLAGER, tile.x, tile.y, 0, T, 0, [], {}])
	var path := _write_fixture("crowded_units", 20, 20000, 100000, {"expansions": [13, 12], "items": items})
	var village := Village.load_from_file(path, _config)
	var on_tile := village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == VILLAGER and placed.tile == UNIT_TILES[0])
	_check(on_tile.size() == 2 and not village.is_crowded(on_tile[0]) and village.is_crowded(on_tile[1]), "of two units on one tile, the second must move")
	var on_house: Village.PlacedItem = village.items[-2]
	var on_farm: Village.PlacedItem = village.items[-1]
	_check(village.is_crowded(on_house) and not village.is_crowded(on_farm), "a unit on a house must move, a unit on a farm can stay")
	_check(not village.is_crowded(village.item_at(UNIT_TILES[1])), "a unit alone on its tile can stay")
	var rng := RandomNumberGenerator.new()
	for i in 20:
		var tile := village.random_free_tile_near(UNIT_TILES[0], Village.CROWD_SEARCH_RINGS, rng)
		var distance := (tile - UNIT_TILES[0]).abs()
		_check(village.is_free(tile) and maxi(distance.x, distance.y) == 1, "the free tile %s is next to the crowded unit" % tile)
	return true


## Wild animals: who owns them, the capture, the building that they go into,
## and the animals that the client spawns when it loads the map.
func _check_animals() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([SHEEP, WILD_TILE.x, WILD_TILE.y, 0, T, 0, [], {}])
	items.append([SHEEP, WILD_TILE.x + 1, WILD_TILE.y, 0, T, 0, [], {}])
	items.append([SHEEP, UNIT_TILES[0].x, UNIT_TILES[0].y, 0, T, 0, [], {}])
	items.append([VILLAGER, UNIT_TILES[1].x, UNIT_TILES[1].y, 0, T, 0, [], {}])
	items.append([SHEEP_RANCH_I, 37, 55, 0, T, 0, [], {}])
	items.append([FITNESS_CENTRE, FITNESS_TILE.x, FITNESS_TILE.y, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items}
	var path := _write_fixture("animals", 11, _config.levels[10].exp_required, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var wild := village.item_at(WILD_TILE)
	var other_wild := village.item_at(WILD_TILE + Vector2i(1, 0))
	var tame := village.item_at(UNIT_TILES[0])
	var villager := village.item_at(UNIT_TILES[1])
	var ranch := village.item_at(Vector2i(37, 55))
	_check(village.is_wild_animal(wild) and not village.is_own_unit(wild), "a sheep on land that the player does not own is wild")
	_check(village.is_own_unit(tame) and not village.is_wild_animal(tame), "a sheep on owned land belongs to the player, as in the client")
	_check(village.can_capture(villager, WILD_TILE + Vector2i(4, 0), wild) and village.can_capture(villager, WILD_TILE + Vector2i(0, -4), wild), "a unit captures an animal at 4 tiles")
	_check(not village.can_capture(villager, WILD_TILE + Vector2i(5, 0), wild) and not village.can_capture(villager, WILD_TILE + Vector2i(3, 3), wild), "a unit does not capture an animal further away than 4 tiles")
	_check(not village.can_capture(other_wild, WILD_TILE, wild) and not village.can_capture(villager, WILD_TILE, tame), "a wild animal does not capture, and an own animal cannot be captured")
	_check(not village.can_enter(wild, ranch), "a wild sheep does not go into the ranch")
	village.capture(wild)
	_check(village.is_own_unit(wild) and village.can_enter(wild, ranch) and village.animal_home(wild) == ranch, "a captured sheep belongs to the player and goes into the sheep ranch")
	_check(village.animal_home(villager) == null and village.town_hall() == village.item_at(TOWN_HALL_TILE), "a villager has no ranch; the village has its town hall")
	_check(village.walking_speed(tame) == _config.get_item(SHEEP).velocity and village.walking_speed(villager) == 7, "a sheep walks at its velocity; a villager at the speed of town hall I plus the fitness centre")
	_check(village.sell(village.item_at(FITNESS_TILE), T) == Village.Placement.OK and village.walking_speed(villager) == 5, "without the fitness centre, a villager walks at the speed of town hall I")
	_check(village.push_unit(wild, ranch, T) == Village.Placement.OK and village.seconds_to_ready(ranch, T) == 90, "the sheep goes into the ranch, which starts to produce")
	var out := village.pop_unit(ranch, 0, T + 1)
	_check(out != null and village.is_own_unit(out), "a sheep that comes out of the ranch belongs to the player")
	_check(not village.can_enter(villager, ranch), "a villager does not go into a ranch")

	# Level 11: 7 cows, 7 sheep and 6 horses. The map has 3 sheep, and the ranch none.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var new_animals := village.spawn_animals(T + 2, rng)
	var kinds := {}
	for animal in new_animals:
		kinds[animal.item_id] = kinds.get(animal.item_id, 0) + 1
	_check(kinds == {COW: 7, SHEEP: 4, HORSE: 6}, "the client spawns animals until the map has 7 cows, 7 sheep and 6 horses: %s" % kinds)
	_check(new_animals.all(func(animal: Village.PlacedItem) -> bool: return village.is_wild_animal(animal) and not IsoGrid.land_area_number(animal.tile / IsoGrid.LAND_TILES) in village.owned_land), "the new animals are wild and on land that the player does not own")
	_check(village.spawn_animals(T + 3, rng).is_empty(), "a second load spawns no animals")
	_check(village.save_to_file(path) == OK, "the village with the new animals saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	# The server counted 3 sheep at the load; the spawns add to the counts.
	_check(saved["privateState"]["arrayAnimals"] == {"74": 7.0, "75": 7.0, "88": 6.0}, "the save counts the animals of the day: %s" % saved["privateState"]["arrayAnimals"])
	_check(saved["privateState"]["boughtUnits"].has(float(SHEEP)), "the server lists the bought animals")
	_check(saved["maps"][0]["items"].filter(func(entry: Array) -> bool: return int(entry[0]) == HORSE).size() == 6, "the save has the horses")

	# 15 sheep in the ranch count for the day: only 5 more sheep spawn. Level 10 has no horses.
	var counted := {"items": _initial["maps"][0]["items"].duplicate(true) + [[SHEEP_RANCH_I, 37, 55, 0, T, 0, [], {}]]}
	counted["items"].back()[6].assign(range(15).map(func(i: int) -> int: return SHEEP))
	village = Village.load_from_file(_write_fixture("animals_limit", 10, _config.levels[9].exp_required, 0, counted), _config)
	kinds = {}
	for animal in village.spawn_animals(T, rng):
		kinds[animal.item_id] = kinds.get(animal.item_id, 0) + 1
	_check(kinds == {COW: 7, SHEEP: 5}, "the client spawns at most 20 animals of a kind for each day: %s" % kinds)
	village = Village.load_from_file(_write_fixture("animals_troll", 1, 0, 0, {"race": "t"}), _config)
	kinds = {}
	for animal in village.spawn_animals(T, rng):
		kinds[animal.item_id] = kinds.get(animal.item_id, 0) + 1
	_check(kinds == {BOAR: 7}, "a troll map gets boars: %s" % kinds)
	return true


## The training stables, the nursery, the altar, refuges, the fortress, the unit
## warehouse, and units that come out of a sold building.
func _check_unit_buildings() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append_array([
		[TRAINING_STABLES, 24, 44, 0, T, 0, [], {}], [NURSERY, 28, 43, 0, T, 0, [], {}],
		[SACRIFICE_ALTAR, 33, 44, 0, T, 0, [], {}], [SMALL_REFUGE, 37, 43, 0, T, 0, [], {}],
		[FORTRESS, 27, 52, 0, T, 0, [], {}], [UNIT_WAREHOUSE, 35, 52, 0, T, 0, [], {}],
		[HOUSE, 30, 41, 0, T, 0, [], {}], [HOUSE, 36, 41, 0, T, 0, [], {}],
	])
	var units := [HORSE, SHEEP, SHEEP, COW, SPEARMAN, LIGHT_ARCHER, VILLAGER, VILLAGER, CATAPULT, SPEARMAN, LIGHT_ARCHER]
	for i in units.size():
		items.append([units[i], 21 + i, 56, 0, T, 0, [], {}])
	var plenty := {"wood": 100000, "stone": 100000, "food": 100000, "expansions": [13, 12], "items": items,
			"warehousedUnits": {str(HEALER): 1}, "warehouseAditionalCapacitySingle": 3}
	var path := _write_fixture("unit_buildings", 40, _config.levels[39].exp_required, 100000, plenty)
	var village := Village.load_from_file(path, _config)
	var at := func(x: int) -> Village.PlacedItem: return village.item_at(Vector2i(x, 56))
	var horse: Village.PlacedItem = at.call(21)
	var sheep: Village.PlacedItem = at.call(22)
	var cow: Village.PlacedItem = at.call(24)
	var spearman: Village.PlacedItem = at.call(25)
	var archer: Village.PlacedItem = at.call(26)
	var villager: Village.PlacedItem = at.call(27)
	var catapult: Village.PlacedItem = at.call(29)
	var stables := village.item_at(Vector2i(24, 44))
	var nursery := village.item_at(Vector2i(28, 43))
	var altar := village.item_at(Vector2i(33, 44))
	var refuge := village.item_at(Vector2i(37, 43))
	var fortress := village.item_at(Vector2i(27, 52))
	var warehouse := village.item_at(Vector2i(35, 52))

	# A horse goes into the training stables; a spearman there takes it and becomes a knight.
	_check(not village.can_enter(spearman, stables) and not village.can_mount(spearman, stables), "a spearman cannot go into empty training stables")
	_check(not village.can_enter(sheep, stables) and village.animal_home(horse) == stables, "the training stables take horses, not sheep")
	_check(village.push_unit(horse, stables, T) == Village.Placement.OK, "the horse goes into the training stables")
	_check(village.can_mount(spearman, stables) and not village.can_mount(villager, stables) and not village.can_mount(catapult, stables), "a spearman can mount the horse, a villager and a catapult cannot")
	_check(village.push_unit(spearman, stables, T) == Village.Placement.NOT_ALLOWED, "mounting is not a push")
	var population := village.population()
	var xp := village.get_xp()
	var knight := village.mount(spearman, stables, Vector2i(25, 46), T + 1)
	_check(knight != null and knight.item_id == LIGHT_KNIGHT and knight.tile == Vector2i(25, 46) and knight.frame == 1, "the spearman becomes a light knight on its tile")
	_check(not spearman in village.items and village.units_in(stables).is_empty() and village.population() == population + 1, "the spearman and the horse are gone; the knight needs 2 population")
	_expect("after mounting (the knight gives 8 XP)", village, {"xp": xp + 8})
	_check(village.mount(at.call(30), stables, Vector2i(26, 46), T + 1) == null, "with no horse there is nothing to mount")

	# The nursery breeds an animal from two of one kind.
	_check(village.push_unit(sheep, nursery, T) == Village.Placement.OK and not village.can_enter(cow, nursery), "a sheep goes into the nursery; a cow cannot join it")
	_check(not village.can_enter(villager, nursery), "a villager does not go into the nursery")
	_check(village.needs_units(nursery) and village.seconds_to_ready(nursery, T + 100000) == -1, "the nursery does not breed with one sheep")
	_check(village.push_unit(at.call(23), nursery, T + 10) == Village.Placement.OK and village.seconds_to_ready(nursery, T + 10) == 32400, "with two sheep the nursery breeds in 9 hours")
	_check(village.collect(nursery, T + 10 + 32399) == Village.Production.NOT_READY, "the nursery is not ready before 9 hours")
	xp = village.get_xp()
	var count := village.items.size()
	_check(village.bred_unit(nursery).id == SHEEP and village.collect(nursery, T + 10 + 32400) == Village.Production.OK, "the nursery is ready after 9 hours")
	var lamb: Village.PlacedItem = village.items.back()
	_check(village.items.size() == count + 1 and lamb.item_id == SHEEP and village.is_own_unit(lamb) and lamb.frame == 1, "a new sheep of the player comes out of the nursery")
	_check(Village.footprint(_config.get_item(NURSERY), nursery.tile).grow(1).has_point(lamb.tile), "the new sheep is next to the nursery")
	_check(village.units_in(nursery) == [SHEEP, SHEEP] and village.seconds_to_ready(nursery, T + 10 + 32400) == 32400, "the nursery keeps its sheep and starts again")
	_expect("after the nursery (15 XP)", village, {"xp": xp + 15})

	# The altar sacrifices a unit after 1.08 seconds; it gives back what selling the unit gives.
	_check(not village.can_enter(catapult, altar) and village.can_enter(cow, altar), "the altar takes all units except siege units")
	_check(village.push_unit(villager, altar, T) == Village.Placement.OK and not village.can_enter(cow, altar), "a villager goes into the altar, which has room for one")
	_check(village.complete_sacrifice(altar, T + 1) == null, "the sacrifice takes 1.08 seconds")
	var food := village.get_resource("f")
	var victim := village.complete_sacrifice(altar, T + 2)
	_check(victim != null and victim.id == VILLAGER and village.units_in(altar).is_empty(), "the villager is sacrificed")
	_expect("after the sacrifice (50 food / 20)", village, {"f": food + 2})
	_check(village.complete_sacrifice(altar, T + 3) == null, "an empty altar sacrifices nothing")

	# Refuges take any unit; the fortress takes units that shoot.
	_check(village.push_unit(archer, refuge, T) == Village.Placement.OK and village.push_unit(cow, refuge, T) == Village.Placement.OK, "an archer and a cow go into the small refuge")
	_check(not village.can_enter(at.call(28), refuge), "the small refuge has room for 2 units")
	_check(village.can_enter(at.call(31), fortress) and not village.can_enter(at.call(30), fortress) and not village.can_enter(catapult, fortress), "an archer goes into the fortress; a spearman and a catapult do not")
	_check(village.population() == population + 1 - 1, "units in a refuge count for the population")

	# The warehouse keeps units outside the map and the population.
	_check(village.warehouse_capacity() == 3 and village.warehoused_units() == {HEALER: 1}, "the warehouse holds 1 healer of 3 places")
	population = village.population()
	_check(village.push_unit(at.call(31), warehouse, T) == Village.Placement.OK and village.population() == population - 1, "an archer goes into the warehouse and leaves the population")
	_check(village.push_unit(at.call(30), warehouse, T) == Village.Placement.OK and not village.can_enter(catapult, warehouse), "a spearman fills the warehouse")
	_check(village.warehoused_units() == {HEALER: 1, LIGHT_ARCHER: 1, SPEARMAN: 1}, "the warehouse holds a healer, an archer and a spearman")
	var cash := village.get_resource("c")
	_check(village.buy_warehouse_slot() == Village.Placement.OK and village.warehouse_capacity() == 4 and village.can_enter(catapult, warehouse), "one more place costs 2 cash")
	_expect("after the place", village, {"c": cash - 2})
	_check(village.place_warehoused(warehouse, SPEARMAN, T + 5) == Village.Placement.OK, "the spearman comes out of the warehouse")
	var back: Village.PlacedItem = village.items.back()
	_check(back.item_id == SPEARMAN and Village.footprint(_config.get_item(UNIT_WAREHOUSE), warehouse.tile).grow(1).has_point(back.tile), "the spearman stands next to the warehouse")
	_check(village.place_warehoused(warehouse, SPEARMAN, T + 5) == Village.Placement.NOT_ALLOWED, "the warehouse has no more spearmen")

	# A sold building first lets its units out.
	_check(village.sell(refuge, T + 6) == Village.Placement.OK, "the refuge with units is sold")
	var tiles := Village.footprint(_config.get_item(SMALL_REFUGE), refuge.tile).grow(1)
	_check(village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id in [LIGHT_ARCHER, COW] and tiles.has_point(placed.tile)).size() == 2, "the archer and the cow come out of the sold refuge")

	_check(village.save_to_file(path) == OK, "the village with the unit buildings saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["maps"][0]["warehousedUnits"] == {str(HEALER): 1.0, str(LIGHT_ARCHER): 1.0} and int(saved["maps"][0]["warehouseAditionalCapacitySingle"]) == 4, "the save has the warehouse units and places")
	_check(saved["privateState"]["boughtUnits"].has(float(LIGHT_KNIGHT)) and saved["privateState"]["boughtUnits"].has(float(HORSE)), "the server lists the knight and the horse")

	# Units out of the warehouse need the population and count for the unit limit: a map can have 5 healers.
	items = _initial["maps"][0]["items"].duplicate(true) + [[UNIT_WAREHOUSE, 35, 52, 0, T, 0, [], {}]]
	for i in 10:
		items.append([HEALER if i < 5 else VILLAGER, 21 + i, 56, 0, T, 0, [], {}])
	village = Village.load_from_file(_write_fixture("warehouse_limit", 40, _config.levels[39].exp_required, 0, {"expansions": [13, 12], "items": items, "warehousedUnits": {str(HEALER): 1, str(SPEARMAN): 1}}), _config)
	_check(village.population() > village.max_population(), "the population is over its maximum")
	_check(village.place_warehoused(village.item_at(Vector2i(35, 52)), HEALER, T) == Village.Placement.UNIT_LIMIT_REACHED, "a sixth healer cannot come out of the warehouse")
	_check(village.place_warehoused(village.item_at(Vector2i(35, 52)), SPEARMAN, T) == Village.Placement.POPULATION_FULL, "a unit comes out of the warehouse only when the population has room")
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


## The Treasure Mine, the items of the collections, their rewards and the item store.
func _check_collections() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([TREASURE_MINE, 25, 45, 0, T, 0, [], {}])
	var path := _write_fixture("collections", 20, 20000, 100000, {"expansions": [13, 12], "items": items})
	var collections := [[]]
	for i in Collections.count():
		collections.append([0, 0, 0, 0, 0, 0])
	collections[3] = [0, 1, 1, 1, 1, 2]
	collections[1] = [0, 1, 0, 3, 0, 0]
	_patch_private(path, {"collections": collections}, 20)
	var village := Village.load_from_file(path, _config)
	var mine := village.item_at(Vector2i(25, 45))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_check(Collections.loot(Collections.Source.HARVEST, 4.0, rng) == Vector2i.ZERO, "a harvest roll of 4 finds nothing")
	var found := Collections.loot(Collections.Source.HARVEST, 0.2, rng)
	_check(found != Vector2i.ZERO and Collections.TABLE[found.x - 1][1][found.y - 1][1] == Collections.Source.HARVEST and Collections.TABLE[found.x - 1][1][found.y - 1][2] == Collections.Rarity.EPIC, "a harvest roll of 0.2 finds an epic item of a harvest")
	found = Collections.loot(Collections.Source.HARVEST, 3.0, rng)
	_check(found != Vector2i.ZERO and Collections.TABLE[found.x - 1][1][found.y - 1][2] == Collections.Rarity.UNCOMMON, "a harvest roll of 3 finds an uncommon item")
	found = Collections.loot(Collections.Source.CHEST, 0.2, rng)
	_check(found.x in [19, 20], "a chest roll of 0.2 finds an epic item; only collections 19 and 20 have epic chest items")
	_check(Collections.loot(Collections.Source.CHEST, 3.0, rng) == Vector2i.ZERO, "a chest roll of 3 finds nothing, because chests have no uncommon items")
	var hardcore := 0
	for i in 200:
		hardcore += 1 if Collections.loot(Collections.Source.HARDCORE, 0.2, rng) != Vector2i.ZERO else 0
	_check(hardcore > 60 and hardcore < 140, "the hardcore source drops about half of the time: %d of 200" % hardcore)
	_check(village.is_producer(mine) and village.seconds_to_ready(mine, T + 86399) > 0 and village.seconds_to_ready(mine, T + 86400) == 0, "the Treasure Mine is ready after 24 hours")
	var gold := village.get_resource("g")
	var xp := village.get_xp()
	_check(village.collect(mine, T + 86400) == Village.Production.OK, "the Treasure Mine collects")
	_expect("after the Treasure Mine", village, {"g": gold, "xp": xp + 1})

	_check(not village.can_complete_collection(1) and village.collection_cash_price(1) == 3, "collection 1 with 2 kinds costs 5 - 2 cash")
	_check(village.collection_cash_price(10) == 15 and village.collection_cash_price(23) == 0, "collection 10 has a fixed price; collection 23 has no price")
	_check(village.can_complete_collection(3) and village.collection_cash_price(3) == 1, "collection 3 is complete; for cash it costs at least 1")
	_check(village.complete_collection(3, false) == Village.Placement.OK, "collection 3 gives its reward")
	_check(village.collected(3, 1) == 0 and village.collected(3, 5) == 1 and village.stored_items() == {GARDEN: 1}, "the items are used and the garden is in the item store")
	var cash := village.get_resource("c")
	_check(village.complete_collection(1, true) == Village.Placement.OK and village.get_resource("c") == cash - 3 and village.collected(1, 3) == 3, "collection 1 for cash keeps the items")
	_check(village.save_to_file(path) == OK, "the village with the rewards saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["privateState"]["collectionsCompleted"] == [3.0, 1.0] and saved["privateState"]["collections"][3][0] == 1.0, "the save keeps the completed collections")
	_check(saved["maps"][0]["store"] == {"178": 1.0, "176": 1.0}, "the save keeps the rewards in the item store")
	var garden := _config.get_item(GARDEN)
	gold = village.get_resource("g")
	xp = village.get_xp()
	_check(village.place_stored(garden, Vector2i(5, 5), T) == Village.Placement.NOT_OWNED_LAND, "a stored item needs own land")
	var tile := _free_tile(village, GARDEN, Rect2i(20, 40, 20, 20))
	_check(village.place_stored(garden, tile, T) == Village.Placement.OK and village.item_at(tile).item_id == GARDEN, "the garden is placed from the item store")
	_expect("after the stored item", village, {"g": gold, "xp": xp})
	_check(not village.stored_items().has(GARDEN) and village.place_stored(garden, tile + Vector2i(4, 0), T) == Village.Placement.NOT_ALLOWED, "the item store has no garden now")
	_check(village.get_resource("p") == 0, "potions are a resource")
	var count_items := func() -> int:
		var total := 0
		for collection in range(1, Collections.count() + 1):
			for index in range(1, Collections.ITEMS_PER_COLLECTION + 1):
				total += village.collected(collection, index)
		return total
	var before: int = count_items.call()
	var finds := 0
	for i in 20:
		finds += 1 if village.find_collectible(true, rng) != Vector2i.ZERO else 0
	_check(finds > 0 and count_items.call() == before + finds, "the items that the Treasure Mine finds are counted: %d of 20" % finds)
	return true


## The free dragon nest and Soul Mixer, and the care of the dragon nest.
func _check_nests() -> bool:
	const T := 1800000000
	var path := _write_fixture("nests", 5, _config.levels[4].exp_required, 200000, {"expansions": [13, 12]})
	# The initial save has active nests.
	_patch_private(path, {"dragonNestActive": 0, "dragonNumber": 0, "stepNumber": 0, "timeStampTakeCare": 0}, 100)
	var village := Village.load_from_file(path, _config)
	var free := village.add_free_buildings(T)
	_check(free.size() == 1 and free[0].item_id == DRAGON_NEST and village.check_location(_config.get_item(DRAGON_NEST), free[0].tile, free[0]) == Village.Placement.OK, "below level 8 the client gives only a free dragon nest, on free own land")
	_check(village.add_free_buildings(T).is_empty(), "the client gives the nest only once")
	var nest := free[0]
	_check(not village.is_nest_active(nest) and village.care_for_nest(nest, T) == Village.Placement.NOT_ALLOWED, "an inactive nest cannot have care")
	var gold := village.get_resource("g")
	_check(village.activate_nest(nest, "g") == Village.Placement.OK, "the nest starts for gold")
	_expect("after the nest starts", village, {"g": gold - 100000})
	_check(village.nest_unit(nest).id == DRAGGY and village.nest_wait_cash(nest) == 3, "the first dragon is Draggy, and a wait costs 3 cash")
	var cash := village.get_resource("c")
	var now := T
	for step in Village.NEST_STEPS:
		_check(village.care_for_nest(nest, now) == Village.Placement.OK, "care step %d" % (step + 1))
		_check(village.nest_steps_done(nest, now) == step and village.care_for_nest(nest, now + 100) == Village.Placement.NOT_ALLOWED, "step %d counts only after its wait" % (step + 1))
		if step % 2 == 0:
			now += Village.NEST_STEP_SECONDS
		else:
			_check(village.end_nest_wait(nest, now) == Village.Placement.OK, "cash ends the wait of step %d" % (step + 1))
	_expect("after 5 waits with cash", village, {"c": cash - 15})
	_check(village.nest_steps_done(nest, now) == Village.NEST_STEPS, "the dragon has all steps")
	var xp := village.get_xp()
	_check(village.take_nest_unit(nest, now) == Village.Placement.OK and village.items.back().item_id == DRAGGY, "Draggy comes out of the nest")
	_expect("after Draggy", village, {"xp": xp + _config.get_item(DRAGGY).xp})
	_check(village.nest_unit(nest).id == FURIOUS_DRAGON and village.nest_steps_done(nest, now) == 0 and village.nest_wait_cash(nest) == 15, "the second dragon starts, and a wait costs 15 cash")
	_check(village.save_to_file(path) == OK, "the village with the nest saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var state: Dictionary = saved["privateState"]
	_check([state["dragonNestActive"], state["dragonNumber"], state["stepNumber"], state["timeStampTakeCare"]] == [1.0, 1.0, 0.0, 0.0], "the save has the state of the nest")

	var last_path := "user://checks/nests_last.json"
	DirAccess.copy_absolute(path, last_path)
	_patch_private(last_path, {"dragonNestActive": 1, "dragonNumber": 5, "stepNumber": 10, "timeStampTakeCare": 0}, 100)
	village = Village.load_from_file(last_path, _config)
	nest = village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == DRAGON_NEST)[0]
	_check(village.take_nest_unit(nest, now) == Village.Placement.OK and not village.is_nest_active(nest), "after the last dragon the nest stops")
	return true


## The Rider Academy and Dragon Riding.
func _check_riders() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([RIDER_ACADEMY, 25, 45, 0, T, 0, [], {}])
	items.append([DRAGON_RIDING, 30, 45, 0, T, 0, [], {}])
	var path := _write_fixture("riders", 34, 2000000, 200000, {"expansions": [13, 12], "items": items})
	_patch_private(path, {}, 100)
	var village := Village.load_from_file(path, _config)
	_check(village.select_rider(1) == Village.Placement.LEVEL_TOO_LOW, "Dragon Rider I needs level 35")
	path = _write_fixture("riders", 50, HIGHEST_LEVEL_XP, 200000, {"expansions": [13, 12], "items": items})
	_patch_private(path, {}, 100)
	village = Village.load_from_file(path, _config)
	var academy := village.item_at(Vector2i(25, 45))
	var riding := village.item_at(Vector2i(30, 45))
	var free := village.add_free_buildings(T)
	_check(free.map(func(placed: Village.PlacedItem) -> int: return placed.item_id) == [DRAGON_NEST, SOUL_MIXER], "from level 8 the client also gives a free Soul Mixer")
	_check(village.select_rider(1) == Village.Placement.OK and village.select_rider(2) == Village.Placement.NOT_ALLOWED, "the academy trains one rider at a time")
	var cash := village.get_resource("c")
	var now := T
	for step in 5:
		_check(village.train_rider(now) == Village.Placement.OK and village.train_rider(now) == Village.Placement.NOT_ALLOWED, "training step %d, then a wait" % (step + 1))
		_check(village.end_rider_wait(now) == Village.Placement.OK, "cash ends the wait of step %d" % (step + 1))
	_expect("after 5 waits with cash", village, {"c": cash - 75})
	_check(village.train_rider(now) == Village.Placement.NOT_ALLOWED and village.take_rider(academy, now) == Village.Placement.OK, "after 5 steps the rider is trained")
	var rider: Village.PlacedItem = village.items.back()
	_check(rider.item_id == DRAGON_RIDER_I and village.rider_type() == 0, "Dragon Rider I comes out, and the academy is free")

	village.buy(_config.get_item(FURIOUS_DRAGON), _free_tile(village, FURIOUS_DRAGON, Rect2i(20, 40, 20, 20)), T)
	var dragon: Village.PlacedItem = village.items.back()
	village.buy(_config.get_item(EPIC_TWO_HEAD_DRAGON), _free_tile(village, EPIC_TWO_HEAD_DRAGON, Rect2i(20, 40, 20, 20)), T)
	var wrong_dragon: Village.PlacedItem = village.items.back()
	_check(village.push_unit(dragon, riding, T) == Village.Placement.OK and not village.can_enter(wrong_dragon, riding), "a second dragon cannot go into Dragon Riding")
	_check(village.tame(riding, T) == Village.Placement.NOT_ALLOWED, "a dragon alone cannot be tamed")
	_check(village.push_unit(rider, riding, T) == Village.Placement.OK, "the rider goes in")
	var xp := village.get_xp()
	_check(village.tame(riding, T) == Village.Placement.OK and village.units_in(riding).is_empty() and village.items.back().item_id == FURIOUS_DRAGON_RIDER, "the rider tames the dragon")
	_expect("after the taming", village, {"xp": xp + _config.get_item(FURIOUS_DRAGON_RIDER).xp})
	village.buy(_config.get_item(DRAGON_RIDER_I), _free_tile(village, DRAGON_RIDER_I, Rect2i(20, 40, 20, 20)), T)
	village.push_unit(village.items.back(), riding, T)
	village.push_unit(wrong_dragon, riding, T)
	_check(village.units_in(riding).size() == 2 and village.tame(riding, T) == Village.Placement.NOT_ALLOWED, "Dragon Rider I cannot tame a dragon for Dragon Rider II")
	_check(village.save_to_file(path) == OK, "the village after the riders saves")
	return true


## The graveyard, the potions and the Heroes Grave.
func _check_graveyards() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([GRAVEYARD, 25, 45, 0, T, 0, [], {}])
	items.append([HEROES_GRAVE, 30, 45, 0, T, 0, [], {}])
	for i in 6:
		items.append([HOUSE, 21 + 2 * i, 41, 0, T, 0, [], {}])
	var path := _write_fixture("graveyards", 20, 20000, 10000, {"expansions": [13, 12], "items": items})
	_patch_private(path, {"resurrectableUnits": [FURIOUS_DRAGON, SPEARMAN, FURIOUS_DRAGON], "deadHeroes": {str(HEALER): 1}, "potion": 2}, 10)
	var village := Village.load_from_file(path, _config)
	var graveyard := village.item_at(Vector2i(25, 45))
	var grave := village.item_at(Vector2i(30, 45))
	_check(village.graveyard_units() == {FURIOUS_DRAGON: 2, SPEARMAN: 1} and village.dead_heroes() == {HEALER: 1}, "the graveyards list the dead units")
	_check(village.resurrect(graveyard, FURIOUS_DRAGON, T) == Village.Placement.NOT_ENOUGH_RESOURCES, "the dragon needs 4 potions")
	_check(village.buy_potions() == Village.Placement.OK, "the graveyard sells potions")
	_expect("after the potions", village, {"c": 5, "p": 27})
	var xp := village.get_xp()
	_check(village.resurrect(graveyard, FURIOUS_DRAGON, T) == Village.Placement.OK and village.items.back().item_id == FURIOUS_DRAGON, "the dragon comes back")
	_expect("after the dragon", village, {"p": 23, "xp": xp})
	_check(village.graveyard_units() == {FURIOUS_DRAGON: 1, SPEARMAN: 1}, "one dragon is still in the graveyard")
	_check(village.resurrect_hero(grave, HEALER, T) == Village.Placement.OK and village.dead_heroes().is_empty(), "the healer comes back")
	_expect("after the healer", village, {"g": 10000 - 4 * Village.RESURRECT_GOLD_PER_CASH})
	_check(village.save_to_file(path) == OK, "the village after the graveyards saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["privateState"]["resurrectableUnits"] == [float(SPEARMAN), float(FURIOUS_DRAGON)] and saved["privateState"]["deadHeroes"].is_empty() and saved["privateState"]["potion"] == 23.0, "the save has the graveyards")
	return true


## The Soul Mixer: the result, a power-up, the mix and the units that come back.
func _check_soul_mixer() -> bool:
	const T := 1800000000
	var items: Array = _initial["maps"][0]["items"].duplicate(true)
	items.append([SOUL_MIXER, 25, 45, 0, T, 0, [], {}])
	for i in 6:
		items.append([HOUSE, 21 + 2 * i, 41, 0, T, 0, [], {}])
	items.append([SPEARMAN, UNIT_TILES[0].x, UNIT_TILES[0].y, 0, T, 0, [], {}])
	items.append([LIGHT_KNIGHT, UNIT_TILES[1].x, UNIT_TILES[1].y, 0, T, 0, [], {}])
	items.append([VILLAGER, UNIT_TILES[2].x, UNIT_TILES[2].y, 0, T, 0, [], {}])
	var path := _write_fixture("soul_mixer", 20, 20000, 10000, {"expansions": [13, 12], "items": items})
	_patch_private(path, {}, 100)
	var village := Village.load_from_file(path, _config)
	var mixer := village.item_at(Vector2i(25, 45))
	var spearman := village.item_at(UNIT_TILES[0])
	var knight := village.item_at(UNIT_TILES[1])
	var count_units := func(ids: Array) -> int: return village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id in ids).size()
	var units_before: int = count_units.call([SPEARMAN, LIGHT_KNIGHT])
	_check(not village.can_enter(village.item_at(UNIT_TILES[2]), mixer), "a villager has no soul power")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	village.push_unit(spearman, mixer, T)
	_check(village.soul_mix_result(mixer, rng) == null, "one unit does not mix")
	village.push_unit(knight, mixer, T)
	var result := village.soul_mix_result(mixer, rng)
	# Powers 12 and 19: ceil(12 * 0.3 + 19 * 0.7) = 17, plus 0 to 11.
	_check(result != null and result.breeding_order >= 17 and not result.id in [SPEARMAN, LIGHT_KNIGHT], "the result is stronger than 17 and is not one of the two units")
	_check(village.soul_mix_result(mixer, rng) == result, "the result stays until the mix")
	var population := village.population()
	_check(village.power_up_soul_mix(mixer, rng) == Village.Placement.OK, "a power-up")
	var stronger := village.soul_mix_result(mixer, rng)
	_check(stronger.breeding_order >= result.breeding_order and stronger != result and village.soul_power_ups_cash(mixer) == 1, "the power-up gives a stronger unit for 1 cash")
	var cash := village.get_resource("c")
	var xp := village.get_xp()
	_check(village.mix_souls(mixer, T, rng) == Village.Placement.OK and village.get_resource("c") == cash - 1, "the mix pays the power-up")
	_check(village.population() == population and not village.can_enter(village.item_at(UNIT_TILES[2]), mixer), "the mix does not count for the population yet")
	_check(village.complete_training(mixer, T + stronger.sm_training_time) == null, "the client does not take the mixed unit out by itself")
	_check(village.take_soul_mix(mixer, T) == Village.Placement.NOT_ALLOWED, "the mix needs its time")
	_check(village.speed_up_cost(mixer, T) == ceili(stronger.sm_training_time / 3600.0) and village.speed_up_training(mixer, T) == Village.Training.OK, "cash ends the mix")
	_check(village.take_soul_mix(mixer, T) == Village.Placement.OK, "the mixed unit comes out")
	_check(village.units_in(mixer).is_empty() and count_units.call([SPEARMAN, LIGHT_KNIGHT]) == units_before and count_units.call([stronger.id]) >= 1, "the two units come back out with the new unit")
	_expect("after the mix", village, {"xp": xp})
	_check(village.unqueue_unit(mixer) == Village.Training.NOT_TRAINER, "the Soul Mixer has no training queue to cancel")
	_check(village.save_to_file(path) == OK, "the village after the mix saves")
	return true


## Sets privateState values and the cash of the fixture at path.
## The goal list: the active goals, the counts of the session, the rewards
## in the save, and the goals that read the save.
func _check_goals() -> bool:
	_check(_config.goals.size() == 205 and _config.goals[0].id == 1 and _config.goals[9].id == 9, "the configuration has 205 goals in its order, without goal 0")
	var path := _write_fixture("goals", 1, 4, 1000)
	var village := Village.load_from_file(path, _config)
	var steps := {}
	var goals := GoalBook.new(village, _config, steps)
	var completed: Array[int] = []
	goals.goal_completed.connect(func(goal: GameConfig.GoalDef) -> void: completed.append(goal.id))
	_check(not goals.on_map_loaded() and goals.active_goals().size() == GoalBook.MAX_ACTIVE, "a new village has 15 active goals and none is complete")
	_check(goals.shown_goals().map(func(goal: GameConfig.GoalDef) -> int: return goal.id) == [1, 2], "the goal box shows the first two goals")
	_check(goals.progress_text(_goal(8)) == "2/4", "the two houses of the map count for the house goal when the map loads")
	var farm := _config.get_item(10)
	_buy(village, 10, _free_tile(village, 10, Rect2i(40, 40, 20, 20)), Village.Placement.OK)
	_check(completed == [1] and village.goal_ids("rewarded") == [1] and village.goal_ids("completed") == [1], "a farm completes the farm goal, which the save lists as completed and rewarded")
	_expect("after the farm goal", village, {"g": 1000 - farm.cost * int(farm.cost_type == "g") + 10})
	_check(goals.shown_goals().map(func(goal: GameConfig.GoalDef) -> int: return goal.id) == [2, 3], "the next goal comes into the box")
	_check(goals.steps_done(_goal(24)) == 1, "a goal that is not active yet counts too")
	for i in 14:
		goals.record(VillageEvent.Kind.ZOOMED, {})
	_check(not 6 in completed, "14 steps of the mouse wheel do not complete the zoom goal")
	goals.record(VillageEvent.Kind.ZOOMED, {})
	_check(6 in completed, "the 15th step completes it")
	_buy(village, 10, _free_tile(village, 10, Rect2i(40, 40, 20, 20)), Village.Placement.OK)
	_check(7 in completed and not 24 in completed, "the second farm completes the goal of two farms, not the goal of five")
	_check(goals.hint(_goal(10)).get("text") == _config.text("GOALS_BUILDING_NOT_FOUND").replace("#0#", _config.get_item(38).name), "the hint of a goal without its building is the alert of the client")
	_check(goals.hint(_goal(9)).get("build") == _config.get_item(38), "the hint of a building goal opens the build menu with the building")
	_check(goals.progress_text(_goal(98)) == "0/8", "a goal of work time shows hours")
	village.reward_goal(_goal(2))
	_check(village.goal_ids("rewarded").count(2) == 1 and village.goal_ids("completed").count(2) == 1, "a goal is rewarded once")
	_check(village.save_to_file(path) == OK, "the village with goals saves")
	village = Village.load_from_file(path, _config)
	goals = GoalBook.new(village, _config, {})
	goals.on_map_loaded()
	_check(goals.shown_goals()[0].id == 3 and goals.steps_done(_goal(7)) == 2, "after a load the rewarded goals stay done and the farms count again")
	# The server completes the land goals of a map that already has the land.
	path = _write_fixture("goals_land", 10, _config.levels[9].exp_required, 1000, {"expansions": [13, 12, 14]})
	village = Village.load_from_file(path, _config)
	goals = GoalBook.new(village, _config, {})
	_check(goals.on_map_loaded() and 73 in village.goal_ids("rewarded") and 171 in village.goal_ids("rewarded") and not 239 in village.goal_ids("rewarded"), "a map with 3 land areas completes the goals of 2 and 3 areas at the load")
	return true


func _goal(id: int) -> GameConfig.GoalDef:
	for goal in _config.goals:
		if goal.id == id:
			return goal
	return null


## The actions of the village that the goals need: the item store, the name,
## land, the market, workers, unit packs, repairs and the healing spring.
func _check_village_actions() -> bool:
	var path := _write_fixture("actions", 20, _config.levels[19].exp_required, 100000)
	_patch_private(path, {}, 200)
	var village := Village.load_from_file(path, _config)
	var events := []
	village.happened.connect(func(kind: VillageEvent.Kind, data: Dictionary) -> void: events.append([kind, data]))
	var town_hall := village.item_at(TOWN_HALL_TILE)
	_check(not village.can_store(town_hall), "the town hall cannot go into the item store")
	var garden_tile := _free_tile(village, GREEN_TREE, Rect2i(40, 40, 20, 20))
	_buy(village, GREEN_TREE, garden_tile, Village.Placement.OK)
	var tree := village.item_at(garden_tile)
	_check(village.store_item(tree, NOW) == Village.Placement.OK and village.item_at(garden_tile) == null and village.stored_items().get(GREEN_TREE) == 1, "a decoration goes into the item store")
	_check(events.any(func(event: Array) -> bool: return event[0] == VillageEvent.Kind.STORED and event[1]["item"] == GREEN_TREE), "the store sends the event of the store goal")
	_check(village.rename("  Camelot ") == Village.Placement.OK and village.map_name() == "Camelot" and village.rename(" ") == Village.Placement.NOT_ALLOWED, "the map gets a name; an empty name is refused")
	# Land: the price of the second area, and gold only with neighbours.
	_check(village.next_land_price() == {"coins": 4000, "cash": 20, "neighbors": 1}, "the second land area costs 4000 gold with 1 neighbour, or 20 cash")
	_check(not village.can_buy_land(1) and village.buy_land(14, false, 0) == Village.Placement.NEIGHBOURS_NEEDED, "a far area cannot be bought, and gold needs a neighbour")
	_check(village.buy_land(14, true, 0) == Village.Placement.OK and 14 in village.owned_land and village.next_land_price()["cash"] == 25, "the area is bought for cash, and the next costs 25 cash")
	_expect("after the land", village, {"c": 180})
	# The market: 100 of a resource at Market I.
	var market_tile := _free_tile(village, MARKET, Rect2i(40, 40, 20, 20))
	_buy(village, MARKET, market_tile, Village.Placement.OK)
	var market := village.item_at(market_tile)
	_check(village.market() == null and village.trade("w", false, NOW) == Village.Placement.NOT_ALLOWED, "the market trades only when its workers opened it")
	while village.hire_worker(market) == Village.Placement.OK:
		pass
	village.open_building(market)
	_check(village.market() == market and village.market_amount() == 100 and village.market_trades_left(NOW) == Village.MARKET_MAX_TRADES, "Market I trades 100 of a resource, 20 times")
	_check(village.market_price("w", false) == 100 and village.market_price("s", true) == 112, "100 wood costs 100 gold; 100 stone sells for 112 gold, as the server rounds")
	var gold := village.get_resource("g")
	var wood := village.get_resource("w")
	_check(village.trade("w", false, NOW) == Village.Placement.OK and village.get_resource("w") == wood + 100 and village.get_resource("g") == gold - 100, "buying wood gives 100 wood for 100 gold")
	_check(village.market_price("w", false) == 102 and village.market_trades_left(NOW) == Village.MARKET_MAX_TRADES - 1, "the next wood costs 2% more, and one trade is used")
	var stone := village.get_resource("s")
	_check(village.trade("s", true, NOW) == Village.Placement.OK and village.get_resource("s") == stone - 112 and village.get_resource("g") == gold - 100 + 112, "a sale takes the price in stone, as the server does, and gives it in gold")
	# A building with workers.
	var mill_tile := _free_tile(village, 6, Rect2i(40, 40, 20, 20))
	_buy(village, 6, mill_tile, Village.Placement.OK)
	var mill := village.item_at(mill_tile)
	_check(village.is_being_built(mill) and village.workers(mill) == [1, 6] and not village.is_producer(mill), "Mill II needs 6 workers, has the player's villager, and does not work yet")
	_check(village.open_building(mill) == Village.Placement.NOT_ALLOWED, "it cannot open without its workers")
	for i in 5:
		village.hire_worker(mill)
	_check(village.workers(mill) == [6, 6] and village.hire_worker(mill) == Village.Placement.NOT_ALLOWED, "5 workers are hired, and no more")
	_check(village.open_building(mill) == Village.Placement.OK and not village.is_being_built(mill) and village.is_producer(mill) and not mill._entry[7].has("si"), "the mill opens and works")
	_check(events.any(func(event: Array) -> bool: return event[0] == VillageEvent.Kind.SOCIAL_BUILDING_OPENED and event[1]["item"] == 6), "the opening sends the event of its goal")
	_expect("after the workers", village, {"c": 166})
	# Unit packs: the first pack is one Guardian for 50 gold, once.
	var pack := village.unit_pack_for_slot(1, NOW)
	_check(int(pack.get("id", 0)) == 1 and village.max_unit_packs(pack) == 1 and village.unit_pack_cost(pack, 1) == ["g", 50], "the first place of the store has the Guardian pack for 50 gold, once")
	_check(village.unit_pack_cost(_config.unit_packs[2], 8) == ["c", 41], "8 packs of 6 cash cost 15% less, rounded up as the server does")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var stored := village.stored_items().size()
	var units := village.buy_unit_packs(pack, 1, rng)
	_check(units.size() == 1 and units[0] in pack["custom"].map(func(entry: Dictionary) -> int: return int(entry["id"])) and village.stored_items().size() == stored + 1, "the pack gives one of its units, which goes into the item store")
	_check(village.unit_packs_bought([1]) == 1 and village.unit_pack_for_slot(1, NOW).get("id", 0) != 1, "the pack is bought out")
	# Damage, repairs and the healing spring.
	var house := village.item_at(HOUSE_TILE)
	village.set_health(house, 10)
	village._stored()[str(VILLAGER)] = 1
	_check(village.place_stored(_config.get_item(VILLAGER), _free_tile(village, VILLAGER, Rect2i(44, 46, 8, 8)), NOW) == Village.Placement.OK, "a villager comes out of the item store")
	var villager := village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == VILLAGER and village.is_own_unit(placed))
	_check(not villager.is_empty() and village.can_repair(villager[0], house), "a villager can repair a damaged house")
	var repairs := 0
	while not village.repair(house):
		repairs += 1
	_check(repairs == ceili((_config.get_item(HOUSE).life - 10) / float(Village.REPAIR_STEP)) - 1 and not village.is_damaged(house), "each repair step gives 25 life until the house is whole")
	_check(events.any(func(event: Array) -> bool: return event[0] == VillageEvent.Kind.FIRE_PUT_OUT), "the repair sends the event of its goal")
	var spring_id: int = _config.items().filter(func(item: GameConfig.ItemDef) -> bool: return item.subcat_functional == Village.SUBCAT_HEALING)[0].id
	var spring_tile := _free_tile(village, spring_id, Rect2i(44, 44, 12, 12))
	_check(village.place_stored(_config.get_item(spring_id), spring_tile, NOW) == Village.Placement.NOT_ALLOWED, "a spring that the store does not have cannot be placed")
	village._stored()[str(spring_id)] = 1
	_check(village.place_stored(_config.get_item(spring_id), spring_tile, NOW) == Village.Placement.OK, "a healing spring is placed")
	var spring := village.item_at(spring_tile)
	village.set_health(villager[0], 5)
	var target := village.spring_target(spring)
	if target == villager[0]:
		village.heal(spring, villager[0])
		_check(village.health(villager[0]) == mini(5 + _config.get_item(spring_id).attack, _config.get_item(VILLAGER).life), "the spring heals the damaged villager near it by its attack")
	else:
		_check(Vector2(villager[0].tile).distance_to(Vector2(Village.footprint(_config.get_item(spring_id), spring_tile).get_center())) > _config.get_item(spring_id).attack_range, "the spring heals only units in its range")
	_check(village.save_to_file(path) == OK, "the village after the actions saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var game_map: Dictionary = saved["maps"][0]
	_check(saved["playerInfo"]["map_names"][0] == "Camelot" and game_map["expansions"].has(14.0) and game_map["numTradesDone"] == 2 and game_map["resourcesTraded"] == {"w": 1.0, "s": -1.0} and saved["privateState"]["unitPacks"] == {"1": 1.0}, "the save has the name, the land, the trades and the pack as the server writes them")
	return true


## The neighbours of the import, help in visits, help from neighbours, and the
## workers that the server hires from the neighbours.
func _check_neighbours() -> bool:
	var source := NeighbourSource.load_from(_neighbour_copy(), _config)
	var list := source.neighbours("port_player")
	var pids: Array = list.map(func(entry: Dictionary) -> String: return entry["pid"])
	_check(pids.size() == 11 and pids[0] == "AcidCaos" and pids[1] == "mock_1" and not pids.any(func(pid: String) -> bool: return pid in NeighbourSource.ARTHUR_IDS), "the neighbours are the friend village and the 10 mock villages, without Arthur, in the order of the server")
	_check(source.has("100000032") and source.load_village("100000032", NOW).get_level() == 34, "the villages of Arthur and Guinevere can be visited")
	var path := _write_fixture("neighbours", 20, _config.levels[19].exp_required, 100000)
	_patch_private(path, {}, 200)
	var village := Village.load_from_file(path, _config)
	village.neighbour_ids.assign(pids)
	var events := []
	village.happened.connect(func(kind: VillageEvent.Kind, data: Dictionary) -> void: events.append([kind, data]))
	var mill_tile := _free_tile(village, 6, Rect2i(40, 40, 20, 20))
	_buy(village, 6, mill_tile, Village.Placement.OK)
	var mill := village.item_at(mill_tile)
	_check(mill._entry[7]["si"] == ["0", "AcidCaos", "mock_1", "mock_10", "mock_2", "mock_3"] and village.open_building(mill) == Village.Placement.OK, "Mill II gets the villager and the first 5 neighbours, as hire_friends of the server, and opens")
	_check(events.any(func(event: Array) -> bool: return event[0] == VillageEvent.Kind.WORKERS_HIRED and event[1]["amount"] == 6), "the workers send the event of the goal that counts them")
	_check(village.buy_land(14, false, village.neighbour_ids.size()) == Village.Placement.OK, "with neighbours, the second land area is sold for gold")
	# Help for a neighbour: once a day, honour for 5 buildings.
	_check(village.can_assist("mock_1", NOW), "a neighbour that the player never helped can be helped")
	village.assist_neighbour("mock_1", 4, NOW)
	_check(village.honour() == 0 and not village.can_assist("mock_1", NOW + 3600) and village.can_assist("mock_1", NOW + 86401), "4 buildings give no honour; the neighbour can be helped again after a day")
	village.assist_neighbour("mock_2", 5, NOW)
	_check(village.honour() == _config.honour_help_friend, "5 buildings give honour")
	village.assist_neighbour("mock_3", 0, NOW)
	_check(village.can_assist("mock_3", NOW), "a visit without help does not count")
	var arthur := source.load_village("100000031", NOW)
	var helped := arthur.items.filter(func(placed: Village.PlacedItem) -> bool: return VillageSocial.is_assistable(_config.get_item(placed.item_id)))
	_check(not helped.is_empty() and not VillageSocial.is_assistable(_config.get_item(TREASURE_MINE)) and not VillageSocial.is_assistable(_config.get_item(HOUSE)), "farms, mills and mines can be helped; the Treasure Mine and houses not")
	# Help from a neighbour, as the save of the server keeps it.
	var farm_tile := _free_tile(village, PUMPKIN_CROP, Rect2i(40, 40, 20, 20))
	_buy(village, PUMPKIN_CROP, farm_tile, Village.Placement.OK)
	village._map["receivedAssists"] = {"mock_4": [[farm_tile.x, farm_tile.y, PUMPKIN_CROP], [1, 1, PUMPKIN_CROP]], "mock_5": [[farm_tile.x, farm_tile.y, PUMPKIN_CROP]]}
	var food := village.get_resource("f")
	var xp := village.get_xp()
	var accepted := village.accept_assist("mock_4")
	_check(accepted.size() == 1 and village.get_resource("f") == food + floori(_config.get_item(PUMPKIN_CROP).collect / 4.0) and village.get_xp() == xp + 10, "the help gives a quarter of the collect of each building that is still there, and 10 experience")
	village.decline_assist("mock_5")
	_check(village.received_assists().is_empty(), "accepted and declined help leaves the save")
	return true


## The allies buildings: the Allies Building, the Allies Market and the Recruitment Prize.
func _check_allies_buildings() -> bool:
	var path := _write_fixture("allies", 20, _config.levels[19].exp_required, 100000)
	_patch_private(path, {}, 200)
	var village := Village.load_from_file(path, _config)
	village.neighbour_ids.assign(["n1", "n2"])
	var market_tile := _free_tile(village, 266, Rect2i(40, 40, 20, 20))
	_buy(village, 266, market_tile, Village.Placement.OK)
	var market := village.item_at(market_tile)
	_check(market._entry[7]["si"] == [] and village.allies_market_resource() == "n" and village.allies_market_seconds(market, NOW) == -1, "the Allies Market hires no one and waits for a resource")
	_check(village.set_allies_market_resource(market, "w", NOW) == Village.Placement.OK and village.allies_market_seconds(market, NOW) == 86400, "a chosen resource starts the day of the market")
	_check(village.hire_worker(market) == Village.Placement.OK and village.allies_market_amount(market) == 250, "a hired worker adds 125 wood to the 125")
	var wood := village.get_resource("w")
	_check(village.collect_allies_market(market, NOW + 100) == Village.Placement.NOT_ALLOWED and village.collect_allies_market(market, NOW + 86400) == Village.Placement.OK, "the market gives its resource after a day")
	_check(village.get_resource("w") == wood + 250 and market._entry[7]["si"] == [] and village.allies_market_resource() == "n", "it gives 250 wood, and the workers and the resource start again")
	var summit_tile := _free_tile(village, ALLIES_BUILDING, Rect2i(40, 40, 20, 20))
	_buy(village, ALLIES_BUILDING, summit_tile, Village.Placement.OK)
	var summit := village.item_at(summit_tile)
	_check(village.workers(summit) == [0, 9] and village.open_allies_building(summit, NOW).is_empty(), "the Allies Building needs 9 allies")
	for i in 9:
		village.hire_worker(summit)
	_check(village.workers(summit) == [9, 9] and village.get_resource("c") == 200 - 2 - 27, "9 allies cost 3 cash each")
	var room := village.population() + Village.SUMMIT_KNIGHTS <= village.max_population()
	_check(room or village.open_allies_building(summit, NOW).is_empty(), "the knights need room in the population")
	while village.population() + Village.SUMMIT_KNIGHTS > village.max_population():
		if village.buy(_config.get_item(HOUSE), _free_tile(village, HOUSE, Rect2i(20, 40, 40, 20)), NOW) != Village.Placement.OK:
			break
	var knights := village.open_allies_building(summit, NOW)
	_check(knights.size() == Village.SUMMIT_KNIGHTS and knights.all(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Village.ALLIANCE_KNIGHT and village.is_own_unit(placed)) and village.workers(summit) == [0, 9], "with all allies, 9 Alliance Knights come and the allies leave")
	var prize_tile := _free_tile(village, Village.RECRUITMENT_PRIZE, Rect2i(40, 40, 20, 20))
	_buy(village, Village.RECRUITMENT_PRIZE, prize_tile, Village.Placement.OK)
	var prize := village.item_at(prize_tile)
	var first: Dictionary = village.open_recruitment_prizes()[0]
	_check(village.take_recruitment_prize(prize, first) == Village.Placement.NOT_ALLOWED and village.hire_worker(prize) == Village.Placement.OK, "a prize needs its recruits; a recruit costs nothing")
	_check(village.take_recruitment_prize(prize, first) == Village.Placement.OK and village.stored_items().get(first["units"][0]) == 1 and village.workers(prize)[0] == 0, "the first prize gives its unit into the item store and uses the recruit")
	_check(not village.open_recruitment_prizes().any(func(other: Dictionary) -> bool: return other["id"] == first["id"]) and village._document["privateState"]["recruitmentPrices"] == [first["id"]], "the save keeps the prize as taken")
	var round_table_tile := _free_tile(village, ROUND_TABLE, Rect2i(40, 40, 20, 20))
	_buy(village, ROUND_TABLE, round_table_tile, Village.Placement.OK)
	_check(village.hire_worker(village.item_at(round_table_tile)) == Village.Placement.NOT_ALLOWED, "the Round Table takes only neighbours")
	return true


## Shields, the search, the end of an attack for both players, and the PvP battle.
func _check_pvp() -> bool:
	var path := _write_fixture("pvp", 20, _config.levels[19].exp_required, 100000)
	_patch_private(path, {}, 200)
	var village := Village.load_from_file(path, _config)
	_check(village.pvp_search_cost() == 25 and village.pay_pvp_search() == Village.Placement.OK and village.get_resource("g") == 100000 - 25, "a search costs 25 gold from level 11")
	_check(village.buy_shield(1, NOW) == Village.Placement.OK and village.get_resource("c") == 210 and village.shield_seconds(NOW) == 86400, "a shield of a day costs 10 cash, and the server gives back 20")
	_check(not village.can_buy_shield(1, NOW) and village.buy_shield(2, NOW + 10) == Village.Placement.OK and village.shield_seconds(NOW + 10) == 86400 - 10 + 172800, "each shield once; a second one adds its time")
	_check(village.can_buy_shield(1, NOW + 172800 + 11), "after the cooldown all shields can be bought again")
	village.drop_shield()
	_check(village.shield_seconds(NOW) == 0, "an attack ends the shield")
	var knights := village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == LIGHT_KNIGHT).size()
	var gold := village.get_resource("g")
	village.end_pvp_attack({"units": [[LIGHT_KNIGHT, 2, 2, 1]], "loot": {"g": 100, "w": 50, "s": 0, "f": 0}, "xp": 7, "won": false, "percentage": 0.2})
	_check(village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == LIGHT_KNIGHT).size() == knights - 1 and village.graveyard_units().get(LIGHT_KNIGHT, 0) == 1, "a unit that did not come back leaves the map for the graveyard")
	_check(village.get_resource("g") == gold + 100 and village.honour() == 40 and village.attacks_lost() == 1 and village._document["playerInfo"]["attacks_lost"] == 1, "a lost attack gives its loot and 5 honour for each tenth not taken, and counts as lost")
	village.end_pvp_attack({"units": [], "loot": {"g": 0, "w": 0, "s": 0, "f": 0}, "xp": 0, "won": true, "percentage": 1.0})
	_check(village.honour() == 40 + _config.honour_pvp_win and village.attacks_won() == 1, "a won attack gives 15 honour and counts as won")
	# The other player: shield and attack log, in the file of the neighbour.
	var source := NeighbourSource.load_from(_neighbour_copy(), _config)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var enemy := source.find_enemy("port_player", 5, NOW, rng)
	_check(source.has(enemy) and absi(source.load_village(enemy, NOW).get_level() - 5) <= NeighbourSource.SEARCH_LEVEL_RANGE and not enemy in NeighbourSource.ARTHUR_IDS, "the search finds a village within 10 levels, never Arthur")
	_check(source.record_attack("mock_1", {"name": "Emperor", "level": 20, "id": "port_player"}, true, {"g": 5}, NOW), "the attack is written into the village of the neighbour")
	var victim := source.load_village("mock_1", NOW)
	_check(victim.shield_seconds(NOW) == VillageSocial.PVP_VICTIM_SHIELD_SECONDS and victim.attacks_received().size() == 1 and victim.attacks_received()[0]["attackWinner"] == "port_player", "the neighbour gets a shield of 12 hours and the attack in its log")
	var found := {}
	for i in 30:
		found[source.find_enemy("port_player", 4, NOW, rng)] = true
	_check(not found.has("mock_1"), "a village with a shield is not found")
	# The battle: the loot and the win.
	var map := source.load_village("mock_2", NOW + 86400 * 3)
	var loot := PvpBattle.loot_of(map, 20, _config, rng)
	_check(loot["g"] == int(map.loot_resources()["g"] * PvpBattle.LOOT_SHARE), "the loot is a third of each resource")
	var battle := PvpBattle.create(map, {LIGHT_KNIGHT: 3}, loot, Vector2i(10, 50), _config, null, rng, 20)
	_check(battle.has_town_hall and not battle.is_won() and battle.sim.fighters.filter(func(f: BattleFighter) -> bool: return f.team == BattleFighter.Team.PLAYER).size() == 3, "the army lands, and the village has a town hall")
	var town_hall: BattleFighter = battle._targets.filter(func(f: BattleFighter) -> bool: return f.def.subcat_functional == PvpBattle.SUBCAT_TOWN_HALL)[0]
	battle.sim.receive_attack(town_hall, 10, null)
	_check(battle.taken["g"] > 0 and battle.percentage() > 0 and battle.percentage() < 1, "damage to the town hall takes a part of the loot")
	for target in battle._targets.duplicate():
		battle.sim.kill(target)
	var result := battle.result()
	_check(battle.is_won() and result["loot"] == loot and is_equal_approx(result["percentage"], 1.0), "with all resource buildings destroyed, the attack is won and takes all the loot")
	for i in 40:
		battle.sim.step()
		battle.update()
	_check(battle.is_finished(), "the battle ends a second after the win")
	return true


## A copy of the neighbour folders of the import, so that the checks can write into it.
## The troll town: the purchase of "buy_map", the map of fix_troll_empire, and two towns in one save.
func _check_second_town() -> bool:
	var path := _write_fixture("second_town", 19, _config.levels[18].exp_required, 150000)
	_patch_private(path, {}, 30)
	var village := Village.load_from_file(path, _config)
	_check(not village.has_second_town() and village.can_buy_second_town(false) == Village.Placement.LEVEL_TOO_LOW, "the troll town needs level 20")
	path = _write_fixture("second_town", 20, _config.levels[19].exp_required, 150000)
	_patch_private(path, {}, 30)
	village = Village.load_from_file(path, _config)
	_check(village.buy_second_town(false, NOW) == Village.Placement.OK and village.get_resource("g") == 50000 and village.get_resource("c") == 30, "the troll town costs 100000 gold")
	var document := village._document
	_check(document["privateState"]["maps"] == [{"r": "h"}, {"r": "t"}] and document["maps"].size() == 2 and document["playerInfo"]["map_names"][1] == "My Empire 1", "the save lists the bought town and has its map")
	_check(village.buy_second_town(true, NOW) == Village.Placement.NOT_ALLOWED, "the player buys the troll town only once")
	_check(village.save_to_file(path) == OK, "the save with two towns is written")
	var trolls := Village.load_from_file(path, _config, Village.SECOND_TOWN)
	_check(trolls != null and trolls.race == "t" and trolls.get_level() == 1 and trolls.get_resource("g") == 250 and trolls.owned_land == PackedInt32Array([13]) and trolls.items.size() == 7, "the troll town starts as the server makes it")
	_check(trolls.has_second_town() and not trolls.is_first_map() and trolls.get_resource("c") == 30, "the towns share the cash and the list of towns")
	var house := _config.get_item(307)
	_check(house.is_sold_to("t") and not house.is_sold_to("h") and trolls.buy(house, _free_tile(trolls, 307, Rect2i(39, 39, 13, 13)), NOW) == Village.Placement.OK, "the troll town builds troll buildings")
	_check(trolls.save_to_file(path) == OK and Village.load_from_file(path, _config).get_resource("g") == 50000, "a purchase in the troll town does not change the gold of the first town")
	# A save of the server already has the troll map; the purchase keeps it.
	path = _write_fixture("second_town_cash", 20, _config.levels[19].exp_required, 0)
	_patch_private(path, {"maps": [{"r": "h"}]}, 22)
	village = Village.load_from_file(path, _config)
	village._add_troll_town(NOW)
	village._document["maps"][1]["coins"] = 999
	_check(village.buy_second_town(false, NOW) == Village.Placement.NOT_ENOUGH_RESOURCES and village.buy_second_town(true, NOW) == Village.Placement.OK and village.get_resource("c") == 0, "the troll town costs 22 cash")
	_check(village._document["maps"].size() == 2 and village._document["maps"][1]["coins"] == 999, "the purchase keeps a troll map that the save has")
	return true


## The repairs of the server's save migration (SaveMigration): the list of
## the bought units with the race rule of each town, the gifts of old saves,
## the Heroes Grave without its graveyard list, and a save of an old server.
func _check_save_migration() -> bool:
	const TROLL := 525
	const DEVIOUS_TROLL := 526
	var path := _write_fixture("migration", 20, _config.levels[19].exp_required, 150000)
	var village := Village.load_from_file(path, _config)
	_check(village._document["privateState"]["boughtUnits"] == [512, 516], "a save without bought units gets the units of its map")
	_check(village.buy_second_town(false, NOW) == Village.Placement.OK and village.save_to_file(path) == OK, "the save with the troll town is written")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var trolls: Dictionary = document["maps"][1]
	trolls["items"].append([TROLL, 40, 40, 0, NOW, 0, [], {}])
	trolls["store"] = {"513": 1}
	var gifts := []
	gifts.resize(DEVIOUS_TROLL + 1)
	gifts.fill(0)
	gifts[DEVIOUS_TROLL] = 2
	document["privateState"].merge({"boughtUnits": [], "gifts": gifts, "deadHeroes": {"534": 1, "509": 2}}, true)
	document["privateState"].erase("resurrectableUnits")
	_write_document(path, document)
	var private: Dictionary = Village.load_from_file(path, _config)._document["privateState"]
	# The troll town counts its troll units but not the human unit in its item
	# store; the gifts and the dead heroes count with each race.
	_check(private["boughtUnits"] == [512, 516, 580, TROLL, DEVIOUS_TROLL, 534], "the bought units follow the race of each town: %s" % [private["boughtUnits"]])
	_check(private["gifts"] == {str(DEVIOUS_TROLL): 2.0}, "a list of gifts becomes a dictionary without the zeros")
	_check(private["deadHeroes"] == {"534": 1.0} and private["resurrectableUnits"] == [], "the Heroes Grave keeps only the heroes")

	document = _initial.duplicate(true)
	document["version"] = "old"
	document["maps"][0]["level"] = 40
	for entry: Array in document["maps"][0]["items"]:
		entry.resize(5)
	document["privateState"]["mana"] = 5
	_write_document(path, document)
	village = Village.load_from_file(path, _config)
	private = village._document["privateState"]
	var mana := (41 - _config.start_level_mana_reward) * _config.mana_reward_per_level
	_check(village.items.size() == _initial["maps"][0]["items"].size() and not village._document.has("version"), "the items of a save of an old server load")
	_check(int(private["mana"]) == 5 + mana and int(private["monsterNestActive"]) == 1, "a save of an old server gets the mana of its levels and the monster nest")
	return true


func _write_document(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t", false))
	file.close()


## The first purchase offer ("open me"): when the icon shows, the time after
## the first opening, and the purchase as the server makes it.
func _check_first_offer() -> bool:
	var offer := _config.first_offer
	_check(offer.get("cost") == 28 and offer.get("seconds") == 86400 and offer.get("units") == [2245, 2248, 2242] and offer.get("reward") == {"g": 20000, "f": 40000}, "the offer of the configuration: %s" % [offer])
	var path := _write_fixture("first_offer", 10, _config.levels[9].exp_required, 1000)
	_patch_private(path, {"numDayLogged": 3}, 30)
	_check(not Village.load_from_file(path, _config).first_offer_shown(NOW), "from the third day of the login bonus an offer that was not opened does not show")
	_patch_private(path, {"numDayLogged": 2}, 20)
	var village := Village.load_from_file(path, _config)
	_check(village.first_offer_shown(NOW) and village.first_offer_seconds_left(NOW) == 0, "the offer shows in the first two days before its first opening")
	_check(village.buy_first_offer(NOW) == Village.Placement.NOT_ALLOWED, "the player buys the offer only after its opening")
	village.open_first_offer(NOW)
	village.open_first_offer(NOW + 100)
	_check(village._document["privateState"]["firstPurchaseTimestamp"] == NOW and village.first_offer_seconds_left(NOW + 100) == 86300, "the first opening starts the time")
	_check(village.buy_first_offer(NOW + 100) == Village.Placement.NOT_ENOUGH_RESOURCES and village.get_resource("c") == 20 and village.stored_items().is_empty(), "the offer costs 28 cash")
	_check(not village.first_offer_shown(NOW + 86400) and village.buy_first_offer(NOW + 86400) == Village.Placement.NOT_ALLOWED, "the offer ends after 24 hours")
	_patch_private(path, {"numDayLogged": 2, "firstPurchaseTimestamp": NOW}, 30)
	village = Village.load_from_file(path, _config)
	_check(village.buy_first_offer(NOW + 100) == Village.Placement.OK, "the player buys the offer")
	_expect("after the offer", village, {"c": 2, "g": 21000, "f": 40000 + int(_initial["maps"][0]["food"])})
	var bought: Array = village._document["privateState"]["boughtUnits"]
	_check(village.stored_items() == {2245: 1, 2248: 1, 2242: 1} and [2245, 2248, 2242].all(func(id: int) -> bool: return bought.has(id)), "the three dragons go to the item store and the list of bought units")
	_check(village._document["privateState"]["firstPurchaseTimestamp"] == 1 and not village.first_offer_shown(NOW + 200), "after the purchase the offer does not show")
	return true


## The unit list (UnitCollections): the groups of the configuration, the count
## from the save, the alert of a unit that completes a group, and the reward.
func _check_unit_collections() -> bool:
	var groups := _config.unit_collections
	_check(groups.size() == 128 and groups[0] == {"id": 1, "reward": 608, "position": 5, "name": "SWORDS", "units": [509, 510, 511, 539, 608]}, "the 128 groups of the mega patch in their order: %s" % [groups[0] if not groups.is_empty() else null])
	var path := _write_fixture("unit_collections", 10, _config.levels[9].exp_required, 1000, {"store": {"608": 1, "510": 1}})
	# A list that is not empty, so that the save migration does not make the list from the item store.
	_patch_private(path, {"boughtUnits": [9999], "unitCollectionsCompleted": []}, 20)
	var base := UnitCollections.new(_config, Village.load_from_file(path, _config))
	_check(base.total() == 504, "the total counts the 5 units that are in two groups twice, as the client does")
	_patch_private(path, {"boughtUnits": [509, 511, 539, 9999]}, 20)
	var village := Village.load_from_file(path, _config)
	var collections := UnitCollections.new(_config, village)
	_check(collections.owned_count() == base.owned_count() + 3 and collections.owned_in(groups[0]) == 3, "the bought units count, except units that are in no group")
	_check(collections.claim(groups[0]) == Village.Placement.NOT_ALLOWED, "the reward needs all units of the group")
	var alerts: Array[int] = []
	village.happened.connect(func(kind: VillageEvent.Kind, data: Dictionary) -> void:
		if kind == VillageEvent.Kind.UNIT_ARRIVED and collections.add_unit(data["unit"]):
			alerts.append(data["unit"]))
	var area := Rect2i(40, 40, 30, 30)
	_check(village.place_stored(_config.get_item(510), _free_tile(village, 510, area), NOW) == Village.Placement.OK and alerts.is_empty() and collections.owned_in(groups[0]) == 4, "a unit from the item store counts when it comes on the map")
	_check(village.place_stored(_config.get_item(608), _free_tile(village, 608, area), NOW) == Village.Placement.OK and alerts == [608], "the last unit of a group brings the alert")
	_check(not collections.add_unit(608), "a unit counts once")
	_check(collections.claim(groups[0]) == Village.Placement.OK and village.get_resource("c") == 21 and village.unit_collections_claimed() == [1], "the reward gives 1 cash and goes into unitCollectionsCompleted")
	_check(collections.claim(groups[0]) == Village.Placement.NOT_ALLOWED and village.get_resource("c") == 21, "the player takes the reward once")
	_check(village.save_to_file(path) == OK and UnitCollections.new(_config, Village.load_from_file(path, _config)).is_claimed(groups[0]), "the save keeps the reward")
	return true


## The quests in the town (TownQuests): the race filter, the rewards, a camp
## from its start to its end, the server rules of the wait, the fights at a
## camp, a quest of activators and a quest of boss waves.
func _check_town_quests() -> bool:
	_check(TownQuests.playable_id(9, "h") == 10 and TownQuests.playable_id(11, "h") == 12 and TownQuests.playable_id(0, "h") == 0, "humans skip the quests 9 and 11")
	_check([0, 4, 7, 11, 14, 20].map(func(id: int) -> int: return TownQuests.playable_id(id, "t")) == [1, 5, 10, 12, 14, 1], "the troll town skips the quests of humans")
	_check(TownQuests.reward(5) == Vector2i(250, 50) and TownQuests.reward(21) == Vector2i(650, 90) and TownQuests.reward(26) == Vector2i(750, 100), "the gold and experience of the end go by level")
	var path := _write_fixture("town_quests", 10, _config.levels[9].exp_required, 1000, {"idCurrentTreasure": 0, "timestampLastTreasure": 0, "currentQuestVars": {}})
	var village := Village.load_from_file(path, _config)
	var rng := RandomNumberGenerator.new()
	rng.seed = 46
	var quests := TownQuests.new(village, _config, rng)
	var xp := village.get_xp()
	_check(not quests.is_active() and quests.can_start(NOW) and quests.start(NOW) and quests.quest_id() == 0, "the first quest starts when the map opens")
	_check(village.get_xp() == xp and village.quest_roles.size() == 45, "the camp has its walls, towers and treasure, and gives no experience")
	var vars := village.town_quest_vars()
	_check(vars.get("spawned") == true and vars.get("quest") == 0 and vars.get("sites", []).size() == 1, "the save keeps the quest and its site")
	var treasure: Village.PlacedItem = village.quest_roles.keys().filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == 83).front()
	var wall: Village.PlacedItem = village.quest_roles.keys().filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == 305).front()
	_check(not quests.is_open(treasure) and quests.collect(treasure, NOW) == "", "the guards keep the princess closed")
	_check(not village.can_move(wall) and not village.can_sell(wall), "the player cannot move or sell the camp")
	_check(village.save_to_file(path) == OK, "the save with the camp is written")
	village = Village.load_from_file(path, _config)
	quests = TownQuests.new(village, _config, rng)
	_check(quests.is_active() and village.quest_roles.size() == 45, "the quest and its items come back with the save")
	wall = village.quest_roles.keys().filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == 305).front()
	treasure = village.quest_roles.keys().filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == 83).front()
	var battle := VillageBattle.new(village, [], _config, null, rng, func(_placed: Village.PlacedItem) -> bool: return false)
	_check(battle.fighter_of(wall).team == BattleFighter.Team.ENEMY and battle.fighter_of(treasure).team == BattleFighter.Team.NEUTRAL, "the walls fight for the enemy; the prisoner is neutral")
	battle.fighter_of(wall).dead = true
	battle.apply()
	_check(not wall in village.items, "a wall that the player destroys leaves the map")
	for placed in village.items.duplicate():
		if village.is_enemy_unit(placed):
			village.kill_enemy(_config.get_item(placed.item_id), placed)
	var gold := village.get_resource("g")
	xp = village.get_xp()
	_check(quests.is_open(treasure) and quests.collect(treasure, NOW + 10) == "done", "the princess opens when the enemies near her are dead, and the player frees her")
	_check(village.get_resource("g") == gold + 350 and village.get_xp() == xp + 60 and village.town_quest_id() == 1 and village.town_quest_time() == NOW + 10 and village.town_quest_vars().is_empty(), "the end sends collect_treasure: 350 gold, 60 XP and the next quest")
	_check(village.items.any(func(placed: Village.PlacedItem) -> bool: return placed.item_id == 533 and village.is_own_unit(placed)) and village.quest_roles.is_empty(), "the Warrior Princess joins the player and the camp goes away")
	_check(village.finish_town_quest(1, 1, 2, 0, 0, NOW + 20) == Village.Placement.NOT_ALLOWED and village.town_quest_id() == 1, "the server refuses another end in the 4 hours")
	village.set_town_quest_var("spawned", true, NOW + 20)
	_check(village.town_quest_vars().is_empty() and not quests.can_start(NOW + 20) and quests.seconds_to_next(NOW + 10 + 3600) == 3 * 3600, "the next quest waits 4 hours, and the server ignores quest values in that time")
	_check(quests.can_start(NOW + 10 + Village.TOWN_QUEST_WAIT + 1), "after the wait the next quest can start")
	# A quest of activators without a treasure.
	path = _write_fixture("town_quests_activators", 30, _config.levels[29].exp_required, 1000, {"idCurrentTreasure": 26, "timestampLastTreasure": 0, "currentQuestVars": {}})
	village = Village.load_from_file(path, _config)
	quests = TownQuests.new(village, _config, rng)
	_check(quests.start(NOW) and quests.open_items().is_empty() and quests.progress_text().contains("0 of 4"), "the four activators of the Atlantis quest are guarded")
	for placed in village.items.duplicate():
		if village.is_enemy_unit(placed):
			village.kill_enemy(_config.get_item(placed.item_id), placed)
	var open := quests.open_items()
	_check(open.size() == 4 and quests.collect(open[0], NOW + 1) == "1 of 4 collected." and village.town_quest_vars()["activators"].size() == 1, "an activator opens without guards, and the save keeps it")
	for placed in quests.open_items():
		quests.collect(placed, NOW + 1)
	_check(not quests.is_active() and village.stored_items().get(274, 0) == 1 and village.town_quest_id() == 27, "the last activator ends the quest; its reward goes to the item store")
	# A quest of boss waves.
	path = _write_fixture("town_quests_waves", 30, _config.levels[29].exp_required, 1000, {"idCurrentTreasure": 24, "timestampLastTreasure": 0, "currentQuestVars": {}})
	village = Village.load_from_file(path, _config)
	quests = TownQuests.new(village, _config, rng)
	var count := func(id: int) -> int: return village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == id).size()
	_check(quests.start(NOW) and count.call(679) == 4 and count.call(678) == 0 and count.call(613) == 2, "the first wave and the helpers come at the start")
	for placed in village.items.duplicate():
		if placed.item_id == 679:
			village.kill_enemy(_config.get_item(placed.item_id), placed)
	_check(quests.update(NOW + 1) and count.call(680) == 4 and village.town_quest_vars()["wave"] == 2, "the next wave comes when the last one is dead")
	return true


func _neighbour_copy() -> String:
	var target := "user://checks/neighbours"
	for folder in NeighbourSource.FOLDERS:
		var from := _data_dir.path_join("neighbours").path_join(folder)
		DirAccess.make_dir_recursive_absolute(target.path_join(folder))
		for file in DirAccess.get_files_at(from) if DirAccess.dir_exists_absolute(from) else PackedStringArray():
			DirAccess.copy_absolute(from.path_join(file), target.path_join(folder).path_join(file))
	return target


## The tutorial of a new empire: the steps, what they allow, and the save.
func _check_tutorial() -> bool:
	var path := _write_fixture("tutorial", 1, 4, 250)
	var village := Village.load_from_file(path, _config)
	var tutorial := Tutorial.new(village, _config)
	_check(tutorial.is_active() and tutorial.step == 0 and tutorial.box()[0] == _config.text("TUTORIAL_INTRO_TITULO") and tutorial.box()[3] == true, "a new empire starts the tutorial with the welcome box and its button")
	_check(_config.text("TUTORIAL_INTRO_LECCION").contains("#0#") and tutorial.box()[1].contains(_config.text("TUTORIAL_HOST_NAME_MALE")), "the lesson names the host")
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(TOWN_HALL))
	_check(tutorial.step == 0, "a step goes on only with its own action")
	tutorial.handle(Tutorial.Action.BOX_BUTTON)
	_check(tutorial.step == 1 and village.tutorial_step() == 1 and tutorial.box()[2] == _config.text("POPUP_TUTORIAL_PAGINA").replace("#0#", "1").replace("#1#", "7"), "the button goes to step 1, page 1 of 7, and the save has the step")
	_check(not tutorial.allows_select(_config.get_item(KNIGHT), false) and tutorial.allows_select(_config.get_item(TOWN_HALL), false), "at step 1 only the town hall can be selected")
	_check(not tutorial.allows_build(_config.get_item(HOUSE)) and not tutorial.allows_orders() and not tutorial.allows_training(_config.get_item(VILLAGER)), "at step 1 the player cannot build, move units or train")
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(TOWN_HALL))
	_check(tutorial.allows_training(_config.get_item(VILLAGER)) and not tutorial.allows_training(_config.get_item(SPEARMAN)), "at step 2 only villagers train")
	tutorial.handle(Tutorial.Action.TRAINING_STARTED, _config.get_item(VILLAGER))
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(VILLAGER))
	tutorial.handle(Tutorial.Action.UNIT_ORDERED)
	tutorial.handle(Tutorial.Action.UNIT_ORDERED, _config.get_item(19))
	tutorial.handle(Tutorial.Action.HARVEST_DONE)
	_check(tutorial.step == 8 and village.tutorial_step() == 8, "a harvest goes past the step of the wood, because the port has no wood to pick up")
	_check(tutorial.allows_build(_config.get_item(HOUSE)) and not tutorial.allows_build(_config.get_item(10)), "the build menu offers only House I")
	tutorial.handle(Tutorial.Action.BUILD_ITEM_CHOSEN, _config.get_item(HOUSE))
	_check(tutorial.step == 10 and not tutorial.allows_place(Vector2i(54, 55)) and tutorial.allows_place(Vector2i(55, 55)), "House I goes only on tile 55, 55")
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(KNIGHT))
	_check(tutorial.step == 10, "the house does not go to step 11 before its construction ends")
	tutorial.handle(Tutorial.Action.CONSTRUCTED, _config.get_item(HOUSE))
	_check(tutorial.step == 11 and village.tutorial_step() == 11, "the end of the construction of the house goes to step 11")
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(KNIGHT))
	tutorial.handle(Tutorial.Action.ATTACK_ORDERED)
	tutorial.handle(Tutorial.Action.ENEMY_KILLED)
	_check(tutorial.step == 15 and village.tutorial_step() == 15 and tutorial.box().is_empty() and tutorial.goal_for_box() == 1, "the dead troll goes to step 15, past the congratulations, with the goal box")
	tutorial.handle(Tutorial.Action.GOAL_BOX)
	tutorial.handle(Tutorial.Action.BUILD_ITEM_CHOSEN, _config.get_item(10))
	_check(tutorial.step == 19 and tutorial.allows_place(Vector2i(52, 44)) and not tutorial.allows_place(Vector2i(52, 45)), "the farm goes only on tile 52, 44")
	for action: Tutorial.Action in [Tutorial.Action.CONSTRUCTED, Tutorial.Action.GOAL_BOX, Tutorial.Action.GOAL_WINDOW_CLOSED]:
		tutorial.handle(action, _config.get_item(10))
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(TOWN_HALL))
	tutorial.handle(Tutorial.Action.TRAINING_STARTED, _config.get_item(VILLAGER))
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(VILLAGER))
	tutorial.handle(Tutorial.Action.UNIT_ORDERED, _config.get_item(10))
	tutorial.handle(Tutorial.Action.FARM_READY)
	tutorial.handle(Tutorial.Action.COLLECTED, _config.get_item(10))
	tutorial.handle(Tutorial.Action.GOAL_BOX)
	tutorial.handle(Tutorial.Action.GOAL_WINDOW_CLOSED)
	tutorial.handle(Tutorial.Action.SELECTED, _config.get_item(VILLAGER))
	_check(tutorial.step == Tutorial.LAST_STEP and village.tutorial_step() == 31, "the farm, the food and the goal window lead to the last step")
	var finished := [false]
	tutorial.finished.connect(func() -> void: finished[0] = true)
	tutorial.handle(Tutorial.Action.TREE_HARVESTED)
	tutorial.handle(Tutorial.Action.TREE_HARVESTED)
	_check(tutorial.is_active(), "two trees do not end the tutorial")
	tutorial.handle(Tutorial.Action.TREE_HARVESTED)
	_check(finished[0] and not tutorial.is_active() and tutorial.allows_other(), "the third tree ends it")
	var nest := village.add_tutorial_nest(NOW)
	_check(nest != null and nest.item_id == DRAGON_NEST and (nest.tile - Village.TUTORIAL_NEST_TILE).length() < 5, "the client gives a dragon nest near tile 50, 60 at the end")
	_check(village.is_nest_active(nest) and village.nest_steps_done(nest, NOW) == 8 and village.nest_steps_done(nest, NOW + Village.NEST_STEP_SECONDS) == 9, "the nest of the tutorial gets 9 care steps, and the last one waits")
	_check(village.save_to_file(path) == OK, "the village after the tutorial saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["playerInfo"]["completed_tutorial"] == "31", "the save has the last step as text, as the server writes it")
	_check(not Tutorial.new(Village.load_from_file(path, _config), _config).is_active(), "a village after the tutorial does not start it again")
	return true


func _patch_private(path: String, values: Dictionary, cash: int) -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	document["privateState"].merge(values, true)
	document["playerInfo"]["cash"] = cash
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t", false))
	file.close()


## The first tile in area where the item fits.
func _free_tile(village: Village, item_id: int, area: Rect2i) -> Vector2i:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if village.check_location(_config.get_item(item_id), Vector2i(x, y)) == Village.Placement.OK:
				return Vector2i(x, y)
	return Village.ANY_TILE


## The Time Machine: a packet costs cash, and its use moves the times of the
## save back as the server does, except the shield.
func _check_time_machine() -> bool:
	const T := 1800000000
	var path := _write_fixture("time_machine", 5, _config.levels[4].exp_required, 1000, {"questTimes": {"100000006": T}, "lastQuestTimes": [T, 600]})
	_patch_private(path, {"timeStampTakeCare": T, "shieldEndTime": T, "timeStampTemple": 100, "survivalVidaTimeStamp": [T], "barracksQueues": {"1": {"ts": T}}}, 100)
	var village := Village.load_from_file(path, _config)
	_check(_config.time_packets.size() == 6 and _config.time_packets[0] == [0.5, 2] and _config.time_packets[5] == [24.0, 75], "the configuration has 6 packets, from 30 minutes for 2 cash to 24 hours for 75 cash")
	_check(village.time_packets() == [0, 0, 0, 0, 0, 0] and village.use_time_packet(0) == Village.Placement.NOT_ALLOWED, "without a packet the Time Machine does nothing")
	_check(village.buy_time_packet(0) == Village.Placement.OK and village.time_packets()[0] == 1, "a packet of 30 minutes is bought")
	_expect("after the packet", village, {"c": 98})
	var item_times: Array = village.items.map(func(placed: Village.PlacedItem) -> float: return placed._entry[4])
	_check(village.use_time_packet(0) == Village.Placement.OK and village.time_packets()[0] == 0, "the packet is used")
	var moved := true
	for i in village.items.size():
		moved = moved and village.items[i]._entry[4] == maxf(item_times[i] - 1800, 0)
	_check(moved, "the times of the items are 30 minutes earlier")
	_check(village.save_to_file(path) == OK, "the village after the Time Machine saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var state: Dictionary = saved["privateState"]
	var game_map: Dictionary = saved["maps"][0]
	_check(game_map["questTimes"]["100000006"] == T - 1800 and game_map["lastQuestTimes"] == [float(T - 1800), 0.0], "the quest times move back, not below 0")
	_check(state["timeStampTakeCare"] == T - 1800 and state["survivalVidaTimeStamp"] == [float(T - 1800)] and state["barracksQueues"]["1"]["ts"] == T - 1800, "the nest, survival and the training queues move back")
	_check(state["timeStampTemple"] == 0 and state["kompuLastTimeStamp"] == 0 and game_map["timestampLastTrade"] == 0, "a time below 0 and a missing time become 0, as on the server")
	_check(state["shieldEndTime"] == T and state["countTimePacket"] == [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "the shield keeps its time, and the save has the packets")
	return true


## The Weather Machine: the free style, the unlock for cash and the saved style.
func _check_weather_machine() -> bool:
	var path := _write_fixture("weather", 5, _config.levels[4].exp_required, 1000)
	_patch_private(path, {}, 30)
	var village := Village.load_from_file(path, _config)
	_check(village.skin == 0 and village.set_skin(1) == Village.Placement.NOT_ALLOWED and village.unlock_skin(3) == Village.Placement.NOT_ALLOWED, "a locked style, and style 3, which the window does not have, cannot be used")
	_check(_config.unlock_skin_cash == 20 and village.unlock_skin(1) == Village.Placement.OK and village.skin == 1, "style 1 is unlocked for 20 cash and used")
	_expect("after the unlock", village, {"c": 10})
	_check(village.unlock_skin(2) == Village.Placement.NOT_ENOUGH_RESOURCES and village.unlock_skin(1) == Village.Placement.NOT_ALLOWED, "an unlock needs the cash, and only once")
	_check(village.set_skin(0) == Village.Placement.OK and village.set_skin(1) == Village.Placement.OK and village.set_skin(1) == Village.Placement.NOT_ALLOWED, "the free style and the unlocked style can be used again without cash")
	_expect("after the changes", village, {"c": 10})
	_check(village.save_to_file(path) == OK, "the village with the new style saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(saved["maps"][0]["skin"] == "1" and saved["privateState"]["unlockedSkins"].get("1") == true, "the save has the style as text and the unlocked style, as the server writes them")
	_check(Village.load_from_file(path, _config).skin == 1, "the saved style loads")
	return true


## The Supreme Dragon Temple: 12 steps in any order with a wait after each,
## the sacrifices, the heart and the Supreme Bahamut Dragon.
func _check_temple() -> bool:
	const T := 1800000000
	var level := mini(60, _config.levels.size())
	var dragons: Array[int] = Village.TEMPLE_SACRIFICES
	var store := {str(SUPREME_TEMPLE): 1}
	for id in dragons:
		store[str(id)] = 1
	var path := _write_fixture("temple", level, _config.levels[level - 1].exp_required, 200000, {"expansions": [13, 12], "wood": 100000, "stone": 100000, "food": 99999, "store": store})
	_patch_private(path, {"mana": 50, "templeStep": [], "timeStampTemple": 0}, 100)
	var village := Village.load_from_file(path, _config)
	var temple_tile := _free_tile(village, SUPREME_TEMPLE, Rect2i(40, 40, 30, 30))
	_check(village.place_stored(_config.get_item(SUPREME_TEMPLE), temple_tile, T) == Village.Placement.OK, "the temple is placed")
	var temple: Village.PlacedItem = village.items.back()
	for i in dragons.size():
		_check(village.place_stored(_config.get_item(dragons[i]), UNIT_TILES[i], T) == Village.Placement.OK, "dragon %d is placed" % dragons[i])
	var now := T
	_check(village.do_temple_step(11, now) == Village.Placement.NOT_ALLOWED and village.do_temple_step(3, now) == Village.Placement.NOT_ENOUGH_RESOURCES, "the heart step needs the heart, and the food step 100000 food")
	_check(village.do_temple_step(6, now) == Village.Placement.OK and not village.items.any(func(placed: Village.PlacedItem) -> bool: return placed.item_id == dragons[0]), "the Furious Dragon is sacrificed and leaves the map")
	_check(not village.graveyard_units().has(dragons[0]), "a sacrificed dragon does not go to the graveyard")
	_check(village.temple_wait_seconds(now) == Village.TEMPLE_STEP_SECONDS and village.do_temple_step(0, now) == Village.Placement.NOT_ALLOWED, "after a step the player waits 48 hours")
	_check(village.end_temple_wait(now) == Village.Placement.OK and village.temple_wait_seconds(now) == 0, "5 cash ends the wait")
	_expect("after the wait with cash", village, {"c": 95})
	for step: int in [0, 1, 2, 4, 5]:
		_check(village.do_temple_step(step, now) == Village.Placement.OK, "offering step %d" % step)
		now += Village.TEMPLE_STEP_SECONDS
	_expect("after the offerings", village, {"g": 100000, "s": 0, "w": 0, "m": 0, "c": 45})
	_check(village.do_temple_step(0, now) == Village.Placement.NOT_ALLOWED, "a step is done only once")
	for step in range(7, 11):
		_check(village.do_temple_step(step, now) == Village.Placement.OK, "sacrifice step %d" % step)
		now += Village.TEMPLE_STEP_SECONDS
	village._stored()[str(BAHAMUT_HEART)] = 1
	village._map["food"] = 100000
	_check(village.do_temple_step(3, now) == Village.Placement.OK, "the food step")
	now += Village.TEMPLE_STEP_SECONDS
	_check(village.do_temple_step(11, now) == Village.Placement.OK and village.stored_items().has(BAHAMUT_HEART), "the heart is offered and stays in the item store")
	_check(village.temple_steps_done().size() == Village.TEMPLE_STEPS and village.take_supreme_bahamut(temple, now) == Village.Placement.NOT_ALLOWED, "after the last step the dragon comes only after the wait")
	now += Village.TEMPLE_STEP_SECONDS
	var xp := village.get_xp()
	_check(village.take_supreme_bahamut(temple, now) == Village.Placement.OK and village.items.back().item_id == SUPREME_BAHAMUT, "the Supreme Bahamut Dragon comes")
	_expect("after the dragon", village, {"xp": xp + _config.get_item(SUPREME_BAHAMUT).xp})
	_check(not village.stored_items().has(BAHAMUT_HEART) and village.temple_steps_done().is_empty() and village.temple_wait_seconds(now) == 0, "the heart is sold, and the temple starts again")
	return true


## Buys the item on the first tile in area where it fits.
func _buy_free(village: Village, item_id: int, area: Rect2i, expected: Village.Placement) -> void:
	var item := _config.get_item(item_id)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if village.check_location(item, Vector2i(x, y)) == Village.Placement.OK:
				_buy(village, item_id, Vector2i(x, y), expected)
				return
	_check(false, "item %d fits in %s" % [item_id, area])


## The enemies of the village: the idle groups at the border, the attacks by
## level, the reward for a killed enemy and the units that the player loses.
func _check_village_enemies() -> bool:
	var path := _write_fixture("enemies", 1, 4, 500)
	var village := Village.load_from_file(path, _config)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var trolls := village.items.filter(village.is_enemy_unit)
	_check(trolls.size() == 2 and trolls.all(func(placed: Village.PlacedItem) -> bool: return placed.item_id == SMALL_TROLL), "the two small trolls of the start village are enemies")
	_check(VillageAttacks.enemy_ids(1, "h") == [SMALL_TROLL] and VillageAttacks.enemy_ids(30, "t").has(MONK), "the enemies depend on the level and the race")
	var attacks := VillageAttacks.new(village, _config, rng)
	_check(attacks.attacks().is_empty(), "no attacks come at level 1")
	var placed := attacks.spawn_idle_enemies(NOW)
	var size := placed.size() / VillageAttacks.IDLE_GROUPS
	_check(placed.size() % VillageAttacks.IDLE_GROUPS == 0 and size >= 3 and size <= 4, "6 groups of 3 or 4 idle enemies come (%d)" % placed.size())
	var at_border := func(item: Village.PlacedItem) -> bool: return IsoGrid.land_area_number(item.tile / IsoGrid.LAND_TILES) in VillageAttacks.BORDER_AREAS
	_check(placed.all(at_border) and placed.all(village.is_enemy_unit), "the idle enemies stand on the land at the border")
	_check(VillageAttacks.new(village, _config, rng).spawn_idle_enemies(NOW).is_empty(), "a full map gets no more idle enemies")
	var troll: Village.PlacedItem = trolls[0]
	village.kill_enemy(_config.get_item(SMALL_TROLL), troll)
	_check(not troll in village.items, "a killed enemy leaves the map")
	_expect("after the kill", village, {"xp": 4 + 1, "g": 500 + Village.KILL_GOLD})
	var knight := village.item_at(KNIGHT_TILE)
	village.lose_unit(knight)
	_check(not knight in village.items and village.graveyard_units().get(knight.item_id, 0) == 1, "a lost unit goes to the graveyard")
	var path_20 := _write_fixture("enemies_20", 20, 20000, 500)
	var groups := VillageAttacks.new(Village.load_from_file(path_20, _config), _config, rng).attacks()
	_check(groups.map(func(group: VillageAttacks.Group) -> int: return group.ai.wait_frames) == [7 * 1800, 14 * 1800, 21 * 1800], "at level 20 three bandit groups come and wait 7, 14 and 21 minutes")
	_check(groups.all(func(group: VillageAttacks.Group) -> bool: return group.attackers.size() == 5), "each bandit group has a unit for each 4 levels")
	# The server gives the experience of an idle enemy without a level; from
	# level 5 the client publishes its own experience after the load, which
	# takes it back.
	var with_xp: Array = VillageAttacks.enemy_ids(30, "h").filter(func(id: int) -> bool: return _config.get_item(id).xp > 0)
	var next_xp := _config.levels[4].exp_required
	var low := Village.load_from_file(_write_fixture("enemies_xp", 4, next_xp - 1, 500), _config)
	var enemy := _config.get_item(with_xp[0])
	low.add_enemy(enemy, Vector2i(5, 5), NOW)
	_expect("an idle enemy at level 4", low, {"level": 4, "xp": next_xp - 1 + enemy.xp})
	low.publish_score(next_xp - 1)
	_expect("the published experience", low, {"level": 4, "xp": next_xp - 1})
	return true


## What the client does each time it loads the map: it clears the border,
## places the trees, stones and gold, and its "rt_publish_score" takes back
## the experience that the server gave for the items that it placed itself.
func _check_map_start() -> bool:
	var village := Village.load_from_file(_write_fixture("map_start", 8, 1000, 500), _config)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var knight := village.item_at(KNIGHT_TILE)
	var border := Vector2i(10, 50)
	_check(village.move_unit(knight, border, 1) == Village.Placement.OK, "a knight walks to the border")
	var enemy := village.add_enemy(_config.get_item(SMALL_TROLL), Vector2i(90, 50), NOW)
	village.clean_border(rng)
	_check(not enemy in village.items, "the border loses the idle enemy")
	_check(knight in village.items and VillageUnits.INNER_LAND.has_point(knight.tile), "the knight of the player comes back from the border")
	_check(village.items.all(func(placed: Village.PlacedItem) -> bool: return VillageUnits.INNER_LAND.has_point(placed.tile)), "nothing is left at the border")
	var xp := village.get_xp()
	var placed := village.spawn_resources(NOW, rng)
	var count := func(ids: Array) -> int: return village.items.filter(func(item: Village.PlacedItem) -> bool: return item.item_id in ids).size()
	_check(count.call(VillageUnits.GOLD) >= 15 and count.call(VillageUnits.STONES) >= 15, "3 groups of gold and of stones come (%d, %d)" % [count.call(VillageUnits.GOLD), count.call(VillageUnits.STONES)])
	_check(count.call(VillageUnits.TREES) >= VillageUnits.TREES_ALONE + 10 * 16, "10 groups of trees and 100 single trees come (%d)" % count.call(VillageUnits.TREES))
	_check(placed.all(func(item: Village.PlacedItem) -> bool: return not IsoGrid.land_area_number(item.tile / IsoGrid.LAND_TILES) in village.owned_land), "the resources stand on land that the player does not own")
	# A group of gold or stone can count less than the average group, so the
	# client can add a group at the next load; the trees are enough.
	_check(village.spawn_resources(NOW, rng).all(func(item: Village.PlacedItem) -> bool: return not item.item_id in VillageUnits.TREES), "the next load places no more trees")
	var enemy_xp: Array = VillageAttacks.enemy_ids(30, "h").filter(func(id: int) -> bool: return _config.get_item(id).xp > 0)
	village.add_enemy(_config.get_item(enemy_xp[0]), Vector2i(5, 5), NOW)
	var free := village.add_free_buildings(NOW)
	var free_xp: int = free.reduce(func(sum: int, item: Village.PlacedItem) -> int: return sum + _config.get_item(item.item_id).xp, 0)
	_check(village.get_xp() == xp + _config.get_item(enemy_xp[0]).xp + free_xp and village.client_xp() == xp, "the server counts the experience of the idle enemy and the free buildings; the client does not")
	village.publish_score(village.client_xp())
	_expect("after the publish", village, {"level": 8, "xp": xp})
	return true


## The login bonus of the server: a reward for each new day of play, five days.
func _check_daily_bonus() -> bool:
	var village := Village.load_from_file(_write_fixture("daily_bonus", 8, 1000, 500), _config)
	var start := {"g": 500, "w": village.get_resource("w"), "s": village.get_resource("s"), "f": village.get_resource("f")}
	var state := village.start_daily_bonus(NOW)
	_check(state == {"days_logged": 1, "last_rewarded": 0, "shown": true}, "a new save shows the first day")
	_expect("the first day", village, {"g": start["g"] + 250, "w": start["w"] + 250, "s": start["s"] + 250, "f": start["f"] + 250})
	_check(village.start_daily_bonus(NOW + 60) == {"days_logged": 1, "last_rewarded": 1, "shown": true}, "a second start on the same day shows the window without a reward")
	_expect("the same day", village, {"g": start["g"] + 250})
	_check(village.start_daily_bonus(NOW + Village.DAY_SECONDS)["days_logged"] == 2, "the next day is day 2")
	village.add_daily_bonus_unit(int(_config.daily_bonus[1]["reward"]["u"]))
	_check(village.stored_items().get(int(_config.daily_bonus[1]["reward"]["u"]), 0) == 1, "the unit of day 2 goes to the item store")
	var cash := village.get_resource("c")
	_check(village.start_daily_bonus(NOW + 4 * Village.DAY_SECONDS)["days_logged"] == 3 and village.get_resource("c") == cash + 10, "a pause of some days gives the next day, day 3, with 10 cash")
	var potions := village.get_resource("p")
	village.start_daily_bonus(NOW + 5 * Village.DAY_SECONDS)
	_check(village.get_resource("p") == potions + 25, "day 4 gives 25 potions")
	village.start_daily_bonus(NOW + 6 * Village.DAY_SECONDS)
	_check(not village.start_daily_bonus(NOW + 7 * Village.DAY_SECONDS)["shown"], "after day 5 the bonus ends")
	return true


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
