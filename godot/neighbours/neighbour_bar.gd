class_name NeighbourBar
extends PanelContainer
## The neighbour bar of the client (FriendsWindow and FriendButton) at the
## bottom of the village, between the spell book and the HUD panel: the neighbours sorted by experience, then the host
## of the tutorial, who stands for Arthur and Guinevere. It shows SHOWN
## neighbours; the arrows move the list by one or by SHOWN. A click on a
## neighbour opens the menu with "Visit" (PopOverVisit). A neighbour whose
## buildings the player can help has a mark.

signal visit_requested(entry: Dictionary)

const SHOWN := 6
const BUTTON_SIZE := Vector2(100, 64)
## The spell book is at the bottom left, the HUD panel at the right.
const LEFT := 130
const HELP_MARK := "+ "  ## Before the name of a neighbour that the player can help.

var _entries: Array[Dictionary] = []
var _start := 0
var _row := HBoxContainer.new()
var _menu := PopupMenu.new()
var _chosen: Dictionary


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = LEFT
	offset_bottom = -6
	add_child(_row)
	_menu.add_item("Visit", 0)
	_menu.id_pressed.connect(func(_id: int) -> void: visit_requested.emit(_chosen))
	add_child(_menu)


## The entries of the bar, as the client builds them: neighbours (see
## NeighbourSource.neighbours()) sorted by experience, then the host at
## round(1.2 × the level of the player). can_assist(pid) tells whether the
## player can help the neighbour now. Each entry: {"pid", "name", "level",
## "xp", "host", "assist"}.
static func entries(neighbours: Array[Dictionary], village: Village, config: GameConfig, now: int, helped: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for neighbour in neighbours:
		result.append({"pid": neighbour["pid"], "name": neighbour["name"], "level": neighbour["level"], "xp": neighbour["xp"], "host": false,
				"assist": village.can_assist(neighbour["pid"], now) and not neighbour["pid"] in helped})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["xp"] < b["xp"])
	var host_level := mini(roundi(village.get_level() * 1.2), config.levels.size() - 1)
	result.append({"pid": host_pid(village.get_level()), "name": config.text("TUTORIAL_HOST_NAME_MALE"), "level": host_level,
			"xp": config.levels[host_level].exp_required, "host": true, "assist": false})
	return result


## The client visits one of the three villages of Arthur and Guinevere, by the level of the player.
static func host_pid(level: int) -> String:
	return NeighbourSource.ARTHUR_IDS[0 if level <= 10 else (1 if level <= 20 else 2)]


func show_entries(new_entries: Array[Dictionary]) -> void:
	_entries = new_entries
	_start = clampi(_start, 0, maxi(_entries.size() - SHOWN, 0))
	_refresh()


func _refresh() -> void:
	for child in _row.get_children():
		child.queue_free()
	_arrow("<<", -SHOWN)
	_arrow("<", -1)
	for index in range(_start, _start + SHOWN):
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		if index < _entries.size():
			var entry := _entries[index]
			button.text = "%s%s\nLevel %d" % [HELP_MARK if entry["assist"] else "", entry["name"], entry["level"]]
			button.clip_text = true
			button.tooltip_text = "%s, XP %d%s" % [entry["name"], entry["xp"], ". You can help this neighbour." if entry["assist"] else ""]
			button.pressed.connect(func() -> void:
				_chosen = entry
				_menu.popup(Rect2i(get_global_mouse_position(), Vector2i.ZERO)))
		else:
			button.text = "No neighbour"
			button.disabled = true
		_row.add_child(button)
	_arrow(">", 1)
	_arrow(">>", SHOWN)


func _arrow(text: String, step: int) -> void:
	var button := Button.new()
	button.text = text
	var next := clampi(_start + step, 0, maxi(_entries.size() - SHOWN, 0))
	button.disabled = next == _start
	button.pressed.connect(func() -> void:
		_start = next
		_refresh())
	_row.add_child(button)
