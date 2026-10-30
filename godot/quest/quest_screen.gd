class_name QuestScreen
extends Node2D
## A campaign quest on the screen: the island with the battle, and the windows
## of the client around it.
##
## 1. The map of the island shows with the army on it, under the start window
##    (QuestStartWindow). The battle waits.
## 2. The start button starts the battle with the chosen stars (started).
## 3. During the battle the bar shows the gold and experience (QuestHud). On a
##    troll island the treasure gets a mark when it opens; a click on it wins.
## 4. At the end, or after the Withdraw button and "Yes", the result window
##    shows (QuestEndWindow). Its OK button gives the result (closed).

signal started(stars: int)
signal closed(result: Dictionary)  ## The result for Village.end_quest().

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


## village: the village of the player, for the stars and the honour.
func _init(quest_battle: QuestBattle, village: Village, ui: UiLibrary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	quest = quest_battle
	_village = village
	_ui = ui
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
	_screen.paused = false


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
