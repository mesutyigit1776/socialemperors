class_name DragonQuest
extends QuestBattle
## The first dragon island (QuestBossDragon of the client). The map has only
## rocks and the Huge Egg; the items keep the side of their race, so the egg
## is an enemy. When the egg is destroyed, rocks close the entrance one after
## the other, and then the dragon boss comes (DragonBossAI). The stars make
## the boss stronger. The player wins when the boss is dead.
##
## The quest gives no experience. The gold is shared only when the boss comes,
## and the half for the win is doubled.

const EGG := 437
const ROCK := 946
const BOSS := 657
const BOSS_TILE := Vector2i(49, 26)
## A rock closes the entrance every 500 ms, from ENTRANCE_FIRST_ROW to
## ENTRANCE_LAST_ROW in column ENTRANCE_COLUMN; then the boss comes.
const ROCK_FRAMES := 15
const ENTRANCE_COLUMN := 61
const ENTRANCE_FIRST_ROW := 29
const ENTRANCE_LAST_ROW := 20
## The attack, the speed and the life of the boss for 1, 2 and 3 stars.
const BOSS_STATS: Array[Vector3i] = [Vector3i(35, 10, 12000), Vector3i(40, 13, 20000), Vector3i(47, 20, 30000)]

var boss: BattleFighter
var _egg: BattleFighter
var _entrance_row := ENTRANCE_FIRST_ROW


func counter_texts() -> Array[String]:
	return []


func recovered_percent() -> int:
	return _config.quest_units_back_boss


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	return BattleFighter.Team.NEUTRAL if def.race == "n" else BattleFighter.Team.ENEMY


func _gives_map_units() -> bool:
	return false


func _on_placed(item: BattleFighter) -> void:
	if item.def.id == EGG:
		_egg = item


func _apply_stars() -> void:
	pass


func _divide_reward() -> void:
	pass


func _gives_reward(item: BattleFighter) -> bool:
	if _pays_gold(item):
		gold += _gold_per_kill
		changed.emit()
	return false


func _on_enemy_died(item: BattleFighter) -> void:
	if item == _egg:
		sim.after(ROCK_FRAMES, _close_entrance)
	elif item == boss:
		_win()


## Puts the next rock in the entrance, or brings the boss.
func _close_entrance() -> void:
	if _entrance_row >= ENTRANCE_LAST_ROW:
		var rock := _config.get_item(ROCK)
		_add(rock, Vector2i(ENTRANCE_COLUMN, _entrance_row), BattleFighter.Team.NEUTRAL)
		_entrance_row -= rock.width
		sim.after(ROCK_FRAMES, _close_entrance)
		return
	var tile: Variant = BattleFormation.nearest_free_tile(BOSS_TILE, IsoGrid.MAP_TILES, sim.is_free)
	if tile == null:
		return
	boss = _add(_config.get_item(BOSS), tile, BattleFighter.Team.ENEMY)
	var stats := BOSS_STATS[stars - 1]
	boss.attack = stats.x
	sim.set_speed(boss, stats.y)
	boss.max_health = stats.z
	boss.health = stats.z
	if boss.ai is DragonBossAI:
		boss.ai.difficulty = stars
	super._divide_reward()
	_gold_on_win *= 2
