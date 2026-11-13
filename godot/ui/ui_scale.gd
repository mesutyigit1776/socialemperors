class_name UiScale
extends Node
## The size of the HUD, the windows and the map on the screen. The client was
## made for a Flash stage of 760 × 600 pixels; on a larger window the port
## enlarges everything by a factor in steps of STEP, as a browser zoom
## enlarged the Facebook page of the game. The layout of the client stays:
## the HUD keeps its column of 760 pixels in the middle of the window.
##
## The factor is the content scale of the window, so the nodes keep the
## coordinates of the client and the viewport is the window size divided by
## the factor. FrameCache and UiLibrary draw the Flash art at this factor, so
## that it stays sharp.
##
## Automatic (the default): the largest step that leaves at least 760 × 600
## pixels of the client in the window. The player can choose a fixed factor
## with Ctrl and + or −, and go back to automatic with Ctrl and 0. A fixed
## factor is at most the automatic one, so that the windows of the client fit.

const STEP := 0.25
const MIN_SCALE := 1.0
const MAX_SCALE := 4.0
const AUTOMATIC := 0.0
const CLIENT_SIZE := Vector2(760, 600)
const SETTING_SECTION := "display"
const SETTING_KEY := "ui_scale"
const MESSAGE_SECONDS := 2.0
const MESSAGE_LAYER := 100

## The factor that the player chose, or AUTOMATIC.
var chosen := AUTOMATIC
var _message: Label
var _message_timer := Timer.new()


## The largest factor for a window of this size.
static func fitting(window_size: Vector2) -> float:
	var room := minf(window_size.x / CLIENT_SIZE.x, window_size.y / CLIENT_SIZE.y)
	return clampf(floorf(room / STEP + 0.001) * STEP, MIN_SCALE, MAX_SCALE)


## The factor for a window of this size when the player chose this factor or AUTOMATIC.
static func factor_for(window_size: Vector2, choice: float) -> float:
	var largest := fitting(window_size)
	return largest if choice == AUTOMATIC else clampf(choice, MIN_SCALE, largest)


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := ConfigFile.new()
	if settings.load(SoundPlayer.SETTINGS_FILE) == OK:
		var value: Variant = settings.get_value(SETTING_SECTION, SETTING_KEY, AUTOMATIC)
		chosen = clampf(snappedf(float(value), STEP), MIN_SCALE, MAX_SCALE) if (value is float or value is int) and value != AUTOMATIC else AUTOMATIC
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message.visible = false)
	add_child(_message_timer)
	var layer := CanvasLayer.new()
	layer.layer = MESSAGE_LAYER
	_message = Label.new()
	_message.visible = false
	_message.position = Vector2(12, 12)
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_constant_override("outline_size", 4)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(_message)
	add_child(layer)
	get_tree().root.size_changed.connect(_apply)
	_apply()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed):
		return
	var current: float = get_tree().root.content_scale_factor
	match event.physical_keycode:
		KEY_EQUAL, KEY_KP_ADD:
			_choose(current + STEP)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_choose(current - STEP)
		KEY_0, KEY_KP_0:
			_choose(AUTOMATIC)
		_:
			return
	get_viewport().set_input_as_handled()


func _choose(choice: float) -> void:
	var window := get_tree().root
	chosen = AUTOMATIC if choice == AUTOMATIC else clampf(choice, MIN_SCALE, fitting(Vector2(window.size)))
	var settings := ConfigFile.new()
	settings.load(SoundPlayer.SETTINGS_FILE)
	settings.set_value(SETTING_SECTION, SETTING_KEY, chosen)
	if settings.save(SoundPlayer.SETTINGS_FILE) != OK:
		push_error("Cannot save the settings to '%s'." % SoundPlayer.SETTINGS_FILE)
	_apply()
	_message.text = "Interface size %d%%%s" % [roundi(window.content_scale_factor * 100), " (automatic)" if chosen == AUTOMATIC else ""]
	_message.visible = true
	_message_timer.start(MESSAGE_SECONDS)


func _apply() -> void:
	var window := get_tree().root
	var factor := factor_for(Vector2(window.size), chosen)
	if window.content_scale_factor != factor:
		window.content_scale_factor = factor
