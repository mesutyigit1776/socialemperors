class_name QuestEndWindow
extends Control
## The result window of a quest (PopupQuestFinished of the client).
##
## - During the battle, the Withdraw button opens it with the question whether
##   the player wants to end the battle (show_question()). "No" closes it.
## - At the end, and after "Yes", it shows the gold, the experience and the
##   honour, and the units that the player lost under the second tab
##   (show_result()). The client then offers to share the result on Facebook;
##   the port has no sharing, so it shows the OK button at once, as the client
##   does after the player skips the sharing.

signal withdraw_confirmed
signal withdraw_cancelled
signal confirmed  ## The player closed the result.

## Pictures of the results in the client.
const WIN_PICTURE := "ataque_ganado.jpg"
const LOSS_PICTURE := "ataque_perdido.jpg"
const UNFINISHED_PICTURE := "pop_up5_sueno2.jpg"
## Lost units: up to MAX_PORTRAITS portraits, in rows of PORTRAITS_PER_ROW, or
## twice as large in rows of BIG_PORTRAITS_PER_ROW when they are few.
const MAX_PORTRAITS := 30
const PORTRAITS_PER_ROW := 10
const BIG_PORTRAITS_PER_ROW := 6
const PORTRAIT_STEP := Vector2(55, 75)
const THUMB_SIZE := Vector2(45, 45)

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip
var _picture := TextureRect.new()
var _lost_kinds := 0


func _init(ui: UiLibrary, config: GameConfig) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupQuestFinishedMC")
	add_child(_window)
	_window.set_text("popupTitle", config.text("POPUP_QUESTEND_TITLE"))
	_window.set_text("header1", config.text("POPUP_QUESTEND_HEADER_1"))
	_window.set_text("tfNoCasualties", config.text("POPUP_QUESTEND_NO_CASUALTIES"))
	_window.set_text("btnResults/lbl", config.text("POPUP_QUESTEND_BUT_RESULTS"))
	_window.set_text("btnUnitsSaved/lbl", config.text("POPUP_QUESTEND_BUT_USAVED"))
	for name: String in ["savingResults", "message1", "message2", "btnResults", "btnUnitsSaved", "tfNoCasualties", "honorPoints"]:
		_window.set_part_visible(name, false)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.clip("images/image").add_child(_picture)
	var yes := _window.clip("message2/yesBtn")
	var no := _window.clip("message2/noBtn")
	for button: UiClip in [yes, no, _window.clip("message1/okButton"), _window.clip("btnResults"), _window.clip("btnUnitsSaved")]:
		button.make_button()
	yes.pressed.connect(func() -> void: withdraw_confirmed.emit())
	no.pressed.connect(func() -> void: withdraw_cancelled.emit())
	_window.clip("message1/okButton").pressed.connect(func() -> void: confirmed.emit())
	_window.clip("btnResults").pressed.connect(_show_tab.bind(true))
	_window.clip("btnUnitsSaved").pressed.connect(_show_tab.bind(false))


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


## The question of the Withdraw button, with the gold and experience so far.
func show_question(gold: int, xp: int) -> void:
	_show_amounts(gold, xp)
	_show_picture(UNFINISHED_PICTURE, "POPUP_QUESTEND_UNFINISHED", "")
	_window.set_text("message2/lbl", _config.text("POPUP_QUESTEND_MESSAGE2"))
	_window.set_part_visible("message2", true)


## The result. finished: the quest ended with a win or a loss, not with the
## Withdraw button. lost: unit id -> number of units that did not come back.
func show_result(finished: bool, won: bool, gold: int, xp: int, honour: int, lost: Dictionary) -> void:
	_show_amounts(gold, xp)
	_window.set_part_visible("message2", false)
	_window.set_text("honorPoints", str(honour))
	_window.set_part_visible("honorPoints", true)
	if finished:
		if won:
			_show_picture(WIN_PICTURE, "", "POPUP_QUESTEND_WIN")
		else:
			_show_picture(LOSS_PICTURE, "", "POPUP_QUESTEND_LOSE")
		_window.set_part_visible("btnResults", true)
		_window.set_part_visible("btnUnitsSaved", true)
		_show_portraits(lost)
		# The client shows neither tab until the player chooses one.
		_window.clip("btnResults").show_frame(0)
		_window.clip("btnUnitsSaved").show_frame(1)
		_window.set_part_visible("images", false)
		_window.set_part_visible("portraits_mc", false)
	_window.set_text("message1/lbl", _config.text("POPUP_QUESTEND_MESSAGE1_WIN" if won else "POPUP_QUESTEND_MESSAGE1_LOSE"))
	_window.set_part_visible("message1", true)
	_window.set_part_visible("message1/yesBtn", false)
	_window.set_part_visible("message1/noBtn", false)


func _show_amounts(gold: int, xp: int) -> void:
	_window.set_text("goldGained", str(gold))
	_window.set_text("xpGained", str(xp))


func _show_picture(picture: String, first_text: String, second_text: String) -> void:
	_picture.texture = _ui.image(picture)
	# The client centres the pictures of its windows on their container.
	if _picture.texture != null:
		_picture.position = -_picture.texture.get_size() / 2
	_window.set_part_visible("images/msg1", not first_text.is_empty())
	_window.set_part_visible("images/msg2", not second_text.is_empty())
	_window.set_text("images/msg1", _config.text(first_text) if not first_text.is_empty() else "")
	_window.set_text("images/msg2", _config.text(second_text) if not second_text.is_empty() else "")


func _show_tab(results: bool) -> void:
	_window.clip("btnResults").show_frame(0 if results else 1)
	_window.clip("btnUnitsSaved").show_frame(1 if results else 0)
	_window.set_part_visible("images", results)
	_window.set_part_visible("portraits_mc", not results)
	_window.set_part_visible("tfNoCasualties", not results and _lost_kinds == 0)


## A portrait of each kind of lost unit with the number.
func _show_portraits(lost: Dictionary) -> void:
	var box := _window.clip("portraits_mc")
	var ids := lost.keys()
	_lost_kinds = ids.size()
	ids.sort()
	var big := ids.size() <= PORTRAITS_PER_ROW
	var per_row := BIG_PORTRAITS_PER_ROW if big else PORTRAITS_PER_ROW
	var scale_factor := 2.0 if big else 1.0
	for i in mini(ids.size(), MAX_PORTRAITS):
		var portrait := _ui.make("PortraitAssaultMC")
		portrait.position = Vector2(i % per_row, i / per_row) * PORTRAIT_STEP * scale_factor
		portrait.scale = Vector2.ONE * scale_factor
		portrait.set_text("numUnits", str(lost[ids[i]]))
		var item := _config.get_item(ids[i])
		var thumb := TextureRect.new()
		thumb.texture = _ui.thumb(item.img_name) if item != null else null
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.size = THUMB_SIZE
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var image := portrait.clip("image")
		if image != null:
			image.add_child(thumb)
		box.add_child(portrait)
