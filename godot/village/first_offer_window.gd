class_name FirstOfferWindow
extends Control
## The window of the first purchase offer (PopupFirstBuy of the client): three
## eggs with the units of GameConfig.first_offer, the time that is left, and
## HATCH!, which buys the offer. The mouse over an egg shows the card of its
## unit (InfoButtonOver of the client) with the unit walking. The window
## closes when the time ends.

signal buy_requested
signal closed

const EGGS := 3
## The card of the client fits the walking unit in a box of THUMB_SIZE and
## only makes it smaller.
const THUMB_SIZE := Vector2(120, 120)
const THUMB_MARGIN := 8.0

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
		var card := _make_card(ui, sprites, item)
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


## The card of the client for a unit (InfoButtonStore6bMC): the name, the
## life, attack, attack interval, speed, range and population, and the unit
## walking down and to the right.
func _make_card(ui: UiLibrary, sprites: SpriteLibrary, item: GameConfig.ItemDef) -> UiClip:
	var card := ui.make("InfoButtonStore6bMC")
	card.set_part_visible("descEspecial", false)
	card.set_text("label", item.name)
	card.set_text("txNombre", "")
	for pair: Array in [["mcVida/txVida", item.life], ["mcAttack/txAttack", item.attack], ["mcDefense/txDefense", item.attack_interval],
			["mcSpeed/txSpeed", item.velocity], ["mcRange/txRange", item.attack_range], ["mcPop/txPop", item.population]]:
		card.set_text(pair[0], str(pair[1]))
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return card
	var frame := UnitSprite.frame_of(UnitSprite.Action.WALKING, 4)
	var box := Control.new()
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = card.part("thumb").position - Vector2(THUMB_MARGIN, THUMB_MARGIN)
	box.size = THUMB_SIZE + Vector2(THUMB_MARGIN, THUMB_MARGIN) * 2
	card.add_child(box)
	var unit := UnitSprite.new(sprite)
	unit.show_action(UnitSprite.Action.WALKING, 4)
	var size: Vector2 = sprite.frame_sizes[frame] if frame < sprite.frame_sizes.size() else THUMB_SIZE
	var origin: Vector2 = sprite.frame_origins[frame] if frame < sprite.frame_origins.size() else Vector2.ZERO
	var ratio := maxf(maxf(size.x / THUMB_SIZE.x, size.y / THUMB_SIZE.y), 1.0)
	unit.scale = Vector2.ONE / ratio
	unit.position = Vector2(THUMB_MARGIN, THUMB_MARGIN) + (THUMB_SIZE - size / ratio) / 2 - origin / ratio
	box.add_child(unit)
	return card


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
