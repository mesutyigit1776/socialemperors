class_name HorusAbility
extends BattleAbility
## The Horus Herald and the Horus Gryphon (HorusDelegate and
## HorusGryphonDelegate of the client). Both throw a spear 250 ms after an attack.
##
## - Herald: the fifth attack, next to the target (2 tiles or less), is a spin
##   (special attack 1, it cannot act) for 2 seconds: each time the animation
##   reaches frame 22, up to 10 enemies within 2 tiles, not on its tile, take
##   its attack and units fly 4 tiles away.
## - Gryphon: next to the target, the fourth attack is a smash (special attack
##   2) at frame 50: up to 10 enemies within 3 tiles take its attack and units
##   fly 3 tiles away. Farther away, the eighth attack is an energy ball rain
##   (special attack 1) for 6 seconds: each time the animation reaches frame 30
##   it throws an energy ball at the best enemy near it.

const SPEAR := "p.horusSpear"
const ENERGY_BALL := "p.energyBall"
const GRYPHON := 869
const SPEAR_DELAY := 8  ## 250 ms.

var _gryphon := false
var _counter := 0


func configure(item_id: int) -> void:
	_gryphon = item_id == GRYPHON
	_counter = 1 if _gryphon else 0


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var near := sim.distance(fighter, fighter.target) <= 2
	if _gryphon:
		if near and _counter == 4:
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 60, {50: func() -> void: _blast(sim, fighter, 3, 3)}, Callable(), true)
		elif not near and _counter == 8:
			_looping(sim, fighter, UnitSprite.Action.SPECIAL, 30, 180, func() -> void:
				var enemy := sim.nearest_enemy(fighter, fighter.tile, BattleAI.AGGRO_RANGE)
				if enemy != null:
					sim.set_target(fighter, enemy)
					sim.shoot(fighter, enemy, ENERGY_BALL, fighter.attack))
		else:
			_spear(sim, fighter)
		_counter += 1
		if _counter > 8:
			_counter = 1
		return false
	if _counter == 4 and near:
		_looping(sim, fighter, UnitSprite.Action.SPECIAL, 22, 60, func() -> void: _blast(sim, fighter, 2, 4))
	else:
		_spear(sim, fighter)
	_counter += 1
	if _counter > 4:
		_counter = 0
	return false


func _spear(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(SPEAR_DELAY, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, SPEAR, fighter.attack))


func _blast(sim: BattleSim, fighter: BattleFighter, range_tiles: int, push: int) -> void:
	for enemy in enemies_near(sim, fighter, fighter.tile, range_tiles, 10, false):
		sim.receive_attack(enemy, fighter.attack, fighter)
		if enemy.is_unit():
			sim.push_in_air(enemy, fighter, push)


## Plays a looping animation for frames frames; action runs each time the
## animation reaches frame.
func _looping(sim: BattleSim, fighter: BattleFighter, animation: int, frame: int, frames: int, action: Callable) -> void:
	var length := sim.animation_frames(fighter, animation, 30)
	var events := {}
	var at := frame
	while at <= frames:
		events[at] = action
		at += length
	sim.play_special(fighter, animation, frames, events, Callable(), true)
