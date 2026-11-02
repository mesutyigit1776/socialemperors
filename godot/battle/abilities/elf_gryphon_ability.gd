class_name ElfGryphonAbility
extends BattleAbility
## The Imperial Elf Gryphon (ElfGryphonDelegate of the client). It fights only
## next to its target (2 tiles or less), as a melee unit.
##
## - The eighth attack is a frozen rain (special attack 2, it cannot act): at
##   frame 18 ice falls on the 5 x 5 tiles around the target, each with half
##   its attack, after 10 to 45 frames; 1.5 seconds later the enemy units within
##   3 tiles freeze for 6 seconds. The attack ends after 3 seconds.
## - The sixteenth attack throws a crystal ball (special attack 1) at frame 30
##   and ends after 5 seconds.

const BALL := "p.crystalBall"
const RAIN_FRAMES := 90  ## 3 seconds.
const BALL_FRAMES := 150  ## 5 seconds.
const FREEZE_DELAY := 45
const FREEZE_FRAMES := 180  ## 6 ticks of 1 second.

var _counter := 1


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) > 2:
		return false
	var normal := false
	if _counter == 8:
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, RAIN_FRAMES, {18: func() -> void: _rain(sim, fighter)}, Callable(), true)
	elif _counter == 16:
		sim.play_special(fighter, UnitSprite.Action.SPECIAL, BALL_FRAMES, {30: func() -> void:
			if fighter.target != null and not fighter.target.dead:
				sim.shoot(fighter, fighter.target, BALL, fighter.attack)}, Callable(), true)
	else:
		normal = true
	_counter += 1
	if _counter > 16:
		_counter = 1
	return normal


func _rain(sim: BattleSim, fighter: BattleFighter) -> void:
	storm_symmetric(sim, fighter, MagicParticles.FROZEN_RAIN, 2, 0.5, 10, 35)
	sim.after(FREEZE_DELAY, func() -> void:
		if fighter.dead:
			return
		for unit in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
			sim.freeze(unit, FREEZE_FRAMES))
