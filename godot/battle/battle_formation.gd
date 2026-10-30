class_name BattleFormation
extends RefCounted
## The tiles to which the client sends a group of units that the player orders.
## On free ground the units fill a square, around one of their own items they
## fill the rings around it, and around an enemy they stand on the rings at
## their attack range. is_free and is_standable tell which tiles the units can
## take, see BattleSim.
##
## The client sorts some tile lists by distance with a sort that does not keep
## the order of equal values. The port keeps the order in which it finds the
## tiles, so among tiles at the same distance it can choose another one.

const FAR_CORNER := Vector2i(200, 200)


## Up to count free tiles in a square that grows to the right and down from
## tile: each step adds the column on the right and then the row below.
static func square_tiles(tile: Vector2i, count: int, is_free: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for size in IsoGrid.MAP_TILES + 1:
		var column: Array[Vector2i] = []
		for y in range(tile.y, tile.y + size + 1):
			column.append(Vector2i(tile.x + size, y))
		if size > 0:
			for x in range(tile.x + size - 1, tile.x - 1, -1):
				column.append(Vector2i(x, tile.y + size))
		for candidate in column:
			if is_free.call(candidate):
				result.append(candidate)
				if result.size() >= count:
					return result
	return result


## The free tile where the client puts a new item near tile: tile itself when
## it is free, else a free tile on the nearest ring with free tiles, up to
## max_rings rings. On that ring the client takes the tile nearest to the tile
## (200, 200), outside the map, so it prefers tiles down and to the right.
## Returns null when no ring has a free tile.
static func nearest_free_tile(tile: Vector2i, max_rings: int, is_free: Callable) -> Variant:
	if is_free.call(tile):
		return tile
	for ring in range(1, max_rings + 1):
		var candidates: Array[Vector2i] = []
		for x in range(maxi(0, tile.x - ring), mini(tile.x + ring, IsoGrid.MAP_TILES - 1) + 1):
			candidates.append(Vector2i(x, tile.y + ring))
			candidates.append(Vector2i(x, tile.y - ring))
		for y in range(maxi(0, tile.y - ring + 1), mini(tile.y + ring - 1, IsoGrid.MAP_TILES - 1) + 1):
			candidates.append(Vector2i(tile.x - ring, y))
			candidates.append(Vector2i(tile.x + ring, y))
		var best: Variant = null
		for candidate in candidates:
			if is_free.call(candidate) and (best == null or _far_corner_distance(candidate) < _far_corner_distance(best)):
				best = candidate
		if best != null:
			return best
	return null


static func _far_corner_distance(tile: Vector2i) -> int:
	return (tile - FAR_CORNER).length_squared()


## Up to count free tiles on the rings around tile, nearest first. On each ring
## the client looks at the rows below and above, then at the columns left and right.
static func spiral_tiles(tile: Vector2i, count: int, is_free: Callable) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if is_free.call(tile):
		found.append(tile)
	for ring in range(1, IsoGrid.MAP_TILES + 1):
		if found.size() >= count:
			break
		var candidates: Array[Vector2i] = []
		for x in range(tile.x - ring, tile.x + ring + 1):
			candidates.append(Vector2i(x, tile.y + ring))
			candidates.append(Vector2i(x, tile.y - ring))
		for y in range(tile.y - ring + 1, tile.y + ring):
			candidates.append(Vector2i(tile.x - ring, y))
			candidates.append(Vector2i(tile.x + ring, y))
		for candidate in candidates:
			if is_free.call(candidate):
				found.append(candidate)
				if found.size() >= count:
					break
	var result: Array[Vector2i] = []
	result.assign(_sorted_stable(found, func(a: Vector2i) -> int: return (a - tile).length_squared()))
	return result


## The tile of each unit around target: {BattleFighter: Vector2i}. The units with
## the longest range choose first. Each unit takes the tile nearest to it on the
## ring at its range; when that ring is full, it looks on the next ring. A large
## unit keeps the tiles around its tile free for the others.
static func attack_tiles(target: BattleFighter, units: Array[BattleFighter], is_standable: Callable) -> Dictionary:
	var by_range := _sorted_stable(units, func(unit: BattleFighter) -> int: return -unit.def.attack_range)
	var half := target.def.width / 2
	var even := 1 if target.def.width % 2 == 0 else 0
	var centre := target.tile - Vector2i(half, target.def.height / 2)
	var taken := {}
	var result := {}
	var ring := 0
	var ring_range := -1
	for unit: BattleFighter in by_range:
		if unit.def.attack_range != ring_range:
			ring_range = unit.def.attack_range
			ring = ring_range + half
		var best: Variant = null
		while best == null and ring <= IsoGrid.MAP_TILES:
			var best_squared := 0
			for candidate in ring_tiles(centre, ring, even):
				if taken.has(candidate) or not is_standable.call(candidate):
					continue
				var squared := (candidate - unit.tile).length_squared()
				if best == null or squared < best_squared:
					best = candidate
					best_squared = squared
			if best == null:
				ring += 1
		if best == null:
			continue
		result[unit] = best
		taken[best] = true
		var keep_free: int = unit.def.size - 1
		for x in range(best.x - keep_free, best.x + keep_free + 1):
			for y in range(best.y - keep_free, best.y + keep_free + 1):
				taken[Vector2i(x, y)] = true
	return result


## The tiles of a ring around centre, in the order of the client: the rows
## below and above, then the columns. For an item of even width the ring starts
## one tile later on the left and the top.
static func ring_tiles(centre: Vector2i, ring: int, even: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(centre.x - ring + even, centre.x + ring + 1):
		result.append(Vector2i(x, centre.y + ring))
		result.append(Vector2i(x, centre.y - ring + even))
	for y in range(centre.y - ring + 1 + even, centre.y + ring):
		result.append(Vector2i(centre.x - ring + even, y))
		result.append(Vector2i(centre.x + ring, y))
	return result


## Sorts by key and keeps the order of equal keys.
static func _sorted_stable(values: Array, key: Callable) -> Array:
	var indexed := []
	for i in values.size():
		indexed.append([key.call(values[i]), i, values[i]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var result := []
	for entry: Array in indexed:
		result.append(entry[2])
	return result
