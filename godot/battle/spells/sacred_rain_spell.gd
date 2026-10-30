class_name SacredRainSpell
extends BattleSpell
## Sacred Rain: rain falls on each tile of the area, each after a random delay
## of up to 30 frames. It should heal the unit of the player on its tile by 100
## life, and at levels 2 and 3 by 20 more life each second for 5 or 10 seconds.
##
## In the client the rain heals nobody: its particles act only on enemy items,
## and the healing acts only on units of the player. The port does the same.
## Set FIX_CLIENT_ERROR to true to heal the units of the player.

const FIX_CLIENT_ERROR := false
const HEAL := 100
const HEAL_PER_SECOND := 20
const HEAL_SECONDS: Array[int] = [0, 5, 10]
const MAX_DELAY := 30


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	for point in _square_from_corner(tile, area(level)):
		_particle(sim, sim.rng.randf() * MAX_DELAY, _attack_frame, func() -> void:
			var team := BattleFighter.Team.PLAYER if FIX_CLIENT_ERROR else BattleFighter.Team.ENEMY
			var item := _item_of(sim, point, team)
			if item != null and item.is_unit() and item.team == BattleFighter.Team.PLAYER and not item.dead:
				sim.heal(item, HEAL)
				for second in range(1, HEAL_SECONDS[level - 1] + 1):
					sim.after(second * BattleSim.FRAMES_PER_SECOND, func() -> void: sim.heal(item, HEAL_PER_SECOND)))
