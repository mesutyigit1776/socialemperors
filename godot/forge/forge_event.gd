class_name ForgeEvent
extends Node
## The Island Forge in the village screen: the forge island on the map, its
## icon in the icon panel, the pictures of the items that the player finds
## (ForgeToken), and the windows. IslandForge has the rules. The owner saves
## the village on changed, and opens PvP and the forge islands on the request
## signals.
##
## As in the client (CollectGameManager.spawnIsland), the island stands in a
## free square of ISLAND_ZONE tiles near ISLAND_NEAR, on any land, while the
## event runs and a prize is left. The client adds it without a server
## command, so the save does not have it (Village.add_unsaved()).

signal changed
signal pvp_requested
signal quest_requested(quest_id: String)

const ISLAND_NEAR := Vector2i(10, 10)
const ISLAND_ZONE := 10
const ISLAND_SEARCH := 100
const ICON_SYMBOL := "easterDragon"

var forge: IslandForge
var _village: Village
var _view: VillageView
var _hud: VillageHud
var _ui: UiLibrary
var _icon_ui: UiLibrary
var _bar_ui: UiLibrary
var _hammer_ui: UiLibrary
var _config: GameConfig
var _sprites: SpriteLibrary
var _rng: RandomNumberGenerator
var _windows: Node
var _clock: Callable
var _island: Village.PlacedItem
var _icon: UiClip
var _window: ForgeWindow


## windows: the node of the windows. clock returns the time now.
func _init(island_forge: IslandForge, village: Village, view: VillageView, hud: VillageHud, ui: UiLibrary, data_dir: String, frames: FrameCache,
		config: GameConfig, sprites: SpriteLibrary, rng: RandomNumberGenerator, windows: Node, clock: Callable) -> void:
	forge = island_forge
	_village = village
	_view = view
	_hud = hud
	_ui = ui
	_config = config
	_sprites = sprites
	_rng = rng
	_windows = windows
	_clock = clock
	for pair: Array in [["ui/forge_icon", "_icon_ui"], ["ui/forge_bar", "_bar_ui"], ["ui/forge_hammer", "_hammer_ui"]]:
		if FileAccess.file_exists(data_dir.path_join(pair[0]).path_join("layout.json")):
			set(pair[1], UiLibrary.load_from(data_dir, frames, pair[0]))


func is_island(placed: Village.PlacedItem) -> bool:
	return placed != null and placed == _island


## Puts the island on the map or takes it away, and shows or removes the
## icon. show_icon is false while the tutorial hides the icon panel.
func update(now: int, show_icon: bool) -> void:
	var shown := forge.island_shown(now)
	if shown and _island == null:
		var item := _config.get_item(_config.collect_game["building"])
		var tile := _village.free_zone_near(ISLAND_NEAR, ISLAND_ZONE, ISLAND_SEARCH)
		if item != null and tile != Village.ANY_TILE:
			_island = _village.add_unsaved(item, tile)
			_view.add_placed(_island)
	elif not shown and _island != null:
		_view.remove_placed(_island)
		_village.remove_unsaved(_island)
		_island = null
	var icon_shown := show_icon and forge.running(now) and not _village.forge_rewarded() and _icon_ui != null and _icon_ui.has_symbol(ICON_SYMBOL)
	if icon_shown and _icon == null:
		_icon = _icon_ui.make(ICON_SYMBOL)
		_hud.add_icon(_icon, open_window)
	elif not icon_shown and _icon != null:
		_hud.remove_icon(_icon)
		_icon = null


## The client opens the window when the player can take a prize, in the
## village (CollectGameManager.checkPrizes).
func check_prizes() -> void:
	if forge.prize_ready() and _window == null:
		open_window()


func open_window() -> void:
	if _window != null or not _ui.has_symbol("PoupIslandForgeMC"):
		return
	_window = ForgeWindow.new(_ui, _bar_ui, _hammer_ui, _config, _sprites, forge, _clock)
	_window.changed.connect(func() -> void:
		changed.emit()
		update(_clock.call(), true))
	_window.pvp_requested.connect(func() -> void:
		_window.queue_free()
		pvp_requested.emit())
	_window.islands_requested.connect(_open_islands)
	_window.tree_exited.connect(func() -> void: _window = null)
	_windows.add_child(_window)


## The island list opens only when the player has units (loadWorldForgeIsland).
func _open_islands() -> void:
	if _village.quest_army().is_empty():
		_windows.add_child(AlertWindow.new(_ui, _config, _config.text("AVISO_VOLAR_SIN_TROPAS").strip_edges()))
		return
	if _window != null:
		_window.queue_free()
	var islands := ForgeIslandsWindow.new(_ui, _config, forge, _village, _clock)
	islands.island_chosen.connect(func(quest_id: String) -> void:
		if not forge.quest_open(quest_id, _clock.call()):
			_windows.add_child(AlertWindow.new(_ui, _config, _config.text("AVISO_QUEST_BLOQUEADA").strip_edges()))
			return
		islands.queue_free()
		forge.quest_started(_clock.call())
		changed.emit()
		quest_requested.emit(quest_id))
	_windows.add_child(islands)


## The village events that give items: a collect of a mill or mine.
func on_village_event(kind: VillageEvent.Kind, data: Dictionary) -> void:
	if kind == VillageEvent.Kind.COLLECTED and forge.collected(int(data.get("minutes", 0)), _clock.call(), _rng):
		_drop(IslandForge.COLLECT, _view, data["tile"])
		changed.emit()
		check_prizes()


## Enemy units that die in the battle give items: in the village (pvp
## false) or in an attack on another player. view shows the battle.
func watch_battle(sim: BattleSim, view: Node2D, pvp: bool) -> void:
	sim.died.connect(func(item: BattleFighter, _killer: BattleFighter) -> void:
		if item.team != BattleFighter.Team.ENEMY or item.summoned or not forge.enemy_killed(item.def, pvp, _clock.call(), _rng):
			return
		_drop(IslandForge.PVP if pvp else IslandForge.TROLLS, view, item.tile)
		changed.emit())


## The end of a forge island: a win with more stars gives an item. old_stars
## is the rank before the quest.
func quest_ended(result: Dictionary, old_stars: int) -> void:
	if int(result["win"]) == 1 and forge.quest_won(str(result["quest_id"]), int(result["difficulty"]), old_stars, _clock.call()):
		changed.emit()


func _drop(item_id: int, view: Node2D, tile: Vector2i) -> void:
	var picture := _ui.image("IslandForge/%d.png" % item_id)
	if picture != null and is_instance_valid(view):
		view.add_child(ForgeToken.new(picture, tile, _rng))
