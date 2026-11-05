class_name TeamWindow
extends Control
## The window in which the player chooses the team for an island with teams
## (SelectionTeamWindow of the client, quest mode). See QuestTeam for the rules.
##
## - The units of the army show 5 at a time, with the number that is left;
##   the arrows show the other pages. A click on a unit puts one in the team.
## - The team shows in 2 rows of 10 places. A click on a place takes the
##   unit out of the team.
## - OK checks the groups of the island, then that the team has a unit, and
##   asks with Yes and No when the team has fewer than 20 units. These alerts
##   use the window of the client for the team window (Alert, AlertTournamentMC).
## - The client also shows the formations of the tournaments here. They do not
##   change a quest, so the port hides them.

signal accepted(team: Dictionary)  ## Unit id -> number.
signal closed

const THUMB_SIZE := 90.0
const THUMB_MARGIN := 10.0
const THUMBS_PER_PAGE := 5
const THUMBS_AT := Vector2(-250, 10)
const PLACE_SIZE := 50.0
const PLACE_MARGIN := 8.0
const PLACE_COLUMNS := 10
const PLACES_AT := Vector2(-285, -175)
const FORMATION_TITLE := "#16"  ## The unnamed text "Formations".

var _window: UiClip
var _ui: UiLibrary
var _config: GameConfig
var _island: QuestIsland
var _choices: Array[Array]  # [unit id, number left], see QuestTeam.choices().
var _team: Array[int] = []  # The unit ids of the places, in order.
var _page := 0
var _thumbs := Control.new()
var _places := Control.new()


func _init(ui: UiLibrary, config: GameConfig, island: QuestIsland, army: Dictionary) -> void:
	_ui = ui
	_config = config
	_island = island
	_choices = QuestTeam.choices(army, config)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("SelectionTeamWindowMC")
	add_child(_window)
	_window.set_text("title_txt", config.text("POPUP_TEAM_SELECTION_TITLE"))
	_window.set_text("subtitle2_txt", config.text("POPUP_TEAM_SELECTION_SUBTITLE_2"))
	_window.set_text("ok_btn/txtLabel", "OK")
	for part in ["tourSelecBtn", "formation_buttons", "formation_txt", "formation_desc", FORMATION_TITLE]:
		_window.set_part_visible(part, false)
	_thumbs.position = THUMBS_AT
	_places.position = PLACES_AT
	for node: Control in [_thumbs, _places]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.add_child(node)
	var ok := _window.clip("ok_btn")
	ok.make_button(true)
	ok.pressed.connect(_on_ok)
	var close := _window.clip("btnClose")
	close.make_button(true)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	for pair: Array in [["left_btn", -1], ["right_btn", 1]]:
		var arrow := _window.clip(pair[0])
		arrow.make_button(true)
		arrow.pressed.connect(_turn_page.bind(pair[1]))
	_show()
	if not island.groups.is_empty():
		_show_alert.call_deferred(_requirement_text())


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _turn_page(step: int) -> void:
	var page := _page + step
	if page >= 0 and page < _page_count():
		_page = page
		_show()


func _page_count() -> int:
	return ceili(_available().size() / float(THUMBS_PER_PAGE))


## The choices with units left; the client hides the others.
func _available() -> Array[Array]:
	return _choices.filter(func(choice: Array) -> bool: return choice[1] > 0)


func _show() -> void:
	_page = clampi(_page, 0, maxi(_page_count() - 1, 0))
	for node: Control in [_thumbs, _places]:
		for child in node.get_children():
			child.queue_free()
	var shown := _available().slice(_page * THUMBS_PER_PAGE, (_page + 1) * THUMBS_PER_PAGE)
	for i in shown.size():
		var choice: Array = shown[i]
		var thumb := _thumb(choice[0], THUMB_SIZE)
		thumb.position = Vector2(i * (THUMB_SIZE + THUMB_MARGIN), 0)
		thumb.pressed.connect(_add.bind(choice))
		var count := Label.new()
		count.text = "x%d" % choice[1]
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		count.position = Vector2(4, THUMB_SIZE - 26)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(count)
		_thumbs.add_child(thumb)
	for i in _team.size():
		var place := _thumb(_team[i], PLACE_SIZE)
		place.position = Vector2(i % PLACE_COLUMNS, i / PLACE_COLUMNS) * (PLACE_SIZE + PLACE_MARGIN)
		place.pressed.connect(_remove.bind(i))
		_places.add_child(place)
	_window.set_text("subtitle1_txt", "%s: %d/%d" % [_config.text("POPUP_TEAM_SELECTION_SUBTITLE_1"), _team.size(), QuestBattle.TEAM_SIZE])
	_window.clip("left_btn").modulate.a = 1.0 if _page > 0 else 0.5
	_window.clip("right_btn").modulate.a = 1.0 if _page < _page_count() - 1 else 0.5


func _thumb(unit_id: int, side: float) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _ui.thumb(_config.get_item(unit_id).img_name)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(side, side)
	button.size = Vector2(side, side)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _add(choice: Array) -> void:
	if _team.size() >= QuestBattle.TEAM_SIZE or choice[1] <= 0:
		return
	choice[1] -= 1
	_team.append(choice[0])
	_show()


func _remove(index: int) -> void:
	var id := _team[index]
	_team.remove_at(index)
	for choice in _choices:
		if choice[0] == id:
			choice[1] += 1
	_show()


func _on_ok() -> void:
	var team := {}
	for id in _team:
		team[id] = int(team.get(id, 0)) + 1
	if not QuestTeam.meets_groups(_island, team, _config):
		_show_alert(_requirement_text())
		return
	if team.is_empty():
		_show_alert(_config.text("QUEST_TEAM_SELECTION_ALERT_1_UNIT"))
		return
	if _team.size() < QuestBattle.TEAM_SIZE:
		_show_alert(_config.text("QUEST_TEAM_SELECTION_ALERT_LESS_20_CONFIRM"), _accept.bind(team))
		return
	_accept(team)


func _accept(team: Dictionary) -> void:
	accepted.emit(team)
	queue_free()


## The text of the client that names the groups that the island asks for.
func _requirement_text() -> String:
	var text := _config.text("TEAM_SELECTION_REQUIREMENTS_MSG").replace("#0#", str(_island.group_count))
	for group in _island.groups:
		text += "- " + group.capitalize() + "\n"
	return text


## An alert with OK, or with Yes and No when on_yes is given: Yes calls on_yes.
func _show_alert(text: String, on_yes := Callable()) -> void:
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.3)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var alert := _ui.make("AlertTournamentMC")
	alert.position = _window.position
	cover.add_child(alert)
	alert.set_text("msg_txt", text)
	var asks := on_yes.is_valid()
	alert.set_part_visible("ok_btn", not asks)
	alert.set_part_visible("yes_btn", asks)
	alert.set_part_visible("no_btn", asks)
	var buttons := {"yes_btn": ["AUX_SI", on_yes], "no_btn": ["AUX_NO", Callable()]} if asks else {"ok_btn": ["AUX_OK", Callable()]}
	for part: String in buttons:
		alert.set_text(part + "/txtLabel", _config.text(buttons[part][0]))
		var button := alert.clip(part)
		button.make_button(true)
		var action: Callable = buttons[part][1]
		button.pressed.connect(func() -> void:
			cover.queue_free()
			if action.is_valid():
				action.call())
