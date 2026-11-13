class_name HostSprite
extends Sprite2D
## Plays a host graphic as the client does: it appears ("apparait"), and
## well_done() plays "bien1" (TutorialMain.nextStep). After that the frame
## scripts of the symbol decide (Host.frame_scripts()).

const FRAME_SECONDS := 1.0 / 30.0

var _graphic: SpriteLibrary.ItemSprite
var _host: Host
var _frame: int
var _playing := true
var _time := 0.0


func _init(graphic: SpriteLibrary.ItemSprite, host: Host) -> void:
	_graphic = graphic
	_host = host
	centered = false
	offset = graphic.origin
	_play("appear")


func well_done() -> void:
	_play("well_done")


func _play(animation: String) -> void:
	_frame = _host.start_frame(animation)
	_playing = true
	texture = _graphic.get_frame(_frame)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	if _time < FRAME_SECONDS:
		return
	_time = fmod(_time, FRAME_SECONDS)
	var scripts := _host.frame_scripts()
	if scripts.has(_frame):
		_playing = scripts[_frame][1]
		_frame = scripts[_frame][0]
	else:
		_frame += 1
	texture = _graphic.get_frame(_frame)
