class_name VillageView
extends Node2D
## Draws one village map: the land areas, then the items in depth order.
## In placement mode it shows the selected item at the tile under the mouse.

## Emitted when the player clicks to place the selected item. The view does not change the village.
signal placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i)

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

var _land_layer := Node2D.new()
var _item_layer := Node2D.new()
var _placement_layer := Node2D.new()

# Placement mode. _placing_item is null when the mode is off.
var _placing_item: GameConfig.ItemDef
var _placing_village: Village
var _placing_tile := Vector2i(-1, -1)
var _ghost: Sprite2D
var _outline := Polygon2D.new()


func _ready() -> void:
	add_child(_land_layer)
	_item_layer.y_sort_enabled = true  # Items further down the screen are in front.
	add_child(_item_layer)
	_placement_layer.add_child(_outline)
	_placement_layer.visible = false
	add_child(_placement_layer)


func show_village(village: Village, config: GameConfig, sprites: SpriteLibrary) -> void:
	for layer: Node2D in [_land_layer, _item_layer]:
		for child in layer.get_children():
			child.queue_free()

	var land_item := config.get_item(LAND_ITEM_BASE_ID + village.skin)
	if land_item == null:
		push_warning("The configuration has no land item for map skin %d." % village.skin)
	else:
		for y in IsoGrid.LAND_AREAS:
			for x in IsoGrid.LAND_AREAS:
				var area := Vector2i(x, y)
				var owned := IsoGrid.land_area_number(area) in village.owned_land
				_place(_land_layer, land_item, IsoGrid.land_area_anchor_tile(area), LAND_FRAME_OWNED if owned else LAND_FRAME_WILD, sprites)

	for placed in village.items:
		add_placed(placed, config, sprites)


## Draws one item of the village. show_village() draws all items; use this for items added later.
func add_placed(placed: Village.PlacedItem, config: GameConfig, sprites: SpriteLibrary) -> void:
	var item := config.get_item(placed.item_id)
	if item == null:
		return  # Village reports items that are not in the configuration when it loads them.
	if item.is_unit():
		_place_unit(item, placed.tile, sprites)
	else:
		_place(_item_layer, item, placed.tile, placed.frame, sprites)


## Shows the item at the tile under the mouse until the player clicks or cancels.
## Returns false when the item has no graphic.
func begin_placement(item: GameConfig.ItemDef, village: Village, sprites: SpriteLibrary) -> bool:
	end_placement()
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return false
	_placing_item = item
	_placing_village = village
	_ghost = _make_sprite(sprite, 0, Vector2i.ZERO)
	_ghost.offset = _building_offset(sprite, 0)
	_placement_layer.add_child(_ghost)
	_placement_layer.visible = true
	_update_placement(IsoGrid.map_to_tile(get_local_mouse_position()))
	return true


func end_placement() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_placing_item = null
	_placing_village = null
	_placement_layer.visible = false


func is_placing() -> bool:
	return _placing_item != null


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing():
		return
	if event is InputEventMouseMotion:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_placement(IsoGrid.map_to_tile(make_input_local(event).position))
		get_viewport().set_input_as_handled()
		placement_confirmed.emit(_placing_item, _placing_tile)
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		get_viewport().set_input_as_handled()
		end_placement()


func _update_placement(tile: Vector2i) -> void:
	_placing_tile = tile
	_ghost.position = IsoGrid.tile_to_map(tile)
	_outline.polygon = IsoGrid.footprint_outline(Village.footprint(_placing_item, tile))
	var valid := _placing_village.check_location(_placing_item, tile) == Village.Placement.OK
	_ghost.modulate = PLACEMENT_VALID_COLOR if valid else PLACEMENT_INVALID_COLOR
	_outline.color = Color(_ghost.modulate, 0.35)


func _place(layer: Node2D, item: GameConfig.ItemDef, tile: Vector2i, frame: int, sprites: SpriteLibrary) -> void:
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return
	var node := _make_sprite(sprite, frame, tile)
	node.offset = _building_offset(sprite, frame)
	layer.add_child(node)


## The client puts the bottom centre of the shown frame on the item position.
static func _building_offset(sprite: SpriteLibrary.ItemSprite, frame: int) -> Vector2:
	var size := sprite.get_frame_size(frame)
	return Vector2(-floorf(size.x / 2.0), -size.y) + sprite.origin


func _place_unit(item: GameConfig.ItemDef, tile: Vector2i, sprites: SpriteLibrary) -> void:
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return
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


func _make_sprite(sprite: SpriteLibrary.ItemSprite, frame: int, tile: Vector2i) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = sprite.get_frame(frame)
	node.centered = false
	node.position = IsoGrid.tile_to_map(tile)
	return node
