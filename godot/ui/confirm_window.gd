class_name ConfirmWindow
extends Control
## The confirm window of the client (PopupConfirm): a question with Yes and No.

signal confirmed
signal declined

var _window: UiClip


## covered: PopupConfirm opens with the cover over the open windows
## (PopupUtils.openPopup). The port also asks with this window where the client
## shows a popup without a cover (the assist of a neighbour, infoFriendAssistPopup).
func _init(ui: UiLibrary, config: GameConfig, question: String, covered := true) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if covered:
		add_child(GuiCover.new(GuiCover.Place.OVER_WINDOWS))
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
