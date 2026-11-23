class_name RiderLevel
extends RefCounted
## The ground and the things on it in a level of the mini-game: the terrain
## (main.level_terrain) and the details in front of it (main.level_details),
## whose frame N is level N + 1. Both move to the left as the hero goes on.
## The pits, the crows and the falling tree in them are actors (Pit, Crow, FallingTree).

## Where the client places the terrain and the details at the start.
const TERRAIN_START := Vector2(-371.85, 313.9)
const DETAILS_FROM_TERRAIN := 55.85
const DETAILS_Y := 146.0
const NO_GROUND := INF

var game: RiderGame
var terrain: Node2D
var details: Node2D
var pits: Array[Pit] = []
var crows: Array[Crow] = []
var trees: Array[FallingTree] = []
var _hazards := {}  # Sprite id -> the class of its actor.
var _tops := PackedFloat32Array()  # The top of the ground in each column of the terrain, or NO_GROUND.
var _tops_origin := Vector2.ZERO  # The point of the terrain at column 0, row 0.


func _init(rider_game: RiderGame, level: int) -> void:
	game = rider_game
	var art := game.art
	_hazards = {art.symbol("main.level_pit"): Pit, art.symbol("main.crow"): Crow, art.symbol("main.level_falling_tree"): FallingTree}
	var terrain_id := art.symbol("main.level_terrain")
	terrain = Node2D.new()
	terrain.position = TERRAIN_START
	_place(terrain, terrain_id, level - 1)
	details = Node2D.new()
	details.position = Vector2(TERRAIN_START.x + DETAILS_FROM_TERRAIN, DETAILS_Y)
	_place(details, art.symbol("main.level_details"), level - 1)
	_measure_ground(terrain_id, level - 1)


func terrain_x() -> float:
	return terrain.position.x


## Moves the terrain and the details by dx, when the screen follows the hero.
func scroll(dx: float) -> void:
	terrain.position.x += dx
	details.position.x += dx


## The top of the ground at x on the screen of the game, or NO_GROUND over a pit.
func ground_y(x: float) -> float:
	var column := int(floor(x - terrain.position.x - _tops_origin.x))
	if column < 0 or column >= _tops.size() or _tops[column] == NO_GROUND:
		return NO_GROUND
	return terrain.position.y + _tops_origin.y + _tops[column]


## The highest ground under a width of the screen, from x to x + width: the
## client tests all pixels of a body against the terrain.
func ground_under(x: float, width: float) -> float:
	var result := NO_GROUND
	var step := 0.0
	while step <= width:
		result = minf(result, ground_y(x + step))
		step += 2.0
	return minf(result, ground_y(x + width))


## One frame of the actors in the level.
func update() -> void:
	for pit in pits:
		pit.update()
	for crow: Crow in crows.duplicate():
		crow.update()
	for tree in trees:
		tree.update()


## Places the parts of a frame of a sprite as children of parent: the actors,
## and a FlashClip for each other part. A part with an actor in it is opened.
func _place(parent: Node2D, sprite_id: int, frame: int) -> void:
	for info: Dictionary in game.art.parts(sprite_id, frame):
		var id: int = info.id
		if _hazards.has(id):
			var actor: Variant = (_hazards[id] as GDScript).new(self, id, info.transform)
			parent.add_child(actor.clip)
			if actor is Pit:
				pits.append(actor)
			elif actor is Crow:
				crows.append(actor)
			else:
				trees.append(actor)
		elif _contains_hazard(id):
			var holder := Node2D.new()
			holder.transform = info.transform
			holder.name = info.name if not str(info.name).is_empty() else "part%d" % info.depth
			parent.add_child(holder)
			_place(holder, id, 0)
		else:
			var clip := FlashClip.new(game.art, id)
			clip.transform = info.transform
			clip.modulate = info.multiply
			parent.add_child(clip)
			game.add_clip(clip)


func _contains_hazard(id: int) -> bool:
	for frame in game.art.frame_count(id):
		for info: Dictionary in game.art.parts(id, frame):
			if _hazards.has(info.id) or _contains_hazard(info.id):
				return true
	return false


## Reads the top of the ground from the picture of the terrain at scale 1: in
## each column, the first pixel from the top that is not transparent. The
## client tests the pixels of the hero and of the platforms against the terrain;
## the port tests the bottom of their bounds against this line.
func _measure_ground(terrain_id: int, frame: int) -> void:
	var ground: Dictionary = {}
	for info: Dictionary in game.art.parts(terrain_id, frame):
		if info.name == "terrain":
			ground = info
	if ground.is_empty():
		push_error("RiderLevel: level %d has no terrain" % (frame + 1))
		return
	var id: int = ground.id
	var image := game.art.flash.render(id, 0, 1.0)
	var area := game.art.flash.frame_area(id, 0)
	var canvas := game.art.flash.canvas(id)
	_tops_origin = (ground.transform as Transform2D).origin + canvas.position + Vector2(area.position)
	_tops.resize(image.get_width())
	for column in image.get_width():
		_tops[column] = NO_GROUND
		for row in image.get_height():
			if image.get_pixel(column, row).a > 0.5:
				_tops[column] = row
				break


## A pit with stakes. The hero who steps into it falls and dies on the stakes.
class Pit:
	extends RefCounted
	var level: RiderLevel
	var clip: FlashClip
	var _trapped := false
	var _killed := false

	func _init(rider_level: RiderLevel, id: int, place: Transform2D) -> void:
		level = rider_level
		clip = FlashClip.new(level.game.art, id)
		clip.transform = place
		level.game.add_clip(clip)

	func update() -> void:
		var game := level.game
		var hero := game.hero.rect()
		if not _trapped and game.hero.yspeed >= 0.0 and clip.part_rect(["pit"], game.stage).intersects(hero):
			_trapped = true
			var black := clip.clip("black")
			if black != null:
				black.go_to(1, true)
			game.hero.fall_into_pit()
		if not _killed and clip.part_rect(["pales"], game.stage).intersects(hero):
			_killed = true
			game.hurt_hero(2000.0)


## A crow on the ground. Some time after the hero comes near, it flies away
## and comes back with a warrior, unless the sword of the hero kills it first.
class Crow:
	extends RefCounted
	const WAIT_FRAMES := 200
	var level: RiderLevel
	var clip: FlashClip
	var _flying := false
	var _wait := 0
	var _death := false
	var _pose := ""

	func _init(rider_level: RiderLevel, id: int, place: Transform2D) -> void:
		level = rider_level
		clip = FlashClip.new(level.game.art, id)
		clip.transform = place
		clip.go_to(0, false)
		clip.set_part_frame("crow_In", level.game.rng.randi_range(0, 199))
		level.game.add_clip(clip)

	func update() -> void:
		var game := level.game
		var screen_x := FlashClip.transform_to(clip, game.stage).origin.x
		var delta := screen_x - game.hero.x
		if delta < 200.0 and not _flying:
			_flying = true
		if _flying and not _death:
			_wait += 1
			if _wait < WAIT_FRAMES:
				_set_pose("IdleLeft" if delta >= 0.0 else "IdleRight")
			else:
				clip.position.y -= (300.0 + clip.position.y) / 30.0
				clip.position.x += 1500.0 / (300.0 + clip.position.y) + 1.0
				_set_pose("FlyingRight")
		if not _death and _flying and game.hero.combat and game.hero.sword_hits(clip.rect_in(game.stage)):
			_death = true
			_set_pose("DeathLeft" if delta >= 0.0 else "DeathRight")
			game.play_sound("crow_death")
		if _death:
			clip.position.y += 0.5
		if clip.position.y < -260.0:
			game.add_warrior_from_crow()
			_remove()
		elif clip.position.y > 50.0:
			_remove()

	func _set_pose(label: String) -> void:
		if _pose != label:
			_pose = label
			clip.go_to(label, false)

	func _remove() -> void:
		level.crows.erase(self)
		level.game.remove_clip(clip)


## A tree that falls when the hero comes to it. It only falls; it does not hurt.
class FallingTree:
	extends RefCounted
	var level: RiderLevel
	var clip: FlashClip
	var _fell := false

	func _init(rider_level: RiderLevel, id: int, place: Transform2D) -> void:
		level = rider_level
		clip = FlashClip.new(level.game.art, id)
		clip.transform = place
		clip.go_to(0, false)
		level.game.add_clip(clip, func(frame: int) -> void:
			if frame == 59:
				clip.playing = false)

	func update() -> void:
		if _fell or not clip.part_rect(["active_zone"], level.game.stage).intersects(level.game.hero.rect()):
			return
		_fell = true
		clip.go_to(1, true)
		level.game.play_sound("falling_tree")
