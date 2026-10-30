extends SceneTree
## Checks the rules of the spells without a window.
##
##   godot --headless --path godot --script res://checks/spell_check.gd -- --data <data folder>
##
## It needs config.json and villages/initial.json from an import of the
## unchanged socialemperors files: the spells and prices below come from them.
## The exit code is the number of failed checks.

const FIRE_HAVOC := 2  # level 35, 1000 gold or 35 cash, 5 mana
const ETHER_SHIELD := 9  # level 38, 50000 gold or 40 cash, 6 mana
const BLACK_HOLE := 16  # level 49

var _data: String
var _config: GameConfig
var _failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--data")
	if index < 0 or index + 1 >= args.size():
		push_error("Give the data folder: -- --data <folder>")
		quit(1)
		return
	_data = args[index + 1]
	_config = GameConfig.load_from_file(_data.path_join("config.json"))
	if _config == null:
		push_error("Cannot read the imported data in '%s'." % _data)
		quit(1)
		return
	# A script error stops only the function in which it occurs, so a scenario
	# that does not return true has stopped before its end.
	for scenario: Callable in [_check_configuration, _check_buy_mana, _check_buy_spell, _check_use_spell]:
		_check(scenario.call() == true, "%s runs to its end" % scenario.get_method())
	print("%d failed" % _failures if _failures > 0 else "all passed")
	quit(_failures)


func _check_configuration() -> bool:
	_check(_config.spells.size() == 15, "the configuration has 15 spells")
	var shield := _config.get_spell(ETHER_SHIELD)
	_check(shield.areas == [5, 7, 9] and shield.mana == 6 and shield.target == 1, "Ether Shield has the areas 5, 7 and 9, costs 6 mana and marks the player's side")
	_check(_config.mana_per_purchase == 5 and _config.mana_price_gold == 20000 and _config.mana_price_cash == 1, "5 mana cost 20000 gold or 1 cash")
	_check(_config.spell_level(0) == 1 and _config.spell_level(24) == 1 and _config.spell_level(25) == 2 and _config.spell_level(50) == 3, "a spell gets level 2 after 25 casts and level 3 after 50")
	return true


func _check_buy_mana() -> bool:
	var village := _village(40, 30000, 1, 0)
	_check(village.buy_mana(false) == Village.Placement.OK and village.get_resource("g") == 10000 and village.get_resource("m") == 5, "5 mana cost 20000 gold")
	_check(village.buy_mana(false) == Village.Placement.NOT_ENOUGH_RESOURCES and village.get_resource("g") == 10000 and village.get_resource("m") == 5, "the player cannot buy mana without the gold")
	_check(village.buy_mana(true) == Village.Placement.OK and village.get_resource("c") == 0 and village.get_resource("m") == 10, "5 mana cost 1 cash")
	return true


func _check_buy_spell() -> bool:
	var village := _village(38, 60000, 50, 0)
	var shield := _config.get_spell(ETHER_SHIELD)
	_check(village.buy_spell(_config.get_spell(BLACK_HOLE), false) == Village.Placement.LEVEL_TOO_LOW, "the player cannot buy a spell below its level")
	_check(village.buy_spell(shield, false) == Village.Placement.OK and village.get_resource("g") == 10000, "Ether Shield costs 50000 gold")
	_check(village.get_resource("m") == 6 and village.spell_uses() == {ETHER_SHIELD: 0}, "a new spell gives the mana of one cast and has no casts")
	_check(village.buy_spell(shield, true) == Village.Placement.NOT_ALLOWED and village.get_resource("c") == 50, "the player cannot buy a spell twice")
	_check(village.buy_spell(_config.get_spell(FIRE_HAVOC), true) == Village.Placement.OK and village.get_resource("c") == 15 and village.get_resource("g") == 10000, "Fire Havoc costs 35 cash")
	_check(_saved_spells(village) == {str(ETHER_SHIELD): 0, str(FIRE_HAVOC): 0}, "the save keeps the spells with the id as text, as the server does")
	return true


func _check_use_spell() -> bool:
	var village := _village(40, 0, 0, 7, {str(ETHER_SHIELD): 24})
	var shield := _config.get_spell(ETHER_SHIELD)
	_check(village.use_spell(_config.get_spell(FIRE_HAVOC)) == 0 and village.get_resource("m") == 7, "the player cannot cast a spell that they did not buy")
	_check(village.use_spell(shield) == 2 and village.get_resource("m") == 1, "the 25th cast costs the mana and already has level 2")
	_check(village.use_spell(shield) == 0 and village.get_resource("m") == 1 and village.spell_uses()[ETHER_SHIELD] == 25, "the player cannot cast without the mana")
	_check(_saved_spells(village) == {str(ETHER_SHIELD): 25}, "the save counts the casts")
	return true


## The starting village with this level, gold, cash, mana and spells.
func _village(level: int, gold: int, cash: int, mana: int, spells: Dictionary = {}) -> Village:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_data.path_join("villages/initial.json")))
	document["maps"][0]["level"] = level
	document["maps"][0]["coins"] = gold
	document["playerInfo"]["cash"] = cash
	document["privateState"]["mana"] = mana
	document["privateState"]["magics"] = spells
	DirAccess.make_dir_recursive_absolute("user://checks")
	var path := "user://checks/spell_village.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	return Village.load_from_file(path, _config)


## The spells in the save as the port writes it. JSON gives the numbers as
## floats; the save has whole numbers.
func _saved_spells(village: Village) -> Dictionary:
	var path := "user://checks/spell_saved.json"
	village.save_to_file(path)
	var spells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))["privateState"]["magics"]
	var result := {}
	for key: String in spells:
		result[key] = int(spells[key])
	return result


func _check(passed: bool, description: String) -> void:
	if not passed:
		_failures += 1
	print("%s: %s" % ["ok" if passed else "FAILED", description])
