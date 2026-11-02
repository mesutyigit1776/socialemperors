class_name OrcSlasherAbility
extends BattleAbility
## The Brutal Slasher and the Evil Demon (OrcSlasherDelegate of the client).
## Each attack hits the target. The eighth attack is a whirlwind (special
## attack 1) for 6 seconds: each time the animation reaches frame 30, up to 10
## enemy units within 3 tiles, not on its tile, take its attack and fly 3 tiles
## away. The sixteenth attack is a smash (special attack 2, it cannot act) at
## frame 30: the target takes 3 times its attack, and up to 5 enemy units
## within 2 tiles of it take half its attack and fly 3 tiles away.

const WHIRLWIND_FRAMES := 180  ## 6 seconds.

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _counter == 8:
		var length := sim.animation_frames(fighter, UnitSprite.Action.SPECIAL, 40)
		var events := {}
		var at := 30
		while at <= WHIRLWIND_FRAMES:
			events[at] = func() -> void:
				for unit in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
					if unit.ability == null or not unit.ability.immune_to_push:
						sim.receive_attack(unit, fighter.attack, fighter)
						sim.push_in_air(unit, fighter, 3)
			at += length
		sim.play_special(fighter, UnitSprite.Action.SPECIAL, WHIRLWIND_FRAMES, events)
	elif _counter == 16:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {30: func() -> void:
			var target := fighter.target
			if target == null or target.dead:
				return
			var near := sim.items_near(target.tile, 2, 5, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead)
			sim.receive_attack(target, fighter.attack * 3, fighter)
			for unit in near:
				if not unit.dead and (unit.ability == null or not unit.ability.immune_to_push):
					sim.receive_attack(unit, fighter.attack / 2, fighter)
					sim.push_in_air(unit, fighter, 3)}, Callable(), true)
	else:
		sim.receive_attack(fighter.target, fighter.attack, fighter)
	_counter += 1
	if _counter > 16:
		_counter = 1
	return false
