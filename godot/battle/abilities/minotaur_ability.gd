class_name MinotaurAbility
extends BattleAbility
## The Minotaur (MinotaurDelegate of the client), a ranged unit that hits like
## a melee unit. Every fourth attack on a unit is a horn thrust (special attack
## 1) instead: at frame 8 the target flies 5 tiles away, without damage.

const ATTACKS_BEFORE_THRUST := 4
const THRUST_FRAME := 8

var _attacks := 0


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	_attacks += 1
	if _attacks < ATTACKS_BEFORE_THRUST:
		return true
	_attacks = 0
	if not fighter.target.is_unit():
		return true
	play(sim, fighter, UnitSprite.Action.SPECIAL, 20, {THRUST_FRAME: func() -> void:
		if fighter.target != null and fighter.target.is_unit() and not fighter.target.dead:
			sim.push_in_air(fighter.target, fighter, 5)})
	return false


func on_leave_fight(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.stop_special(fighter)
