class_name PoisonFloodSpell
extends BattleSpell
## Poisonous Flood: poisons the enemy units within the area (as a radius in
## tiles) of the tile; bosses are safe. See BattleSim.poison() for the poison.

const DAMAGE: Array[int] = [15, 20, 25]
const TICKS: Array[int] = [5, 7, 10]
const INFECTS: Array[int] = [0, 1, 2]
const DELAY := 10


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	_particle(sim, DELAY, _attack_frame, func() -> void:
		var found := sim.items_near(tile, side, side * side, BattleFighter.Team.ENEMY, true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)
		for i in range(found.size() - 1, -1, -1):
			sim.poison(found[i], DAMAGE[level - 1], TICKS[level - 1], INFECTS[level - 1], null))
