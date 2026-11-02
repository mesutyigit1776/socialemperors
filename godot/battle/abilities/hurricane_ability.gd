class_name HurricaneAbility
extends BattleAbility
## The Hurricane (HurricaneDelegate of the client). On each tile it enters, up
## to 8 enemy units within 3 tiles with a population below 6 are stunned and
## take a third of its attack. Each attack pushes such units 2 tiles away and
## hurts them with its attack, besides its normal attack.

const RANGE := 3
const COUNT := 8
const POPULATION_LIMIT := 6


func on_enter_tile(sim: BattleSim, fighter: BattleFighter) -> void:
	for unit in _units(sim, fighter):
		sim.stun(unit, POPULATION_LIMIT)
		sim.receive_attack(unit, fighter.def.attack / 3, fighter)


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	for unit in _units(sim, fighter):
		sim.push_in_air(unit, fighter, 2)
		sim.receive_attack(unit, fighter.def.attack, fighter)
	return true


func _units(sim: BattleSim, fighter: BattleFighter) -> Array[BattleFighter]:
	return sim.items_near(fighter.tile, RANGE, COUNT, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and item.is_valid_target() and item.def.population < POPULATION_LIMIT)
