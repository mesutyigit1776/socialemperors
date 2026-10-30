class_name BattleView
extends Node2D
## Draws a BattleSim: the land, the items, the units with their animations, the
## shots in flight, the selection and the health bars. It does not change the
## battle.
##
## The client shows the health bar of an item while it is selected or under the
## mouse. The bar and the selection mark of the client are graphics of its main
## file, which the importer does not read; the view draws simple shapes in their
## place. The shots are lines until the importer reads their graphics.

const HEALTH_BAR_SIZE := Vector2(48, 6)
const HEALTH_BAR_GAP := 5.0  ## Pixels between the top of the graphic and the bar.
const HEALTH_COLOR := Color(0.2, 0.85, 0.2)
const ENEMY_HEALTH_COLOR := Color(0.9, 0.75, 0.15)
const LOST_HEALTH_COLOR := Color(0.8, 0.1, 0.1)
const BAR_BORDER_COLOR := Color(0.1, 0.1, 0.1)
const SELECTION_COLOR := Color(0.3, 1.0, 0.3, 0.8)
const SELECTION_RADIUS := Vector2(30, 15)
const SHOT_COLOR := Color(0.25, 0.2, 0.1)
const SHOT_LENGTH := 14.0
const BOX_COLOR := Color(1, 1, 1, 0.1)
const BOX_BORDER_COLOR := Color(1, 1, 1)

var _sim: BattleSim
var _sprites: SpriteLibrary
var _land_layer := Node2D.new()
var _marks := _Overlay.new()  # Under the items: selection marks.
var _item_layer := Node2D.new()
var _overlay := _Overlay.new()  # Over the items: shots, health bars, selection box.
var _nodes := {}  # BattleFighter -> Sprite2D or UnitSprite
var _directions := {}  # BattleFighter (unit) -> direction 1 to 8
var _shots := {}  # BattleProjectile -> [first frame, frames of the flight]
var _selected: Array[BattleFighter] = []
var _hovered: BattleFighter
var _box := Rect2()  # The selection box on the map, or an empty rectangle.


## Draws on itself what the view gives it.
class _Overlay:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


func _ready() -> void:
	add_child(_land_layer)
	add_child(_marks)
	_item_layer.y_sort_enabled = true  # Items further down the screen are in front.
	add_child(_item_layer)
	add_child(_overlay)
	_marks.paint = _draw_marks
	_overlay.paint = _draw_overlay


func show_battle(sim: BattleSim, config: GameConfig, sprites: SpriteLibrary, skin: int, owned_land: PackedInt32Array) -> void:
	_sim = sim
	_sprites = sprites
	VillageView.place_land(_land_layer, config, sprites, skin, owned_land)
	for fighter in sim.fighters:
		_add(fighter)
	sim.removed.connect(_on_removed)
	sim.shot_fired.connect(func(shot: BattleProjectile) -> void: _shots[shot] = [sim.frame, shot.frames_left])
	sim.shot_landed.connect(func(shot: BattleProjectile) -> void: _shots.erase(shot))


func show_selection(selected: Array[BattleFighter]) -> void:
	_selected = selected


func show_hovered(fighter: BattleFighter) -> void:
	_hovered = fighter


## The selection box that the player drags, in map pixels.
func show_box(box: Rect2) -> void:
	_box = box


## The living unit whose graphic is under point, the front one when graphics
## overlap, or null.
func unit_at(point: Vector2) -> BattleFighter:
	var found: BattleFighter = null
	for fighter: BattleFighter in _nodes:
		if fighter.is_unit() and not fighter.dead and _nodes[fighter].map_rect().has_point(point) \
				and (found == null or fighter.position.y > found.position.y):
			found = fighter
	return found


## The units of the player whose graphics touch box.
func units_in_box(box: Rect2) -> Array[BattleFighter]:
	var result: Array[BattleFighter] = []
	for fighter in _sim.fighters:
		if fighter.is_unit() and not fighter.dead and _nodes.has(fighter) and _nodes[fighter].map_rect().intersects(box):
			result.append(fighter)
	return result


func _process(_delta: float) -> void:
	for fighter: BattleFighter in _nodes:
		if fighter.is_unit():
			_show_unit(fighter)
	_marks.queue_redraw()
	_overlay.queue_redraw()


func _add(fighter: BattleFighter) -> void:
	if not fighter.is_unit():
		var building := VillageView.place_sprite(_item_layer, _sprites, fighter.def, fighter.tile, fighter.frame)
		if building != null:
			_nodes[fighter] = building
		return
	var sprite := _sprites.get_sprite(fighter.def.img_name)
	if sprite == null:
		return
	var node := UnitSprite.new(sprite)
	_item_layer.add_child(node)
	_nodes[fighter] = node
	_directions[fighter] = VillageView.UNIT_START_DIRECTIONS[(fighter.tile.x + fighter.tile.y) % VillageView.UNIT_START_DIRECTIONS.size()]
	_show_unit(fighter)


func _show_unit(fighter: BattleFighter) -> void:
	var node: UnitSprite = _nodes[fighter]
	node.position = fighter.position
	_directions[fighter] = UnitSprite.direction_to(fighter.position, fighter.face_point, _directions[fighter])
	var action: int
	match fighter.animation:
		BattleFighter.Pose.WALKING:
			action = UnitSprite.Action.WALKING
		BattleFighter.Pose.ATTACKING:
			action = UnitSprite.Action.ATTACKING
		BattleFighter.Pose.SPECIAL:
			action = UnitSprite.Action.SPECIAL + fighter.special_index
		BattleFighter.Pose.DYING:
			action = UnitSprite.Action.DYING
		_:
			action = UnitSprite.Action.IDLE
	node.show_action(action, _directions[fighter])


func _on_removed(fighter: BattleFighter) -> void:
	if _nodes.has(fighter):
		_nodes[fighter].queue_free()
		_nodes.erase(fighter)
	_directions.erase(fighter)
	_selected.erase(fighter)
	if _hovered == fighter:
		_hovered = null


## A ring under each selected unit, and the outline of a selected building.
func _draw_marks(canvas: CanvasItem) -> void:
	for fighter in _selected:
		var points := PackedVector2Array()
		if fighter.is_unit():
			for i in 25:
				points.append(fighter.position + Vector2.from_angle(TAU * i / 24) * SELECTION_RADIUS)
		else:
			points = IsoGrid.footprint_outline(fighter.footprint())
			points.append(points[0])
		canvas.draw_polyline(points, SELECTION_COLOR, 2.0)


func _draw_overlay(canvas: CanvasItem) -> void:
	for shot: BattleProjectile in _shots:
		var flight: Array = _shots[shot]
		var progress := clampf(float(_sim.frame - flight[0]) / maxf(flight[1], 1), 0, 1)
		var point := shot.start.lerp(shot.end, progress)
		var direction := (shot.end - shot.start).normalized()
		canvas.draw_line(point - direction * SHOT_LENGTH, point, SHOT_COLOR, 2.0)
	var barred := _selected.duplicate()
	if _hovered != null and not _hovered in barred:
		barred.append(_hovered)
	for fighter: BattleFighter in barred:
		if _nodes.has(fighter) and not fighter.dead:
			_draw_health_bar(canvas, fighter)
	if _box.has_area():
		canvas.draw_rect(_box, BOX_COLOR)
		canvas.draw_rect(_box, BOX_BORDER_COLOR, false, 2.0)


func _draw_health_bar(canvas: CanvasItem, fighter: BattleFighter) -> void:
	var node: Sprite2D = _nodes[fighter]
	var top: float = node.map_rect().position.y if node is UnitSprite else node.position.y + node.offset.y
	var bar := Rect2(Vector2(fighter.position.x - HEALTH_BAR_SIZE.x / 2, top - HEALTH_BAR_GAP - HEALTH_BAR_SIZE.y), HEALTH_BAR_SIZE)
	canvas.draw_rect(bar.grow(1), BAR_BORDER_COLOR)
	canvas.draw_rect(bar, LOST_HEALTH_COLOR)
	var share := clampf(float(fighter.health) / maxf(fighter.max_life(), 1), 0, 1)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), ENEMY_HEALTH_COLOR if fighter.team == BattleFighter.Team.ENEMY else HEALTH_COLOR)
