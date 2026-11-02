class_name FuriousRedDragonAbility
extends BattleAbility
## The Furious Dragon (FuriousRedDragonDelegate of the client). It breathes
## huge fire. In special attack 1, up to 4 enemies in its range take half its
## attack and units fly 2 tiles away. In special attack 2 it throws an egg, from
## which a summoned Draggy comes. The client adds to its count of draggies also
## when a draggy dies, so it throws at most 3 eggs in a battle.
##
## Its limit attack (lightning beams) starts only from the button of the
## player, see roadmap step 3.2.

const DRAGGY := 638
const MAX_DRAGGIES := 3

var _draggies := 0


func _init() -> void:
	special_intervals = [90, 90]
	special_durations = [20, 60]
	shot_graphic = "p.hugeFire"
	shot_delay = 11


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if fighter.animation == BattleFighter.Pose.ATTACKING:
		return true
	if in_special(fighter, 0):
		for enemy in enemies_near(sim, fighter, fighter.tile, fighter.attack_range, 4):
			sim.receive_attack(enemy, fighter.attack / 2, fighter)
			if enemy.is_unit():
				sim.push_in_air(enemy, fighter, 2)
	elif in_special(fighter, 1) and _draggies < MAX_DRAGGIES:
		throw_egg(sim, fighter, DRAGGY, func(draggy: BattleFighter) -> void:
			_draggies += 1
			sim.died.connect(func(item: BattleFighter, _killer: BattleFighter) -> void:
				if item == draggy:
					_draggies += 1))
	return false
