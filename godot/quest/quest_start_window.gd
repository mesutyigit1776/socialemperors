class_name QuestStartWindow
extends Control
## The start window of a quest (PopupLoadingQuest of the client): the picture
## and the goal of the island, and the stars of the difficulty. The player can
## choose at most one star more than they won on the island; the window shows
## why a star is locked when the mouse is over it.

signal started(stars: int)

## The picture of the troll and civilisation islands is frame 4 of "images".
const PICTURE_FRAME := 3
const PICTURE := "TESORO.jpg"
## Frame 2 of a star shows it chosen.
const STAR_ON := 1
const STAR_OFF := 0

var _window: UiClip
var _config: GameConfig
var _stars := 1
var _max_stars := 1


## rank: the stars that the player won on the island; max_stars: see QuestBook.max_stars().
func _init(ui: UiLibrary, config: GameConfig, island: QuestIsland, rank: int, max_stars: int) -> void:
	_config = config
	_max_stars = max_stars
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupLoadingQuestMC")
	add_child(_window)
	_window.set_text("title", config.text("POPUP_STARTING_QUEST_TITLE"))
	_window.set_text("desc1", config.text(island.description_text))
	_window.set_text("difficultyText", config.text("POPUP_QUEST_ELIGE_DIFICULTAD"))
	_window.set_part_visible("loadingText", false)
	_window.set_part_visible("lockedPopup", false)
	_window.clip("images").show_frame(PICTURE_FRAME)
	var picture := TextureRect.new()
	picture.texture = ui.image(PICTURE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The client centres the pictures of its windows on their container.
	if picture.texture != null:
		picture.position = -picture.texture.get_size() / 2
	_window.clip("images/image").add_child(picture)
	# The client chooses one star more than the player won, up to 3.
	_stars = mini(rank + 1, QuestBook.MAX_STARS) if rank > 0 else 1
	for star in range(1, QuestBook.MAX_STARS + 1):
		var clip := _window.clip("star%d" % star)
		clip.make_button()
		clip.pressed.connect(_choose.bind(star))
		clip.mouse_entered.connect(_show_lock.bind(star))
		clip.mouse_exited.connect(_show_stars.bind(_stars))
	_show_stars(_stars)
	var start := _window.clip("btnStartBattle")
	start.make_button(true)
	start.pressed.connect(func() -> void: started.emit(_stars))


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _choose(star: int) -> void:
	if star <= _max_stars:
		_stars = star
	_show_stars(_stars)


func _show_stars(count: int) -> void:
	_window.set_part_visible("lockedPopup", false)
	for star in range(1, QuestBook.MAX_STARS + 1):
		_window.clip("star%d" % star).show_frame(STAR_ON if star <= count else STAR_OFF)


## A locked star shows what the player must win first; another star shows the stars up to it.
func _show_lock(star: int) -> void:
	if star <= _max_stars:
		_show_stars(star)
		return
	var popup := _window.clip("lockedPopup")
	popup.position.x = _window.clip("star%d" % star).position.x
	popup.visible = true
	var needed := _config.text("POPUP_QUEST_ESTRELLA_%d" % (star - 1))
	_window.set_text("lockedPopup/txDesc", _config.text("POPUP_QUEST_COMPLETAR").replace("#0#", needed))
