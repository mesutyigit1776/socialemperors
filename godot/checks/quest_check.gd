extends SceneTree
## Checks the rules of the campaign quests without a window, with fixed random seeds.
##
##   godot --headless --path godot --script res://checks/quest_check.gd -- --data <data folder>
##
## It needs config.json, villages/initial.json and the quest maps in quests/
## from an import of the unchanged socialemperors files: the islands, units and
## rewards below come from them. The exit code is the number of failed checks.

const TROLLS_1 := "100000006"  # 6 enemy units; the treasure is item 82
const TROLLS_2 := "100000007"  # 11 units, one of them Wallace (555), who joins the player
const VIKINGS := "100000021"  # the second civilisation island in the order
const KAMIKAZES := "100000020"  # 40 kamikazes and 8 fire cannons join the player
const ATLANTIS := "100000023"  # walls and decorations are neutral
const ARCTIC := "100000002"  # a boss island, not in the port
const GOD_1 := "100000090"  # always open, not in the port
const PHARAOHS := "100000046"  # needs level 40
const SPEARMAN := 509
const LIGHT_ARCHER := 516  # The starting village has 2.
const WALLACE := 555
const TREASURE := 82
const PLAYER := BattleFighter.Team.PLAYER
const ENEMY := BattleFighter.Team.ENEMY
const NEUTRAL := BattleFighter.Team.NEUTRAL
const NOW := 2000000000

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
	for scenario: Callable in [_check_island_list, _check_quest_limit, _check_end_quest, _check_sides, _check_stars_and_gold, _check_troll_win, _check_civilisation_win_and_loss, _check_units_back, _check_water]:
		_check(scenario.call() == true, "%s runs to its end" % scenario.get_method())
	print("%d failed" % _failures if _failures > 0 else "all passed")
	quit(_failures)


## The islands open one after the other; the port starts only its islands.
func _check_island_list() -> bool:
	var village := _village()
	var book := QuestBook.new(village, _config)
	_check(book.islands()[0] == TROLLS_1 and book.is_open(TROLLS_1), "the first island of the order is open")
	_check(not book.is_open(TROLLS_2) and book.refusal(TROLLS_2, NOW) == QuestBook.Refusal.LOCKED, "the second island is locked")
	_check(book.is_open(GOD_1) and book.refusal(GOD_1, NOW) == QuestBook.Refusal.NOT_IN_PORT, "a god island is always open, but not in the port")
	_check(book.is_level_locked(PHARAOHS) and not book.is_level_locked(TROLLS_1), "the Pharaohs island needs level 40")
	_check(book.refusal(TROLLS_1, NOW) == QuestBook.Refusal.NONE, "the first island can start with the army of the village")
	_check(book.max_stars(TROLLS_1) == 1, "an island without a win allows 1 star")
	village.end_quest(_result(TROLLS_1, 1, true))
	_check(book.is_open(TROLLS_2) and book.max_stars(TROLLS_1) == 2, "a win opens the next island and allows one more star")
	_check(not QuestIsland.is_in_port(ARCTIC) and QuestIsland.is_in_port(ATLANTIS), "the boss islands are not in the port; the civilisation islands are")
	return true


## 3 quests in a row, or 4 with the Odin statue; a start counts while it is
## less than the window before the next newer start.
func _check_quest_limit() -> bool:
	var window := QuestBook.QUEST_WINDOW_SECONDS
	var village := _village()
	var book := QuestBook.new(village, _config)
	_check(book.quests_left(NOW) == 3, "3 quests at the start")
	for time in [NOW - 100, NOW - 50, NOW - 10]:
		village.start_quest(TROLLS_1, time)
	_check(book.quests_left(NOW) == 0 and book.refusal(TROLLS_1, NOW) == QuestBook.Refusal.LIMIT_REACHED, "3 starts in a row reach the limit")
	_check(book.seconds_to_next_quest(NOW) == window - 10, "the next quest comes one window after the newest start")
	_check(book.quests_left(NOW - 10 + window) == 3, "after one window without a start, all quests are back")
	var chained := _village()
	var chained_book := QuestBook.new(chained, _config)
	for time in [NOW - 2 * window + 300, NOW - window + 200, NOW - 100]:
		chained.start_quest(TROLLS_1, time)
	_check(chained_book.quests_left(NOW) == 0, "starts less than a window apart all count, also when the oldest is more than one window ago")
	var gap := _village()
	for time in [NOW - window - 20, NOW - 10]:
		gap.start_quest(TROLLS_1, time)
	_check(QuestBook.new(gap, _config).quests_left(NOW) == 2, "a start one window before the next start no longer counts")
	var odin := _village([[QuestBook.ODIN_STATUE, 10, 10]])
	_check(QuestBook.new(odin, _config).quests_left(NOW) == 4, "the Odin statue gives a 4th quest")
	return true


## Village.end_quest() changes the save as the server command "end_quest".
func _check_end_quest() -> bool:
	var village := _village()
	var archers := _count(village, LIGHT_ARCHER)
	var gold := village.get_resource("g")
	var honour := int(_saved(village)["playerInfo"].get("honor_points", 0))
	var result := _result(TROLLS_1, 1, true)
	result["resources"] = {"g": 300, "x": 2}
	result["units"] = [[LIGHT_ARCHER, 2, 2, 1]]
	village.end_quest(result)
	_check(village.unlocked_quest_index() == 1 and village.quest_rank(TROLLS_1) == 1, "a win opens the next island and keeps the stars")
	_check(int(_saved(village)["playerInfo"]["honor_points"]) == honour + _config.quest_honour_first[0], "the first win with 1 star gives %d honour" % _config.quest_honour_first[0])
	_check(village.get_resource("g") == gold + 300, "the gold of the quest goes to the map")
	_check(_count(village, LIGHT_ARCHER) == archers - 1, "a unit that died and did not come back leaves the map")
	_check(village.graveyard_units().get(LIGHT_ARCHER, 0) == 1, "the graveyard takes it")
	var again := _result(TROLLS_1, 1, true)
	village.end_quest(again)
	_check(int(_saved(village)["playerInfo"]["honor_points"]) == honour + _config.quest_honour_first[0] + _config.quest_honour[0], "a second win with the same stars gives %d honour" % _config.quest_honour[0])
	var lost := _result(TROLLS_2, 1, false)
	village.end_quest(lost)
	_check(village.unlocked_quest_index() == 1 and village.quest_rank(TROLLS_2) == 0, "a loss opens nothing")
	return true


## The sides of the items: the families of the islands decide them.
func _check_sides() -> bool:
	var trolls := _quest(TROLLS_1, {SPEARMAN: 4}, 0)
	var treasure: Array = trolls.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.def.id == TREASURE)
	_check(treasure.size() == 1 and treasure[0].team == NEUTRAL and trolls.is_treasure(treasure[0]), "the treasure of a troll island is neutral")
	_check(trolls.enemies_left() == 6, "troll island 1 has 6 enemy units (%d)" % trolls.enemies_left())
	_check(_team_count(trolls, PLAYER) == 4, "the army lands")
	var wallace := _quest(TROLLS_2, {SPEARMAN: 4}, 0)
	_check(wallace.sim.fighters.any(func(item: BattleFighter) -> bool: return item.def.id == WALLACE and item.team == PLAYER), "Wallace joins the player on troll island 2")
	_check(wallace.enemies_left() == 10, "the other 10 units are enemies (%d)" % wallace.enemies_left())
	var kamikazes := _quest(KAMIKAZES, {SPEARMAN: 4}, 0)
	_check(_team_count(kamikazes, PLAYER) == 4 + 40 + 8, "the kamikazes and fire cannons of the island join the player (%d)" % _team_count(kamikazes, PLAYER))
	_check(kamikazes.enemies_left() == 1 and kamikazes.counts_town_halls(), "a civilisation island counts its town hall")
	var atlantis := _quest(ATLANTIS, {SPEARMAN: 4}, 0)
	var walls: Array = atlantis.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.def.subcat_functional == 221)
	_check(not walls.is_empty() and walls.all(func(item: BattleFighter) -> bool: return item.team == NEUTRAL), "the walls of Atlantis are neutral")
	return true


## More stars copy the enemy units; the gold is shared between the enemies
## that attack and the win.
func _check_stars_and_gold() -> bool:
	var one := _quest(TROLLS_1, {SPEARMAN: 4}, 0)
	one.start(1)
	var payers := one.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == ENEMY and item.def.attack > 0 and item.def.collect == 0)
	var total := int(_config.quest_gold["QUEST_ISLA_TROLLS_1"] * _config.quest_gold_multipliers[0])
	one.sim.receive_attack(payers[0], 100000, null)
	_check(one.gold == total / 2 / payers.size(), "1 star: an enemy that attacks pays its part of half the %d gold (%d)" % [total, one.gold])
	var three := _quest(TROLLS_1, {SPEARMAN: 4}, 2)
	three.start(3)
	_check(three.enemies_left() == 18, "3 stars give each of the 6 enemy units 2 copies (%d)" % three.enemies_left())
	var civilisation := _quest(VIKINGS, {SPEARMAN: 4}, 1)
	var units_before := _team_units(civilisation, ENEMY)
	var animals := civilisation.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == ENEMY and item.def.subcat_functional in QuestBattle.NOT_COPIED_SUBCATS).size()
	civilisation.start(2)
	_check(_team_units(civilisation, ENEMY) <= 2 * units_before - animals and _team_units(civilisation, ENEMY) > units_before, "2 stars copy the enemy units of a civilisation island, but not its animals")
	return true


## Troll island: the last enemy unit opens the treasure; collecting it wins.
func _check_troll_win() -> bool:
	var quest := _quest(TROLLS_1, {SPEARMAN: 4}, 0)
	quest.start(1)
	var treasure: BattleFighter = quest.sim.fighters.filter(quest.is_treasure).front()
	_check(not quest.collect(treasure), "the closed treasure cannot be collected")
	var opened := [false]
	quest.treasure_opened.connect(func() -> void: opened[0] = true)
	for enemy in quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == ENEMY and item.is_unit()):
		quest.sim.receive_attack(enemy, 100000, null)
	_check(opened[0] and quest.is_treasure_open() and quest.enemies_left() == 0, "the last enemy unit opens the treasure")
	_check(not quest.is_won(), "no win before the treasure")
	var gold := quest.gold
	var half := int(_config.quest_gold["QUEST_ISLA_TROLLS_1"] * _config.quest_gold_multipliers[0]) / 2
	_check(quest.collect(treasure) and quest.is_won() and quest.gold == gold + half, "collecting the treasure wins and gives the other half of the gold")
	_check(not treasure in quest.sim.fighters, "the treasure leaves the map")
	var ended := [false]
	quest.ended.connect(func() -> void: ended[0] = true)
	for i in QuestBattle.END_DELAY_FRAMES - 1:
		quest.sim.step()
		quest.update()
	_check(not ended[0], "the quest does not end at once")
	quest.sim.step()
	quest.update()
	_check(ended[0] and quest.is_finished(), "the quest ends 1 second after the win")
	var result := quest.result()
	_check(result["win"] == 1 and result["voluntary_end"] == 0 and result["quest_id"] == TROLLS_1 and result["difficulty"] == 1, "the result is a win with 1 star")
	_check(result["resources"]["x"] <= _config.quest_max_xp and result["resources"]["x"] > 0, "the killed enemies gave experience")
	return true


## Civilisation island: the last town hall wins. Without units the player loses.
func _check_civilisation_win_and_loss() -> bool:
	var quest := _quest(VIKINGS, {SPEARMAN: 4}, 0)
	quest.start(1)
	var hall: BattleFighter = quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.def.subcat_functional == QuestBattle.SUBCAT_TOWN_HALL).front()
	quest.sim.receive_attack(hall, 1000000, null)
	_check(quest.is_won() and quest.enemies_left() == 0, "the last town hall wins")
	var lost := _quest(ATLANTIS, {SPEARMAN: 2}, 0)
	lost.start(1)
	for unit in lost.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == PLAYER):
		lost.sim.receive_attack(unit, 100000, null)
	for i in QuestBattle.END_DELAY_FRAMES:
		lost.sim.step()
		lost.update()
	_check(lost.is_finished() and not lost.is_won(), "the quest ends as a loss when the last unit of the player is dead")
	_check(lost.result()["win"] == 0, "the result is a loss")
	# The Viking island counts one free unit that its map does not have.
	var vikings := _quest(VIKINGS, {SPEARMAN: 1}, 0)
	vikings.start(1)
	vikings.sim.receive_attack(vikings.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == PLAYER).front(), 100000, null)
	for i in QuestBattle.END_DELAY_FRAMES:
		vikings.sim.step()
		vikings.update()
	_check(not vikings.is_finished(), "on the Viking island the player does not lose with the last unit, as in the client")
	return true


## After the quest, 60 percent of the dead units (rounded up) come back; the
## free units of the island always come back.
func _check_units_back() -> bool:
	var quest := _quest(TROLLS_2, {SPEARMAN: 10}, 0)
	quest.start(1)
	var spearmen := quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == PLAYER and item.def.id == SPEARMAN)
	for i in 7:
		quest.sim.receive_attack(spearmen[i], 100000, null)
	var wallace: BattleFighter = quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.def.id == WALLACE).front()
	quest.sim.receive_attack(wallace, 100000, null)
	quest.retreat()
	var result := quest.result()
	var entries := {}
	for entry: Array in result["units"]:
		entries[entry[0]] = entry
	var back: int = entries[SPEARMAN][3] + entries[WALLACE][3] - 1
	_check(entries[SPEARMAN][1] == 10 and entries[SPEARMAN][2] == 7, "the unit list counts 10 spearmen that went and 7 that died: %s" % [entries[SPEARMAN]])
	_check(back == ceili(8 * _config.quest_units_back_percent / 100.0), "%d of the 8 dead units come back" % back)
	_check(entries[WALLACE][3] >= 1 and entries[WALLACE][1] == 0, "the free unit comes back")
	_check(result["voluntary_end"] == 1 and result["win"] == 0, "a withdrawal is a voluntary end without a win")
	_check(quest.result() == result, "the result does not change when it is asked again")
	var extra: Array = []
	for i in 10:
		extra.append([SPEARMAN, 60 + i, 70])
	var village := _village(extra)
	var before := _count(village, SPEARMAN)
	var lost := quest.lost_units()
	village.end_quest(result)
	_check(_count(village, SPEARMAN) == before - int(lost.get(SPEARMAN, 0)), "the village loses the spearmen that did not come back")
	return true


## The water of an island takes no units.
func _check_water() -> bool:
	var quest := _quest(TROLLS_1, {SPEARMAN: 30}, 0)
	var water := Vector2i(5, 5)  # The first land area of troll island 1 is water.
	_check(QuestIsland.find(TROLLS_1).is_water(water) and not quest.sim.is_free(water), "water is not free")
	var on_water := quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return QuestIsland.find(TROLLS_1).is_water(item.tile))
	_check(on_water.is_empty(), "no item stands on water")
	var unit: BattleFighter = quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == PLAYER).front()
	_check(not quest.sim.walk(unit, water), "a unit cannot walk into the water")
	return true


func _quest(quest_id: String, army: Dictionary, rank: int) -> QuestBattle:
	var map := Village.load_from_file(_data.path_join("quests/%s.save.json" % quest_id), _config)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return QuestBattle.create(QuestIsland.find(quest_id), map, army, _config, rank, null, rng)


## The starting village, with extra items [item id, x, y] on its map.
func _village(extra: Array = []) -> Village:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_data.path_join("villages/initial.json")))
	for entry: Array in extra:
		document["maps"][0]["items"].append([entry[0], entry[1], entry[2], 0, NOW, 0, [], {}])
	DirAccess.make_dir_recursive_absolute("user://checks")
	var path := "user://checks/quest_village.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	return Village.load_from_file(path, _config)


## The save of the village as the port writes it.
func _saved(village: Village) -> Dictionary:
	var path := "user://checks/quest_saved.json"
	village.save_to_file(path)
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _result(quest_id: String, stars: int, won: bool) -> Dictionary:
	return {"quest_id": quest_id, "difficulty": stars, "win": 1 if won else 0, "resources": {"g": 0, "x": 0}, "units": []}


func _count(village: Village, unit_id: int) -> int:
	return village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == unit_id).size()


func _team_count(quest: QuestBattle, team: BattleFighter.Team) -> int:
	return quest.sim.fighters.filter(func(item: BattleFighter) -> bool: return item.team == team and item.is_unit()).size()


func _team_units(quest: QuestBattle, team: BattleFighter.Team) -> int:
	return _team_count(quest, team)


func _check(passed: bool, description: String) -> void:
	if not passed:
		_failures += 1
	print("%s: %s" % ["ok" if passed else "FAILED", description])
