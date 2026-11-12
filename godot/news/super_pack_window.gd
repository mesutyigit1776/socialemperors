class_name SuperPackWindow
extends Control
## The window of a super pack (PopupSuperMistery of the client): all items of
## the pack with their rarity, 5 at a time, and three boxes for 1, 2 and 4
## items with their prices (Village.offer_pack_price). The mouse over a unit
## shows its card. After a purchase, show_prizes() moves the chosen box to the
## middle, opens it, and the items fly from it to their places.
##
## The client also makes the box and the prizes bright and gives them a glow;
## the port does not draw these effects.

signal buy_requested(choice: int)
signal closed

const SHOWN := 5
const RARITY_TEXTS: Array[String] = ["POPUP_MISTERY_RARE", "POPUP_MISTERY_UNCOMMON", "POPUP_MISTERY_COMMON"]
## The client shows another title and a band for this pack.
const CIVILIZATION_PACK := 19
## The places of the prizes for the boxes of 1, 2 and 4 items.
const PRIZE_X: Array[Array] = [[-74.0], [-170.0, 30.0], [-312.0, -153.0, 6.0, 167.0]]
const PICTURE_BACK := Color8(0x99, 0x99, 0x99)
const PICTURE_SIZE := Vector2(90, 90)
const MOVE_SECONDS := 0.5
const OPEN_DELAY := 1.5
const FLY_SECONDS := 1.0
const FLY_DELAY := 0.3
const FLY_X := 30.0
const CARD_GAP := 10.0
const ARROW_DISABLED_ALPHA := 0.5

var _ui: UiLibrary
var _config: GameConfig
var _sprites: SpriteLibrary
var _window: UiClip
var _items: Array[Array] = []  # [item id, rarity text]
var _first := 0
var _displays: Array[UiClip] = []
var _card: UiClip


func _init(ui: UiLibrary, config: GameConfig, sprites: SpriteLibrary, village: Village, pack: Dictionary) -> void:
	_ui = ui
	_config = config
	_sprites = sprites
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupSuperMisteryBoxMC")
	add_child(_window)
	for rarity in pack["items"].size():
		for id: int in pack["items"][rarity]:
			_items.append([id, config.text(RARITY_TEXTS[mini(rarity, RARITY_TEXTS.size() - 1)])])
	var civilization: bool = pack["id"] == CIVILIZATION_PACK
	_window.set_part_visible("onlyThisWeek", civilization)
	_window.set_text("popupTitle", config.text("POPUP_SUPER_MISTERY_CIVILIZATION_TITLE" if civilization else "POPUP_SUPER_MISTERY_TITLE"))
	_window.set_text("txtHeader", config.text("POPUP_SUPER_MISTERY_HEADER").replace("#0#", str(_items.size())))
	_window.set_text("txtFooter", config.text("POPUP_SUPER_MISTERY_FOOTER"))
	_window.set_part_visible("txtFooter", false)
	for choice in 3:
		_window.set_text("txCash%d" % (choice + 1), str(village.offer_pack_price(pack, choice)))
		var buy := _window.clip("btnBuy%d" % (choice + 1))
		buy.set_text("lbl", config.text("AUX_COMPRAR"))
		buy.make_button(true)
		buy.pressed.connect(func() -> void: buy_requested.emit(choice))
		_window.clip("box%d" % (choice + 1)).show_frame(0)
	var ok := _window.clip("btnOk")
	ok.set_text("lbl", config.text("AUX_OK"))
	ok.make_button(true)
	ok.pressed.connect(_close)
	_window.button("left").pressed.connect(_show_items.bind(-1))
	_window.button("right").pressed.connect(_show_items.bind(1))
	for index in SHOWN:
		var display := _window.clip("item%d" % index)
		var back := ColorRect.new()
		back.color = PICTURE_BACK
		back.size = PICTURE_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display.part("pic").add_child(back)
		display.set_part_visible("question", false)
		display.make_button()
		display.mouse_default_cursor_shape = Control.CURSOR_ARROW
		display.mouse_entered.connect(_show_card.bind(display))
		display.mouse_exited.connect(_remove_card)
		_displays.append(display)
	_show_items(0)


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


## The arrows move the items by one.
func _show_items(step: int) -> void:
	_first = clampi(_first + step, 0, maxi(_items.size() - SHOWN, 0))
	for index in SHOWN:
		var display := _displays[index]
		display.visible = _first + index < _items.size()
		if display.visible:
			_show_item(display, _items[_first + index][0], _items[_first + index][1])
	for pair: Array in [["left", _first > 0], ["right", _first + SHOWN < _items.size()]]:
		var arrow := _window.button(pair[0])
		arrow.enabled = pair[1]
		if not pair[1]:
			arrow.modulate.a = ARROW_DISABLED_ALPHA


func _show_item(display: UiClip, id: int, rarity: String) -> void:
	var item := _config.get_item(id)
	display.set_meta("item", id)
	display.show_picture("pic", _ui.thumb(item.img_name) if item != null else null, false)
	display.fit_text("lblName", item.name if item != null else "")
	display.set_text("lblFrequency", rarity)


## The card of a unit, below the item; buildings have no card.
func _show_card(display: UiClip) -> void:
	_remove_card()
	var item := _config.get_item(display.get_meta("item", 0))
	if item == null or not item.is_unit():
		return
	_card = _ui.make("InfoButtonUnitCollectionMC")
	_card.set_text("txNombre", item.name)
	UnitCard.fill(_card, item, _sprites, true)
	# Flash measures the item with its picture and the rectangles of its texts.
	var pic := display.part("pic")
	var area := Rect2(pic.position, PICTURE_SIZE).merge(display.field_rect("lblName")).merge(display.field_rect("lblFrequency"))
	_card.position = display.position + Vector2(area.end.x / 2, area.end.y + CARD_GAP + _card.bounds().size.y)
	_card.clip("background").show_frame(1)
	_window.add_child(_card)


func _remove_card() -> void:
	if _card != null:
		_card.queue_free()
	_card = null


## Shows the prizes of the box of choice (PopupSuperMistery.showPrizes and launchPrizes).
func show_prizes(choice: int, prizes: Array[int]) -> void:
	_remove_card()
	for name in ["left", "right", "btnBuy1", "btnBuy2", "btnBuy3", "txCash1", "txCash2", "txCash3", "icon1", "icon2", "icon3"]:
		_window.set_part_visible(name, false)
	var middle := _window.clip("box2")
	var box := _window.clip("box%d" % (choice + 1))
	for index in 3:
		_window.set_part_visible("box%d" % (index + 1), index == choice)
	create_tween().tween_property(box, "position:x", middle.position.x, MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_window.set_text("txtHeader", _config.text("POPUP_SUPER_MISTERY_HEADER_DONE"))
	_window.set_part_visible("txtFooter", true)
	var places: Array = PRIZE_X[choice]
	for index in SHOWN:
		var display := _displays[index]
		display.visible = index < prizes.size()
		if not display.visible:
			continue
		_show_item(display, prizes[index], _rarity(prizes[index]))
		display.set_part_visible("question", true)
		display.set_part_visible("lblName", false)
		display.set_part_visible("lblFrequency", false)
		create_tween().tween_property(display, "position:x", places[mini(index, places.size() - 1)], MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(OPEN_DELAY).timeout
	if not is_inside_tree():
		return
	for index in 3:
		_window.clip("box%d" % (index + 1)).show_frame(1)
	for index in prizes.size():
		_fly(prizes[index], _displays[index], middle.position, index * FLY_DELAY)


## An item flies from the middle box to its place and grows; then its name shows.
func _fly(id: int, display: UiClip, from: Vector2, delay: float) -> void:
	var item := _config.get_item(id)
	var picture := TextureRect.new()
	picture.texture = _ui.thumb(item.img_name) if item != null else null
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = from
	picture.scale = Vector2.ZERO
	_window.add_child(picture)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(picture, "position", display.position + Vector2(FLY_X, 0), FLY_SECONDS).set_delay(delay)
	tween.tween_property(picture, "scale", Vector2.ONE, FLY_SECONDS).set_delay(delay)
	tween.chain().tween_callback(func() -> void:
		display.set_part_visible("question", false)
		display.set_part_visible("lblName", true)
		display.set_part_visible("lblFrequency", true)
		picture.queue_free())


func _rarity(id: int) -> String:
	for entry in _items:
		if entry[0] == id:
			return entry[1]
	return ""


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
