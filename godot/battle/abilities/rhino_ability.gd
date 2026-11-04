class_name RhinoAbility
extends BattleAbility
## The rhino riders (RinoceronteDelegate and HellRhinoDelegate of the client).
## When a rhino walks onto a tile, the nearest enemy within 1 tile, also on its
## own tile, flies 5 tiles when it is a unit with a population of less than 4.

const PUSH := 5
const POPULATION_LIMIT := 4


func on_enter_tile(sim: BattleSim, fighter: BattleFighter) -> void:
	var found := sim.items_near(fighter.tile, 1, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return not item.dead and item.is_valid_target())
	if not found.is_empty() and found[0].is_unit() and found[0].def.population < POPULATION_LIMIT:
		sim.push_in_air(found[0], fighter, PUSH)
