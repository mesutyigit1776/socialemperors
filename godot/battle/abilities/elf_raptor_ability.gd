class_name ElfRaptorAbility
extends BattleAbility
## The Reptile Knight (ElfRaptorDelegate of the client). It shoots napalm at
## frame 13 of each attack. Next to its target (2 tiles or less):
##
## - The fourth attack breathes fire (special attack 1, it cannot act): at
##   frames 15, 20, 25, 30 and 35 up to 5 enemy units within 4 tiles, not on
##   its tile, that can act take half its attack and fly 2 tiles away; when
##   they land they burn, 5 damage every second, 5 times.
## - The eighth attack eats its target (special attack 2): at frame 8 a unit
##   with MAX_LIFE_TO_EAT life or less that can act is held, and it dies at
##   the end of the animation.

const NAPALM := "p.napalm"
const MAX_LIFE_TO_EAT := 500
const FIRE_FRAMES: Array[int] = [15, 20, 25, 30, 35]

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) > 2:
		_shoot(sim, fighter)
		return false
	if _counter == 4:
		var events := {}
		for frame in FIRE_FRAMES:
			events[frame] = func() -> void: _fire(sim, fighter)
		play(sim, fighter, UnitSprite.Action.SPECIAL, 45, events, Callable(), true)
	elif _counter == 8:
		var eaten: Array[BattleFighter] = []
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {8: func() -> void:
			var target := fighter.target
			if target == null:
				target = sim.nearest_enemy(fighter, fighter.tile, BattleAI.AGGRO_RANGE)
			if target != null and target.is_unit() and not target.dead and not target.incapacitated and target.def.life <= MAX_LIFE_TO_EAT and target.def.subcat_functional != BattleSim.SUBCAT_BOSS:
				target.incapacitated = true
				eaten.append(target)}, func() -> void:
			for unit in eaten:
				if not unit.dead:
					unit.incapacitated = false
					sim.kill(unit, fighter), true)
	else:
		_shoot(sim, fighter)
	_counter += 1
	if _counter > 8:
		_counter = 1
	return false


func _shoot(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(13, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, NAPALM, fighter.attack))


func _fire(sim: BattleSim, fighter: BattleFighter) -> void:
	for unit in sim.items_near(fighter.tile, 4, 5, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead and not item.incapacitated):
		sim.receive_attack(unit, fighter.attack / 2, fighter)
		sim.push_in_air(unit, fighter, 2)
		sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void: sim.incinerate(unit, fighter, 5, 5, 30))
