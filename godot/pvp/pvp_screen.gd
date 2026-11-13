class_name PvpScreen
extends Node2D
## An attack on another player on the screen (PvpBattle), as the client shows
## it in GameMode.ASSAULT (StateAssault): frame 8 of the attack bar with the
## PvP bar (GuiPVPMC): the names and levels of the attacker and the defender,
## the time (red in the last 30 seconds), the loot that is left and that the
## attack took, its percentage, the experience and the Withdraw button 150
## pixels above the bottom of the screen; the portrait buttons of special
## units and the spell book. At the end the result window (PvpResultWindow)
## shows the result; its close button gives the result (closed).
##
## The bar is at the place of the spy screen (SpyScreen.BAR_POSITION), which
## comes before the attack with the same bar.

signal closed(result: Dictionary)  ## For Village.end_pvp_attack().
signal village_changed  ## A spell changed the mana or the spells; the owner saves the village.

const BAR_FRAME := 7  ## Frame 8 of the attack bar holds pvpHud.
const RESOURCE_FIELDS := {"g": "lblGold", "w": "lblWood", "s": "lblStone", "f": "lblFood"}
## StateAssault.adjustScreen puts Withdraw 150 pixels above the bottom of the screen.
const EXIT_FROM_BOTTOM := 150.0
## The size of the Withdraw label that the client shows in Ruffle
## (SpyScreen.grow_label), before the scale of the button in the art (0.73).
const WITHDRAW_FONT_SIZE := 21
## PVPManager colours the time red in the last 30 seconds.
const ENDING_SECONDS := 30
const TIMER_COLOUR := Color.WHITE
const ENDING_TIMER_COLOUR := Color(1, 0, 0)

var battle: PvpBattle
var _village: Village
var _config: GameConfig
var _enemy_name: String
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _ui: UiLibrary
var _bar: UiClip
var _hud: UiClip
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}
var _result_shown := false
var _enemy_level := 0


func _init(pvp: PvpBattle, map: Village, enemy_name: String, start_tile: Vector2i, village: Village, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	battle = pvp
	_village = village
	_config = config
	_enemy_name = enemy_name
	_enemy_level = map.get_level()
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	battle.sim.spell_graphics = spell_graphics
	battle.sim.spell_uses = village.spell_uses()
	add_child(_view)
	_view.show_battle(battle.sim, config, sprites, effects, VillageView.LAND_ITEM_BASE_ID + map.skin, VillageView.village_land_frames(map.owned_land), ui)
	_camera.position = IsoGrid.tile_to_map(start_tile)
	add_child(_camera)
	_screen = BattleScreen.new(battle.sim, _view)
	add_child(_screen)
	_screen.stepped.connect(func() -> void:
		battle.update()
		_update_bar())
	battle.ended.connect(_show_result)
	add_child(_windows)
	# The options panel of the client (music, sounds, full screen, pause).
	_windows.add_child(OptionsPanel.for_battle(ui))
	_ui = ui
	_bar = ui.make("GuiMC/barraAttackArriba")
	_bar.show_frame(BAR_FRAME)
	_windows.add_child(_bar)
	_hud = _bar.clip("pvpHud")
	_hud.clip("StolenResources").show_frame(1)
	_hud.set_text("lblAttackerLevel", str(village.get_level()))
	_hud.set_text("lblAttackerName", village.player_name())
	_hud.set_text("lblDefenderLevel", str(map.get_level()))
	_hud.set_text("lblDefenderName", enemy_name)
	var withdraw := _hud.clip("btnExit")
	withdraw.set_text("lbl", config.text("AUX_WITHDRAW"))
	SpyScreen.grow_label(withdraw, WITHDRAW_FONT_SIZE)
	withdraw.make_button(true)
	withdraw.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTall
		var question := ConfirmWindow.new(ui, config, config.text("AUX_SURE_WANT_TO_SURRENDER").strip_edges())
		question.confirmed.connect(func() -> void:
			battle.retreat()
			_show_result())
		_windows.add_child(question))
	var buttons := UnitButtonPanel.new(battle.sim, ui, config)
	_screen.selection_changed.connect(buttons.show_selection)
	_windows.add_child(buttons)
	if SpellBook.is_shown(village):
		var book := SpellBook.new(ui, cast_ui, config, village, _windows)
		book.cast_on = _cast
		book.marker_layer = _view.under_items()
		book.changed.connect(func() -> void: village_changed.emit())
		add_child(book)
	_update_bar()


## The map of the attack, on which other screens can show things.
func map_view() -> BattleView:
	return _view


func _ready() -> void:
	_layout()
	get_viewport().size_changed.connect(_layout)
	if battle.is_won():
		# A village without a town hall is won at once (PopupNoTownhall).
		_show_result()


func _layout() -> void:
	var screen := get_viewport_rect().size
	_bar.position = Vector2(screen.x / 2 - SpyScreen.STAGE_WIDTH / 2, 0) + SpyScreen.BAR_POSITION
	_hud.part("btnExit").position.y = screen.y - EXIT_FROM_BOTTOM - _bar.position.y - _hud.position.y


func _update_bar() -> void:
	for code: String in RESOURCE_FIELDS:
		var got := mini(int(battle.taken[code]), battle.loot[code])
		_hud.set_text("EnemyResources/" + RESOURCE_FIELDS[code], str(maxi(battle.loot[code] - got, 0)))
		_hud.set_text("StolenResources/" + RESOURCE_FIELDS[code], str(got))
	var seconds := battle.seconds_left()
	_hud.set_text("lblTimer", "%d:%02d" % [seconds / 60, seconds % 60])
	(_hud.part("lblTimer") as Label).add_theme_color_override("font_color", ENDING_TIMER_COLOUR if seconds < ENDING_SECONDS else TIMER_COLOUR)
	_hud.set_text("lblPercentage", "%d%%" % roundi(minf(battle.percentage() * 100, 100)))
	_hud.set_text("lblXP", str(battle.xp))


func _show_result() -> void:
	if _result_shown:
		return
	_result_shown = true
	_screen.paused = true
	_bar.visible = false
	var result := battle.result()
	var window := PvpResultWindow.new(_ui, _config, result, battle.is_timed_out(), battle.lost_units(), _village.pvp_honour(result["won"], result["percentage"]),
			{"name": _village.player_name(), "level": _village.get_level()}, {"name": _enemy_name, "level": _enemy_level})
	window.closed.connect(func() -> void: closed.emit(result))
	_windows.add_child(window)


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(battle.sim, tile, level)
