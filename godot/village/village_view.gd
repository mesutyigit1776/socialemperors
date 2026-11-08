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
## With selection_tool, the player dragged a box over these units.
signal units_boxed(units: Array[Village.PlacedItem])

const LAND_ITEM_BASE_ID := 1000
## The colour around the map for each map style (Village.skin), as in the client.
const BACKGROUND_COLORS: Array[Color] = [Color8(0x66, 0x9C, 0x2C), Color8(0xEA, 0xBC, 0x4C), Color8(0xDF, 0xEC, 0xF2), Color8(0x2E, 0x94, 0xE6), Color8(0x86, 0x38, 0x14), Color8(0x39, 0x8A, 0x00), Color8(0xFF, 0xFF, 0xFF)]
## The graphic of a tree has a clip with a tree for each map style.
const SUBCAT_TREE := 125
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
const DAMAGED_COLOR := Color(1.0, 0.65, 0.5)
const MARK_COLOR := Color(0.3, 0.6, 1.0, 0.5)
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
var _visitors: Array[Node2D] = []  # Units that are on the map but not in the save, see show_visitors().
var _ready_marks: Dictionary = {}  # Village.PlacedItem -> Polygon2D, child of the item node
var _health_bars: Dictionary = {}  # Village.PlacedItem -> ColorRect, child of the item node, see update_damage()
var _fires: Dictionary = {}  # Village.PlacedItem -> [FireMC frame, FireSprite], child of the item node
## The fire graphic of the client and the places of its flames, see FireSprite;
## null without the import, and then a damaged building looks burnt.
var fire_graphic: SpriteLibrary.ItemSprite
var fire_flames: Array = []
## The scaffolds of new buildings (see show_construction()) and the windows of
## the client for their bar; null without an import of them.
var effects: SpriteLibrary
var ui: UiLibrary

# Placement mode. _placing_item is null when the mode is off. _moving is the
# item that moves, or null when the player builds a new item.
var _placing_item: GameConfig.ItemDef
var _moving: Village.PlacedItem
var _placing_tile := Vector2i(-1, -1)
var _placing_frame := 0
var _ghost: Sprite2D
var _outline := Polygon2D.new()

var _press_position := Vector2.INF  # Screen position of the last left button press.
## The next drag selects the units in a box instead of moving the map; the
## owner stops the camera while it is set.
var selection_tool := false
var _box_start := Vector2.INF  # Map position where the box started.
var _box := Polygon2D.new()
var _group_outlines := Node2D.new()
var _marks := Node2D.new()


func _ready() -> void:
	add_child(_land_layer)
	_item_layer.y_sort_enabled = true  # Items further down the screen are in front.
	add_child(_item_layer)
	_selection.color = SELECTION_COLOR
	_selection.visible = false
	add_child(_selection)
	add_child(_group_outlines)
	add_child(_marks)
	_box.color = SELECTION_COLOR
	add_child(_box)
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
	_visitors.clear()
	_village = village
	_config = config
	_sprites = sprites

	RenderingServer.set_default_clear_color(BACKGROUND_COLORS[clampi(village.skin, 0, BACKGROUND_COLORS.size() - 1)])
	place_land(_land_layer, config, sprites, LAND_ITEM_BASE_ID + village.skin, village_land_frames(village.owned_land))
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
			_show_style(node, item, placed.frame)
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
	_show_style(node, item, placed.frame)
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


## Draws units that stand on the map but are not items of the save, for
## example the enemies of an attack that wait at the border (VillageAttacks).
## units: [GameConfig.ItemDef, tile] for each unit; replaces the units of the last call.
func show_visitors(units: Array) -> void:
	for node in _visitors:
		node.queue_free()
	_visitors.clear()
	for entry: Array in units:
		var node := _place_unit(entry[0], entry[1])
		if node != null:
			_visitors.append(node)


## Hides or shows an item, for example a unit that works in a building.
func set_item_visible(placed: Village.PlacedItem, shown: bool) -> void:
	if _nodes.has(placed):
		_nodes[placed].visible = shown


## The direction of a unit that walks from one tile to another.
static func unit_direction(from: Vector2i, to: Vector2i) -> int:
	var delta := IsoGrid.tile_to_map(to) - IsoGrid.tile_to_map(from)
	return UNIT_DIRECTIONS_BY_ANGLE[posmod(roundi(delta.angle() / (PI / 4)), 8)]


## Shows a mark above each building that is ready to collect at the time now,
## and above the items of also_ready (the open items of a quest in the town).
func update_production(now: float, also_ready: Array[Village.PlacedItem] = []) -> void:
	for placed: Village.PlacedItem in _nodes:
		var ready := _village.seconds_to_ready(placed, now) == 0 or placed in also_ready
		if ready and not _ready_marks.has(placed):
			_ready_marks[placed] = add_ready_mark(_nodes[placed], _config.get_item(placed.item_id).collect_type)
			SoundPlayer.play(SoundEffect.READY_TO_COLLECT)  # addIconoCollect
		elif not ready and _ready_marks.has(placed):
			_ready_marks[placed].queue_free()
			_ready_marks.erase(placed)


## Shows the life of the damaged items, see Village.health(), in the colours
## of the battle screen. A damaged building also burns with the fire of the
## client, see FireSprite.
func update_damage() -> void:
	for placed: Village.PlacedItem in _nodes:
		var damaged := _village.is_damaged(placed)
		var node: Sprite2D = _nodes[placed]
		if not damaged:
			if _health_bars.has(placed):
				_health_bars[placed].queue_free()
				_health_bars.erase(placed)
				node.self_modulate = Color.WHITE
			if _fires.has(placed):
				_fires[placed][1].queue_free()
				_fires.erase(placed)
			continue
		if not _health_bars.has(placed):
			var new_bar := ColorRect.new()
			new_bar.color = BattleView.BAR_BORDER_COLOR
			new_bar.size = BattleView.HEALTH_BAR_SIZE + Vector2(2, 2)
			var filled := ColorRect.new()
			filled.color = BattleView.HEALTH_COLOR
			filled.position = Vector2.ONE
			new_bar.add_child(filled)
			node.add_child(new_bar)
			_health_bars[placed] = new_bar
		var bar: ColorRect = _health_bars[placed]
		var top: float = (node as UnitSprite).map_rect().position.y - node.position.y if node is UnitSprite else node.offset.y
		bar.position = Vector2(-bar.size.x / 2, top - BattleView.HEALTH_BAR_GAP - bar.size.y)
		var share := clampf(float(_village.health(placed)) / maxf(_config.get_item(placed.item_id).life, 1), 0, 1)
		(bar.get_child(0) as ColorRect).size = Vector2(BattleView.HEALTH_BAR_SIZE.x * share, BattleView.HEALTH_BAR_SIZE.y)
		if not node is UnitSprite:
			_show_fire(placed, node)


func _show_fire(placed: Village.PlacedItem, node: Node2D) -> void:
	var state := FireSprite.state(_village.health(placed), _config.get_item(placed.item_id).life)
	if fire_graphic == null or state > fire_flames.size():
		(node as Sprite2D).self_modulate = DAMAGED_COLOR
		return
	if _fires.has(placed) and _fires[placed][0] == state:
		return
	if _fires.has(placed):
		_fires[placed][1].queue_free()
	var fire := FireSprite.new(fire_graphic, fire_flames[state - 1])
	node.add_child(fire)
	_fires[placed] = [state, fire]


## Shows the scaffold of the graphic symbol of effects instead of the new
## building, with the bar of the client, for this many seconds. small: see
## ConstructionSprite.
func show_construction(placed: Village.PlacedItem, symbol: String, seconds: float, small: bool) -> void:
	if not _nodes.has(placed):
		return
	var node: Sprite2D = _nodes[placed]
	var construction := ConstructionSprite.new(effects.get_sprite(symbol) if effects != null else null, ui, seconds, small)
	node.self_modulate.a = 0.0
	node.add_child(construction)
	construction.finished.connect(func() -> void:
		node.self_modulate.a = 1.0
		construction.queue_free())


## Removes the item from the map after Village.sell().
func remove_placed(placed: Village.PlacedItem) -> void:
	_fires.erase(placed)
	if _nodes.has(placed):
		_nodes[placed].queue_free()
		_nodes.erase(placed)
		_ready_marks.erase(placed)
		_health_bars.erase(placed)


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


func _box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := make_input_local(event).position as Vector2
		if event.pressed:
			_box_start = point
		elif _box_start != Vector2.INF:
			var box := Rect2(_box_start, Vector2.ZERO).expand(point)
			_box_start = Vector2.INF
			_box.polygon = PackedVector2Array()
			selection_tool = false
			var units: Array[Village.PlacedItem] = []
			for placed: Village.PlacedItem in _nodes:
				if _nodes[placed] is UnitSprite and _nodes[placed].visible and (_nodes[placed] as UnitSprite).map_rect().intersects(box):
					units.append(placed)
			units_boxed.emit(units)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _box_start != Vector2.INF:
		var box := Rect2(_box_start, Vector2.ZERO).expand(make_input_local(event).position)
		_box.polygon = PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])


## Marks the tiles of the items and the tiles: what the tutorial asks for, or
## the buildings that the player helped in a visit. Empty lists remove the marks.
func show_marks(items: Array[Village.PlacedItem], tiles: Array[Vector2i]) -> void:
	for child in _marks.get_children():
		child.queue_free()
	var areas: Array[Rect2i] = []
	for placed in items:
		areas.append(Village.footprint(_config.get_item(placed.item_id), placed.tile))
	for tile in tiles:
		areas.append(Rect2i(tile, Vector2i.ONE))
	for area in areas:
		var outline := Polygon2D.new()
		outline.color = MARK_COLOR
		outline.polygon = IsoGrid.footprint_outline(area)
		_marks.add_child(outline)


## Outlines the tiles of the units of a selected group; an empty list removes the outlines.
func show_group(units: Array[Village.PlacedItem]) -> void:
	for child in _group_outlines.get_children():
		child.queue_free()
	for placed in units:
		var outline := Polygon2D.new()
		outline.color = SELECTION_COLOR
		outline.polygon = IsoGrid.footprint_outline(Village.footprint(_config.get_item(placed.item_id), placed.tile))
		_group_outlines.add_child(outline)


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
	if not is_placing() and selection_tool:
		_box_input(event)
		return
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


## The frame (from 0) of the land graphic in each land area of a village map,
## row by row: the areas in owned_land (see IsoGrid.land_area_number()) show
## the owned land. The land graphic is the item LAND_ITEM_BASE_ID + skin.
static func village_land_frames(owned_land: PackedInt32Array) -> Array[int]:
	var frames: Array[int] = []
	for y in IsoGrid.LAND_AREAS:
		for x in IsoGrid.LAND_AREAS:
			frames.append(LAND_FRAME_OWNED if IsoGrid.land_area_number(Vector2i(x, y)) in owned_land else LAND_FRAME_WILD)
	return frames


## Draws the land areas of a map with the land item: frames has the frame
## (from 0) of each area, row by row. The client places a land graphic with
## its first frame and then only shows another frame, so all frames keep the
## place of the first one; the coasts of the quest islands have other bounds.
static func place_land(layer: Node2D, config: GameConfig, sprites: SpriteLibrary, land_item_id: int, frames: Array[int]) -> void:
	var land_item := config.get_item(land_item_id)
	if land_item == null:
		push_warning("The configuration has no land item %d." % land_item_id)
		return
	for y in IsoGrid.LAND_AREAS:
		for x in IsoGrid.LAND_AREAS:
			var area := Vector2i(x, y)
			var node := place_sprite(layer, sprites, land_item, IsoGrid.land_area_anchor_tile(area), frames[y * IsoGrid.LAND_AREAS + x])
			if node != null:
				node.offset = building_offset(sprites.get_sprite(land_item.img_name), 0)


## Draws an item that is not a unit at its tile in layer. Returns null when its graphic is missing.
static func place_sprite(layer: Node2D, sprites: SpriteLibrary, item: GameConfig.ItemDef, tile: Vector2i, frame: int) -> Sprite2D:
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	var node := _make_sprite(sprite, frame, tile)
	node.offset = building_offset(sprite, frame)
	layer.add_child(node)
	return node


## Puts the mark of a building that the player can collect above its node:
## a circle in the color of the resource code.
static func add_ready_mark(node: Sprite2D, resource: String) -> Node2D:
	var mark := _circle(READY_MARK_RADIUS + 2, READY_MARK_BORDER_COLOR)
	mark.add_child(_circle(READY_MARK_RADIUS, READY_MARK_COLORS.get(resource, Color.WHITE)))
	mark.position = _mark_position(node)
	node.add_child(mark)
	return mark


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


## A tree shows the frame of its clip for the map style, as the client does;
## the first frame is style 0, which the graphic of the item already shows.
func _show_style(node: Sprite2D, item: GameConfig.ItemDef, frame: int) -> void:
	if item.subcat_functional != SUBCAT_TREE or _village.skin == 0:
		return
	var sprite := _sprites.get_sprite(item.img_name)
	var frame_clip := sprite.still_clip(frame)
	if frame_clip == null or frame_clip.clip.frame_count() <= _village.skin:
		return
	var tree: Sprite2D = node.get_node_or_null("Style")
	if tree == null:
		tree = Sprite2D.new()
		tree.name = "Style"
		tree.centered = false
		node.add_child(tree)
	node.texture = null
	# The node draws the frame image at its offset; the registration point is sprite.origin inside it.
	tree.transform = Transform2D(0, node.offset - sprite.origin) * frame_clip.transform
	tree.offset = frame_clip.clip.origin
	tree.texture = frame_clip.clip.get_frame(_village.skin)


static func _make_sprite(sprite: SpriteLibrary.ItemSprite, frame: int, tile: Vector2i) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = sprite.get_frame(frame)
	node.centered = false
	node.position = IsoGrid.tile_to_map(tile)
	return node
