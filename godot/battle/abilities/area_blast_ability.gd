class_name AreaBlastAbility
extends BattleAbility
## The Celestial Priest and the Celestial Reaper (AngelPriestDelegate and
## DeathDelegate of the client). In their special attack, up to 10 enemies
## within their range take half their attack, and units fly 3 tiles away.

const TARGETS := 10
const PUSH := 3


func _init() -> void:
	special_intervals = [105]
	special_durations = [35]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if not in_special(fighter, 0):
		return true
	for enemy in sim.items_near(fighter.tile, fighter.attack_range, TARGETS, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
		sim.receive_attack(enemy, fighter.attack / 2, fighter)
		if enemy.is_unit():
			sim.push_in_air(enemy, fighter, PUSH)
	return false
