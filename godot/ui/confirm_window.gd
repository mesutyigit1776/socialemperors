class_name ConfirmWindow
extends Control
## The confirm window of the client (PopupConfirm): a question with Yes and No.

signal confirmed
signal declined

var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig, question: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.3)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupConfirmMC")
	add_child(_window)
	_window.set_text("confirmText", question)
	for pair: Array in [["yesBtn", "AUX_SI"], ["noBtn", "AUX_NO"]]:
		_window.set_text(pair[0] + "/lbl", config.text(pair[1]))
		var button := _window.clip(pair[0])
		button.make_button(true)
		var yes: bool = pair[0] == "yesBtn"
		button.pressed.connect(func() -> void:
			if yes:
				confirmed.emit()
			else:
				declined.emit()
			queue_free())


func _ready() -> void:
	_window.keep_centred()
