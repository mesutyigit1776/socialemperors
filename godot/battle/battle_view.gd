class_name BattleView
extends Node2D
## Draws a BattleSim: the land, the items, the units with their animations, the
## shots in flight with their effects, the selection and the health bars. It
## does not change the battle.
##
## The client shows the health bar of an item while it is selected or under the
## mouse. The bar and the selection mark of the client are graphics of its main
## file, which the importer does not read; the view draws simple shapes in their
## place.
##
## Shots move as in the client. A stepped shot flies in a curve and leaves its
## trail effect in each frame; where it lands, its blast effect plays. A timed
## shot flies straight, or in an arc: first up to above the middle of its way,
## then down, in 1.6 times the time.

const HEALTH_BAR_SIZE := Vector2(48, 6)
const HEALTH_BAR_GAP := 5.0  ## Pixels between the top of the graphic and the bar.
const HEALTH_COLOR := Color(0.2, 0.85, 0.2)
const ENEMY_HEALTH_COLOR := Color(0.9, 0.75, 0.15)
const LOST_HEALTH_COLOR := Color(0.8, 0.1, 0.1)
const BAR_BORDER_COLOR := Color(0.1, 0.1, 0.1)
const SELECTION_COLOR := Color(0.3, 1.0, 0.3, 0.8)
const SELECTION_RADIUS := Vector2(30, 15)
const MAX_TRAILS := 100
const MAX_BLASTS := 50
## A trail turns up to this angle from the shot, and has this colour, both at random.
const TRAIL_TURN := deg_to_rad(20)
const TRAIL_SHADE := Vector2(0.7, 0.85)
## A shot in an arc does not turn when its way is shorter than this in x.
const ARC_MIN_TURN_WIDTH := 50.0
const ARC_RISE := 1.0 / 20  ## The arc rises by this part of the width of the way.
const BOX_COLOR := Color(1, 1, 1, 0.1)
const BOX_BORDER_COLOR := Color(1, 1, 1)

var _sim: BattleSim
var _sprites: SpriteLibrary
var _effects: SpriteLibrary
var _land_layer := Node2D.new()
var _marks := _Overlay.new()  # Under the items: selection marks.
var _item_layer := Node2D.new()
var _trail_layer := Node2D.new()
var _shot_layer := Node2D.new()  # Shots and blasts.
var _overlay := _Overlay.new()  # Over the items: health bars, selection box.
var _nodes := {}  # BattleFighter -> Sprite2D or UnitSprite
var _directions := {}  # BattleFighter (unit) -> direction 1 to 8
var _shots := {}  # BattleProjectile -> _Flight
var _blast_count := 0
var _rng := RandomNumberGenerator.new()  # For the looks of the effects, not for the battle.
var _selected: Array[BattleFighter] = []
var _hovered: BattleFighter
var _box := Rect2()  # The selection box on the map, or an empty rectangle.


## A shot on the screen.
class _Flight:
	var node: ClipSprite  ## Or null, when the graphic is not imported.
	var fired: int  ## The frame of the battle when the shot left.
	var frames: int  ## The frames of its flight.
	var shown: int  ## The last frame of the battle that the view showed.


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
	add_child(_trail_layer)
	add_child(_shot_layer)
	add_child(_overlay)
	_marks.paint = _draw_marks
	_overlay.paint = _draw_overlay


## effects: the graphics of the shots and their effects.
func show_battle(sim: BattleSim, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary, skin: int, owned_land: PackedInt32Array) -> void:
	_sim = sim
	_sprites = sprites
	_effects = effects
	VillageView.place_land(_land_layer, config, sprites, skin, owned_land)
	for fighter in sim.fighters:
		_add(fighter)
	sim.removed.connect(_on_removed)
	sim.shot_fired.connect(_on_shot_fired)
	sim.shot_landed.connect(_on_shot_landed)


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
	for shot: BattleProjectile in _shots:
		_show_shot(shot, _shots[shot])
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


func _on_shot_fired(shot: BattleProjectile) -> void:
	var flight := _Flight.new()
	flight.fired = _sim.frame
	flight.frames = shot.frames_left
	flight.shown = _sim.frame
	var sprite := _effects.get_sprite(shot.graphic())
	if sprite != null:
		flight.node = ClipSprite.new(sprite)
		flight.node.play(0, true)
		_shot_layer.add_child(flight.node)
	_shots[shot] = flight
	_show_shot(shot, flight)


func _on_shot_landed(shot: BattleProjectile) -> void:
	var flight: _Flight = _shots[shot]
	_shots.erase(shot)
	if flight.node != null:
		flight.node.queue_free()
	if shot.kind == BattleProjectile.Kind.STEPPED and shot.definition.has("blast") and _blast_count < MAX_BLASTS:
		var blast := _play_effect(shot.definition["blast"], _shot_layer, shot.end)
		if blast != null:
			_blast_count += 1
			blast.finished.connect(func() -> void: _blast_count -= 1)


func _show_shot(shot: BattleProjectile, flight: _Flight) -> void:
	if shot.kind == BattleProjectile.Kind.STEPPED:
		# The trails of each frame since the last one shown.
		for frame in range(flight.shown + 1, _sim.frame + 1):
			if shot.definition.has("trail"):
				_add_trails(shot, _stepped_point(shot, _step(shot, flight, frame - 1)), _stepped_point(shot, _step(shot, flight, frame)))
		flight.shown = _sim.frame
	if flight.node == null:
		return
	if shot.kind == BattleProjectile.Kind.STEPPED:
		var step := _step(shot, flight, _sim.frame)
		var point := _stepped_point(shot, step)
		flight.node.position = point
		flight.node.rotation = (point - _stepped_point(shot, step - 1)).angle() + PI / 2
	else:
		var progress := clampf(float(_sim.frame - flight.fired) / flight.frames, 0, 1)
		var place := _timed_place(shot, progress)
		flight.node.position = shot.start + place[0]
		flight.node.rotation = place[1]


## The step of a stepped shot in a frame of the battle.
func _step(shot: BattleProjectile, flight: _Flight, frame: int) -> float:
	return minf(shot.first_step + frame - flight.fired, shot.steps)


func _stepped_point(shot: BattleProjectile, step: float) -> Vector2:
	var part := maxf(step, 0) / shot.steps
	var curve: float = shot.steps * 4 * shot.definition["curve"]
	return shot.start.lerp(shot.end, part) - Vector2(0, sin(part * PI) * curve)


## The trails of a stepped shot between two points of its flight.
func _add_trails(shot: BattleProjectile, from: Vector2, to: Vector2) -> void:
	var count: int = shot.definition["trails"]
	for i in count:
		if _trail_layer.get_child_count() >= MAX_TRAILS:
			return
		var trail := _play_effect(shot.definition["trail"], _trail_layer, to - (to - from) * i / count)
		if trail == null:
			return
		trail.rotation = (to - from).angle() + PI / 2 + _rng.randf_range(-TRAIL_TURN, TRAIL_TURN)
		var shade := _rng.randf_range(TRAIL_SHADE.x, TRAIL_SHADE.y)
		trail.modulate = Color(shade, shade, shade)


## Plays the first frame of an effect once at point, or returns null when its graphic is not imported.
func _play_effect(graphic: String, layer: Node2D, point: Vector2) -> ClipSprite:
	var sprite := _effects.get_sprite(graphic)
	if sprite == null:
		return null
	var effect := ClipSprite.new(sprite)
	effect.position = point
	effect.play(0, false)
	effect.finished.connect(effect.queue_free)
	layer.add_child(effect)
	return effect


## [offset from the start, rotation] of a timed shot at progress (0 to 1) of its flight.
func _timed_place(shot: BattleProjectile, progress: float) -> Array:
	var way := shot.end - shot.start
	var straight_turn := way.angle() + PI / 2
	if not shot.arc:
		return [way * progress, straight_turn]
	var middle := Vector2(way.x / 2, minf(way.y, 0) - roundf(absf(way.x) * ARC_RISE))
	var first_turn := middle.angle() + PI / 2
	var top_turn := PI / 2 if way.x > 0 else -PI / 2
	var last_turn := (way - middle).angle() + PI / 2
	if absf(way.x) < ARC_MIN_TURN_WIDTH:
		top_turn = first_turn
		last_turn = first_turn
	var rise := 1 / BattleProjectile.ARC_TIME  # The part of the flight that goes up.
	if progress < rise:
		var t := progress / rise
		return [Vector2(middle.x * t, middle.y * sqrt(1 - (t - 1) * (t - 1))), lerpf(first_turn, top_turn, t)]
	var t := (progress - rise) / (1 - rise)
	var fall := 1 - sqrt(1 - t * t)
	return [Vector2(lerpf(middle.x, way.x, t), lerpf(middle.y, way.y, fall)), lerpf(top_turn, last_turn, t)]


func _draw_overlay(canvas: CanvasItem) -> void:
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
