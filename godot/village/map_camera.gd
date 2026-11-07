class_name MapCamera
extends Camera2D
## Pans with a mouse drag and zooms with the mouse wheel.

## Each step of the mouse wheel, also at the zoom limits, as the client counts it for the goals.
signal zoomed

var panning := true  ## False while a drag does something else, for example a selection box.

const ZOOM_STEP := 1.1
const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and panning and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
		position -= event.relative / zoom
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(zoom.x * ZOOM_STEP)
			zoomed.emit()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_level(zoom.x / ZOOM_STEP)
			zoomed.emit()


## Zooms as one step of the mouse wheel does, for example from the zoom slider of the HUD.
func zoom_to(level: float) -> void:
	_set_zoom_level(level)
	zoomed.emit()


func _set_zoom_level(level: float) -> void:
	zoom = Vector2.ONE * clampf(level, ZOOM_MIN, ZOOM_MAX)
