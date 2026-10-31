class_name BuyManaWindow
extends Control
## The mana window of the client (PopupBuyMana): the player buys
## GameConfig.mana_per_purchase mana for gold or for cash.

signal closed
signal buy_requested(with_cash: bool)

const WINDOW_SCALE := 0.9
const WIZARD_SCALE := 0.88

var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupBuyManaMC")
	_window.scale = Vector2.ONE * WINDOW_SCALE
	add_child(_window)
	_window.set_text("popupTitle", config.text("POPUP_COMPRAR_MANA_TITULO"))
	_window.set_text("header", config.text("POPUP_COMPRAR_MANA_CABECERA"))
	_window.set_text("manaQtyGold", str(config.mana_per_purchase))
	_window.set_text("manaQtyCash", str(config.mana_per_purchase))
	_window.set_text("goldQty", str(config.mana_price_gold))
	_window.set_text("cashQty", str(config.mana_price_cash))
	var wizard := TextureRect.new()
	wizard.texture = ui.image("mago_altar.png")
	wizard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wizard.texture != null:
		# The client centres the pictures of its windows on their container.
		wizard.scale = Vector2.ONE * WIZARD_SCALE
		wizard.position = -wizard.texture.get_size() * WIZARD_SCALE / 2
	_window.clip("fotoWizard").add_child(wizard)
	_window.button("butClose").pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	for pair: Array in [["btnBuyGold", false], ["btnBuyCash", true]]:
		var button := _window.clip(pair[0])
		button.make_button(true)
		button.pressed.connect(func() -> void: buy_requested.emit(pair[1]))


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2
