class_name BattleView
extends Node2D
## Draws a BattleSim: the land, the items, the units with their animations, the
## shots in flight with their effects, the selection and the health bars. It
## does not change the battle.
##
## The client shows the health bar of an item while it is selected or under the
## mouse (HealthBar), and in a tournament always over the enemies. A selected
## item has the selection mark of the client under it (SelectionMark). Without
## these symbols in the import, the view draws simple shapes in their place.
##
## Shots move as in the client. A stepped shot flies in a curve and leaves its
## trail effect in each frame; where it lands, its blast effect plays. A timed
## shot flies straight, or in an arc: first up to above the middle of its way,
## then down, in 1.6 times the time.
##
## Spells show their particles (see show_spell()), and the states of the units:
## a frozen or poisoned unit has the colour that the client adds to it, an
## enlarged unit grows to twice its size in half a second, a stunned unit jumps
## and falls, and a swallowed item shrinks. While the player aims a spell, the
## items that it would mark glow, see show_marked().
##
## Abilities show the magic particles of the client (MagicParticleMC, one frame
## for each type), units that fly through the air after a push, beams that go
## from the shooter to the target, open doors and units that the client draws
## bigger or smaller (BattleAbility.scale).

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
## The colours that the client adds to frozen and poisoned units, and the glow of marked items.
const FROZEN_COLOR := Color8(0, 0, 128)
const POISONED_COLOR := Color8(204, 51, 255)
const MARKED_COLOR := Color8(110, 110, 60)
const ENLARGED_SIZE := 2.0
const RESIZE_SECONDS := 0.5
const APPEAR_SECONDS := 0.5  ## See BattleFighter.grows_in.
## The Huge Egg flashes red when it is hit (EggDelegate.onRecibirAtaque): the
## red grows to 0.6 three times in 0.1 seconds, then goes in 0.3 seconds.
const FLASH_ON_HIT: Array[int] = [434]
const HIT_FLASH := {"colour": Color(1, 0, 0), "amount": 0.6, "rise": 0.1, "fall": 0.0, "pulses": 3, "end": 0.3}
## A unit that BattleSim.highlighted names flashes white: up to 0.5 in 0.3
## seconds and back in 0.3 seconds, three times (highlightElement).
const HIGHLIGHT_FLASH := {"colour": Color(1, 1, 1), "amount": 0.5, "rise": 0.3, "fall": 0.3, "pulses": 3, "end": 0.0}
const FLASH_STEP := 0.05  ## The colour changes in steps, so that the view needs few materials.
## Item id -> the rocks without damage that the client adds to each rock of
## the unit, at a random speed from 8 to 10 pixels in a frame (CatapultDelegate).
const EXTRA_ROCKS := {521: 4}
const EXTRA_ROCK_SPEED := Vector2(8, 10)
## Item id -> the shots without damage that the item fires every STREAM_FRAMES
## frames while it has a target (Machinegun of FireCastleDelegate: Castle III).
const STREAMS := {198: BattleProjectile.FIRE_ARROW}
const STREAM_FRAMES := 2
const MAX_VIEW_SHOTS := 200
const STUN_JUMP := 100.0  ## Pixels.
const STUN_SECONDS := 0.5  ## Up, then down.
## The selection mark of each team, see SelectionMark.
const SIDES := {BattleFighter.Team.PLAYER: SelectionMark.Party.PLAYER, BattleFighter.Team.ENEMY: SelectionMark.Party.ENEMY, BattleFighter.Team.NEUTRAL: SelectionMark.Party.NEUTRAL}
const ENEMY_BAR_SIZE := 2.0  ## The bars of the enemies of a tournament.
const BOX_COLOR := Color(1, 1, 1, 0.1)
const BOX_BORDER_COLOR := Color(1, 1, 1)
const MAGIC_PARTICLES := "MagicParticleMC"
const PUSH_HEIGHT := 60.0  ## Pixels: the top of the flight of a pushed unit.
const DOOR_OPEN_FRAMES := 2  ## The client shows an open door 2 frames after the closed one.

var _sim: BattleSim
var _config: GameConfig
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
var _below_layer := Node2D.new()  # Spell particles under the items.
var _above_layer := Node2D.new()  # Spell particles over the items.
var _sizes := {}  # BattleFighter (unit) -> its size now, 1 or more.
var _stuns := {}  # BattleFighter (unit) -> seconds since its stun.
var _marked: Array[BattleFighter] = []
var _pushes := {}  # BattleFighter (unit) -> [from, to, seconds since the push, seconds of the flight].
var _opened: Array[BattleFighter] = []  # Doors that show open.
var _map_ui: UiLibrary  # The marks and bars of the client, see SelectionMark and HealthBar; or null.
var _mark_nodes := {}  # BattleFighter -> UiClip: the selection marks, children of the nodes.
var _bars := {}  # BattleFighter -> HealthBar.
var _dome_ranges := {}  # BattleFighter (a dome) -> DomeRange.
var _appearing := {}  # BattleFighter -> seconds since it came, see BattleFighter.grows_in.
var _flashes := {}  # BattleFighter -> [flash (HIT_FLASH or HIGHLIGHT_FLASH), seconds since it started].
var _view_shots: Array[BattleProjectile] = []  # Shots that only the view has, see EXTRA_ROCKS and STREAMS.
var _stream_frame := 0  # The last frame of the battle for which _show_streams() ran.
## The enemies show their health bars all the time, twice as big (a tournament).
var enemy_bars := false


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
	add_child(_below_layer)
	add_child(_marks)
	_item_layer.y_sort_enabled = true  # Items further down the screen are in front.
	add_child(_item_layer)
	add_child(_trail_layer)
	add_child(_shot_layer)
	add_child(_above_layer)
	add_child(_overlay)
	_marks.paint = _draw_marks
	_overlay.paint = _draw_overlay


## effects: the graphics of the shots and their effects. ui: the windows of
## the client, for the marks and bars; without it the view draws shapes.
func show_battle(sim: BattleSim, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary, land_item_id: int, land_frames: Array[int], ui: UiLibrary = null) -> void:
	_sim = sim
	_config = config
	_map_ui = ui.for_map() if ui != null else null
	_sprites = sprites
	_effects = effects
	VillageView.place_land(_land_layer, config, sprites, land_item_id, land_frames)
	for fighter in sim.fighters:
		_add(fighter)
	sim.added.connect(_add)
	sim.look_changed.connect(func(fighter: BattleFighter) -> void:
		if _nodes.has(fighter):
			_nodes[fighter].queue_free()
			_nodes.erase(fighter)
		_add(fighter))
	sim.removed.connect(_on_removed)
	sim.shot_fired.connect(_on_shot_fired)
	sim.shot_landed.connect(_on_shot_landed)
	sim.state_changed.connect(_on_state_changed)
	sim.hit.connect(func(target: BattleFighter, _attacker: BattleFighter, _damage: int, _critical: bool) -> void:
		if target.def.id in FLASH_ON_HIT and not _flashes.has(target):
			_flashes[target] = [HIT_FLASH, 0.0])
	sim.highlighted.connect(func(unit: BattleFighter) -> void: _flashes[unit] = [HIGHLIGHT_FLASH, 0.0])
	sim.particle_added.connect(_on_particle_added)
	sim.spell_created.connect(show_spell)
	sim.effect_played.connect(func(graphic: String, tile: Vector2i) -> void:
		_play_effect(graphic, _shot_layer, IsoGrid.tile_to_map(tile)))
	sim.pushed.connect(func(unit: BattleFighter, frames: int) -> void:
		_pushes[unit] = [unit.position, IsoGrid.tile_to_map(unit.tile), 0.0, frames / float(BattleSim.FRAMES_PER_SECOND)])


## Shows the particles of spell, see BattleSpell.particle_shown.
func show_spell(spell: BattleSpell) -> void:
	spell.particle_shown.connect(_add_particle)


## The layer under the items, for example for the marker of the area of a spell.
func under_items() -> Node2D:
	return _below_layer


## The items that glow while the player aims a spell.
func show_marked(marked: Array[BattleFighter]) -> void:
	var changed := _marked + marked
	_marked = marked
	for fighter in changed:
		_update_tint(fighter)


## Marks a building that the player can collect, as the village marks a
## building that is ready: the treasure of a troll island.
func show_collectable(fighter: BattleFighter, resource: String) -> void:
	if _nodes.has(fighter) and not fighter.is_unit():
		VillageView.add_ready_mark(_nodes[fighter], resource)


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


func _process(delta: float) -> void:
	for fighter: BattleFighter in _nodes:
		if fighter.is_unit():
			_show_unit(fighter)
			_show_size(fighter, delta)
	for shot: BattleProjectile in _shots.keys():
		_show_shot(shot, _shots[shot])
		if shot in _view_shots and _sim.frame - _shots[shot].fired >= _shots[shot].frames:
			_view_shots.erase(shot)
			_on_shot_landed(shot)
	_show_streams()
	_update_marks()
	_update_bars()
	for fighter: BattleFighter in _flashes.keys():
		var flash: Dictionary = _flashes[fighter][0]
		_flashes[fighter][1] += delta
		if _flashes[fighter][1] >= (flash["rise"] + flash["fall"]) * flash["pulses"] + flash["end"]:
			_flashes.erase(fighter)
		_update_tint(fighter)
	for dome: BattleFighter in _dome_ranges:
		_dome_ranges[dome].show_state(dome in _selected, dome == _hovered)
	_marks.queue_redraw()
	_overlay.queue_redraw()


func _add(fighter: BattleFighter) -> void:
	if not fighter.is_unit():
		var building := VillageView.place_sprite(_item_layer, _sprites, fighter.def, fighter.tile, fighter.frame)
		if building != null:
			_nodes[fighter] = building
			FortressUnits.show_in(building, _sprites.get_sprite(fighter.def.img_name), fighter.frame, _sprites, _config, fighter.inside_ids)
			if DomeRange.is_dome(fighter.def) and _map_ui != null:
				_dome_ranges[fighter] = DomeRange.attach(building, fighter.def, _map_ui, _map_ui.other("ui/dome", true))
		return
	var sprite := _sprites.get_item_sprite(fighter.look if fighter.look != null else fighter.def)
	if sprite == null:
		return
	var node := UnitSprite.new(sprite)
	_item_layer.add_child(node)
	BattleSounds.watch_graphic(fighter.def.id, node)
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
	if fighter.forced_action >= 0 and not fighter.dead:
		action = fighter.forced_action
	elif fighter.shown_action >= 0 and not fighter.dead:
		action = fighter.shown_action
	node.show_action(action, _directions[fighter])
	if _pushes.has(fighter):
		var push: Array = _pushes[fighter]
		var part: float = clampf(push[2] / push[3], 0, 1) if push[3] > 0 else 1.0
		node.position = push[0].lerp(push[1], part) - Vector2(0, sin(part * PI) * PUSH_HEIGHT)
		if not fighter.in_air:
			_pushes.erase(fighter)


## The size of a unit follows its state; a stunned unit jumps and falls.
func _show_size(fighter: BattleFighter, delta: float) -> void:
	var node: UnitSprite = _nodes[fighter]
	var normal := (fighter.ability.scale if fighter.ability != null else 1.0) * fighter.draw_scale
	var target := 0.0 if fighter.swallowed else normal * (ENLARGED_SIZE if fighter.enlarged else 1.0)
	if not _sizes.has(fighter):
		_sizes[fighter] = normal
	if _pushes.has(fighter):
		_pushes[fighter][2] += delta
	var size: float = move_toward(_sizes.get(fighter, 1.0), target, delta / RESIZE_SECONDS * maxf(ENLARGED_SIZE - 1, 1))
	_sizes[fighter] = size
	node.scale = Vector2(signf(node.scale.x) * size, size)
	if fighter.grows_in and _appearing.get(fighter, 0.0) < APPEAR_SECONDS:
		var time: float = _appearing.get(fighter, 0.0) + delta
		_appearing[fighter] = time
		# An elastic tween, as the client does (Elastic.easeOut).
		node.scale.y *= Tween.interpolate_value(0.5, 0.5, minf(time, APPEAR_SECONDS), APPEAR_SECONDS, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
		node.modulate.a = Tween.interpolate_value(0.0, 1.0, minf(time, APPEAR_SECONDS), APPEAR_SECONDS, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	if _stuns.has(fighter):
		var time: float = _stuns[fighter] + delta
		_stuns[fighter] = time
		var rise := time / STUN_SECONDS
		node.position.y -= STUN_JUMP * (1 - pow(1 - rise, 3) if rise < 1 else maxf(1 - (rise - 1) * (rise - 1), 0) if rise < 2 else 0.0)
		if rise >= 2:
			_stuns.erase(fighter)


func _on_state_changed(fighter: BattleFighter) -> void:
	if fighter.stunned and not _stuns.has(fighter):
		_stuns[fighter] = 0.0
	if not fighter.is_unit() and fighter.swallowed and _nodes.has(fighter):
		create_tween().tween_property(_nodes[fighter], "scale", Vector2.ZERO, RESIZE_SECONDS)
	if fighter.opened and not fighter in _opened and _nodes.has(fighter):
		_opened.append(fighter)
		_nodes[fighter].queue_free()
		_nodes.erase(fighter)
		var door := VillageView.place_sprite(_item_layer, _sprites, fighter.def, fighter.tile, fighter.frame + DOOR_OPEN_FRAMES)
		if door != null:
			_nodes[fighter] = door
	_update_tint(fighter)


func _update_tint(fighter: BattleFighter) -> void:
	if not _nodes.has(fighter):
		return
	var colour := Color.BLACK
	if fighter.frozen:
		colour = FROZEN_COLOR
	elif fighter.poisoned:
		colour = POISONED_COLOR
	if fighter in _marked:
		colour = Color(minf(colour.r + MARKED_COLOR.r, 1), minf(colour.g + MARKED_COLOR.g, 1), minf(colour.b + MARKED_COLOR.b, 1))
	var node: Sprite2D = _nodes[fighter]
	# A tint of the client mixes the colour in: the graphic times 1 - amount, plus the colour times amount.
	var amount := snappedf(_flash_amount(fighter), FLASH_STEP)
	var flash_colour: Color = _flashes[fighter][0]["colour"] if _flashes.has(fighter) else Color.BLACK
	node.modulate = Color(1 - amount, 1 - amount, 1 - amount, node.modulate.a)
	colour = Color(minf(colour.r + flash_colour.r * amount, 1), minf(colour.g + flash_colour.g * amount, 1), minf(colour.b + flash_colour.b * amount, 1))
	if node is ClipSprite:
		node.tint = colour
	else:
		FrameMaterial.show(node, node.texture, colour)


## The part of the colour of the flash of fighter now, from 0.
func _flash_amount(fighter: BattleFighter) -> float:
	if not _flashes.has(fighter):
		return 0.0
	var flash: Dictionary = _flashes[fighter][0]
	var time: float = _flashes[fighter][1]
	var pulse: float = flash["rise"] + flash["fall"]
	if time < pulse * flash["pulses"]:
		var part := fmod(time, pulse)
		return flash["amount"] * (part / flash["rise"] if part < flash["rise"] else 1 - (part - flash["rise"]) / flash["fall"])
	return flash["amount"] * maxf(1 - (time - pulse * flash["pulses"]) / flash["end"], 0) if flash["end"] > 0 else 0.0


func _add_particle(graphic: String, tile: Vector2i, look: Dictionary) -> void:
	var sprite := _effects.get_sprite(graphic)
	if sprite == null:
		return
	var particle := SpellParticle.new(sprite, look)
	particle.position = IsoGrid.tile_to_map(tile)
	match look.get("depth"):
		"mixed":
			_item_layer.add_child(particle)
		"above":
			_above_layer.add_child(particle)
		_:
			_below_layer.add_child(particle)


func _on_removed(fighter: BattleFighter) -> void:
	if _nodes.has(fighter):
		_nodes[fighter].queue_free()
		_nodes.erase(fighter)
	_directions.erase(fighter)
	_sizes.erase(fighter)
	_stuns.erase(fighter)
	_pushes.erase(fighter)
	_marked.erase(fighter)
	_selected.erase(fighter)
	if _hovered == fighter:
		_hovered = null
	_mark_nodes.erase(fighter)  # The mark and the range of a dome go with the node.
	_dome_ranges.erase(fighter)
	_appearing.erase(fighter)
	_flashes.erase(fighter)
	if _bars.has(fighter):
		_bars[fighter].queue_free()
		_bars.erase(fighter)


## The selection marks of the client under the selected items.
func _update_marks() -> void:
	if not SelectionMark.can_attach(_map_ui):
		return
	for fighter: BattleFighter in _mark_nodes.keys():
		var mark: UiClip = _mark_nodes[fighter]
		if not fighter in _selected or fighter.dead or not is_instance_valid(mark):
			if is_instance_valid(mark):
				mark.queue_free()
			_mark_nodes.erase(fighter)
	for fighter in _selected:
		if not fighter.dead and _nodes.has(fighter) and not _mark_nodes.has(fighter):
			var mark := SelectionMark.attach(_nodes[fighter], _map_ui, SIDES[fighter.team], fighter.is_unit(), fighter.def.width)
			if mark != null:
				_mark_nodes[fighter] = mark


## The health bars of the client over the selected item, the item under the
## mouse and, in a tournament, the enemies.
func _update_bars() -> void:
	if not HealthBar.can_make(_map_ui):
		return
	var barred := _barred()
	for fighter: BattleFighter in _bars.keys():
		if not fighter in barred:
			_bars[fighter].queue_free()
			_bars.erase(fighter)
	for fighter in barred:
		if not _bars.has(fighter):
			var big := enemy_bars and fighter.team == BattleFighter.Team.ENEMY
			_bars[fighter] = HealthBar.new(_map_ui, fighter.team == BattleFighter.Team.ENEMY, ENEMY_BAR_SIZE if big else 1.0)
			_overlay.add_child(_bars[fighter])
		var bar: HealthBar = _bars[fighter]
		bar.show_life(float(fighter.health) / maxf(fighter.max_life(), 1))
		bar.place(_nodes[fighter].position, _graphic_height(fighter))


## The items that show a health bar now.
func _barred() -> Array[BattleFighter]:
	var candidates: Array[BattleFighter] = _selected.duplicate()
	if _hovered != null:
		candidates.append(_hovered)
	if enemy_bars:
		candidates.append_array(_sim.fighters.filter(func(fighter: BattleFighter) -> bool: return fighter.team == BattleFighter.Team.ENEMY))
	var barred: Array[BattleFighter] = []
	for fighter in candidates:
		if _nodes.has(fighter) and not fighter.dead and not fighter in barred:
			barred.append(fighter)
	return barred


## The height of the graphic of an item on the map (ghostBuilding.height of the client).
func _graphic_height(fighter: BattleFighter) -> float:
	var node: Sprite2D = _nodes[fighter]
	if node is UnitSprite:
		return node.map_rect().size.y
	var sprite := _sprites.get_sprite(fighter.def.img_name)
	return sprite.get_frame_size(fighter.frame).y if sprite != null else 0.0


## A ring under each selected unit, and the outline of a selected building,
## when the import has no selection marks.
func _draw_marks(canvas: CanvasItem) -> void:
	if SelectionMark.can_attach(_map_ui):
		return
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
	if shot.kind == BattleProjectile.Kind.STEPPED and shot.attacker != null and shot.target != null and shot.graphic_name == "" and EXTRA_ROCKS.has(shot.attacker.def.id):
		for i in EXTRA_ROCKS[shot.attacker.def.id]:
			var definition := shot.definition.duplicate()
			definition["speed"] = _rng.randf_range(EXTRA_ROCK_SPEED.x, EXTRA_ROCK_SPEED.y)
			_add_view_shot(BattleProjectile.stepped_for_view(shot.attacker, shot.target, _rng, definition))
	_add_flight(shot)


func _add_view_shot(shot: BattleProjectile) -> void:
	_view_shots.append(shot)
	_add_flight(shot)


## The streams of shots without damage of the items of STREAMS while they have a target.
func _show_streams() -> void:
	if _sim.frame == _stream_frame:
		return
	for frame in range(_stream_frame + 1, _sim.frame + 1):
		if frame % STREAM_FRAMES != 0:
			continue
		for fighter in _sim.fighters:
			if STREAMS.has(fighter.def.id) and not fighter.dead and not fighter.moving and fighter.target != null and not fighter.target.dead and _view_shots.size() < MAX_VIEW_SHOTS:
				_add_view_shot(BattleProjectile.stepped_for_view(fighter, fighter.target, _rng, STREAMS[fighter.def.id]))
	_stream_frame = _sim.frame


func _add_flight(shot: BattleProjectile) -> void:
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
	if not shot.beam:
		flight.node.scale = Vector2.ONE * shot.scale
	if shot.kind == BattleProjectile.Kind.STEPPED:
		var step := _step(shot, flight, _sim.frame)
		var point := _stepped_point(shot, step)
		flight.node.position = point
		flight.node.rotation = (point - _stepped_point(shot, step - 1)).angle() + PI / 2
	elif shot.beam:
		# A beam reaches the target at once: its graphic stretches over the way.
		var way := shot.end - shot.start
		flight.node.position = shot.start
		flight.node.rotation = way.angle() + PI / 2
		var length := _sprite_length(shot.graphic())
		if length > 0:
			flight.node.scale = Vector2(1, way.length() / length)
	else:
		var progress := clampf(float(_sim.frame - flight.fired) / flight.frames, 0, 1)
		var place := _timed_place(shot, progress)
		flight.node.position = shot.start + place[0]
		flight.node.rotation = place[1]


## The height of the first frame of an effect graphic, or 0.
func _sprite_length(graphic: String) -> float:
	var sprite := _effects.get_sprite(graphic)
	return sprite.get_frame_size(0).y if sprite != null and sprite.frame_count() > 0 else 0.0


## A magic particle of an ability: its clip plays once on the tile after delay frames.
func _on_particle_added(type: int, tile: Vector2i, delay: int) -> void:
	var sprite := _effects.get_sprite(MAGIC_PARTICLES)
	if sprite == null or type < 1 or type > sprite.frame_count():
		return
	var show := func() -> void:
		var particle := ClipSprite.new(sprite)
		particle.position = IsoGrid.tile_to_map(tile)
		particle.play(type - 1, false)
		particle.finished.connect(particle.queue_free)
		_above_layer.add_child(particle)
		if sprite.get_frame_clip(type - 1) == null:
			# A frame without a clip does not end by itself; the client fades such particles in 1 second.
			get_tree().create_timer(1.0).timeout.connect(particle.queue_free)
	if delay <= 0:
		show.call()
	else:
		get_tree().create_timer(delay / float(BattleSim.FRAMES_PER_SECOND)).timeout.connect(show)


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
	if not HealthBar.can_make(_map_ui):
		for fighter in _barred():
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
