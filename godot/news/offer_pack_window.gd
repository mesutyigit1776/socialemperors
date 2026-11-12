class_name OfferPackWindow
extends Control
## The window that sells a normal promotion pack (PopupGetPack of the client:
## the picture of the pack and its cash) or a random pack (PopupMistery: the
## four items, from rare to common, and the cash). Buy emits buy_requested.

signal buy_requested
signal closed

## The client shows the items of a random pack from the last (rare) to the first (common).
const RANDOM_LABELS: Array[String] = ["POPUP_MISTERY_RARE", "POPUP_MISTERY_UNCOMMON", "POPUP_MISTERY_COMMON", "POPUP_MISTERY_COMMON"]

var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig, pack: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var random: bool = pack["type"] == GameConfig.OFFER_RANDOM
	_window = ui.make("PopupMisteryMC" if random else "PopupGetPackMC")
	add_child(_window)
	_window.set_text("txCash", str(pack["cash"]))
	if random:
		_window.set_text("txTitle", config.text("POPUP_MISTERY_TITLE"))
		_window.set_text("txSubtitle", config.text("POPUP_MISTERY_SUBTITLE"))
		var items: Array = pack["items"]
		for place in mini(RANDOM_LABELS.size(), items.size()):
			var item := config.get_item(items[items.size() - 1 - place][0])
			_window.set_text("tx%d" % (place + 1), config.text(RANDOM_LABELS[place]))
			_window.set_text("lbl%d" % (place + 1), item.name if item != null else "")
			_window.show_picture("foto%d" % (place + 1), ui.thumb(item.img_name) if item != null else null, false)
	else:
		_window.set_text("txTitle", config.text("POPUP_PACK_TITLE"))
		_window.set_text("txSubtitle", config.text("POPUP_PACK_SUBTITLE"))
		_window.show_picture("foto", ui.image(config.localized_image("offer_pack_%d.png" % pack["id"])))
	var buy := _window.clip("btnBuy")
	buy.set_text("lbl", config.text("AUX_COMPRAR"))
	buy.make_button(true)
	buy.pressed.connect(func() -> void: buy_requested.emit())
	_window.button("closeButt").pressed.connect(close)


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
