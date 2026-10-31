class_name SpellParticle
extends Sprite2D
## The graphic of one particle of a spell on the map, see BattleSpell.particle_shown.
## It plays the frames of the graphic at the frame rate of the client. At its
## last frame the graphic stops, or goes on from the frame "loop_from" of the
## look (1-based), as its frame scripts in the client do. After its frames it fades out and
## leaves; with frames -1 it stays.

const FRAME_SECONDS := 1.0 / 30.0

var _sprite: SpriteLibrary.ItemSprite
var _loop_from: Variant
var _frames_left: int
var _frame := 0
var _time := 0.0


## look: see BattleSpell.particle_shown.
func _init(sprite: SpriteLibrary.ItemSprite, look: Dictionary) -> void:
	_sprite = sprite
	_loop_from = look.get("loop_from")
	_frames_left = int(look.get("frames", -1))
	centered = false
	offset = sprite.origin
	scale = Vector2.ONE * float(look.get("scale", 1.0))
	modulate.a = float(look.get("alpha", 1.0))
	texture = sprite.get_frame(0)


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		_next_frame()
		if _frames_left > 0:
			_frames_left -= 1
			if _frames_left == 0:
				create_tween().tween_property(self, "modulate:a", 0.0, BattleSpell.FADE_FRAMES * FRAME_SECONDS).finished.connect(queue_free)


func _next_frame() -> void:
	if _frame + 1 < _sprite.frames.size():
		_frame += 1
	elif _loop_from != null:
		_frame = int(_loop_from) - 1
	texture = _sprite.get_frame(_frame)
