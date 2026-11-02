class_name ElfEagleRiderAbility
extends BattleAbility
## The Elven Eagle Rider (ElfEagleRiderDelegate of the client).
##
## - At 2 tiles or more from its target it shoots two lasers at frame 10.
## - Next to the target, the sixth attack grabs up to 2 enemy units within 2
##   tiles with MAX_LIFE_TO_EAT life or less (special attack 2): they cannot
##   act, and they die at the end of the animation. The twelfth attack is a
##   wing attack (special attack 1): at frames 70, 75 and 80, up to 4 enemy
##   units within 2 tiles take twice its attack and fly 4 tiles away. The
##   other attacks are the lasers.

const LASER := "p.goldenDragon"
const MAX_LIFE_TO_EAT := 350
const GRAB_EVERY := 6
const WINGS_EVERY := 12

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) >= 2:
		_lasers(sim, fighter)
		return false
	if _counter == GRAB_EVERY and not _eatable(sim, fighter).is_empty():
		var grabbed := _eatable(sim, fighter)
		for unit in grabbed:
			unit.incapacitated = true
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {}, func() -> void:
			for unit in grabbed:
				if not unit.dead:
					unit.incapacitated = false
					sim.kill(unit)
			var enemy := sim.nearest_enemy(fighter, fighter.tile, BattleAI.AGGRO_RANGE)
			if enemy != null:
				sim.attack(fighter, enemy), true)
	elif _counter == WINGS_EVERY:
		var wings := func() -> void:
			for unit in sim.items_near(fighter.tile, 2, 4, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
				if unit.ability == null or not unit.ability.immune_to_push:
					sim.receive_attack(unit, fighter.attack * 2, fighter)
					sim.push_in_air(unit, fighter, 4)
		play(sim, fighter, UnitSprite.Action.SPECIAL, 90, {70: wings, 75: wings, 80: wings}, Callable(), true)
	else:
		_lasers(sim, fighter)
	_counter += 1
	if _counter > WINGS_EVERY:
		_counter = 1
	return false


func _lasers(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(10, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, LASER, fighter.attack)
			sim.shoot(fighter, fighter.target, LASER, fighter.attack))


func _eatable(sim: BattleSim, fighter: BattleFighter) -> Array[BattleFighter]:
	return sim.items_near(fighter.tile, 2, 2, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)
