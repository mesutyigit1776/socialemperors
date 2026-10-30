class_name Pathfinder
extends RefCounted
## Finds the shortest walk of a unit on the tiles of the map. A unit steps to one
## of the 8 tiles around it. A diagonal step needs both tiles beside it free, so
## that a unit does not cut the corner of a building.

const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


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
			if came_from.has(next) or not is_free.call(next):
				continue
			if step.x != 0 and step.y != 0 and not (is_free.call(tile + Vector2i(step.x, 0)) and is_free.call(tile + Vector2i(0, step.y))):
				continue
			came_from[next] = tile
			if is_goal.call(next):
				while next != start:
					result.push_front(next)
					next = came_from[next]
				return result
			frontier.append(next)
	return result
