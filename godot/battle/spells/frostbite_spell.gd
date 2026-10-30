class_name FrostbiteSpell
extends BattleSpell
## Deadly Frostbite: ice falls on each tile of the area, each after a random
## delay of up to 60 frames, and freezes the enemy unit on its tile. Bosses
## are not frozen. The ice does no damage.

const FREEZE_FRAMES: Array[int] = [450, 600, 900]
const MAX_DELAY := 60


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	for point in _square_from_corner(tile, area(level)):
		_particle(sim, sim.rng.randf() * MAX_DELAY, _attack_frame, func() -> void:
			var enemy := _item_of(sim, point, BattleFighter.Team.ENEMY)
			if enemy != null and enemy.is_unit() and not _is_protected(enemy):
				# The client ends the freeze with a particle that starts one frame later.
				sim.freeze(enemy, FREEZE_FRAMES[level - 1] + 1))
