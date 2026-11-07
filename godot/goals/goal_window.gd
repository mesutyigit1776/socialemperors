class_name GoalWindow
extends Control
## The goal windows of the client: one goal (popupInfo of MissionPopup) with
## its picture, character, description, reward and progress, or the list of
## the active goals (PopupGoalList with a GoalListLine for each goal, 5 on a
## page).

## The player pressed "DO IT" for the goal; see GoalBook.hint().
signal do_it(goal: GameConfig.GoalDef)
signal closed

const LINES_ON_PAGE := 5
const LINE_GAP := 5.0
const ICON_FRAMES := 4

var _ui: UiLibrary
var _goals: GoalBook
var _config: GameConfig
var _window: UiClip
var _page := 0
var _centre_offset := Vector2.ZERO  # The point of the window that is in the middle of the screen.


func _init(ui: UiLibrary, goals: GoalBook, config: GameConfig) -> void:
	_ui = ui
	_goals = goals
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)


func show_goal(goal: GameConfig.GoalDef) -> void:
	_replace(_ui.make("popUpMissionsMC"))
	for part: String in GoalBox.HIDDEN + ["mcGoal1", "mcGoal2", "btnHelp"]:
		if part != "popupInfo":
			_window.set_part_visible(part, false)
	var info := _window.clip("popupInfo")
	# The client covers the screen with the dark background "fons"; the port has its cover.
	info.set_part_visible("fons", false)
	info.set_part_visible("btnPay", false)
	info.set_text("popupTitle", _config.text("POPUP_MISION_TITULO"))
	info.set_text("title", _goals.text(goal.title))
	info.set_text("desc", "%s\n\n%s" % [_goals.text(goal.description), _config.text("POPUP_MISION_COMPLETADO").replace("#0#", _goals.progress_text(goal))])
	info.set_text("lblReward", _config.text("AUX_RECOMPENSA") + ":")
	info.set_text("rewardDesc", str(goal.reward))
	info.set_text("btnTutorialize/lbl", _config.text("GOALS_GO"))
	info.set_text("btnGoalList/lbl", _config.text("OPEN_GOAL_LIST"))
	_add_picture(info.clip("foto"), goal.image)
	_add_picture(info.clip("ninot"), goal.character)
	_button(info.clip("btnTutorialize"), func() -> void: do_it.emit(goal))
	_button(info.clip("btnGoalList"), show_list)
	info.button("closeButt").pressed.connect(_close)
	_centre(info.position)


func show_list() -> void:
	_replace(_ui.make("PopupGoalListMC"))
	_window.set_text("lblTitle", _config.text("AUX_OBJETIVOS"))
	_window.button("btnClose").pressed.connect(_close)
	for pair: Array in [["butPrev", -1], ["butNext", 1]]:
		var step: int = pair[1]
		_button(_window.clip(pair[0]), func() -> void:
			_page += step
			_show_page())
	_page = 0
	_show_page()
	_centre(Vector2.ZERO)


func _show_page() -> void:
	var anchor := _window.clip("listAnchor")
	for child in anchor.get_children():
		if child is UiClip:
			child.queue_free()
	var goals := _goals.active_goals()
	var pages := maxi(ceili(goals.size() / float(LINES_ON_PAGE)), 1)
	_page = clampi(_page, 0, pages - 1)
	var y := 0.0
	for goal in goals.slice(_page * LINES_ON_PAGE, (_page + 1) * LINES_ON_PAGE):
		var line := _ui.make("GoalListLineMC")
		line.position.y = y
		line.set_text("title", _goals.text(goal.title))
		line.set_text("percent", _config.text("POPUP_MISION_COMPLETADO").replace("#0#", _goals.progress_text(goal)))
		line.clip("goalIcon").show_frame(goal.id % ICON_FRAMES)
		line.set_part_visible("btnPay", false)
		line.set_part_visible("btnReward", false)
		line.set_text("btnInfo/lbl", "+ " + _config.text("BTN_MORE_INFO"))
		_button(line.clip("btnInfo"), show_goal.bind(goal))
		anchor.add_child(line)
		y += line.bounds().end.y + LINE_GAP
	_window.set_part_visible("butPrev", _page > 0)
	_window.set_part_visible("butNext", _page < pages - 1)


func _replace(window: UiClip) -> void:
	if _window != null:
		_window.queue_free()
	_window = window
	add_child(_window)


func _ready() -> void:
	_place()


## Puts the point of the window at this position in the middle of the screen.
func _centre(point: Vector2) -> void:
	_centre_offset = point
	_place()


func _place() -> void:
	if is_inside_tree() and _window != null:
		_window.position = get_viewport_rect().size / 2 - _centre_offset


func _button(clip: UiClip, action: Callable) -> void:
	clip.make_button(true)
	clip.pressed.connect(action)


## The client centres the pictures of the goals on their part (getRealSizeBitmap).
func _add_picture(holder: UiClip, name: String) -> void:
	var texture := _ui.image(name) if name != "none" and not name.is_empty() else null
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.position = -texture.get_size() / 2
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)


func _close() -> void:
	closed.emit()
	queue_free()
