class_name QuestListWindow
extends Control
## The island window of the client (PopupQuestsManager): 7 pictures of the sea
## side by side, which the arrows scroll, with a button for each island of
## GameConfig.quest_order. A button shows the name, the stars that the player
## won, and a lock when the island is not open. The islands that the port does
## not have yet (see QuestIsland) also get a lock and a "not in the port" sign
## below the name, in the style of the name ribbon. The window also shows the
## quests that are left (QuestBook) and all stars won.

signal island_chosen(quest_id: String)
signal closed

const PAGE_WIDTH := 723.0
const PAGES := 7
const SCROLL_SECONDS := 1.0
## The places of the island buttons on the pictures, as in the client, in the
## order of GameConfig.quest_order.
const BUTTON_PLACES: Array[Vector2] = [
	Vector2(132, 203), Vector2(550, 246), Vector2(130, 400), Vector2(370, 545), Vector2(620, 435),
	Vector2(PAGE_WIDTH + 170, 530), Vector2(PAGE_WIDTH + 330, 318), Vector2(PAGE_WIDTH + 588, 214), Vector2(PAGE_WIDTH + 580, 507),
	Vector2(2 * PAGE_WIDTH + 280, 540), Vector2(2 * PAGE_WIDTH + 140, 270), Vector2(2 * PAGE_WIDTH + 600, 260), Vector2(2 * PAGE_WIDTH + 450, 415), Vector2(2 * PAGE_WIDTH + 620, 543),
	Vector2(2412, 541), Vector2(2779, 534), Vector2(2519, 320), Vector2(2771, 232), Vector2(3044, 250),
	Vector2(3500, 250), Vector2(3030, 500), Vector2(3250, 540), Vector2(3510, 490),
	Vector2(5 * PAGE_WIDTH + 155, 515), Vector2(5 * PAGE_WIDTH + 340, 308),
	Vector2(6 * PAGE_WIDTH + 158, 265), Vector2(6 * PAGE_WIDTH + 560, 260), Vector2(6 * PAGE_WIDTH + 285, 508),
]
## The sign of an island that the port does not have yet: the name ribbon of
## the button, smaller, in the place of the stars below the name, or above the
## name when the button is too near the bottom of the pictures.
const SIGN_SCALE := 0.85
const SIGN_BELOW := Vector2(0, 28)
const SIGN_ABOVE := Vector2(0, -26)
const PAGE_HEIGHT := 562.0
const SIGN_TEXT := "Not in the port yet"
const SIGN_FONT_SIZE := 12
const NOT_IN_PORT_ALERT := "This island is not in the port yet.\nIts quest comes in a later version."

var _book: QuestBook
var _config: GameConfig
var _window: UiClip
var _strip := Control.new()
var _page := 1
var _now: Callable


## now returns the time in seconds, for the quest limit.
func _init(ui: UiLibrary, book: QuestBook, config: GameConfig, now: Callable) -> void:
	_book = book
	_config = config
	_now = now
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupQuestsManagerMC")
	add_child(_window)

	# The client shows the pictures in bgContent, under the mask mcMask.
	var mask := Control.new()
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_part := _window.clip("mcMask")
	mask.position = mask_part.position
	mask.size = mask_part.bounds().size
	_window.add_child(mask)
	_window.move_child(mask, _window.part("bgContent").get_index())
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(_strip)
	for i in PAGES:
		var picture := TextureRect.new()
		picture.texture = ui.image("quests_manager_img_%d.jpg" % (i + 1))
		picture.position = Vector2(PAGE_WIDTH * i, 0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strip.add_child(picture)
	var islands := book.islands()
	for i in mini(islands.size(), BUTTON_PLACES.size()):
		_strip.add_child(_island_button(ui, islands[i], BUTTON_PLACES[i]))

	_window.set_part_visible("btnHelp", false)
	for name: String in ["btnPrev", "btnNext", "btnClose"]:
		_window.clip(name).make_button()
	_window.clip("btnPrev").pressed.connect(_scroll.bind(-1))
	_window.clip("btnNext").pressed.connect(_scroll.bind(1))
	_window.clip("btnClose").pressed.connect(func() -> void: closed.emit())
	_window.set_text("txtCompletedStars", "%d/%d" % [book.won_stars(), BUTTON_PLACES.size() * QuestBook.MAX_STARS])
	# The window opens on the page of the last island that the player reached.
	var current := clampi(book.current_island(), 0, mini(islands.size(), BUTTON_PLACES.size()) - 1)
	_page = int(BUTTON_PLACES[current].x / PAGE_WIDTH) + 1
	_strip.position.x = -(_page - 1) * PAGE_WIDTH
	_update_arrows()
	_update_timer()
	var clock := Timer.new()
	clock.wait_time = 1.0
	clock.autostart = true
	clock.timeout.connect(_update_timer)
	add_child(clock)


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _island_button(ui: UiLibrary, quest_id: String, place: Vector2) -> UiClip:
	var button := ui.make("NewQuestIslandButtonMC")
	button.position = place
	button.set_text("nombreIsla", QuestIsland.name_of(quest_id, _config))
	var open := _book.is_open(quest_id)
	var in_port := QuestIsland.is_in_port(quest_id)
	var level_locked := _book.is_level_locked(quest_id)
	button.clip("stars").show_frame(_book.stars(quest_id))
	button.set_part_visible("stars", not level_locked)
	button.set_part_visible("mcLevelLock", level_locked)
	button.set_part_visible("lock", not open or not in_port)
	button.set_part_visible("enterQuestButton", open and in_port)
	if not in_port:
		var below := place.y + SIGN_BELOW.y + 4 < PAGE_HEIGHT
		button.add_child(_sign(ui, button, SIGN_BELOW if below else SIGN_ABOVE))
		button.set_part_visible("stars", false)
	button.make_button()
	button.pressed.connect(func() -> void: island_chosen.emit(quest_id))
	return button


## The "not in the port" sign: a smaller copy of the name ribbon below it,
## with the text in the font of the name.
func _sign(ui: UiLibrary, button: UiClip, offset: Vector2) -> Control:
	var sign := Control.new()
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.position = offset
	sign.scale = Vector2.ONE * SIGN_SCALE
	var ribbon := TextureRect.new()
	ribbon.texture = ui.clip_image(button.sprite_id, 0)
	ribbon.position = ui.clip_origin(button.sprite_id)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(ribbon)
	var label := button.part("nombreIsla").duplicate() as Label
	label.text = SIGN_TEXT
	label.add_theme_font_size_override("font_size", SIGN_FONT_SIZE)
	sign.add_child(label)
	return sign


func _scroll(step: int) -> void:
	var page := clampi(_page + step, 1, PAGES)
	if page == _page:
		return
	_page = page
	create_tween().tween_property(_strip, "position:x", -(_page - 1) * PAGE_WIDTH, SCROLL_SECONDS) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_update_arrows()


func _update_arrows() -> void:
	_window.clip("btnPrev").modulate.a = 0.4 if _page <= 1 else 1.0
	_window.clip("btnNext").modulate.a = 0.4 if _page >= PAGES else 1.0


## The client shows the quests that are left, or the time until the next one.
func _update_timer() -> void:
	var now: int = _now.call()
	var left := _book.quests_left(now)
	if left > 0:
		_window.set_text("txtQuestTimer", "REMAINING QUESTS: %d" % left)
		return
	var seconds := _book.seconds_to_next_quest(now)
	var hours := seconds / 3600
	var text := "%02d : %02d : %02d" % [hours, seconds % 3600 / 60, seconds % 60] if hours > 0 else "%02d : %02d" % [seconds % 3600 / 60, seconds % 60]
	_window.set_text("txtQuestTimer", "NEXT QUEST IN \n" + text)
