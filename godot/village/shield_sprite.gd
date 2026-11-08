class_name ShieldSprite
extends Sprite2D
## The shield of the HUD (ShieldDisplay of the client), from the files
## swf/shieldEnabled.swf and swf/shieldDisabled.swf. Without a shield it shows
## the still picture of shieldDisabled. With a shield it plays the clip of
## shieldEnabled once, and again every REPLAY_SECONDS.

const REPLAY_SECONDS := 30.0
const FRAME_SECONDS := 1.0 / 30.0

var _clip: SpriteLibrary.Clip
var _frame := 0
var _time := 0.0
var _since_start := 0.0


## graphic: the imported shieldEnabled (enabled) or shieldDisabled.
func _init(graphic: SpriteLibrary.ItemSprite, enabled: bool) -> void:
	centered = false
	var frame_clip := graphic.get_frame_clip(0) if enabled else null
	if frame_clip == null:
		texture = graphic.get_frame(0)
		offset = graphic.origin
		return
	_clip = frame_clip.clip
	transform = frame_clip.transform
	offset = _clip.origin
	texture = _clip.get_frame(0)


func _process(delta: float) -> void:
	if _clip == null:
		return
	_since_start += delta
	if _since_start >= REPLAY_SECONDS:
		_since_start = 0.0
		_frame = 0
		texture = _clip.get_frame(0)
		return
	if _frame >= _clip.frame_count() - 1:
		return
	_time += delta
	if _time < FRAME_SECONDS:
		return
	_time = fmod(_time, FRAME_SECONDS)
	_frame += 1
	texture = _clip.get_frame(_frame)
