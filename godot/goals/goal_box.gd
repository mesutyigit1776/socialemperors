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
## The host of the box (Host.goal_symbol()) is mirrored at half size, and
## the mask of the box cuts it; adjustToScreen puts them this far from the
## left edge.
const HOST_X := 49.0
const HOST_MASK_X := 75.35
const HOST_SCALE := Vector2(-0.5, 0.5)

var _clip: UiClip
var _host_area: Control
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


## The host of the box behind the icons (HostSprite).
## graphic: the imported Host.goal_symbol(), or null.
func show_host(graphic: SpriteLibrary.ItemSprite, host: Host) -> void:
	if graphic == null:
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
	var sprite := HostSprite.new(graphic, host)
	sprite.position = Vector2(HOST_X, _clip.part("mayor").position.y) - area.position
	sprite.scale = HOST_SCALE
	area.add_child(sprite)
	_host_area = area


## The client hides the host of the box while the host of the tutorial shows.
func set_host_visible(shown: bool) -> void:
	if _host_area != null:
		_host_area.visible = shown


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

