class_name QuestScreen
extends Node2D
## A campaign quest on the screen: the island with the battle, and the windows
## of the client around it.
##
## 1. The map of the island shows with the army on it, under the start window
##    (QuestStartWindow). The battle waits.
## 2. The start button starts the battle with the chosen stars (started).
## 3. During the battle the bar shows the gold and experience (QuestHud), and
##    the player can cast spells (SpellBook). On a troll island the treasure
##    gets a mark when it opens; a click on it wins.
## 4. At the end, or after the Withdraw button and "Yes", the result window
##    shows (QuestEndWindow). Its OK button gives the result (closed).

signal started(stars: int)
signal closed(result: Dictionary)  ## The result for Village.end_quest().
signal village_changed  ## A spell or mana changed the village; the owner saves it.

const TREASURE_RESOURCE := "g"  ## The mark of the treasure has the color of gold.
## The client fills the screen behind a quest island with this blue, which is
## the sea around the island.
const SEA_COLOR := Color8(0x2e, 0x94, 0xe6)

var quest: QuestBattle
var _village: Village
var _ui: UiLibrary
var _config: GameConfig
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _hud: QuestHud
var _end_window: QuestEndWindow
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}  # Spell id -> BattleSpell of this battle.


## village: the village of the player, for the stars, the honour and the spells.
## cast_ui and spell_graphics: the banner of a cast and how the spell graphics
## play, see SpellBook and BattleSpell.read_graphics().
func _init(quest_battle: QuestBattle, village: Village, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	quest = quest_battle
	_village = village
	_ui = ui
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	_config = config
	var island := quest.island
	add_child(_view)
	_view.show_battle(quest.sim, config, sprites, effects, island.land_item, island.land_frames())
	_camera.position = IsoGrid.tile_to_map(island.start_tile)
	add_child(_camera)
	# After the camera, so that it gets the mouse first: a selection box does not move the map.
	_screen = BattleScreen.new(quest.sim, _view)
	_screen.paused = true
	add_child(_screen)
	_screen.stepped.connect(quest.update)
	_screen.item_clicked.connect(func(item: BattleFighter) -> void: quest.collect(item))
	quest.treasure_opened.connect(_on_treasure_opened)
	quest.ended.connect(_on_ended)
	add_child(_windows)
	var rank := village.quest_rank(island.id)
	var start_window := QuestStartWindow.new(ui, config, island, rank, QuestBook.new(village, config).max_stars(island.id))
	start_window.started.connect(_on_started.bind(start_window))
	_windows.add_child(start_window)


func _enter_tree() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOR)


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))


func _on_started(stars: int, start_window: QuestStartWindow) -> void:
	start_window.queue_free()
	quest.start(stars)
	started.emit(stars)
	_hud = QuestHud.new(_ui, _config, quest)
	_hud.withdraw_requested.connect(_on_withdraw_requested)
	_windows.add_child(_hud)
	if SpellBook.is_shown(_village):
		# After the battle screen, so that it gets the mouse first while the player aims.
		var book := SpellBook.new(_ui, _cast_ui, _config, _village, _windows)
		book.cast_on = _cast
		book.mark = _mark
		book.marker_layer = _view.under_items()
		book.changed.connect(func() -> void: village_changed.emit())
		add_child(book)
	_screen.paused = false


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(quest.sim, tile, level)


## The items of team on the area tiles from tile to the left and up glow.
func _mark(tile: Variant, area: int, team: Variant) -> void:
	var marked: Array[BattleFighter] = []
	if tile != null and team != null:
		for y in area:
			for x in area:
				var item := quest.sim.fighter_at(tile - Vector2i(x, y))
				if item != null and item.team == team and not item in marked:
					marked.append(item)
	_view.show_marked(marked)


## The client moves the view to the treasure and marks it.
func _on_treasure_opened() -> void:
	var treasure: BattleFighter = quest.sim.fighters.filter(quest.is_treasure).front()
	_view.show_collectable(treasure, TREASURE_RESOURCE)
	create_tween().tween_property(_camera, "position", treasure.position, 1.5).set_trans(Tween.TRANS_SINE)


func _on_ended() -> void:
	_screen.paused = true
	_show_result(true)


func _on_withdraw_requested() -> void:
	if _end_window != null:
		return
	_screen.paused = true
	_end_window = _new_end_window()
	_end_window.show_question(quest.gold, quest.xp)
	_end_window.withdraw_cancelled.connect(func() -> void:
		_end_window.queue_free()
		_end_window = null
		_screen.paused = false)
	_end_window.withdraw_confirmed.connect(func() -> void:
		quest.retreat()
		_show_result(false))


func _show_result(finished: bool) -> void:
	if _end_window == null:
		_end_window = _new_end_window()
	var result := quest.result()
	var won := quest.is_won()
	_end_window.show_result(finished, won, quest.gold, quest.xp, _village.quest_honour(quest.island.id, quest.stars, won), quest.lost_units())
	_end_window.confirmed.connect(func() -> void: closed.emit(result))


func _new_end_window() -> QuestEndWindow:
	var window := QuestEndWindow.new(_ui, _config)
	_windows.add_child(window)
	return window
