class_name TornadoAbility
extends BattleAbility
## The Tornado (TornadoDelegate of the client). On each tile it enters, up to
## 5 enemy units within 3 tiles with a population below 6 fly 5 tiles away and
## take a third of its attack.

const RANGE := 3
const COUNT := 5
const POPULATION_LIMIT := 6


func on_enter_tile(sim: BattleSim, fighter: BattleFighter) -> void:
	var units := sim.items_near(fighter.tile, RANGE, COUNT, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return not item.dead and item.is_valid_target())
	for unit in units:
		if unit.is_unit() and unit.def.population < POPULATION_LIMIT:
			sim.push_in_air(unit, fighter, 5)
			sim.receive_attack(unit, fighter.def.attack / 3, fighter)
