class_name FireHavocSpell
extends BattleSpell
## Fire Havoc: 30 fireballs, one every 3 frames. Every third ball falls on an
## enemy unit near the area, the others on random tiles of the area. A ball
## hurts the enemy item on its tile.
##
## The client computes the area with half tiles and drops the fractions, so the
## area of the balls lies 3 tiles further left and up than the marked square.

const DAMAGE: Array[int] = [150, 200, 250]
const BALLS := 30
const BALL_DELAY := 3
const SUBCAT_PEASANT := 71


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var half := side / 2.0
	var start := Vector2i(int(tile.x - half), int(tile.y - half))
	var area_points: Array[Vector2i] = []
	for i in side:
		for j in side:
			area_points.append(Vector2i(int(start.x + i - half), int(start.y + j - half)))
	var enemy_points: Array[Vector2i] = []
	for unit in sim.items_near(start, int(half), BALLS, BattleFighter.Team.ENEMY, true, _is_fighting_unit):
		enemy_points.append(unit.tile)
	for ball in BALLS:
		var points := enemy_points if ball % 3 == 0 and not enemy_points.is_empty() else area_points
		var point: Vector2i = points[roundi(sim.rng.randf() * (points.size() - 1))]
		_particle(sim, BALL_DELAY * ball, _attack_frame, func() -> void:
			var enemy := _item_of(sim, point, BattleFighter.Team.ENEMY)
			if enemy != null:
				sim.receive_attack(enemy, DAMAGE[level - 1], null))


## The units that the client looks for by default: alive, with an attack, not villagers.
static func _is_fighting_unit(item: BattleFighter) -> bool:
	return item.is_unit() and not item.dead and item.attack > 0 and item.def.subcat_functional != SUBCAT_PEASANT
