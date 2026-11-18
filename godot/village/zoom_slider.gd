class_name ZoomSlider
extends Control
## The zoom slider of the client (ZoomSlider): the + and - buttons change the
## zoom by BUTTON_STEP, and the knob shows the zoom and can be dragged. The
## village HUD and the bottom bar of the battles (BattleBar) show it.
##
## The client puts the knob at the bottom of the bar for the zoom
## KNOB_ZOOM_OFFSET and at the top for KNOB_ZOOM_OFFSET + MapCamera.ZOOM_MAX.
## So the knob never reaches the top, and a lower zoom, as in the tournament,
## puts it below the bar.

## The player used the slider: the zoom of MapCamera that it asks for.
signal zoom_requested(level: float)

## The slider is 24 pixels from the right edge of the screen and 200 pixels
## above the bottom of the 600-pixel stage of the client.
const FROM_RIGHT := 24.0
const FROM_BOTTOM := 200.0
const BUTTON_STEP := 0.2
const KNOB_ZOOM_OFFSET := 0.2

## True: the slider ignores the mouse, as during the tutorial.
var locked := false
var _clip: UiClip
var _level := 1.0
var _dragging := false


func _init(ui: UiLibrary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip = ui.make("ZoomSliderMC")
	add_child(_clip)
	for pair: Array in [["zoomIn", BUTTON_STEP], ["zoomOut", -BUTTON_STEP]]:
		var step: float = pair[1]
		var button := _clip.clip(pair[0])
		button.make_button()
		button.pressed.connect(func() -> void:
			if not locked:
				zoom_requested.emit(clampf(_level + step, MapCamera.ZOOM_MIN, MapCamera.ZOOM_MAX)))
	_clip.clip("slider").make_button()
	_clip.clip("slider").gui_input.connect(_on_drag)


## Keeps the slider and camera together: the slider zooms the camera, and
## the knob follows each zoom of the camera.
func follow(camera: MapCamera) -> void:
	zoom_requested.connect(camera.zoom_to)
	camera.zoomed.connect(func() -> void: show_zoom(camera.zoom.x))
	show_zoom(camera.zoom.x)


## Puts the slider at its place on a screen of this size.
func place(screen: Vector2) -> void:
	global_position = Vector2(screen.x - FROM_RIGHT, screen.y - FROM_BOTTOM)


## Moves the knob to the zoom of the camera (ZoomSlider.setValue).
func show_zoom(level: float) -> void:
	_level = level
	_clip.clip("slider").position.y = _bar_height() * (1.0 - (level - KNOB_ZOOM_OFFSET) / MapCamera.ZOOM_MAX)


func _on_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and not locked
	elif event is InputEventMouseMotion and _dragging:
		var height := _bar_height()
		var place_y := clampf(_clip.get_local_mouse_position().y, 0.0, height)
		var level := KNOB_ZOOM_OFFSET + MapCamera.ZOOM_MAX * (1.0 - place_y / height)
		zoom_requested.emit(clampf(level, MapCamera.ZOOM_MIN, MapCamera.ZOOM_MAX))


## slideBar.height of the client, which includes the scale of the bar in the art.
func _bar_height() -> float:
	var bar := _clip.clip("slideBar")
	return bar.bounds().size.y * bar.scale.y
