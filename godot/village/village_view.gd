class_name VillageView
extends Node2D
## Draws one village map: the land areas, then the items in depth order.
## In placement mode it shows the item to build or to move at the tile under the
## mouse; the space bar turns it. A mark shows the buildings that are ready to collect.
## The view does not change the village; it reports the clicks of the player.

## The player clicked to build the item from the store. frame is the direction.
signal placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i, frame: int)
## The player clicked to put the moving item on the tile.
signal move_confirmed(placed: Village.PlacedItem, tile: Vector2i, frame: int)
## The player clicked on the map outside placement mode. placed is the item on
## the tile, or null.
signal map_clicked(tile: Vector2i, placed: Village.PlacedItem)

const LAND_ITEM_BASE_ID := 1000
const LAND_FRAME_WILD := 0
const LAND_FRAME_OWNED := 3

# Units face one of 8 directions, from up (1) clockwise; see UnitSprite. A new
# unit faces down-right, down or down-left.
const UNIT_START_DIRECTIONS: Array[int] = [4, 5, 8]
## Directions for screen angles in steps of 45 degrees, from the right, clockwise.
const UNIT_DIRECTIONS_BY_ANGLE: Array[int] = [3, 4, 5, 8, 7, 6, 1, 2]

const PLACEMENT_VALID_COLOR := Color(0.5, 1.0, 0.5, 0.8)
const PLACEMENT_INVALID_COLOR := Color(1.0, 0.4, 0.4, 0.8)
const SELECTION_COLOR := Color(1.0, 1.0, 0.4, 0.35)
const READY_MARK_COLORS := {
	"g": Color(1.0, 0.85, 0.2), "w": Color(0.6, 0.4, 0.2), "s": Color(0.7, 0.7, 0.7),
	"f": Color(1.0, 0.55, 0.15), "c": Color(0.3, 0.75, 0.3), "m": Color(0.4, 0.5, 1.0),
}
const READY_MARK_RADIUS := 10.0
const READY_MARK_BORDER_COLOR := Color(0.15, 0.1, 0.05)
## A press and release of the left button closer than this is a click; a longer
## movement pans the map (see MapCamera).
const CLICK_MAX_DISTANCE := 6.0

var _land_layer := Node2D.new()
var _item_layer := Node2D.new()
var _placement_layer := Node2D.new()
var _selection := Polygon2D.new()

var _village: Village
var _config: GameConfig
var _sprites: SpriteLibrary
var _nodes: Dictionary = {}  # Village.PlacedItem -> Sprite2D
var _ready_marks: Dictionary = {}  # Village.PlacedItem -> Polygon2D, child of the item node

# Placement mode. _placing_item is null when the mode is off. _moving is the
# item that moves, or null when the player builds a new item.
var _placing_item: GameConfig.ItemDef
var _moving: Village.PlacedItem
var _placing_tile := Vector2i(-1, -1)
var _placing_frame := 0
var _ghost: Sprite2D
var _outline := Polygon2D.new()

var _press_position := Vector2.INF  # Screen position of the last left button press.


func _ready() -> void:
	add_child(_land_layer)
	_item_layer.y_sort_enabled = true  # Items further down the screen are in front.
	add_child(_item_layer)
	_selection.color = SELECTION_COLOR
	_selection.visible = false
	add_child(_selection)
	_placement_layer.add_child(_outline)
	_placement_layer.visible = false
	add_child(_placement_layer)


func show_village(village: Village, config: GameConfig, sprites: SpriteLibrary) -> void:
	end_placement()
	show_selection(null)
	for layer: Node2D in [_land_layer, _item_layer]:
		for child in layer.get_children():
			child.queue_free()
	_nodes.clear()
	_ready_marks.clear()
	_village = village
	_config = config
	_sprites = sprites

	place_land(_land_layer, config, sprites, village.skin, village.owned_land)
	for placed in village.items:
		add_placed(placed)


## Draws one item of the village. show_village() draws all items; use this for items added later.
func add_placed(placed: Village.PlacedItem) -> void:
	var item := _config.get_item(placed.item_id)
	if item == null:
		return  # Village reports items that are not in the configuration when it loads them.
	var node: Sprite2D
	if item.is_unit():
		node = _place_unit(item, placed.tile)
	else:
		node = place_sprite(_item_layer, _sprites, item, placed.tile, placed.frame)
	if node != null:
		_nodes[placed] = node


## Draws the item at its tile and in its direction after Village.move() or Village.rotate().
func update_placed(placed: Village.PlacedItem) -> void:
	if not _nodes.has(placed):
		return
	var node: Sprite2D = _nodes[placed]
	var item := _config.get_item(placed.item_id)
	if item.is_unit():
		show_unit(placed, IsoGrid.tile_to_map(placed.tile), placed.frame, false)
		return
	var sprite := _sprites.get_sprite(item.img_name)
	node.position = IsoGrid.tile_to_map(placed.tile)
	node.texture = sprite.get_frame(placed.frame)
	node.offset = building_offset(sprite, placed.frame)
	if _ready_marks.has(placed):
		_ready_marks[placed].position = _mark_position(node)


## Draws a unit at a position of the map, for example on its way between two
## tiles, in a direction from 1 (up) to 8 (up-left), standing or walking.
func show_unit(placed: Village.PlacedItem, map_position: Vector2, direction: int, walking: bool) -> void:
	if not _nodes.has(placed):
		return
	var node: UnitSprite = _nodes[placed]
	node.position = map_position
	node.show_action(UnitSprite.Action.WALKING if walking else UnitSprite.Action.IDLE, direction)


## Hides or shows an item, for example a unit that works in a building.
func set_item_visible(placed: Village.PlacedItem, shown: bool) -> void:
	if _nodes.has(placed):
		_nodes[placed].visible = shown


## The direction of a unit that walks from one tile to another.
static func unit_direction(from: Vector2i, to: Vector2i) -> int:
	var delta := IsoGrid.tile_to_map(to) - IsoGrid.tile_to_map(from)
	return UNIT_DIRECTIONS_BY_ANGLE[posmod(roundi(delta.angle() / (PI / 4)), 8)]


## Shows a mark above each building that is ready to collect at the time now.
func update_production(now: float) -> void:
	for placed: Village.PlacedItem in _nodes:
		var ready := _village.seconds_to_ready(placed, now) == 0
		if ready and not _ready_marks.has(placed):
			var mark := _circle(READY_MARK_RADIUS + 2, READY_MARK_BORDER_COLOR)
			mark.add_child(_circle(READY_MARK_RADIUS, READY_MARK_COLORS.get(_config.get_item(placed.item_id).collect_type, Color.WHITE)))
			mark.position = _mark_position(_nodes[placed])
			_nodes[placed].add_child(mark)
			_ready_marks[placed] = mark
		elif not ready and _ready_marks.has(placed):
			_ready_marks[placed].queue_free()
			_ready_marks.erase(placed)


## Removes the item from the map after Village.sell().
func remove_placed(placed: Village.PlacedItem) -> void:
	if _nodes.has(placed):
		_nodes[placed].queue_free()
		_nodes.erase(placed)
		_ready_marks.erase(placed)


## Draws the items that the village gained and removes the items that it lost,
## for changes that add or remove more than one item: for example a sold
## building and the units that come out of it.
func sync_items() -> void:
	for placed: Village.PlacedItem in _nodes.keys():
		if not placed in _village.items:
			remove_placed(placed)
	for placed in _village.items:
		if not _nodes.has(placed):
			add_placed(placed)


## Outlines the tiles of the item, or removes the outline when placed is null.
func show_selection(placed: Village.PlacedItem) -> void:
	_selection.visible = placed != null
	if placed != null:
		_selection.polygon = IsoGrid.footprint_outline(Village.footprint(_config.get_item(placed.item_id), placed.tile))


## Shows a new item from the store at the tile under the mouse until the player
## clicks or cancels. Returns false when the item has no graphic.
func begin_placement(item: GameConfig.ItemDef) -> bool:
	return _begin(item, 0, null)


## Shows the item at the tile under the mouse, and hides it at its old tile,
## until the player clicks or cancels. Returns false when the item has no graphic.
func begin_move(placed: Village.PlacedItem) -> bool:
	if not _begin(_config.get_item(placed.item_id), placed.frame, placed):
		return false
	if _nodes.has(placed):
		_nodes[placed].visible = false
	return true


func _begin(item: GameConfig.ItemDef, frame: int, moving: Village.PlacedItem) -> bool:
	end_placement()
	var sprite := _sprites.get_sprite(item.img_name)
	if sprite == null:
		return false
	_placing_item = item
	_moving = moving
	_placing_frame = frame
	_ghost = _make_sprite(sprite, frame, Vector2i.ZERO)
	_ghost.offset = building_offset(sprite, frame)
	_placement_layer.add_child(_ghost)
	_placement_layer.visible = true
	_update_placement(IsoGrid.map_to_tile(get_local_mouse_position()))
	return true


func end_placement() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _moving != null and _nodes.has(_moving):
		_nodes[_moving].visible = true
	_placing_item = null
	_moving = null
	_placement_layer.visible = false


func is_placing() -> bool:
	return _placing_item != null


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_position = event.position
			elif event.position.distance_to(_press_position) <= CLICK_MAX_DISTANCE:
				_press_position = Vector2.INF
				var tile := IsoGrid.map_to_tile(make_input_local(event).position)
				map_clicked.emit(tile, _village.item_at(tile))
		return
	if event is InputEventMouseMotion:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
		get_viewport().set_input_as_handled()
		if _moving != null:
			move_confirmed.emit(_moving, _placing_tile, _placing_frame)
		else:
			placement_confirmed.emit(_placing_item, _placing_tile, _placing_frame)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_placing_frame = (_placing_frame + 1) % _placing_item.max_frame
		var sprite := _sprites.get_sprite(_placing_item.img_name)
		_ghost.texture = sprite.get_frame(_placing_frame)
		_ghost.offset = building_offset(sprite, _placing_frame)
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		end_placement()


func _update_placement(tile: Vector2i) -> void:
	_placing_tile = tile
	_ghost.position = IsoGrid.tile_to_map(tile)
	_outline.polygon = IsoGrid.footprint_outline(Village.footprint(_placing_item, tile))
	var valid: bool
	if _moving != null:
		valid = _village.check_move(_moving, tile) == Village.Placement.OK
	else:
		valid = _village.check_location(_placing_item, tile) == Village.Placement.OK \
				and _village.check_limits(_placing_item, tile) == Village.Placement.OK
	_ghost.modulate = PLACEMENT_VALID_COLOR if valid else PLACEMENT_INVALID_COLOR
	_outline.color = Color(_ghost.modulate, 0.35)


## Draws the land areas of a map with the land graphic of its skin. The areas in
## owned_land (see IsoGrid.land_area_number()) show the owned land.
static func place_land(layer: Node2D, config: GameConfig, sprites: SpriteLibrary, skin: int, owned_land: PackedInt32Array) -> void:
	var land_item := config.get_item(LAND_ITEM_BASE_ID + skin)
	if land_item == null:
		push_warning("The configuration has no land item for map skin %d." % skin)
		return
	for y in IsoGrid.LAND_AREAS:
		for x in IsoGrid.LAND_AREAS:
			var area := Vector2i(x, y)
			var owned := IsoGrid.land_area_number(area) in owned_land
			place_sprite(layer, sprites, land_item, IsoGrid.land_area_anchor_tile(area), LAND_FRAME_OWNED if owned else LAND_FRAME_WILD)


## Draws an item that is not a unit at its tile in layer. Returns null when its graphic is missing.
static func place_sprite(layer: Node2D, sprites: SpriteLibrary, item: GameConfig.ItemDef, tile: Vector2i, frame: int) -> Sprite2D:
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	var node := _make_sprite(sprite, frame, tile)
	node.offset = building_offset(sprite, frame)
	layer.add_child(node)
	return node


static func _circle(radius: float, color: Color) -> Polygon2D:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		points.append(Vector2.from_angle(TAU * i / 16) * radius)
	circle.polygon = points
	circle.color = color
	return circle


## Above the top centre of the item graphic.
static func _mark_position(node: Sprite2D) -> Vector2:
	return node.offset + Vector2(node.texture.get_width() / 2.0, -READY_MARK_RADIUS - 4)


## The client puts the bottom centre of the shown frame on the item position.
static func building_offset(sprite: SpriteLibrary.ItemSprite, frame: int) -> Vector2:
	var size := sprite.get_frame_size(frame)
	return Vector2(-floorf(size.x / 2.0), -size.y) + sprite.origin


func _place_unit(item: GameConfig.ItemDef, tile: Vector2i) -> Sprite2D:
	var sprite := _sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	# The client picks the start direction at random. A fixed choice per tile keeps screenshots stable.
	var direction: int = UNIT_START_DIRECTIONS[(tile.x + tile.y) % UNIT_START_DIRECTIONS.size()]
	var node := UnitSprite.new(sprite)
	node.position = IsoGrid.tile_to_map(tile)
	node.show_action(UnitSprite.Action.IDLE, direction)
	_item_layer.add_child(node)
	return node


static func _make_sprite(sprite: SpriteLibrary.ItemSprite, frame: int, tile: Vector2i) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = sprite.get_frame(frame)
	node.centered = false
	node.position = IsoGrid.tile_to_map(tile)
	return node
