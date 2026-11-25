class_name AlertWindow
extends Control
## The alert window of the client (AlertPopup): a text and a Close button.

signal closed

var _window: UiClip


## place: the cover of an alert is under the open windows, except for the help
## alerts of some windows, which the client opens on the popup layer.
func _init(ui: UiLibrary, config: GameConfig, text: String, place := GuiCover.Place.UNDER_WINDOWS) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(GuiCover.new(place))
	_window = ui.make("PopupAlertMC")
	add_child(_window)
	_window.set_text("alertText", text)
	# The client writes "Close", then "OK" on the button that closes the alert (AlertPopup).
	_window.set_text("okButton/lbl", config.text("AUX_OK"))
	var button := _window.clip("okButton")
	button.make_button(true)
	button.pressed.connect(func() -> void:
		closed.emit()
		queue_free())


func _ready() -> void:
	_window.keep_centred()
