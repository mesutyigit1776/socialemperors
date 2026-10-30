class_name BlackHoleSpell
extends BattleSpell
## Black Hole: a hole in the middle of the square swallows the enemy units and
## buildings within half the area (rounded up) of it, at once and then every
## second for 15, 20 or 30 seconds. The same items as for Hell Abyss stay.

const SECONDS: Array[int] = [15, 20, 30]
const DELAY := 10
const START_FRAME := 45  # The client starts the hole at this frame, not at a label.


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var middle := tile - Vector2i.ONE * floori(side / 2.0)
	var pull := func() -> void:
		for item in sim.items_near(middle, ceili(side / 2.0), side * side, BattleFighter.Team.ENEMY, true, HellAbyssSpell._can_fall):
			sim.swallow(item)
	_particle(sim, DELAY, START_FRAME, func() -> void:
		pull.call()
		for second in range(1, SECONDS[level - 1] + 1):
			sim.after(second * BattleSim.FRAMES_PER_SECOND, pull))
