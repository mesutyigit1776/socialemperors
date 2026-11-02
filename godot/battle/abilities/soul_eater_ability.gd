class_name SoulEaterAbility
extends BattleAbility
## The Soul Eater and the Fire Soul Eater (SoulEaterDelegate and
## FireSoulEaterDelegate of the client). They shoot an energy ball 23 frames
## after an attack. Each unit that a ball kills is an eaten soul: with enough
## souls the eater grows and gets a higher attack (GROWTH).
##
## The Soul Eater also has special attacks: far from its target, every sixth
## attack is a purple beam (special attack 2, it cannot act) at frame 20 for 1
## second; near its target, every sixth attack is a smash (special attack 1) at
## frame 31: up to 10 enemy units within 3 tiles, not on its tile, take half
## its attack and fly 5 tiles away. Units that its beam or smash hurt count as
## eaten souls when they die. The client adds twice the attack of the eater to
## each shot of it that ends on a target; the port does the same.

const SOUL_EATER := 2055
const BALL_DELAY := 23
const SCALE_STEP := 0.05
## [start scale, the scales of the growth steps, the attacks of the growth steps].
const GROWTH := {
	2055: [0.6, [0.7, 0.85, 1.0], [55, 65, 75]],
	2081: [0.6, [0.7, 0.8, 0.9, 1.0, 1.1], [55, 65, 75, 85, 100]],
}

var _specials := false
var _short := 1
var _long := 1
var _souls := 0
var _step := 0
var _marked := {}  # Units that count as eaten souls when they die.


func configure(item_id: int) -> void:
	_specials = item_id == SOUL_EATER
	var growth: Array = GROWTH[item_id]
	scale = growth[0]
	shot_graphic = "p.purpleEnergyBall" if _specials else "p.lightBall"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var far := sim.distance(fighter, fighter.target) > 2
	if _specials and far and _long == 6:
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, BattleSim.FRAMES_PER_SECOND, {20: func() -> void: soul_beam(sim, fighter)}, Callable(), true)
	elif _specials and not far and _short == 6:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 40, {31: func() -> void: soul_smash(sim, fighter)}, Callable(), true)
	else:
		sim.after(BALL_DELAY, func() -> void:
			var target := fighter.target
			if fighter.dead or target == null or target.dead or fighter.animation != BattleFighter.Pose.ATTACKING:
				return
			_marked[target] = true
			sim.shoot(fighter, target, shot_graphic, fighter.attack))
	if _specials:
		if far:
			_long = _long % 6 + 1
		else:
			_short = _short % 6 + 1
	return false


func on_shot_landed(sim: BattleSim, fighter: BattleFighter, shot: BattleProjectile) -> void:
	if shot.target != null and not shot.target.dead and not fighter.dead:
		sim.receive_attack(shot.target, fighter.attack * 2, fighter)


func on_killed(_sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	if _marked.has(target) and target.is_unit():
		_eat(fighter)


func on_added(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.died.connect(func(item: BattleFighter, killer: BattleFighter) -> void:
		if killer != fighter and _marked.has(item) and item.is_unit() and not fighter.dead:
			_eat(fighter))


func _eat(fighter: BattleFighter) -> void:
	var growth: Array = GROWTH[SOUL_EATER if _specials else 2081]
	var sizes: Array = growth[1]
	if _step >= sizes.size() or scale >= sizes.back():
		return
	_souls += 1
	var grown: float = scale + SCALE_STEP * _souls
	if grown >= sizes[_step]:
		fighter.attack = growth[2][_step]
		scale = minf(grown, sizes.back())
		_souls = 0
		_step += 1


func soul_beam(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead or sim.distance(fighter, target) > fighter.attack_range:
		return
	_marked[target] = true
	sim.shoot(fighter, target, "p.purpleBeam" if _specials else "p.egyptianBeam", fighter.attack)


func soul_smash(sim: BattleSim, fighter: BattleFighter) -> void:
	for unit in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
		if unit.ability == null or not unit.ability.immune_to_push:
			sim.receive_attack(unit, fighter.attack / 2, fighter)
			sim.push_in_air(unit, fighter, 5)
			_marked[unit] = true
