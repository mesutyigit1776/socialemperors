extends SceneTree
## Checks the village rules and the save format without a window.
##
##   godot --headless --path godot --script res://checks/village_check.gd -- --data <data folder>
##
## It needs config.json and villages/initial.json from an import of the
## unchanged socialemperors files: the tiles and the expected values below come
## from them. It writes its files to user://checks/. The exit code is the number
## of failed checks.

const YELLOW_TREE := 100  # 225 gold, 23 XP
const BLUE_TREE := 101  # needs level 2
const GREEN_TREE := 108  # 60 gold, 6 XP

var _config: GameConfig
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
	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	var initial: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join("villages/initial.json")))
	if _config == null or not initial is Dictionary:
		push_error("Cannot read the imported data in '%s'." % data_dir)
		quit(1)
		return
	_initial = initial
	DirAccess.make_dir_recursive_absolute("user://checks")

	_check_placement_and_save()
	_check_several_levels()
	_check_mana_reward()
	_check_highest_level()
	print("%d failed" % _failures if _failures > 0 else "all passed")
	quit(_failures)


## The placement rules in order, then the save that the purchases wrote.
func _check_placement_and_save() -> void:
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


## One purchase can reach more than one level. Each level gives its own reward.
func _check_several_levels() -> void:
	var village := Village.load_from_file(_write_fixture("levels", 1, 95, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	# 101 XP: level 2 (+50 wood), level 3 (+50 food), level 4 (+400 wood). Level 5 needs 200.
	_expect("after several levels", village, {"level": 4, "xp": 101, "w": 1300, "f": 750, "c": 20})


## From level 36, a new level also gives 2 mana.
func _check_mana_reward() -> void:
	var village := Village.load_from_file(_write_fixture("mana", 35, 80150 - 6, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	_expect("after level 36", village, {"level": 36, "c": 21, "m": 2})


func _check_highest_level() -> void:
	var village := Village.load_from_file(_write_fixture("highest", 100, 2016089205, 500), _config)
	_buy(village, GREEN_TREE, Vector2i(56, 47), Village.Placement.OK)
	_expect("at the highest level", village, {"level": 100, "xp": 2016089211, "c": 20, "m": 0})


## Writes initial.json with a changed level, XP and gold, as the start of a check.
func _write_fixture(check_name: String, level: int, xp: int, coins: int) -> String:
	var document: Dictionary = _initial.duplicate(true)
	document["maps"][0].merge({"level": level, "xp": xp, "coins": coins}, true)
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
