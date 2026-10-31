extends SceneTree
## Checks the rules of the spells without a window.
##
##   godot --headless --path godot --script res://checks/spell_check.gd -- --data <data folder>
##
## It needs config.json, spells.json and villages/initial.json from an import
## of the unchanged socialemperors files: the spells, prices, units and frame
## labels below come from them.
## The exit code is the number of failed checks.

const FIRE_HAVOC := 2  # level 35, 1000 gold or 35 cash, 5 mana
const ETHER_SHIELD := 9  # level 38, 50000 gold or 40 cash, 6 mana
const BLACK_HOLE := 16  # level 49
const HAIL := 3
const FROSTBITE := 4
const SACRED_RAIN := 5
const GOLEMS_WRATH := 6
const HELL_ABYSS := 7
const POISON_FLOOD := 8
const COLOSSUS := 11
const SUMMON_DRAGON := 12
const INSTANT_LIMIT := 13
const DOUBLE_SPEED := 14
const DOUBLE_RANGE := 15
const SPEARMAN := 509  # life 40, speed 3, range 1
const LIGHT_ARCHER := 516  # range 5
const STONE_GOLEM := 538  # boss
const MILL := 300  # 2x2
const TOWN_HALL := 26  # 4x4
const TOWER := 29
const SUMMONED_GOLEM := 630
const PLAYER := BattleFighter.Team.PLAYER
const ENEMY := BattleFighter.Team.ENEMY
const TILE := Vector2i(50, 50)  # The tile on which the checks cast.

var _data: String
var _config: GameConfig
var _graphics: Dictionary
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
	var graphics: Variant = BattleSpell.read_graphics(_data.path_join("spells.json"))
	if graphics == null:
		quit(1)
		return
	_graphics = graphics
	# A script error stops only the function in which it occurs, so a scenario
	# that does not return true has stopped before its end.
	for scenario: Callable in [_check_configuration, _check_buy_mana, _check_buy_spell, _check_use_spell, _check_spells_in_port, _check_fire_havoc, _check_hail, _check_frostbite, _check_sacred_rain, _check_summons, _check_swallowing, _check_poison_flood, _check_ether_shield, _check_colossus, _check_double_stats, _check_descriptions]:
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


func _check_spells_in_port() -> bool:
	var created := _config.spells.filter(func(spell: GameConfig.SpellDef) -> bool: return BattleSpell.create(spell, _config, {}) != null)
	_check(created.size() == 14 and BattleSpell.create(_config.get_spell(INSTANT_LIMIT), _config, {}) == null, "the port has 14 spells; Instant Limit is not in the port")
	_check(not BattleSpell.is_in_port(INSTANT_LIMIT) and BattleSpell.is_in_port(FIRE_HAVOC), "the spell book can tell which spells are in the port")
	return true


## 30 balls: ball n acts 10 frames (the label "attack") after its delay of
## 3 n frames, at least 1. The balls fall on the area 3 tiles further left and
## up than the marked square, or on enemy units within 2 tiles of its middle.
## The effects of a battle frame show after the step of that frame.
func _check_fire_havoc() -> bool:
	var sim := _sim(31)
	var tiles := {}
	for x in range(40, 56):
		for y in range(40, 56):
			var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(x, y), ENEMY)
			unit.health = 100000
			unit.ai.condition = BattleAI.Condition.PASSIVE
	var friend := _passive(sim.add_item(_config.get_item(SPEARMAN), Vector2i(60, 60), PLAYER))
	var frames: Array[int] = []
	sim.hit.connect(func(target: BattleFighter, attacker: BattleFighter, _damage: int, _critical: bool) -> void:
		if attacker == null:
			frames.append(sim.frame)
			tiles[target.tile] = true)
	_spell(FIRE_HAVOC).cast(sim, TILE, 1)
	_run(sim, 200)
	_check(frames.size() == 30 and frames[0] == 11 and frames[1] == 13 and frames[29] == 29 * 3 + 10, "30 balls fall at frame 11, then every 3 frames from frame 13 (%d balls)" % frames.size())
	var inside := tiles.keys().all(func(tile: Vector2i) -> bool: return tile.x >= TILE.x - 6 and tile.x <= TILE.x - 1 and tile.y >= TILE.y - 6 and tile.y <= TILE.y - 1)
	_check(inside, "the balls fall on the tiles from 6 to 1 tiles left and up of the tile")
	_check(friend.health == friend.max_life(), "the balls do not hurt the units of the player")
	return true


## A stone on each of the 6 x 6 tiles: units of the enemy are stunned and take a
## tenth of the damage, buildings take the damage on each of their tiles.
func _check_hail() -> bool:
	var sim := _sim(32)
	var unit := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(5, 5), ENEMY))
	unit.health = 100000
	var mill := sim.add_item(_config.get_item(MILL), TILE - Vector2i(1, 1), ENEMY)
	mill.health = 100000
	var hall := sim.add_item(_config.get_item(TOWN_HALL), TILE + Vector2i(0, -4), ENEMY)
	var outside := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(6, 6), ENEMY))
	var friend := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(3, 3), PLAYER))
	var hits := {}
	sim.hit.connect(func(target: BattleFighter, _attacker: BattleFighter, damage: int, _critical: bool) -> void:
		hits[target] = hits.get(target, []) + [damage])
	var stunned := [false]
	sim.state_changed.connect(func(item: BattleFighter) -> void:
		if item == unit and item.stunned:
			stunned[0] = true)
	_spell(HAIL).cast(sim, TILE, 1)
	_run(sim, 130)
	_check(stunned[0] and hits[unit].size() == 1 and hits[unit][0] >= 75 and hits[unit][0] <= 120, "an enemy unit is stunned and takes a tenth of 800 (%s)" % [hits.get(unit)])
	_check(hits[mill].size() == 4 and hits[mill].all(func(d: int) -> bool: return d >= 790), "a 2 x 2 building takes a stone on each tile")
	_check(not hits.has(hall) and not hits.has(outside) and not hits.has(friend), "the town hall, the player and tiles outside the area take nothing")
	return true


func _check_frostbite() -> bool:
	var sim := _sim(33)
	var unit := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(2, 2), ENEMY))
	var boss := _passive(sim.add_item(_config.get_item(STONE_GOLEM), TILE, ENEMY))
	var friend := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(4, 4), PLAYER))
	var frozen_at := [-1]
	sim.state_changed.connect(func(item: BattleFighter) -> void:
		if item == unit and item.frozen and frozen_at[0] < 0:
			frozen_at[0] = sim.frame)
	_spell(FROSTBITE).cast(sim, TILE, 1)
	_run(sim, 70)
	_check(frozen_at[0] > 0 and frozen_at[0] <= 61 and unit.health == unit.max_life(), "an enemy unit freezes by frame 61 and takes no damage")
	_check(not boss.frozen and not friend.frozen, "bosses and units of the player do not freeze")
	_run(sim, frozen_at[0] + 451 - sim.frame)
	_check(unit.frozen, "the freeze lasts 451 frames")
	_run(sim, 1)
	_check(not unit.frozen and not unit.incapacitated, "then the unit can act again")
	return true


func _check_sacred_rain() -> bool:
	var sim := _sim(34)
	var friend := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(1, 1), PLAYER))
	friend.health = 10
	var enemy := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE - Vector2i(2, 2), ENEMY))
	enemy.health = 10
	_spell(SACRED_RAIN).cast(sim, TILE, 3)
	_run(sim, 400)
	if SacredRainSpell.FIX_CLIENT_ERROR:
		_check(friend.health == friend.max_life(), "the corrected rain heals the units of the player")
	else:
		_check(friend.health == 10 and enemy.health == 10, "as in the client, the rain heals nobody")
	return true


## A golem comes at frame 58 (label 57) on the free tile nearest to the tile;
## a dragon of level 1 leaves after 30 seconds.
func _check_summons() -> bool:
	var sim := _sim(35)
	sim.add_item(_config.get_item(MILL), TILE, ENEMY)
	var summoned: Array[BattleFighter] = []
	sim.added.connect(func(item: BattleFighter) -> void: summoned.append(item))
	_spell(GOLEMS_WRATH).cast(sim, TILE, 2)
	_run(sim, 58)
	_check(summoned.is_empty(), "no golem before its frame")
	_run(sim, 1)
	var golem: BattleFighter = summoned[0] if not summoned.is_empty() else null
	_check(golem != null and golem.def.id == SUMMONED_GOLEM and golem.team == PLAYER and golem.summoned and golem.health == 5000, "a golem of level 2 with 5000 life comes at frame 58")
	_check(golem != null and golem.tile.distance_squared_to(TILE) <= 2 and golem.tile != TILE, "it comes on a free tile next to the tile")
	summoned.clear()
	_spell(SUMMON_DRAGON).cast(sim, Vector2i(80, 80), 1)
	_run(sim, 59)
	var dragon: BattleFighter = summoned[0] if not summoned.is_empty() else null
	_check(dragon != null and dragon.def.id in DragonSpell.DRAGONS and dragon.health == 4000 and dragon.tile == Vector2i(80, 80), "a Bahamut dragon with 4000 life comes on the tile")
	_run(sim, 914)
	_check(dragon in sim.fighters, "the dragon stays 30 seconds and fades for half a second")
	_run(sim, 1)
	_check(not dragon in sim.fighters and not dragon.dead, "then it leaves without dying")
	return true


## Hell Abyss and Black Hole swallow enemy units and buildings within half the
## area of the middle of the square; bosses, town halls and big units stay.
func _check_swallowing() -> bool:
	var sim := _sim(36)
	var middle := TILE - Vector2i(2, 2)
	var near := sim.add_item(_config.get_item(SPEARMAN), middle + Vector2i(3, 0), ENEMY)
	var far := sim.add_item(_config.get_item(SPEARMAN), middle + Vector2i(3, 1), ENEMY)
	var tower := sim.add_item(_config.get_item(TOWER), middle, ENEMY)
	var boss := sim.add_item(_config.get_item(STONE_GOLEM), middle + Vector2i(1, 1), ENEMY)
	var friend := sim.add_item(_config.get_item(SPEARMAN), middle - Vector2i(1, 1), PLAYER)
	for item in [near, far, boss, friend]:
		_passive(item)
	_spell(HELL_ABYSS).cast(sim, TILE, 1)
	_run(sim, 10 + 18 + 15 + 1)
	_check(near.dead and tower.dead and not tower in sim.fighters, "Hell Abyss swallows the enemy unit and the tower within 3 tiles")
	_check(not far.dead and not boss.dead and not friend.dead, "a unit farther away, the boss and the units of the player stay")

	var hole := _sim(37)
	var first := _passive(hole.add_item(_config.get_item(SPEARMAN), middle + Vector2i(1, 0), ENEMY))
	_spell(BLACK_HOLE).cast(hole, TILE, 1)
	_run(hole, 10 + 45 + 15 + 1)
	_check(first.dead, "Black Hole swallows at frame 55")
	var late := _passive(hole.add_item(_config.get_item(SPEARMAN), middle + Vector2i(0, 1), ENEMY))
	_run(hole, 30)
	_check(late.dead, "and again every second")
	_run(hole, 30 * 15)
	var after_end := _passive(hole.add_item(_config.get_item(SPEARMAN), middle, ENEMY))
	_run(hole, 60)
	_check(not after_end.dead, "the hole closes after 15 seconds")
	return true


func _check_poison_flood() -> bool:
	var sim := _sim(38)
	var inside := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE + Vector2i(3, 4), ENEMY))
	var outside := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE + Vector2i(4, 4), ENEMY))
	var boss := _passive(sim.add_item(_config.get_item(STONE_GOLEM), TILE - Vector2i(2, 2), ENEMY))
	_spell(POISON_FLOOD).cast(sim, TILE, 1)
	_run(sim, 10 + 17 + 1)
	_check(inside.poisoned and not outside.poisoned and not boss.poisoned, "the enemy units within 5 tiles of the tile are poisoned, bosses not")
	return true


func _check_ether_shield() -> bool:
	var sim := _sim(39)
	var spell := _spell(ETHER_SHIELD)
	spell.cast(sim, TILE, 1)
	if EtherShieldSpell.FIX_CLIENT_ERRORS:
		_check(sim.shield_factor(TILE - Vector2i(4, 4), PLAYER) == 0.7 and sim.shield_factor(TILE - Vector2i(5, 5), PLAYER) == 1.0, "the corrected shield covers the marked 5 x 5 tiles")
		return true
	_check(sim.shield_factor(TILE - Vector2i(6, 6)) == 0.7 and sim.shield_factor(TILE - Vector2i(7, 7)) == 1.0, "as in the client, the shield of level 1 covers 7 x 7 tiles")
	_check(sim.shield_factor(TILE, ENEMY) == 0.7, "as in the client, the shield also protects enemies")
	_run(sim, 601)
	_check(sim.shield_factor(TILE) == 0.7, "the shield lasts 20 seconds and 1 frame")
	_run(sim, 1)
	_check(sim.shield_factor(TILE) == 1.0, "then it ends")
	spell.cast(sim, TILE, 3)
	_check(sim.shield_factor(TILE) == 1.0, "as in the client, the shield of level 3 protects nothing")
	var again := _sim(40)
	spell.cast(again, TILE, 1)
	spell.cast(again, TILE + Vector2i(20, 20), 1)
	_run(again, 700)
	_check(again.shield_factor(TILE) == 0.7 and again.shield_factor(TILE + Vector2i(20, 20)) == 1.0, "as in the client, a second cast leaves the first shield for the rest of the battle")
	return true


func _check_colossus() -> bool:
	var sim := _sim(41)
	var friend := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE + Vector2i(3, 4), PLAYER))
	var far := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE + Vector2i(4, 4), PLAYER))
	var enemy := _passive(sim.add_item(_config.get_item(SPEARMAN), TILE, ENEMY))
	_spell(COLOSSUS).cast(sim, TILE, 1)
	_run(sim, 20)
	_check(not friend.enlarged, "nothing happens before frame 20 (a delay of 10, and 10 frames without a label)")
	_run(sim, 1)
	_check(friend.enlarged and not far.enlarged and not enemy.enlarged, "the units of the player within 5 tiles get bigger")
	_run(sim, 900)
	_check(not friend.enlarged, "for 30 seconds")
	return true


## 2x Speed doubles once, also when cast again. 2x Range stops at the first
## building, as in the client.
func _check_double_stats() -> bool:
	var sim := _sim(42)
	var middle := TILE - Vector2i(2, 2)
	var unit := _passive(sim.add_item(_config.get_item(SPEARMAN), middle + Vector2i(1, 0), PLAYER))
	var speed := _spell(DOUBLE_SPEED)
	speed.cast(sim, TILE, 1)
	_run(sim, 21)
	_check(unit.speed == 6, "2x Speed doubles the speed at frame 20")
	speed.cast(sim, TILE, 1)
	_run(sim, 21)
	_check(unit.speed == 6, "a second cast does not double it again")
	_run(sim, 20 + 450 + 1 - sim.frame)
	_check(unit.speed == 6, "the end of the first cast does not count for the unit")
	_run(sim, 41 + 450 + 1 - sim.frame)
	_check(unit.speed == 3, "the speed comes back 15 seconds after the second cast")

	var ranges := _sim(43)
	var far := _passive(ranges.add_item(_config.get_item(LIGHT_ARCHER), middle + Vector2i(2, 0), PLAYER))
	ranges.add_item(_config.get_item(TOWER), middle + Vector2i(1, 0), PLAYER)
	var near := _passive(ranges.add_item(_config.get_item(LIGHT_ARCHER), middle, PLAYER))
	_spell(DOUBLE_RANGE).cast(ranges, TILE, 1)
	_run(ranges, 21)
	_check(far.attack_range == 10 and near.attack_range == 5, "2x Range stops at the first building: the units after it get nothing")
	_run(ranges, 900)
	_check(far.attack_range == 10, "the units before it keep the double range")
	return true


## The spell window shows the texts of the client with the numbers of the spells.
func _check_descriptions() -> bool:
	_check(BattleSpell.describe(_config.get_spell(FIRE_HAVOC), _config) == ["Area: 5x5 / Damage: 150+30", "Area: 7x7 / Damage: 200+80", "Area: 9x9 / Damage: 250+150"], "Fire Havoc has the texts of the client")
	_check(BattleSpell.describe(_config.get_spell(ETHER_SHIELD), _config)[2] == "Area: 9x9 / Lasts: 40s / DMG reduction: 60%", "Ether Shield names its marked area")
	_check(BattleSpell.describe(_config.get_spell(INSTANT_LIMIT), _config)[0] == "Area: 5x5", "Instant Limit has its text, also without a port")
	return true


func _spell(spell_id: int) -> BattleSpell:
	var spell := _config.get_spell(spell_id)
	return BattleSpell.create(spell, _config, _graphics.get(spell.img_name, {}))


func _sim(seed: int) -> BattleSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return BattleSim.new(rng)


## A unit that does not look for enemies and does not fight back.
func _passive(unit: BattleFighter) -> BattleFighter:
	unit.ai.condition = BattleAI.Condition.PASSIVE
	return unit


func _run(sim: BattleSim, frames: int) -> void:
	for i in frames:
		sim.step()


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
