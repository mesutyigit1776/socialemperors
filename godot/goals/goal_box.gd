class_name GoalBox
extends Control
## The goal box of the client (MissionPopup) at the left of the village: an
## icon for each of the first two active goals, with the title of the goal
## when the mouse is over it, and the Goals button for the list. The client
## puts the icons 37 pixels from the left edge of the screen, at the height
## that its window of 600 pixels gives them.

signal goal_requested(goal_id: int)
signal list_requested

## The y of the box on the screen (MissionPopup.adjustToScreen in a 600-pixel stage).
const TOP := 825.0
const ICON_X := 37.0
const HELP_X := -30.0
## The parts of the box that the port does not use: its animations, the
## windows (see GoalWindow) and the alert of an attack. The host comes with
## show_host().
const HIDDEN := ["mayor", "mayorMask", "animReward", "animMission", "anim", "btnClick", "popupSelect", "popupInfo", "mcAvisoAttacking"]
const ICON_FRAMES := 4
## The client marks these goals with "Click here!" (NewGoalMC) until the
## player clicks the goal in the session, but not in the tutorial.
const NEW_GOAL_MARKED: Array[int] = [6, 7, 8, 9, 249, 250, 1008]
## The host of the box (GameShowHostMissionMC) is mirrored at half size, and
## the mask of the box cuts it; adjustToScreen puts them this far from the
## left edge.
const HOST_SYMBOL := "GameShowHostMissionMC"
const HOST_X := 49.0
const HOST_MASK_X := 75.35
const HOST_SCALE := Vector2(-0.5, 0.5)
## Frames (from 0) of the host: it appears ("apparait"), then waits
## ("attend1" up to "parle").
const HOST_APPEAR := Vector2i(327, 344)
const HOST_WAIT := Vector2i(0, 268)

var _clip: UiClip
var _ids := [0, 0]
var _clicked := [false, false]
var _marks: Array[UiClip] = []
## False during the tutorial, which shows no "Click here!" marks.
var marks_allowed := true


func _init(ui: UiLibrary, config: GameConfig) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip = ui.make("popUpMissionsMC")
	_clip.position = Vector2(0, TOP)
	add_child(_clip)
	for name: String in HIDDEN:
		_clip.set_part_visible(name, false)
	_clip.clip("btnHelp").position.x = HELP_X
	_clip.set_text("btnHelp/lbl", config.text("AUX_OBJETIVOS"))
	_clip.clip("btnHelp").make_button()
	_clip.clip("btnHelp").pressed.connect(func() -> void: list_requested.emit())
	for index in 2:
		var goal := _clip.clip("mcGoal%d" % (index + 1))
		goal.position.x = ICON_X
		goal.set_part_visible("txInfo", false)
		goal.set_part_visible("txInfoBG", false)
		var hit := goal.clip("hit")
		hit.make_button()
		hit.pressed.connect(_on_goal_clicked.bind(index))
		var mark := ui.make("NewGoalMC")
		mark.set_text("newGoalText", config.text("POPUP_NEW_GOAL"))
		mark.make_button()
		mark.pressed.connect(_on_goal_clicked.bind(index))
		mark.visible = false
		goal.add_child(mark)
		_marks.append(mark)
		hit.mouse_entered.connect(_show_title.bind(goal, true))
		hit.mouse_exited.connect(_show_title.bind(goal, false))
		goal.visible = false


## goals: [id, title] of the goals of the box, see GoalBook.shown_goals().
func show_goals(goals: Array) -> void:
	for index in 2:
		var goal := _clip.clip("mcGoal%d" % (index + 1))
		goal.visible = index < goals.size()
		if goal.visible:
			_ids[index] = goals[index][0]
			# MissionPopup.refreshSingleGoal: the icon is the frame id % 4.
			goal.show_frame(_ids[index] % ICON_FRAMES)
			goal.set_text("txInfo", goals[index][1])
		_marks[index].visible = goal.visible and _ids[index] in NEW_GOAL_MARKED and not _clicked[index] and marks_allowed


## The host of the box, which appears and then waits, behind the icons.
## host: the imported GameShowHostMissionMC, or null.
func show_host(host: SpriteLibrary.ItemSprite) -> void:
	if host == null:
		return
	var mask := _clip.clip("mayorMask")
	var bounds := mask.bounds()
	var area := Control.new()
	area.clip_contents = true
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.position = Vector2(HOST_MASK_X, mask.position.y) + bounds.position * mask.scale
	area.size = bounds.size * mask.scale
	_clip.add_child(area)
	_clip.move_child(area, mask.get_index())
	var sprite := HostSprite.new(host)
	sprite.position = Vector2(HOST_X, _clip.part("mayor").position.y) - area.position
	sprite.scale = HOST_SCALE
	area.add_child(sprite)


func _on_goal_clicked(index: int) -> void:
	_clicked[index] = true
	_marks[index].visible = false
	goal_requested.emit(_ids[index])


## The client shows the title over a background of the width of the text.
func _show_title(goal: UiClip, shown: bool) -> void:
	goal.set_part_visible("txInfo", shown)
	goal.set_part_visible("txInfoBG", shown)
	var label := goal.part("txInfo") as Label
	var background := goal.clip("txInfoBG")
	if shown and label != null and background != null:
		var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		var natural := background.bounds().size.x
		if natural > 0:
			background.scale.x = (width + 16) / natural
			background.position.x = label.position.x + width / 2


## Plays the appearance of the host once, then its waiting frames in a loop.
class HostSprite:
	extends Sprite2D
	const FRAME_SECONDS := 1.0 / 30.0
	var _host: SpriteLibrary.ItemSprite
	var _frame := HOST_APPEAR.x
	var _time := 0.0

	func _init(host: SpriteLibrary.ItemSprite) -> void:
		_host = host
		centered = false
		offset = host.origin
		texture = host.get_frame(_frame)

	func _process(delta: float) -> void:
		_time += delta
		if _time < FRAME_SECONDS:
			return
		_time = fmod(_time, FRAME_SECONDS)
		_frame += 1
		if _frame > HOST_WAIT.y and _frame < HOST_APPEAR.x or _frame > HOST_APPEAR.y:
			_frame = HOST_WAIT.x
		texture = _host.get_frame(_frame)
