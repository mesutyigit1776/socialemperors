class_name VillageView
extends Node2D
## Draws one village map: the land areas, then the items in depth order.
## In placement mode it shows the item to build or to move at the tile under the mouse.
## The view does not change the village; it reports the clicks of the player.

## The player clicked to build the item from the store.
signal placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i)
## The player clicked to put the moving item on the tile.
signal move_confirmed(placed: Village.PlacedItem, tile: Vector2i)
## The player clicked on the map outside placement mode. placed is null when no item is on the tile.
signal item_clicked(placed: Village.PlacedItem)

const LAND_ITEM_BASE_ID := 1000
const LAND_FRAME_WILD := 0
const LAND_FRAME_OWNED := 3

# Unit graphics have 5 frames per animation, one per direction from up (1)
# to down (5). Directions 6 to 8 (up-left, left, down-left) use frames 2 to 4
# mirrored. A new unit faces down-right, down or down-left.
const UNIT_FRAMES_PER_ANIMATION := 5
const UNIT_ANIMATION_IDLE := 0
const UNIT_START_DIRECTIONS: Array[int] = [4, 5, 8]
const UNIT_LAST_UNMIRRORED_DIRECTION := 5

const PLACEMENT_VALID_COLOR := Color(0.5, 1.0, 0.5, 0.8)
const PLACEMENT_INVALID_COLOR := Color(1.0, 0.4, 0.4, 0.8)
const SELECTION_COLOR := Color(1.0, 1.0, 0.4, 0.35)
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

# Placement mode. _placing_item is null when the mode is off. _moving is the
# item that moves, or null when the player builds a new item.
var _placing_item: GameConfig.ItemDef
var _moving: Village.PlacedItem
var _placing_tile := Vector2i(-1, -1)
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
	_village = village
	_config = config
	_sprites = sprites

	var land_item := config.get_item(LAND_ITEM_BASE_ID + village.skin)
	if land_item == null:
		push_warning("The configuration has no land item for map skin %d." % village.skin)
	else:
		for y in IsoGrid.LAND_AREAS:
			for x in IsoGrid.LAND_AREAS:
				var area := Vector2i(x, y)
				var owned := IsoGrid.land_area_number(area) in village.owned_land
				_place(_land_layer, land_item, IsoGrid.land_area_anchor_tile(area), LAND_FRAME_OWNED if owned else LAND_FRAME_WILD)

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
		node = _place(_item_layer, item, placed.tile, placed.frame)
	if node != null:
		_nodes[placed] = node


## Draws the item at its new tile after Village.move().
func update_placed(placed: Village.PlacedItem) -> void:
	if _nodes.has(placed):
		_nodes[placed].position = IsoGrid.tile_to_map(placed.tile)


## Removes the item from the map after Village.sell().
func remove_placed(placed: Village.PlacedItem) -> void:
	if _nodes.has(placed):
		_nodes[placed].queue_free()
		_nodes.erase(placed)


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
	_ghost = _make_sprite(sprite, frame, Vector2i.ZERO)
	_ghost.offset = _building_offset(sprite, frame)
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
				item_clicked.emit(_village.item_at(IsoGrid.map_to_tile(make_input_local(event).position)))
		return
	if event is InputEventMouseMotion:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
		get_viewport().set_input_as_handled()
		if _moving != null:
			move_confirmed.emit(_moving, _placing_tile)
		else:
			placement_confirmed.emit(_placing_item, _placing_tile)
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


func _place(layer: Node2D, item: GameConfig.ItemDef, tile: Vector2i, frame: int) -> Sprite2D:
	var sprite := _sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	var node := _make_sprite(sprite, frame, tile)
	node.offset = _building_offset(sprite, frame)
	layer.add_child(node)
	return node


## The client puts the bottom centre of the shown frame on the item position.
static func _building_offset(sprite: SpriteLibrary.ItemSprite, frame: int) -> Vector2:
	var size := sprite.get_frame_size(frame)
	return Vector2(-floorf(size.x / 2.0), -size.y) + sprite.origin


func _place_unit(item: GameConfig.ItemDef, tile: Vector2i) -> Sprite2D:
	var sprite := _sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	# The client picks the start direction at random. A fixed choice per tile keeps screenshots stable.
	var direction: int = UNIT_START_DIRECTIONS[(tile.x + tile.y) % UNIT_START_DIRECTIONS.size()]
	var mirrored := direction > UNIT_LAST_UNMIRRORED_DIRECTION
	var direction_frame := direction - 4 if mirrored else direction
	var node := _make_sprite(sprite, UNIT_ANIMATION_IDLE * UNIT_FRAMES_PER_ANIMATION + direction_frame - 1, tile)
	# The client puts the registration point of a unit on its position and mirrors around it.
	node.offset = sprite.origin
	if mirrored:
		node.scale.x = -1
	_item_layer.add_child(node)
	return node


func _make_sprite(sprite: SpriteLibrary.ItemSprite, frame: int, tile: Vector2i) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = sprite.get_frame(frame)
	node.centered = false
	node.position = IsoGrid.tile_to_map(tile)
	return node
