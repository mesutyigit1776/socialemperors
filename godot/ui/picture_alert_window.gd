class_name PictureAlertWindow
extends Control
## The alert window of the client with a title and a picture (PopupAlerta),
## for example for the spell book at level 15.

signal closed

## The client shows this window 50 pixels below the middle of the screen.
const BELOW_MIDDLE := Vector2(0, 50)

var _window: UiClip


## image: a picture of the import in ui/images, see UiLibrary.image().
func _init(ui: UiLibrary, config: GameConfig, title: String, text: String, image: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.3)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopUpAlertaMC")
	add_child(_window)
	_window.set_text("txTitle", title)
	_window.set_text("txInfo", text)
	_window.set_text("btnOk/lbl", config.text("AUX_OK"))
	var picture := TextureRect.new()
	picture.texture = ui.image(image)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.texture != null:
		# The client centres the pictures of its windows on their container.
		picture.position = -picture.texture.get_size() / 2
	_window.clip("foto").add_child(picture)
	var button := _window.clip("btnOk")
	button.make_button(true)
	button.pressed.connect(func() -> void:
		closed.emit()
		queue_free())


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2 + BELOW_MIDDLE
