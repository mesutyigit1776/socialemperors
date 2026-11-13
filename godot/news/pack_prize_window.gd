class_name PackPrizeWindow
extends Control
## The window of the item that a random pack gave (PopupGotPack of the
## client): the villager with gifts, the picture of the item and its name.

signal closed

const PICTURE := "aldeana-regalos.png"

var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig, item: GameConfig.ItemDef) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupGotPackMC")
	add_child(_window)
	_window.set_text("txTitle", config.text("POPUP_GOTPACK_TITLE"))
	_window.set_text("txSubtitle", config.text("POPUP_GOTPACK_SUBTITLE").replace("#0#", item.name))
	_window.show_picture("foto", ui.image(PICTURE))
	_window.show_picture("foto2", ui.thumb(item.img_name), false)
	var ok := _window.clip("btnOk")
	ok.set_text("lbl", config.text("AUX_OK"))
	ok.make_button(true)
	ok.pressed.connect(_close)
	_window.button("closeButt").pressed.connect(_close)


func _ready() -> void:
	_window.keep_centred()


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
