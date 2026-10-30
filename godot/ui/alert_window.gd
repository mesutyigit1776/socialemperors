class_name AlertWindow
extends Control
## The alert window of the client (AlertPopup): a text and a Close button.

signal closed

var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig, text: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.3)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupAlertMC")
	add_child(_window)
	_window.set_text("alertText", text)
	_window.set_text("okButton/lbl", config.text("AUX_CLOSE"))
	var button := _window.clip("okButton")
	button.make_button(true)
	button.pressed.connect(func() -> void:
		closed.emit()
		queue_free())


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2
