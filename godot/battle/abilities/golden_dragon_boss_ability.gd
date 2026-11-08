class_name GoldenDragonBossAbility
extends BattleAbility
## The Golden Dragon Boss of the second dragon island (EvilGoldenDragonDelegate
## of the client). Each normal attack shoots a second shot SECOND_SHOT_FRAMES
## after the first. Its special attack shakes the ground: up to
## QUAKE_TARGETS enemies within its range take 1.5 times its attack, and units
## fly 2 tiles away. Push, freeze, poison and conversion do not act on it.

const SHOT := "p.goldenDragon"
const SECOND_SHOT_FRAMES := 15  ## The shot delay and 100 ms.
const QUAKE_TARGETS := 6
const QUAKE_MULTIPLIER := 1.5
const PUSH := 2


func _init() -> void:
	special_intervals = [126]
	special_durations = [42]
	shot_delay = 12
	shot_graphic = SHOT
	immune_to_push = true
	immune_to_freeze = true
	immune_to_poison = true
	immune_to_conversion = true
	immune_to_burn = true
	immune_to_electricity = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if fighter.animation == BattleFighter.Pose.ATTACKING:
		sim.sound_played.emit(SoundEffect.ATTACK_BIG_ARCHER, -1)
		var target := fighter.target
		sim.after(SECOND_SHOT_FRAMES, func() -> void:
			if not fighter.dead and target != null and not target.dead:
				sim.shoot(fighter, target, SHOT, fighter.attack))
	elif in_special(fighter, 0):
		for enemy in sim.items_near(fighter.tile, fighter.attack_range, QUAKE_TARGETS, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
			sim.receive_attack(enemy, int(fighter.attack * QUAKE_MULTIPLIER), fighter)
			if enemy.is_unit():
				sim.push_in_air(enemy, fighter, PUSH)
		return false
	return true
