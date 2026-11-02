class_name MetalTRexAbility
extends BattleAbility
## The Metal T-Rex (MetalTRexDelegate of the client), a ranged unit that hits
## like a melee unit; it cannot act during its attacks.
## - Next to its target (2 tiles or less) it bites at frame 17 of its attack:
##   its attack, and the target flies 1 tile away. The fourth attack is a claw
##   smash (special attack 2) at frames 25 to 45: up to 8 enemy units within 3
##   tiles, not on its tile, take half its attack and fly 6 tiles away.
## - Farther away it shoots a large fireball (special attack 1) at frame 15.

const FIREBALL := "p.largeFireball"

var _counter := 1


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) <= 2:
		if _counter == 4:
			var smash := func() -> void:
				for unit in sim.items_near(fighter.tile, 3, 8, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
					if unit.ability == null or not unit.ability.immune_to_push:
						sim.receive_attack(unit, fighter.attack / 2, fighter)
						sim.push_in_air(unit, fighter, 6)
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 55, {25: smash, 30: smash, 35: smash, 40: smash, 45: smash}, Callable(), true)
		else:
			play(sim, fighter, UnitSprite.Action.ATTACKING, 25, {17: func() -> void:
				var target := fighter.target
				if target == null or target.dead or sim.distance(fighter, target) > 2:
					return
				sim.receive_attack(target, fighter.attack, fighter)
				if target.is_unit():
					sim.push_in_air(target, fighter, 1)}, Callable(), true)
		_counter += 1
		if _counter > 4:
			_counter = 1
	else:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 25, {15: func() -> void:
			if fighter.target != null and not fighter.target.dead:
				sim.shoot(fighter, fighter.target, FIREBALL, fighter.attack)}, Callable(), true)
	return false
