class_name TournamentWindow
extends Control
## The weekly tournament of the port: a match against each bot of the
## configuration. The client gets its tournament windows from the server,
## with the other players of the week, the ranking and the prizes; the port
## has none of these (the decision of the owner), so this window is its own:
## the picture of the tournament, the team, and for each bot its picture,
## its name, the score of the last match in this session and a Start button.

signal team_requested
signal match_requested(bot: int)  ## The index in GameConfig.tournament_bots.
signal closed

const WIDTH := 560.0
const ROW_HEIGHT := 92.0
const BOT_PICTURE := 72.0
const NO_PRIZES := "A tournament of the port: the matches against the bots, without a ranking and without prizes. The original game ranked the players of the week on its server."

var _config: GameConfig


## places: the places of the team (see Village.attack_team()); scores: bot
## index -> score of the last match in this session.
func _init(ui: UiLibrary, config: GameConfig, places: Array[int], formation: int, scores: Dictionary) -> void:
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	# A CenterContainer keeps the panel in the middle after a change of the window size or of UiScale.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	centre.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var picture := TextureRect.new()
	picture.texture = ui.image("tournament_weekly_gold.jpg")
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	column.add_child(picture)
	var note := Label.new()
	note.text = NO_PRIZES
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(WIDTH, 0)
	column.add_child(note)
	var team_row := HBoxContainer.new()
	var team_text := Label.new()
	var count := places.filter(func(id: int) -> bool: return id != 0).size()
	team_text.text = "%s: %d/%d   %s" % [config.text("POPUP_TEAM_SELECTION_SUBTITLE_1"), count, QuestBattle.TEAM_SIZE, config.text(config.tournament_formations[formation][0]) if formation < config.tournament_formations.size() else ""]
	team_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_row.add_child(team_text)
	var team_button := Button.new()
	team_button.text = config.text("POPUP_TEAM_SELECTION_TITLE")
	team_button.pressed.connect(func() -> void: team_requested.emit())
	team_row.add_child(team_button)
	column.add_child(team_row)
	for i in config.tournament_bots.size():
		column.add_child(_bot_row(ui, i, scores, count > 0))
	var close := Button.new()
	close.text = config.text("AUX_CLOSE") if config.text("AUX_CLOSE") != "AUX_CLOSE" else "Close"
	close.pressed.connect(func() -> void: closed.emit())
	column.add_child(close)


func _bot_row(ui: UiLibrary, index: int, scores: Dictionary, has_team: bool) -> Control:
	var bot: Dictionary = _config.tournament_bots[index]
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIDTH, ROW_HEIGHT)
	var picture := TextureRect.new()
	picture.texture = ui.image(bot["picture"])
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(BOT_PICTURE, BOT_PICTURE)
	row.add_child(picture)
	var name_label := Label.new()
	name_label.text = bot["name"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var result := Label.new()
	if scores.has(index):
		var entry: Array = scores[index]
		result.text = "%s  +%dpts." % [_config.text("POPUP_ATAQUE_VICTORIA" if entry[1] else "POPUP_ATAQUE_DERROTA"), entry[0]]
	else:
		result.text = _config.text("TOURNAMENT_RESULTS_MRESULT_PENDING")
	row.add_child(result)
	var start := Button.new()
	start.text = _config.text("AUX_START")
	start.disabled = not has_team
	start.pressed.connect(func() -> void: match_requested.emit(index))
	row.add_child(start)
	return row
