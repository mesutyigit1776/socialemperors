class_name IsoGrid
## Map coordinates of the original client, so that saves and graphics line up.
##
## Tiles are 108 x 54 pixels. A position in a save is a tile (x, y); the
## client puts the item anchor at the point that tile_to_map() returns.

const MAP_TILES := 100
const TILE_SIZE := Vector2(108, 54)  ## Pixels.
const LAND_TILES := 20  ## One land (expansion) area is 20 x 20 tiles.
const LAND_AREAS := MAP_TILES / LAND_TILES


static func tile_to_map(tile: Vector2) -> Vector2:
	return Vector2(54.0 * (tile.x - tile.y), 27.0 * (tile.x + tile.y) - 81.0)


## Returns the tile under a map point. tile_to_map() gives the bottom corner of
## a tile, so the centre of the tile is 27 pixels higher.
static func map_to_tile(point: Vector2) -> Vector2i:
	var a := point.x / 54.0
	var b := (point.y + 108.0) / 27.0
	return Vector2i(roundi((a + b) / 2.0), roundi((b - a) / 2.0))


## The tile whose point (tile_to_map()) is nearest to a map point. The client
## puts a walking unit on this tile.
static func nearest_tile(point: Vector2) -> Vector2i:
	var a := point.x / 54.0
	var b := (point.y + 81.0) / 27.0
	return Vector2i(floori((a + b) / 2.0 + 0.5), floori((b - a) / 2.0 + 0.5))


## One frame of a walk in the client, in villages and in battles: the unit moves
## up to speed pixels toward point on the longer axis, and the other axis in
## proportion.
static func step_toward(position: Vector2, point: Vector2, speed: float) -> Vector2:
	var delta := point - position
	var share := Vector2.ONE
	if absf(delta.y) > absf(delta.x):
		share.x = absf(delta.x) / absf(delta.y)
	else:
		share.y = absf(delta.y) / absf(delta.x)
	var moved := position
	for axis in 2:
		if absf(delta[axis]) > speed:
			moved[axis] += signf(delta[axis]) * speed * share[axis]
		else:
			moved[axis] = point[axis]
	return moved


## Returns the four corners of the diamond that a rectangle of tiles covers on the map.
static func footprint_outline(footprint: Rect2i) -> PackedVector2Array:
	var first := footprint.position
	var last := footprint.end - Vector2i.ONE
	return PackedVector2Array([
		tile_to_map(first) + Vector2(0, -54),
		tile_to_map(Vector2i(last.x, first.y)) + Vector2(54, -27),
		tile_to_map(last),
		tile_to_map(Vector2i(first.x, last.y)) + Vector2(-54, -27),
	])


## Land areas are numbered 1..25, row by row. A save lists its owned areas in "expansions".
static func land_area_number(area: Vector2i) -> int:
	return area.y * LAND_AREAS + area.x + 1


## The client places a land graphic on the last tile of its area.
static func land_area_anchor_tile(area: Vector2i) -> Vector2i:
	return area * LAND_TILES + Vector2i(LAND_TILES - 1, LAND_TILES - 1)
