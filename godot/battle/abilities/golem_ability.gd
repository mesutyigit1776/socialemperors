class_name GolemAbility
extends BattleAbility
## The small Stone Golem (GolemDelegate of the client). In its special attack
## it hits up to 4 units or buildings of the other side on the 4 diagonal tiles
## next to it with its attack, and units fly 2 tiles away.

const MAX_TARGETS := 4
const PUSH := 2


func _init() -> void:
	special_intervals = [140]
	special_durations = [35]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0) and fighter.target != null:
		var hit := 0
		for dy in [-1, 1]:
			for dx in [-1, 1]:
				if hit >= MAX_TARGETS:
					break
				for target in sim.items_near(fighter.tile + Vector2i(dx, dy), 0, 1, enemy_side(fighter), true, GiantBossAbility._can_hit):
					sim.receive_attack(target, fighter.attack, fighter)
					if target.is_unit():
						sim.push_in_air(target, fighter, PUSH)
					hit += 1
	return fighter.animation == BattleFighter.Pose.ATTACKING
