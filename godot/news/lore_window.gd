class_name LoreWindow
extends Control
## A story in pages (PopupLore of the client): a title, and a picture and a
## text on each page, with arrows. The news link "gods" opens the story of
## the gods (GODS_PAGES); the client opens it at page START_PAGE (from 0).

signal closed

const GODS_TITLE := "Gods & Colossus"  ## The client has this title in its code, not in the texts.
## [picture, text name or ""].
const GODS_PAGES: Array[Array] = [["gods_1.jpg", "GODS_1"], ["gods_2.jpg", "GODS_2"], ["gods_3.jpg", "GODS_3"], ["gods_4.jpg", ""],
		["gods_5.jpg", "GODS_4"], ["gods_6.jpg", "GODS_5"], ["gods_7.jpg", ""]]
const START_PAGE := 4
const ARROW_DISABLED_ALPHA := 0.5
const ARROW_HOVER_SCALE := 1.1

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip
var _page := START_PAGE


func _init(ui: UiLibrary, config: GameConfig) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupLoreMC")
	add_child(_window)
	_window.set_text("txTitle", GODS_TITLE)
	_window.button("btClose").pressed.connect(_close)
	for pair: Array in [["btPrev", -1], ["btNext", 1]]:
		var arrow := _window.clip(pair[0])
		arrow.make_button()
		arrow.pressed.connect(_turn.bind(pair[1]))
		arrow.mouse_entered.connect(func() -> void:
			if arrow.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
				arrow.scale = Vector2(signf(arrow.scale.x), 1) * ARROW_HOVER_SCALE)
		arrow.mouse_exited.connect(func() -> void: arrow.scale = Vector2(signf(arrow.scale.x), 1))
	_show_page()


func _ready() -> void:
	_window.keep_centred()


func _turn(step: int) -> void:
	var page := clampi(_page + step, 0, GODS_PAGES.size() - 1)
	if page != _page:
		_page = page
		_show_page()


func _show_page() -> void:
	var page: Array = GODS_PAGES[_page]
	_window.set_text("txInfo", _config.text(page[1]) if not (page[1] as String).is_empty() else "")
	_window.show_picture("mcFoto", _ui.image(page[0]))
	# An arrow that leads nowhere shows at half alpha and takes no clicks.
	for pair: Array in [["btPrev", _page > 0], ["btNext", _page < GODS_PAGES.size() - 1]]:
		var arrow := _window.clip(pair[0])
		arrow.modulate.a = 1.0 if pair[1] else ARROW_DISABLED_ALPHA
		arrow.mouse_filter = Control.MOUSE_FILTER_STOP if pair[1] else Control.MOUSE_FILTER_IGNORE
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pair[1] else Control.CURSOR_ARROW
		if not pair[1]:
			arrow.scale = Vector2(signf(arrow.scale.x), 1)


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
