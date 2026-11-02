class_name ScorpionAbility
extends BattleAbility
## The Scorpion (EscorpionDelegate of the client), a ranged unit that hits like
## a melee unit. Special attack 1 stings the target: its attack and a poison of
## half its attack, 5 times. Special attack 2 grabs two enemy units within 4
## tiles with 350 life or less, when there are two: they cannot act and die at
## frame 54 of the animation.

const MAX_LIFE_TO_EAT := 350
const CLAWS_DISTANCE := 4
const GRAB_END_FRAME := 54

var _stinging := false
var _eating := false


func _init() -> void:
	special_intervals = [105, 105]
	special_durations = [30, 55]
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0) and not _stinging:
		var target := fighter.target
		if target != null and not target.dead:
			sim.receive_attack(target, fighter.attack, fighter)
			if target.is_unit():
				sim.poison(target, fighter.attack / 2, 5, 0, fighter)
	elif in_special(fighter, 1) and not _eating:
		var grabbed := sim.items_near(fighter.tile, CLAWS_DISTANCE, 2, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)
		if grabbed.size() == 2:
			_eating = true
			for unit in grabbed:
				unit.incapacitated = true
			sim.after(GRAB_END_FRAME, func() -> void:
				_eating = false
				for unit in grabbed:
					if not unit.dead:
						unit.incapacitated = false
						sim.kill(unit, fighter))
	return not (_eating or _stinging)
