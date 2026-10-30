class_name ClipSprite
extends Sprite2D
## A graphic that shows one frame of an imported graphic. When the frame
## contains a clip, the clip plays at the frame rate of the client, once or
## in a loop. Units and the shots and effects of battles use it.

signal finished  ## A clip that plays once showed its last frame.

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


## The rectangle on the map that the graphic covers now.
func map_rect() -> Rect2:
	var node: Sprite2D = _clip_node if _clip != null else self
	if node.texture == null:
		return Rect2(global_position, Vector2.ZERO)
	return node.get_global_transform() * Rect2(node.offset, node.texture.get_size())


## Shows frame (0-based). A new frame starts its clip from the first frame.
func play(frame: int, loop: bool) -> void:
	if frame == _frame:
		return
	_frame = frame
	_loop = loop
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
		else:
			set_process(false)
			finished.emit()
			return
	_clip_node.texture = _clip.get_frame(_clip_frame)
