class_name TownQuestWindow
extends Control
## The window of a quest in the town (PopupQuestInfo2 of the client): the
## picture of the quest, the chapter and title, and the text of the quest at
## its start, or of its end with the COMPLETED stamp, which grows into place
## from 10 times its size in one second.

signal closed

const STAMP_SECONDS := 1.0
const STAMP_START_SCALE := 10.0

var _window: UiClip
var _completed := false


## picture: a file of TownQuestBook.PICTURES, or "" for none.
func _init(ui: UiLibrary, config: GameConfig, title: String, text: String, picture: String, completed: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupQuestInfo2MC")
	add_child(_window)
	_window.set_text("txTitle", title)
	_window.set_text("txDesc", text)
	var texture := ui.image(picture) if not picture.is_empty() else null
	if texture != null:
		# The client centres the picture on its part (getRealSizeBitmap).
		var image := TextureRect.new()
		image.texture = texture
		image.position = -texture.get_size() / 2
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.clip("foto").add_child(image)
	_completed = completed
	_window.set_part_visible("mcCompleted", completed)
	_window.set_text("mcCompleted/txtCompleted", config.text("AUX_COMPLETADO"))
	_window.set_text("btnOk/lbl", "OK")
	var ok := _window.clip("btnOk")
	ok.make_button(true)
	ok.pressed.connect(func() -> void:
		closed.emit()
		queue_free())


func _ready() -> void:
	_window.keep_centred()
	if _completed:
		var stamp := _window.clip("mcCompleted")
		stamp.modulate.a = 0.0
		stamp.scale = Vector2.ONE * STAMP_START_SCALE
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(stamp, "modulate:a", 1.0, STAMP_SECONDS)
		tween.tween_property(stamp, "scale", Vector2.ONE, STAMP_SECONDS)
