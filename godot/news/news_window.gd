class_name NewsWindow
extends Control
## The news window of the Gift menu (PopupNews of the client): the 10 news of
## GameConfig.news, which change every NEWS_SECONDS, with their numbers and
## arrows; the cash of the player; and the promotion packs of
## GameConfig.news_packs() with their arrows. A click on the picture of a
## news or on Go to Store follows the link of the news; a click on a pack
## opens its window.

signal link_chosen(link: String)
signal pack_chosen(pack: Dictionary)
signal cash_requested
signal closed

const NEWS_SECONDS := 6.0
## The window is 50 pixels below the middle of the screen.
const OFFSET := Vector2(0, 50)
const NEWS_SCALE := 0.6
## The scales of the client's tweens: a lit number, the picture of a news and
## the card of a pack under the mouse.
const NUMBER_SCALE := 1.5
const NEWS_HOVER_SCALE := 1.1
const PACK_HOVER_SCALE := 1.02
const TWEEN_SECONDS := 0.2

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip
var _news := 0
var _packs: Array[Dictionary] = []
var _pack := 0
var _timer := Timer.new()


func _init(ui: UiLibrary, config: GameConfig, cash: int) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupNewsMC")
	add_child(_window)
	for pair: Array in [["popupTitle", "POPUP_NEWS_TITLE"], ["secHints", "POPUP_NEWS_SEC_HINTS"], ["secLatest", "POPUP_NEWS_SEC_LATEST"], ["secSpecials", "POPUP_NEWS_SPECIAL_OFFERS"]]:
		_window.set_text(pair[0], config.text(pair[1]))
	_window.set_text("txCash", str(cash))
	var more_cash := _window.clip("btnMoreCash")
	more_cash.set_text("lbl", config.text("AUX_GET_MORE_CASH"))
	more_cash.make_button(true)
	more_cash.pressed.connect(func() -> void: cash_requested.emit())
	var store := _window.clip("btnGoStore")
	store.set_text("lbl", config.text("AUX_OPEN_STORE"))
	store.make_button(true)
	store.pressed.connect(_follow_link)
	_window.button("closeButt").pressed.connect(_close)
	_window.button("btPrev").pressed.connect(func() -> void: _show_news(posmod(_news - 1, _config.news.size())))
	_window.button("btNext").pressed.connect(func() -> void: _show_news(posmod(_news + 1, _config.news.size())))
	for index in _config.news.size():
		var number := _window.clip("b%d" % (index + 1))
		if number == null:
			continue
		number.make_button()
		number.pressed.connect(_show_news.bind(index))
		number.mouse_entered.connect(_grow.bind(number, NUMBER_SCALE))
		number.mouse_exited.connect(_grow.bind(number, 1.0))
	_packs = config.news_packs()
	_window.button("btPackPrev").pressed.connect(func() -> void: _show_pack(maxi(_pack - 1, 0)))
	_window.button("btPackNext").pressed.connect(func() -> void: _show_pack(mini(_pack + 1, _packs.size() - 1)))
	_timer.wait_time = NEWS_SECONDS
	_timer.timeout.connect(func() -> void: _show_news((_news + 1) % _config.news.size()))
	add_child(_timer)
	_show_news(0)
	_show_pack(0)


func _ready() -> void:
	_window.keep_centred(OFFSET)
	_timer.start()


func _show_news(index: int) -> void:
	if _config.news.is_empty():
		return
	_news = index
	var news: Dictionary = _config.news[index]
	# The picture is a button; the mouse over it makes its holder bigger.
	var picture := _window.show_picture("foto", _ui.image(_config.localized_image(news["image"])), true, NEWS_SCALE)
	if picture != null:
		var holder := _window.clip("foto")
		picture.mouse_filter = Control.MOUSE_FILTER_STOP
		picture.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		picture.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_follow_link())
		picture.mouse_entered.connect(_grow.bind(holder, NEWS_HOVER_SCALE))
		picture.mouse_exited.connect(_grow.bind(holder, 1.0))
	_window.set_part_visible("btnGoStore", "." in news["link"])
	for number_index in _config.news.size():
		var number := _window.clip("b%d" % (number_index + 1))
		if number != null:
			number.show_frame(1 if number_index == index else 0)
			number.scale = Vector2.ONE * (NUMBER_SCALE if number_index == index else 1.0)
	if _timer.is_inside_tree():
		_timer.start()


func _show_pack(index: int) -> void:
	for child in _window.clip("pack").get_children():
		if child is UiClip:
			child.queue_free()
	_window.set_part_visible("btPackPrev", _packs.size() > 1 and index > 0)
	_window.set_part_visible("btPackNext", _packs.size() > 1 and index < _packs.size() - 1)
	if _packs.is_empty():
		return
	_pack = index
	var pack := _packs[index]
	var card := _ui.make("PackCardMC")
	card.show_picture("image", _ui.image(_config.localized_image("offer_pack_%d.png" % pack["id"])))
	card.set_text("buyLabel", _config.text("AUX_BUY_FOR"))
	var price: int = pack["cash"]
	for part_name in ["txCash", "buyLabel", "iconResources"]:
		card.set_part_visible(part_name, price != 0)
	card.set_text("txCash", str(price))
	card.make_button()
	card.take_mouse()
	card.pressed.connect(func() -> void: pack_chosen.emit(pack))
	card.mouse_entered.connect(_grow.bind(card, PACK_HOVER_SCALE))
	card.mouse_exited.connect(_grow.bind(card, 1.0))
	_window.clip("pack").add_child(card)


## The links of the client (PopupNews.onGoToStore): a store tab
## "menu.subcategory.page", the story of the gods or the quests. A news
## without a link does nothing.
func _follow_link() -> void:
	var link: String = _config.news[_news]["link"]
	if link.is_empty():
		return
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
	link_chosen.emit(link)


func _grow(node: Control, to: float) -> void:
	create_tween().tween_property(node, "scale", Vector2.ONE * to, TWEEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
