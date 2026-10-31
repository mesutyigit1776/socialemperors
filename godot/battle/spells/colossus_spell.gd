class_name ColossusSpell
extends BattleSpell
## Age of Colossus: the units of the player within the area (as a radius in
## tiles) of the tile get bigger and do 1.5 times their damage for 30, 45 or
## 60 seconds. See BattleSim.enlarge().

const FRAMES: Array[int] = [900, 1350, 1800]
const DELAY := 10


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var found := sim.items_near(tile, side, side * side, BattleFighter.Team.PLAYER, true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and not item.def.subcat_functional in [BattleSim.SUBCAT_BOSS, SUBCAT_TOWN_HALL])
	for unit in found:
		_particle(sim, unit.tile, DELAY, _attack_frame, func() -> void:
			if not unit.dead:
				sim.enlarge(unit, FRAMES[level - 1]))


func descriptions(config: GameConfig) -> Array[String]:
	return _area_texts(config, "SPELL_ENLARGE_DESCRIPCION", FRAMES.map(func(frames: int) -> int: return frames / BattleSim.FRAMES_PER_SECOND))
