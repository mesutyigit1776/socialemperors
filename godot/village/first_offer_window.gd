class_name FirstOfferWindow
extends Control
## The window of the first purchase offer (PopupFirstBuy of the client): three
## eggs with the units of GameConfig.first_offer, the time that is left, and
## HATCH!, which buys the offer. The mouse over an egg shows the card of its
## unit (InfoButtonOver of the client, see UnitCard) with the unit walking. The window
## closes when the time ends.

signal buy_requested
signal closed

const EGGS := 3

var _window: UiClip
var _village: Village
var _clock: Callable


## clock: returns the time now (unix seconds).
func _init(ui: UiLibrary, config: GameConfig, sprites: SpriteLibrary, village: Village, clock: Callable) -> void:
	_village = village
	_clock = clock
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupFirstBuyMC")
	add_child(_window)
	_window.set_text("popupTitle", config.text("POPUP_FIRST_OFFER_TITLE"))
	_window.set_text("txtSub", config.text("POPUP_FIRST_OFFER_SUB"))
	_window.set_text("txtHatch", config.text("POPUP_FIRST_OFFER_HATCH"))
	_window.set_text("txtReward", config.text("POPUP_FIRST_OFFER_EXTRA"))
	_window.button("btnClose").pressed.connect(_close)
	var buy := _window.clip("btnBuy")
	buy.make_button(true)
	buy.pressed.connect(func() -> void: buy_requested.emit())
	var units: Array = config.first_offer["units"]
	for index in EGGS:
		var egg := _window.clip("egg%d" % index)
		var item := config.get_item(units[index]) if index < units.size() else null
		if item == null:
			continue
		var card := ui.make("InfoButtonStore6bMC")
		card.set_text("label", item.name)
		card.set_text("txNombre", "")
		UnitCard.fill(card, item, sprites)
		card.visible = false
		egg.clip("thumbAnchor").add_child(card)
		egg.make_button(true)
		egg.mouse_entered.connect(func() -> void: card.visible = true)
		egg.mouse_exited.connect(func() -> void: card.visible = false)
	_refresh_timer()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _process(_delta: float) -> void:
	_refresh_timer()


func _refresh_timer() -> void:
	var left := _village.first_offer_seconds_left(_clock.call())
	_window.set_text("txtTimer", SurvivalWindow.time_text(left))
	if left == 0 and is_inside_tree():
		_close()


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
