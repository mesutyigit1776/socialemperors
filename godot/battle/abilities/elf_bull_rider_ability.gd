class_name ElfBullRiderAbility
extends BattleAbility
## The Red Bull Rider (ElfRedBullRiderDelegate of the client). Each attack hits
## its target and pushes it 2 tiles away. The sixth attack grabs one enemy unit
## within 2 tiles with 350 life or less (special attack 2, it cannot act); the
## unit dies at the end of the animation. The twelfth attack is a smash
## (special attack 1): at frames 60, 65 and 70 up to 10 enemy units within 2
## tiles, not on its tile, take a quarter of its attack and fly 3 tiles away.

const MAX_LIFE_TO_EAT := 350

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _counter == 12:
		var smash := func() -> void:
			for unit in sim.items_near(fighter.tile, 2, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
				if unit.ability == null or not unit.ability.immune_to_push:
					sim.receive_attack(unit, fighter.attack / 4, fighter)
					sim.push_in_air(unit, fighter, 3)
		play(sim, fighter, UnitSprite.Action.SPECIAL, 80, {60: smash, 65: smash, 70: smash}, Callable(), true)
	elif _counter == 6:
		var grabbed := sim.items_near(fighter.tile, 2, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)
		for unit in grabbed:
			unit.incapacitated = true
		if not grabbed.is_empty():
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {}, func() -> void:
				for unit in grabbed:
					if not unit.dead:
						unit.incapacitated = false
						sim.kill(unit, fighter), true)
	else:
		var target := fighter.target
		sim.receive_attack(target, fighter.attack, fighter)
		if target.is_unit() and not target.dead:
			sim.push_in_air(target, fighter, 2)
	_counter += 1
	if _counter > 12:
		_counter = 1
	return false
