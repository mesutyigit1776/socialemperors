class_name PvpScreen
extends Node2D
## An attack on another player on the screen (PvpBattle), as the client shows
## it in GameMode.ASSAULT: the bar at the top with the time, the loot that is
## left and taken and its percentage (the pvpHud of the client), the portrait
## buttons of special units, the spell book and the Withdraw button. At the
## end the result window (PopupPVPFinished) shows the result, the loot, the
## experience, the honour and the units that did not come back; its OK button
## gives the result (closed). The windows use the controls of Godot; the art
## of the client's windows comes with step 5 of the roadmap.

signal closed(result: Dictionary)  ## For Village.end_pvp_attack().
signal village_changed  ## A spell changed the mana or the spells; the owner saves the village.

const RESOURCE_NAMES := {"g": "gold", "w": "wood", "s": "stone", "f": "food"}

var battle: PvpBattle
var _village: Village
var _config: GameConfig
var _enemy_name: String
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _bar := Label.new()
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}
var _result_shown := false


func _init(pvp: PvpBattle, map: Village, enemy_name: String, start_tile: Vector2i, village: Village, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	battle = pvp
	_village = village
	_config = config
	_enemy_name = enemy_name
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	battle.sim.spell_graphics = spell_graphics
	battle.sim.spell_uses = village.spell_uses()
	add_child(_view)
	_view.show_battle(battle.sim, config, sprites, effects, VillageView.LAND_ITEM_BASE_ID + map.skin, VillageView.village_land_frames(map.owned_land))
	_camera.position = IsoGrid.tile_to_map(start_tile)
	add_child(_camera)
	_screen = BattleScreen.new(battle.sim, _view)
	add_child(_screen)
	_screen.stepped.connect(func() -> void:
		battle.update()
		_update_bar())
	battle.ended.connect(_show_result)
	add_child(_windows)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_child(_bar)
	var withdraw := Button.new()
	withdraw.text = config.text("AUX_WITHDRAW").strip_edges()
	withdraw.pressed.connect(func() -> void:
		var question := ConfirmWindow.new(ui, config, config.text("AUX_SURE_WANT_TO_SURRENDER").strip_edges())
		question.confirmed.connect(func() -> void:
			battle.retreat()
			_show_result())
		_windows.add_child(question))
	row.add_child(withdraw)
	panel.add_child(row)
	_windows.add_child(panel)
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


func _ready() -> void:
	if battle.is_won():
		# A village without a town hall is won at once (PopupNoTownhall).
		_show_result()


func _update_bar() -> void:
	var left: Array[String] = []
	var taken: Array[String] = []
	for code: String in RESOURCE_NAMES:
		var got := mini(int(battle.taken[code]), battle.loot[code])
		left.append("%d %s" % [battle.loot[code] - got, RESOURCE_NAMES[code]])
		taken.append("%d" % got)
	var seconds := battle.seconds_left()
	_bar.text = "%s   %d:%02d   Left: %s   Taken: %s (%d%%)   XP +%d" % [_enemy_name, seconds / 60, seconds % 60, ", ".join(left), " / ".join(taken),
			roundi(minf(battle.percentage() * 100, 100)), battle.xp]


func _show_result() -> void:
	if _result_shown:
		return
	_result_shown = true
	_screen.paused = true
	var result := battle.result()
	var window := PanelContainer.new()
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	var key := "POPUP_ATAQUE_ACABADO_RESULTADOS_GANAS" if battle.is_won() else ("POPUP_ATAQUE_ACABADO_RESULTADOS_TIME_EXCEEDED" if battle.is_timed_out() else "POPUP_ATAQUE_ACABADO_RESULTADOS_PIERDES")
	var lines: Array[String] = [_config.text("POPUP_ATAQUE_ACABADO_TITULO").strip_edges(), _config.text(key).strip_edges()]
	var loot: Array[String] = []
	for code: String in RESOURCE_NAMES:
		loot.append("%d %s" % [result["loot"][code], RESOURCE_NAMES[code]])
	lines.append("Loot: %s (%d%%)" % [", ".join(loot), roundi(minf(result["percentage"] * 100, 100))])
	lines.append("Experience: +%d   Honour: +%d" % [result["xp"], _village.pvp_honour(result["won"], result["percentage"])])
	var lost := battle.lost_units()
	var names: Array[String] = []
	for id: int in lost:
		names.append("%s ×%d" % [_config.get_item(id).name, lost[id]])
	lines.append("Units lost: %s" % (", ".join(names) if not names.is_empty() else "none"))
	for line in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	var ok := Button.new()
	ok.text = _config.text("AUX_OK").strip_edges()
	ok.pressed.connect(func() -> void: closed.emit(result))
	column.add_child(ok)
	window.add_child(column)
	_windows.add_child(window)


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(battle.sim, tile, level)
