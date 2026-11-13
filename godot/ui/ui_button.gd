class_name UiButton
extends Control
## A named button of a client window (see UiLibrary): its image changes when
## the mouse is over it and when the player presses it, as a Flash button does.
## A disabled button shows its image at 0.3 alpha and takes no clicks, as the
## client shows the arrows of its windows that lead nowhere.

signal pressed

const DISABLED_ALPHA := 0.3

var enabled := true:
	set(value):
		enabled = value
		modulate.a = 1.0 if value else DISABLED_ALPHA
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		_show("up")

var _library: UiLibrary
var _id: int
var _image := TextureRect.new()
var _state := "up"


func _init(library: UiLibrary, button_id: int) -> void:
	_library = library
	_id = button_id
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.position = library.button_origin(button_id)
	add_child(_image)
	_show("up")
	size = _image.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _show("over"))
	mouse_exited.connect(func() -> void: _show("up"))


## The image is drawn at the scale of the window, and again when it changes.
func _enter_tree() -> void:
	_show(_state)
	get_viewport().size_changed.connect(_on_view_resized)


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_on_view_resized)


func _on_view_resized() -> void:
	_show(_state)


## The rectangle of the image, in the coordinates of the button.
func bounds() -> Rect2:
	return Rect2(_image.position, _image.size)


func _has_point(point: Vector2) -> bool:
	return bounds().has_point(point)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	_show("down" if event.pressed else "over")
	if not event.pressed:
		pressed.emit()


func _show(state: String) -> void:
	_state = state
	var scale := get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	_image.texture = _library.button_image(_id, state, scale)
	_image.size = _image.texture.get_size() if _image.texture != null else Vector2.ZERO
