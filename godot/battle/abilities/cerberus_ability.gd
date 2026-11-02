class_name CerberusAbility
extends BattleAbility
## Cerberus (CerberusDelegate of the client). Its graphic is 1.6 times bigger.
##
## - Near the target (2 tiles or less), every fifth attack is a stomp (special
##   attack 1): at frame STOMP_FRAME the enemy units within STOMP_RANGE tiles
##   take its attack / 2.2 and fly 3 tiles away. The other attacks are three
##   bites, 8 and then 9 frames apart; the second and third bite another unit
##   within 2 tiles when there is one.
## - Farther away it breathes three fireballs (special attack 2), the first
##   after the shot delay; the second and third go to other units in its range.
##   It does not choose a target that cannot act.
## - When it walks, the attack stops.

const FIREBALL := "p.fireBall"
const STOMP_FRAME := 16
const STOMP_RANGE := 5
const STOMP_PUSH := 3
const STOMP_DIVISOR := 2.2
const STOMP_END_FRAMES := 16
const BITE_FRAMES: Array[int] = [8, 9, 9]
const BITE_RANGE := 2

var _attacks := 0
var _in_special := false
var _attack_id := 0


func _init() -> void:
	scale = 1.6
	shot_delay = 13
	shot_graphic = FIREBALL


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	_attack_id += 1
	var id := _attack_id
	if sim.distance(fighter, fighter.target) <= 2:
		if _attacks % 5 == 0:
			_in_special = true
			sim.play_special(fighter, UnitSprite.Action.SPECIAL, 1 << 20, {STOMP_FRAME: func() -> void: _stomp(sim, fighter, id)})
		else:
			_in_special = true
			var wait := 0
			for i in BITE_FRAMES.size():
				wait += BITE_FRAMES[i]
				sim.after(wait, func() -> void: _bite(sim, fighter, id, i))
			sim.after(wait + BITE_FRAMES[-1], func() -> void: _end(sim, fighter, id))
		_attacks += 1
		return false
	if fighter.target.is_unit() and fighter.target.incapacitated:
		var other := _other_target(sim, fighter, fighter.attack_range, true)
		if other == null:
			return false
		sim.set_target(fighter, other)
	_in_special = true
	sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, 1 << 20)
	for i in 3:
		sim.after(shot_delay + i, func() -> void:
			if id != _attack_id or fighter.dead:
				return
			if i > 0 or fighter.target == null:
				sim.set_target(fighter, _other_target(sim, fighter, fighter.attack_range, false))
			if fighter.target != null:
				sim.shoot(fighter, fighter.target, FIREBALL, fighter.attack))
	sim.after(shot_delay + 3, func() -> void: _end(sim, fighter, id))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_attack_id += 1
		_in_special = false
		sim.stop_special(fighter)


func _stomp(sim: BattleSim, fighter: BattleFighter, id: int) -> void:
	if id != _attack_id:
		return
	for enemy in enemy_units_near(sim, fighter, fighter.tile, STOMP_RANGE, 20):
		sim.push_in_air(enemy, fighter, STOMP_PUSH)
		sim.receive_attack(enemy, int(fighter.attack / STOMP_DIVISOR), fighter)
		if fighter.target == null and not enemy.dead:
			sim.set_target(fighter, enemy)
	sim.after(STOMP_END_FRAMES, func() -> void: _end(sim, fighter, id))


func _bite(sim: BattleSim, fighter: BattleFighter, id: int, index: int) -> void:
	if id != _attack_id or fighter.dead:
		return
	if index > 0 or fighter.target == null:
		sim.set_target(fighter, _other_target(sim, fighter, BITE_RANGE, false))
	if fighter.target != null:
		sim.receive_attack(fighter.target, fighter.attack, fighter)


func _end(sim: BattleSim, fighter: BattleFighter, id: int) -> void:
	if id != _attack_id:
		return
	_in_special = false
	sim.stop_special(fighter)


## Another enemy unit within range than the current target; the current target
## when it is the only one. able: only units that can act.
func _other_target(sim: BattleSim, fighter: BattleFighter, range_tiles: int, able: bool) -> BattleFighter:
	var units := sim.items_near(fighter.tile, range_tiles, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead and not (able and item.incapacitated))
	for unit in units:
		if unit != fighter.target:
			return unit
	return fighter.target if fighter.target in units else null
