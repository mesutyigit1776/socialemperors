class_name TournamentScreen
extends Node2D
## A match of the tournament on the screen (TournamentBattle), with the
## windows of the client:
##
## 1. The map shows with both teams, under the window before the match
##    (PopupLoadingTournament). Its button starts the match.
## 2. The bar at the top (frame 6 of the bar of the client) shows the names,
##    the life of each team (red for the player, blue for the bot) and the
##    units that are left. The Withdraw button asks first, then ends the
##    match with 0 points.
## 3. At the end, the result window shows the score; its OK button gives the
##    result (closed).

signal closed(score: int, won: bool)
signal village_changed  ## A spell changed the mana or the spells; the owner saves the village.

const BAR_FRAME := 5
const STAGE_WIDTH := 760.0
const BAR_POSITION := Vector2(295.9, 50.1)
const EXIT_FROM_BOTTOM_RIGHT := Vector2(83.5, 98.0)
const EXIT_SCALE := Vector2(0.73, 0.75)
const PLAYER_BAR_COLOR := Color(1, 0, 0)
const BOT_BAR_COLOR := Color(0, 0, 1)
const BOT_PICTURE_SCALE := 1.58
const RESULT_PICTURE_SCALE := 0.7
const TOURNAMENT_ZOOM := 0.1

var battle: TournamentBattle
var _village: Village
var _ui: UiLibrary
var _config: GameConfig
var _player_name := ""
var _bot: Dictionary
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _bar: UiClip
var _bar_widths := {}  # Part path -> the scale of the full bar.
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}


## map: the tournament map, for its land. bot: an entry of GameConfig.tournament_bots.
func _init(match_battle: TournamentBattle, map: Village, bot: Dictionary, village: Village, player_name: String, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	battle = match_battle
	_village = village
	_ui = ui
	_config = config
	_bot = bot
	_player_name = player_name
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	battle.sim.spell_graphics = spell_graphics
	battle.sim.spell_uses = village.spell_uses()
	add_child(_view)
	_view.show_battle(battle.sim, config, sprites, effects, VillageView.LAND_ITEM_BASE_ID + map.skin, VillageView.village_land_frames(map.owned_land))
	_camera.position = IsoGrid.tile_to_map((TournamentBattle.PLAYER_ORIGIN + TournamentBattle.BOT_ORIGIN) / 2)
	# The client shows the whole field at zoom 0.1, below the limit of the mouse wheel.
	_camera.zoom = Vector2.ONE * TOURNAMENT_ZOOM
	add_child(_camera)
	_screen = BattleScreen.new(battle.sim, _view)
	_screen.paused = true
	add_child(_screen)
	_screen.stepped.connect(battle.update)
	battle.changed.connect(_update_bar)
	battle.ended.connect(_show_result)
	add_child(_windows)
	# The options panel of the client (music, sounds, full screen, pause).
	_windows.add_child(OptionsPanel.for_battle(_ui))


func _ready() -> void:
	var cover := _cover()
	var window := _ui.make("PopupLoadingTournamentMC")
	cover.add_child(window)
	window.position = _screen_size() / 2
	window.set_text("title", _config.text("POPUP_LOADING_TOURNAMENT_TITLE"))
	# The configuration of this project has no text for the help of this window.
	window.set_part_visible("helpText", not _config.text("POPUP_LOADING_TOURNAMENT_TEXT").begins_with("["))
	window.set_text("helpText", _config.text("POPUP_LOADING_TOURNAMENT_TEXT"))
	var start := window.clip("ok_btn")
	start.set_text("txtLabel", "Start Battle")
	start.make_button()
	start.pressed.connect(func() -> void:
		cover.queue_free()
		_start())


func _start() -> void:
	battle.start()
	_bar = _ui.make("GuiMC/barraAttackArriba")
	_bar.show_frame(BAR_FRAME)
	_bar.position = Vector2(_screen_size().x / 2 - STAGE_WIDTH / 2, 0) + BAR_POSITION
	_bar.set_text("nameText", _player_name)
	_bar.set_text("foeNameText", _bot["name"])
	var picture := TextureRect.new()
	picture.texture = _ui.image(_bot["picture"])
	picture.scale = Vector2.ONE * BOT_PICTURE_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.clip("foePic").add_child(picture)
	for pair: Array in [["playerLifeBar/bar", PLAYER_BAR_COLOR], ["foeLifeBar/bar", BOT_BAR_COLOR]]:
		var bar := _bar.clip(pair[0])
		if bar != null:
			bar.set_colour(pair[1])
			_bar_widths[pair[0]] = bar.scale.x
	_windows.add_child(_bar)
	var exit := _ui.make("GuiMC/bgBar/btnExit")
	exit.scale = EXIT_SCALE
	exit.position = _screen_size() - EXIT_FROM_BOTTOM_RIGHT
	exit.set_text("lbl", _config.text("AUX_WITHDRAW"))
	exit.make_button(true)
	exit.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTall
		_windows.add_child(TournamentAlert.new(_ui, _config, _config.text("AUX_SURE_WANT_TO_SURRENDER"), _screen_size() / 2, battle.withdraw)))
	_windows.add_child(exit)
	var buttons := UnitButtonPanel.new(battle.sim, _ui, _config)
	_screen.selection_changed.connect(buttons.show_selection)
	_windows.add_child(buttons)
	if SpellBook.is_shown(_village):
		var book := SpellBook.new(_ui, _cast_ui, _config, _village, _windows)
		book.cast_on = _cast
		book.marker_layer = _view.under_items()
		book.changed.connect(func() -> void: village_changed.emit())
		add_child(book)
	_screen.paused = false
	_update_bar()


func _update_bar() -> void:
	if _bar == null:
		return
	var text := _config.text("TOURNAMENT_UNITS_LEFT")
	_bar.set_text("playerUnitsLeftText", text.replace("#0#", str(battle.units_left(battle.player_team))))
	_bar.set_text("foeUnitsLeftText", text.replace("#0#", str(battle.units_left(battle.bot_team))))
	for pair: Array in [["playerLifeBar/bar", battle.player_team], ["foeLifeBar/bar", battle.bot_team]]:
		var bar := _bar.part(pair[0])
		if bar != null:
			bar.scale.x = _bar_widths.get(pair[0], 1.0) * battle.life_left(pair[1])


func _show_result() -> void:
	_screen.paused = true
	var cover := _cover()
	var window := _ui.make("PopupTournamentFinishedMC")
	cover.add_child(window)
	window.position = _screen_size() / 2
	var picture := TextureRect.new()
	picture.texture = _ui.image("ataque_ganado.jpg" if battle.won else "ataque_perdido.jpg")
	picture.scale = Vector2.ONE * RESULT_PICTURE_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.texture != null:
		picture.position = -picture.texture.get_size() * picture.scale / 2
	window.clip("foto").add_child(picture)
	var title := _config.text("TOURNAMENT_RESULT_WIN_TITLE" if battle.won else "TOURNAMENT_RESULT_LOSE_TITLE")
	# The configuration of this project has no text for the title of a loss.
	if title.begins_with("["):
		title = _config.text("POPUP_ATAQUE_DERROTA")
	window.set_text("txTitle", title)
	window.set_text("txInfo", _config.text("TOURNAMENT_RESULT_WIN_TEXT" if battle.won else "TOURNAMENT_RESULT_LOSE_TEXT"))
	window.set_text("lblScore", "%.2f" % battle.score())
	var ok := window.clip("ok_btn")
	ok.set_text("txtLabel", _config.text("AUX_OK"))
	ok.make_button()
	ok.pressed.connect(func() -> void: closed.emit(battle.score(), battle.won))


func _cover() -> ColorRect:
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.size = _screen_size()
	_windows.add_child(cover)
	return cover


func _screen_size() -> Vector2:
	return get_viewport_rect().size


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(battle.sim, tile, level)
