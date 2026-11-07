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
## The parts of the box that the port does not use: the host, its animations,
## the windows (see GoalWindow) and the alert of an attack.
const HIDDEN := ["mayor", "mayorMask", "animReward", "animMission", "anim", "btnClick", "popupSelect", "popupInfo", "mcAvisoAttacking"]
const ICON_FRAMES := 4

var _clip: UiClip
var _ids := [0, 0]


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
		hit.pressed.connect(func() -> void: goal_requested.emit(_ids[index]))
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
