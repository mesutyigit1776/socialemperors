class_name Pathfinder
extends RefCounted
## Finds the walk of a unit on the tiles of the map. A unit steps to one of the
## 8 tiles around it. A diagonal step needs both tiles beside it free, so that a
## unit does not cut the corner of a building.

const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
## Costs of the client's A* search for a straight and a diagonal step.
const STRAIGHT_COST := 10
const DIAGONAL_COST := 14


## The tiles from start (not included) to the first tile where is_goal is true.
## is_free tells which tiles a unit can walk on. Returns an empty array when
## start is a goal or when no goal can be reached.
static func find_path(start: Vector2i, is_goal: Callable, is_free: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if is_goal.call(start):
		return result
	var came_from := {start: start}
	var frontier: Array[Vector2i] = [start]
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		for step in STEPS:
			var next := tile + step
			if came_from.has(next) or not _can_step(tile, step, is_free):
				continue
			came_from[next] = tile
			if is_goal.call(next):
				while next != start:
					result.push_front(next)
					next = came_from[next]
				return result
			frontier.append(next)
	return result


## The client's A* search, which battles use: the tiles from start (not
## included) to goal (included). Like the client, it returns [goal] when start is
## goal, and nothing when start or goal is not free or goal cannot be reached.
## Among open tiles with the same cost it takes the one nearest to goal in
## straight steps, and then the one that it opened first.
static func find_route(start: Vector2i, goal: Vector2i, is_free: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not (is_free.call(start) and is_free.call(goal)):
		return result
	if start == goal or (start - goal).abs() in [Vector2i(1, 0), Vector2i(0, 1)]:
		result.append(goal)
		return result
	var cost := {start: 0}  # Tile -> cost of the best walk from start.
	var estimate := {}  # Open tile -> cost plus the estimate to goal.
	var came_from := {}
	var closed := {}
	var open: Array[Vector2i] = []
	var tile := start
	while true:
		closed[tile] = true
		if tile == goal:
			break
		for step in STEPS:
			var next := tile + step
			if closed.has(next) or not _can_step(tile, step, is_free):
				continue
			var next_cost: int = cost[tile] + (DIAGONAL_COST if step.x != 0 and step.y != 0 else STRAIGHT_COST)
			if estimate.has(next) and next_cost >= cost[next]:
				continue
			if not estimate.has(next):
				open.append(next)
			var left := (goal - next).abs()
			cost[next] = next_cost
			estimate[next] = next_cost + STRAIGHT_COST * (left.x + left.y) - (2 * STRAIGHT_COST - DIAGONAL_COST) * mini(left.x, left.y)
			came_from[next] = tile
		if open.is_empty():
			return result
		var best := 0
		for i in range(1, open.size()):
			if _is_better(open[i], open[best], estimate, goal):
				best = i
		tile = open[best]
		open.remove_at(best)
		estimate.erase(tile)
	while tile != start:
		result.push_front(tile)
		tile = came_from[tile]
	return result


static func _can_step(tile: Vector2i, step: Vector2i, is_free: Callable) -> bool:
	if not is_free.call(tile + step):
		return false
	return step.x == 0 or step.y == 0 or (is_free.call(tile + Vector2i(step.x, 0)) and is_free.call(tile + Vector2i(0, step.y)))


static func _is_better(a: Vector2i, b: Vector2i, estimate: Dictionary, goal: Vector2i) -> bool:
	if estimate[a] != estimate[b]:
		return estimate[a] < estimate[b]
	var to_goal_a := (goal - a).abs()
	var to_goal_b := (goal - b).abs()
	return to_goal_a.x + to_goal_a.y < to_goal_b.x + to_goal_b.y
