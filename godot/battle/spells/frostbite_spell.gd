class_name FrostbiteSpell
extends BattleSpell
## Deadly Frostbite: ice falls on each tile of the area, each after a random
## delay of up to 60 frames, and freezes the enemy unit on its tile. Bosses
## are not frozen. The ice does no damage.

const FREEZE_FRAMES: Array[int] = [450, 600, 900]
## The spell book names this damage, but the ice of the client does none.
const SHOWN_DAMAGE: Array[int] = [50, 60, 70]
const MAX_DELAY := 60


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	for point in _square_from_corner(tile, area(level)):
		_particle(sim, point, sim.rng.randf() * MAX_DELAY, _attack_frame, func() -> void:
			var enemy := _item_of(sim, point, BattleFighter.Team.ENEMY)
			if enemy != null and enemy.is_unit() and not _is_protected(enemy):
				# The client ends the freeze with a particle that starts one frame later.
				sim.freeze(enemy, FREEZE_FRAMES[level - 1] + 1), {"scale": 0.5, "alpha": 0.7, "depth": "above"})


func descriptions(config: GameConfig) -> Array[String]:
	var texts: Array[String] = []
	for level in range(1, GameConfig.SPELL_LEVELS + 1):
		texts.append(_fill(config, "SPELL_ICEBALL_DESCRIPCION", [area(level), area(level), SHOWN_DAMAGE[level - 1], FREEZE_FRAMES[level - 1] / BattleSim.FRAMES_PER_SECOND]))
	return texts
