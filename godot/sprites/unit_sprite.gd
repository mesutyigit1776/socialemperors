class_name UnitSprite
extends Sprite2D
## The graphic of a unit. Each frame of a unit graphic is one action in one
## direction: frame = action * FRAMES_PER_ACTION + direction. Most frames
## contain a clip that plays its own frames at the frame rate of the client;
## the others are still images. Directions 6 to 8 use the frames of directions
## 2 to 4, mirrored around the registration point of the unit, which is on its
## position.

## The actions of the client, in the order of the frames. Special attack n
## (from 0) is the action SPECIAL + n.
enum Action { IDLE, WALKING, ATTACKING, DYING, SPECIAL = 6 }

const FRAMES_PER_ACTION := 5
const LAST_UNMIRRORED_DIRECTION := 5
const FRAME_SECONDS := 1.0 / 30.0

var _sprite: SpriteLibrary.ItemSprite
var _frame := -1
var _clip: SpriteLibrary.Clip
var _clip_node := Sprite2D.new()
var _clip_frame := 0
var _loop := true
var _time := 0.0


func _init(sprite: SpriteLibrary.ItemSprite) -> void:
	_sprite = sprite
	centered = false
	offset = sprite.origin
	_clip_node.centered = false
	add_child(_clip_node)


func _ready() -> void:
	# Godot turns processing on when the node enters the tree.
	set_process(_clip != null)


## The direction (1 to 8) in which a unit at from looks at to. The client keeps
## the direction current when to is less than a third of a tile away.
static func direction_to(from: Vector2, to: Vector2, current: int) -> int:
	var delta := to - from
	if absf(delta.x) < IsoGrid.TILE_SIZE.x / 3 and absf(delta.y) < IsoGrid.TILE_SIZE.y / 3:
		return current
	if delta.x > 0:
		return 2 if delta.y < 0 else (4 if delta.y > 0 else 3)
	if delta.x < 0:
		return 6 if delta.y < 0 else (8 if delta.y > 0 else 7)
	return 1 if delta.y < 0 else (5 if delta.y > 0 else current)


## The rectangle on the map that the graphic covers now.
func map_rect() -> Rect2:
	var node: Sprite2D = _clip_node if _clip != null else self
	if node.texture == null:
		return Rect2(global_position, Vector2.ZERO)
	return node.get_global_transform() * Rect2(node.offset, node.texture.get_size())


## Shows the action in direction (1 to 8). A new action or direction
## starts its clip from the first frame. The dying action plays once.
func show_action(action: Action, direction: int) -> void:
	var mirrored := direction > LAST_UNMIRRORED_DIRECTION
	scale.x = -1 if mirrored else 1
	var frame := action * FRAMES_PER_ACTION + (direction - 4 if mirrored else direction) - 1
	if frame == _frame:
		return
	_frame = frame
	_loop = action != Action.DYING
	var frame_clip := _sprite.get_frame_clip(frame)
	_clip = frame_clip.clip if frame_clip != null else null
	set_process(_clip != null)
	_clip_node.visible = _clip != null
	if _clip == null:
		texture = _sprite.get_frame(frame)
		return
	texture = null
	_clip_node.transform = frame_clip.transform
	_clip_node.offset = _clip.origin
	_clip_frame = 0
	_time = 0.0
	_clip_node.texture = _clip.get_frame(0)


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		if _clip_frame + 1 < _clip.frame_count():
			_clip_frame += 1
		elif _loop:
			_clip_frame = 0
	_clip_node.texture = _clip.get_frame(_clip_frame)
