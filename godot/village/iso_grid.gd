class_name IsoGrid
## Map coordinates of the original client, so that saves and graphics line up.
##
## Tiles are 108 x 54 pixels. A position in a save is a tile (x, y); the
## client puts the item anchor at the point that tile_to_map() returns.

const MAP_TILES := 100
const LAND_TILES := 20  ## One land (expansion) area is 20 x 20 tiles.
const LAND_AREAS := MAP_TILES / LAND_TILES


static func tile_to_map(tile: Vector2) -> Vector2:
	return Vector2(54.0 * (tile.x - tile.y), 27.0 * (tile.x + tile.y) - 81.0)


## Land areas are numbered 1..25, row by row. A save lists its owned areas in "expansions".
static func land_area_number(area: Vector2i) -> int:
	return area.y * LAND_AREAS + area.x + 1


## The client places a land graphic on the last tile of its area.
static func land_area_anchor_tile(area: Vector2i) -> Vector2i:
	return area * LAND_TILES + Vector2i(LAND_TILES - 1, LAND_TILES - 1)
