extends Node2D
## Loads the imported data and shows a village.
##
## Command line options (after "--"):
##   --data <dir>          folder that importer/import_assets.py wrote
##                         (default: the SE_DATA_DIR environment variable, then user://imported)
##   --village <file>      village save (default: <data>/villages/initial.json)
##   --screenshot <png>    save the first frames as an image and quit; used for checks
##   --battle <file>       try a battle on the map of a save, for example a quest
##                         map, with the units of the village; see BattleScreen
##   --quest <id>          open the start window of the quest island, as a click
##                         in the island window does; used for checks
##   --survival <map id>   go to a survival map, or with "window" open the
##                         survival window; used for checks
##   --tournament <bot>    play the match against the bot with this index (0 to
##                         2), or with "window" open the tournament window;
##                         used for checks
##   --village-attack <kind>  an attack (siege, stampede, army or bandits) whose
##                         wait is over comes to the village; used for checks
##   --town <index>        start in this town of the save: 0 (default) or 1,
##                         the troll town; used for checks

## The windows of the quests are over the village bar and the battle bar. The
## spell book and its windows of the village are over the map, under them.
const WINDOW_LAYER := 10
const SPELL_LAYER := 5
const SURVIVAL_LEVEL := 20  ## MIN_LEVEL_SURVIVAL of the client.
const TOURNAMENT_LEVEL := 15  ## MIN_LEVEL_TOURNAMENT of the client.

var _options: Dictionary = {}
var _config: GameConfig
var _sprites: SpriteLibrary
var _village: Village
var _village_path: String
var _view: VillageView
var _hud: VillageHud
var _store: Store
var _store_key := []  # Level and rotation period of the build menu; it changes with them.
var _selected: Village.PlacedItem  # The item that the player clicked on the map, or null.
var _orders: UnitOrders
var _rng := RandomNumberGenerator.new()  # Kinds of the deposits that grow again, places of new animals, idle units, finds, Soul Mixer.
var _specials: SpecialActions
var _panel := SpecialActions.View.NONE  # What the action panel of the HUD shows.
var _placing_stored := false  # The item that the player places comes from the item store.
var _data_dir: String
var _camera: MapCamera
var _ui: UiLibrary  # The windows of the client; loaded with the village, or when the player opens the quests.
var _cast_ui: UiLibrary  # The banner of a cast spell.
var _spell_graphics: Dictionary  # How the spell graphics play, see BattleSpell.read_graphics().
var _effects: SpriteLibrary  # The shots, effects and spells of battles.
var _spell_layer := CanvasLayer.new()
var _spell_book: SpellBook
var _windows := CanvasLayer.new()  # The windows of the quests, over the village bar.
var _quest_screen: QuestScreen
var _survival_screen: SurvivalScreen
var _tournament_screen: TournamentScreen
var _tournament_scores := {}  # Bot index -> [score, won] of the last match in this session.
var _enemies: VillageEnemies  # The idle enemies and the attacks of the village, see VillageAttacks.
var _village_fight: VillageBattleScreen  # A fight in the village, or null.
var _town_quests: TownQuests  # The quest in the town, see TownQuestBook.
var _daily_bonus: Dictionary = {}  # Village.start_daily_bonus() until the window shows.
var _unit_collections: UnitCollections  # The count of the unit list, from the load of the town.
var _known_level := 0  # The level for which the attacks of a new level came, see _save().
var _frames := FrameCache.new()  # The drawn frames of the map and the windows.
## The client loads the map again after a use of the Time Machine or the
## Weather Machine; the port then starts this scene again (_reload_map()).
## The options that open a quest, a battle or a screenshot apply only to the
## first start. The message of the change shows after the new start.
static var _reload_message := ""
static var _reloaded := false
## The counts of the goals in this session, which stay when the scene starts again; see GoalBook.
static var _goal_steps := {}
## The town of the save that the scene shows; the World window changes it (_travel()).
static var _town := 0
var _goals: GoalBook
var _tutorial: Tutorial
var _tutorial_box: TutorialBox
var _goal_window: GoalWindow
var _goal_done := false  # A goal was completed since the last save, see _record().
var _group: Array[Village.PlacedItem] = []  # Units of the player selected together (double click or box).
var _last_click: Village.PlacedItem  # For the double click.
var _last_click_msec := 0
## The other players, see NeighbourSource.
var _neighbours: NeighbourSource
var _neighbour_bar: NeighbourBar
## The neighbours that the player visited in this session: the client lets the
## player help each neighbour once in a session (arFriendsAssisted).
static var _visited := {}
var _visit: VisitScreen
var _spy: SpyScreen
var _enemy: Dictionary = {}  # The enemy of the spy screen: {"pid", "village", "loot"}.
var _pvp_screen: PvpScreen
const DOUBLE_CLICK_MSEC := 1000
## The time of a construction in the client: build_time of the item, which is
## 0 for all items of the configuration, so 10 seconds.
const CONSTRUCTION_SECONDS := 10.0
## The tutorial builds its farm in 3 seconds; the client shortens all
## constructions of the tutorial to a third.
const TUTORIAL_FARM := 10
const TUTORIAL_FARM_SECONDS := 3.0
const TUTORIAL_PAN_SECONDS := 1.4
const SUBCAT_FARM := 122
const SUBCAT_RANCH := 123
## The graphics of the shield in the HUD (ShieldDisplay of the client).
const FIRST_OFFER_ICON := "viralFirstOffer"  ## The symbol of the icon, see FirstOfferButton of the client.
const SHIELD_ENABLED := "shieldEnabled"
const SHIELD_DISABLED := "shieldDisabled"
const MAX_GROUP := 20  ## MAX_SELECTED_OBJECTS of the client.
const GROUP_RINGS := 6


func _ready() -> void:
	_options = _parse_options(OS.get_cmdline_user_args())
	if _reloaded:
		for key: String in _options.keys():
			if not key in ["data", "village"]:
				_options.erase(key)
	var data_dir: String = _options.get("data", OS.get_environment("SE_DATA_DIR"))
	if data_dir.is_empty():
		data_dir = "user://imported"
	_data_dir = data_dir
	SoundPlayer.load_from(data_dir)
	add_child(_frames)
	_village_path = _options.get("village", data_dir.path_join("villages/initial.json"))
	if _options.has("town"):
		_town = int(_options["town"])

	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	_store = Store.load_from_file(data_dir.path_join("shop.json"), _config) if _config != null else null
	_village = Village.load_from_file(_village_path, _config, _town) if _store != null else null
	if _village != null:
		_neighbours = NeighbourSource.load_from(data_dir.path_join("neighbours"), _config)
		_village.neighbour_ids.assign(_neighbours.neighbours(_village.player_id()).map(func(entry: Dictionary) -> String: return entry["pid"]))
	# The HUD of the village and the windows use the art of the client.
	if _village != null and not _options.has("battle"):
		_ui = UiLibrary.load_from(data_dir, _frames)
	if _village == null or (_ui == null and not _options.has("battle")):
		_show_message("Cannot start. Import the game files first; see godot/README.md.\nData folder: %s" % ProjectSettings.globalize_path(data_dir))
	elif _options.has("battle"):
		_sprites = SpriteLibrary.new(data_dir, _frames)
		_start_battle(_options["battle"], SpriteLibrary.new(data_dir, _frames, "fx"))
	else:
		_sprites = SpriteLibrary.new(data_dir, _frames)
		_view = VillageView.new()
		add_child(_view)
		_view.effects = SpriteLibrary.new(data_dir, _frames, "fx")
		_view.ui = _ui
		_view.fire_graphic = _view.effects.get_sprite(FireSprite.SYMBOL)
		_view.fire_flames = FireSprite.read_flames(data_dir)
		_view.show_village(_village, _config, _sprites)
		_view.placement_confirmed.connect(_on_placement_confirmed)
		_view.move_confirmed.connect(_on_move_confirmed)
		_view.map_clicked.connect(_on_map_clicked)
		_view.units_boxed.connect(_on_units_boxed)
		_specials = SpecialActions.new(_village, _config, _rng)
		_goals = GoalBook.new(_village, _config, _goal_steps)
		_tutorial = Tutorial.new(_village, _config)
		_village.happened.connect(_on_village_event)
		_unit_collections = UnitCollections.new(_config, _village)
		_orders = UnitOrders.new(_village, _view, _config, _rng)
		_orders.village_changed.connect(_on_units_changed)
		_orders.order_failed.connect(func(text: String) -> void: _hud.show_message(text))
		add_child(_orders)
		_camera = MapCamera.new()
		_camera.position = _start_position(_village)
		_camera.zoomed.connect(func() -> void:
			_record(VillageEvent.Kind.ZOOMED, {})
			_hud.show_zoom(_camera.zoom.x))
		add_child(_camera)
		# The controls that the port makes itself get the fonts and colours of
		# the client. A theme of a node does not pass through the canvas
		# layers of the HUD and the windows, so it goes into the default theme.
		ThemeDB.get_default_theme().merge_with(ClientTheme.make(_ui))
		_hud = VillageHud.new(_ui, _config)
		_hud.store.item_selected.connect(_on_item_selected)
		var panel := _hud.selection
		panel.move_requested.connect(_on_move_requested)
		panel.sell_confirmed.connect(_on_sell_confirmed)
		panel.rotate_requested.connect(_on_rotate_requested)
		panel.collect_requested.connect(func() -> void: _collect(_selected))
		panel.hurry_requested.connect(func() -> void: _collect(_selected, true))
		panel.work_time_chosen.connect(_on_work_time_chosen)
		panel.train_requested.connect(_on_train_requested)
		panel.speed_up_requested.connect(_on_speed_up_requested)
		panel.unqueue_requested.connect(_on_unqueue_requested)
		panel.unit_out_requested.connect(_on_unit_out_requested)
		panel.warehouse_unit_out_requested.connect(_on_warehouse_unit_out_requested)
		panel.warehouse_slot_requested.connect(_on_warehouse_slot_requested)
		panel.action_requested.connect(_on_action_requested)
		panel.store_requested.connect(_on_store_requested)
		_hud.tool_cancelled.connect(_cancel_tool)
		_hud.zoom_requested.connect(_camera.zoom_to)
		_hud.collections_requested.connect(func() -> void:
			# The client has the collections only in the human town.
			if _village.race != "h":
				_hud.show_message(_config.text("AVISO_COLECCION_FACCION").strip_edges())
				return
			_show_panel(SpecialActions.View.COLLECTIONS)
			_record(VillageEvent.Kind.WINDOW_OPENED, {"window": "popups.popupCollections"}))
		_hud.packs_requested.connect(func() -> void: _show_panel(SpecialActions.View.PACKS))
		_hud.rename_requested.connect(_on_rename_requested)
		_hud.selection_tool_requested.connect(_start_selection_tool)
		_hud.goal_requested.connect(func(id: int) -> void: _open_goal(id))
		_hud.stored_items_requested.connect(func() -> void: _show_panel(SpecialActions.View.STORE))
		_hud.quests_requested.connect(_open_quests)
		_hud.survival_requested.connect(_open_survival)
		_hud.tournament_requested.connect(_open_tournament)
		_hud.pvp_requested.connect(_open_pvp)
		_hud.towns_requested.connect(_open_towns)
		_hud.first_offer_requested.connect(_open_first_offer)
		_hud.units_requested.connect(_open_unit_list)
		add_child(_hud)
		_hud.show_goal_host(_view.effects.get_sprite(GoalBox.HOST_SYMBOL))
		_hud.set_shield_graphics(_view.effects.get_sprite(SHIELD_ENABLED), _view.effects.get_sprite(SHIELD_DISABLED))
		_hud.show_zoom(_camera.zoom.x)
		_neighbour_bar = NeighbourBar.new(_ui, _config)
		_neighbour_bar.visit_requested.connect(_visit_neighbour)
		_hud.neighbour_anchor().add_child(_neighbour_bar)
		_update_neighbour_bar()
		_windows.layer = WINDOW_LAYER
		add_child(_windows)
		_spell_layer.layer = SPELL_LAYER
		add_child(_spell_layer)
		_add_spell_book()
		SoundPlayer.play_music(SoundPlayer.town_music(_village.race))
		_enemies = VillageEnemies.new(_village, _view, _config, _rng, _orders.is_busy)
		_enemies.fight_needed.connect(func() -> void: _start_village_fight())
		add_child(_enemies)
		_town_quests = TownQuests.new(_village, _config, _rng)
		_goals.goal_completed.connect(_on_goal_completed)
		if _tutorial.is_active():
			_tutorial_box = TutorialBox.new(_ui)
			_tutorial_box.button_pressed.connect(func() -> void: _tutorial.handle(Tutorial.Action.BOX_BUTTON))
			add_child(_tutorial_box)
			_tutorial.step_changed.connect(func(_step: int) -> void:
				_show_tutorial()
				_save())
			_tutorial.finished.connect(_on_tutorial_finished)
			_show_tutorial()
		_daily_bonus = _village.start_daily_bonus(_now())
		_show_first_offer_icon()
		_init_map()
		var kinds := {"siege": CollectiveAI.Kind.SIEGE, "stampede": CollectiveAI.Kind.BIG_MOUNTS, "army": CollectiveAI.Kind.ARMY, "bandits": CollectiveAI.Kind.BANDITS}
		if kinds.has(_options.get("village-attack", "")):
			_enemies.add_due_attack(kinds[_options["village-attack"]])
		var clock := Timer.new()
		clock.timeout.connect(_on_clock)
		add_child(clock)
		clock.start(1.0)
		_update_production()
		if not _reload_message.is_empty():
			_hud.show_message(_reload_message)
			_reload_message = ""
		_offer_received_assists()
		_check_town_quest()

	if _options.has("quest") and _village != null and _view != null:
		_on_island_chosen(_options["quest"], null)
	if _options.has("tournament") and _village != null and _view != null and _load_quest_graphics():
		if _options["tournament"] == "window":
			_open_tournament()
		else:
			_start_tournament_match(int(_options["tournament"]))
	if _options.has("survival") and _village != null and _view != null and _load_quest_graphics():
		if _options["survival"] == "window":
			_open_survival()
		else:
			_start_survival(_options["survival"])
	if _options.has("screenshot"):
		await _save_screenshot(_options["screenshot"])
		get_tree().quit()


func _start_battle(map_path: String, effects: SpriteLibrary) -> void:
	var map := Village.load_from_file(map_path, _config)
	if map == null:
		_show_message("Cannot read the battle map %s." % map_path)
		return
	var battle := BattleScreen.practice_battle(map, _village, _config, _sprites, _rng)
	var view := BattleView.new()
	add_child(view)
	view.show_battle(battle, _config, _sprites, effects, VillageView.LAND_ITEM_BASE_ID + map.skin, VillageView.village_land_frames(map.owned_land))
	var camera := MapCamera.new()
	camera.position = _start_position(map)
	add_child(camera)
	# After the camera, so that it gets the mouse first: a selection box does not move the map.
	add_child(BattleScreen.new(battle, view))


## The spell book of the village, when the import has the windows of the
## client. At home a cast shows the graphic of the spell on the tile and costs
## its mana; the spells do not change the units of the village, and summoned
## units do not come. After the nodes that take clicks on the map, so that it
## gets the mouse first while the player aims.
func _add_spell_book() -> void:
	if not FileAccess.file_exists(_data_dir.path_join("ui/cast/layout.json")) or not _load_quest_graphics():
		return
	_spell_book = SpellBook.new(_ui, _cast_ui, _config, _village, _spell_layer)
	_spell_book.cast_on = func(spell: GameConfig.SpellDef, tile: Vector2i, _level: int) -> void:
		var sprite := _effects.get_sprite(spell.img_name)
		if sprite == null:
			return
		var graphic: Dictionary = _spell_graphics.get(spell.img_name, {})
		var stay := int(graphic.get("labels", {}).get("attack", BattleSpell.DEFAULT_ATTACK_FRAME)) + BattleSpell.DEFAULT_STAY_FRAMES
		var particle := SpellParticle.new(sprite, {"frames": stay, "loop_from": graphic.get("loop_from")})
		particle.position = IsoGrid.tile_to_map(tile)
		_view.add_child(particle)
	_spell_book.changed.connect(_save)
	add_child(_spell_book)


## The client opens the island window from the ship; a village without
## fighting units cannot sail.
func _open_quests() -> void:
	if not _load_quest_graphics():
		return
	if _village.quest_army().is_empty():
		_alert(_config.text("AVISO_NAVEGAR_SIN_TROPAS").strip_edges())
		return
	_record(VillageEvent.Kind.WINDOW_OPENED, {"window": "popups.PopupQuestsManager"})
	var window := QuestListWindow.new(_ui, QuestBook.new(_village, _config), _config, _now)
	window.closed.connect(window.queue_free)
	window.island_chosen.connect(_on_island_chosen.bind(window))
	_windows.add_child(window)


## The survival window of the client, from SURVIVAL_LEVEL. The newest client
## hides its button; older versions showed it in the world menu, and the
## owner of the port decided to have survival.
func _open_survival() -> void:
	if not _load_quest_graphics():
		return
	if _village.get_level() < SURVIVAL_LEVEL:
		_alert("%s %d" % [_config.text("UNLOCK_LEVEL"), SURVIVAL_LEVEL])
		return
	var window := SurvivalWindow.new(_ui, _config, _village, _now)
	window.closed.connect(window.queue_free)
	window.village_changed.connect(_save)
	window.map_chosen.connect(func(map_id: String) -> void:
		window.queue_free()
		_start_survival(map_id))
	_windows.add_child(window)


## Goes to the survival map with the strongest units of the village.
func _start_survival(map_id: String) -> void:
	var map := Village.load_from_file(_data_dir.path_join("quests/%s.save.json" % map_id), _config)
	if map == null:
		_alert("Cannot read this survival map. Import the game files again.")
		return
	var army := SurvivalBattle.army(_village.quest_army(), _config)
	var survival := SurvivalBattle.create(SurvivalMap.find(map_id), map, army, _config, _sprites, _rng, _village.get_level())
	# The client plays the music of the quests in survival; it never plays its survival music.
	SoundPlayer.play_music(SoundPlayer.Music.QUEST)
	_survival_screen = SurvivalScreen.new(survival, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
	_goals.watch_battle(survival.sim)
	_survival_screen.village_changed.connect(_save)
	_survival_screen.started.connect(func() -> void:
		_village.start_survival(_now())
		_save())
	_survival_screen.closed.connect(_on_survival_closed.bind(map_id))
	_select(null)
	_show_village(false)
	add_child(_survival_screen)


## The client gives the reward and the time to the server ("end_survival") and loads the village again.
func _on_survival_closed(seconds: int, reward: int, map_id: String) -> void:
	_village.end_survival(map_id, seconds, reward, _now())
	_init_map()
	_survival_screen.queue_free()
	_survival_screen = null
	_show_village(true)
	_view.sync_items()
	_update_store()
	if reward != 0:
		_hud.show_message("You got a %s. It is in the item store." % _config.get_item(reward).name)


## The weekly tournament against the bots of the configuration, from
## TOURNAMENT_LEVEL; see TournamentWindow.
func _open_tournament() -> void:
	if not _load_quest_graphics():
		return
	if _village.get_level() < TOURNAMENT_LEVEL:
		_alert("%s %d" % [_config.text("UNLOCK_LEVEL"), TOURNAMENT_LEVEL])
		return
	var window := TournamentWindow.new(_ui, _config, _village.attack_team("tournament"), _village.tournament_formation(), _tournament_scores)
	window.closed.connect(window.queue_free)
	window.team_requested.connect(func() -> void:
		window.queue_free()
		_choose_tournament_team())
	window.match_requested.connect(func(bot: int) -> void:
		window.queue_free()
		_start_tournament_match(bot))
	_windows.add_child(window)


func _choose_tournament_team() -> void:
	var window := TeamWindow.new(_ui, _config, null, _village.quest_army(), TeamWindow.Mode.TOURNAMENT, _village.attack_team("tournament"), _village.tournament_formation())
	window.places_chosen.connect(func(places: Array[int], formation: int) -> void:
		_village.set_attack_team("tournament", places, formation)
		_save())
	window.closed.connect(_open_tournament)
	window.accepted.connect(func(_team: Dictionary) -> void: _open_tournament())
	_windows.add_child(window)


## A match against the bot with this index, with the saved team. Units of the
## team that the village no longer has stay out, as the client checks the
## saved team against the units of the village.
func _start_tournament_match(bot_index: int) -> void:
	var map := Village.load_from_file(_data_dir.path_join("quests/%s.save.json" % _config.tournament_map), _config)
	if map == null:
		_alert("Cannot read the map of the tournament. Import the game files again.")
		return
	var left := _village.quest_army()
	var places: Array[int] = []
	for id in _village.attack_team("tournament"):
		var free := int(left.get(id, 0))
		places.append(id if free > 0 else 0)
		if free > 0:
			left[id] = free - 1
	var bot: Dictionary = _config.tournament_bots[bot_index]
	var bot_places: Array[int] = bot["team"]
	var match_battle := TournamentBattle.create(map, places, _village.tournament_formation(), bot_places, 0, _config, _sprites, _rng, _village.get_level())
	_tournament_screen = TournamentScreen.new(match_battle, map, bot, _village, _village.player_name(), _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
	_goals.watch_battle(match_battle.sim)
	_tournament_screen.village_changed.connect(_save)
	_tournament_screen.closed.connect(func(score: int, won: bool) -> void:
		_tournament_scores[bot_index] = [score, won]
		_init_map()
		_tournament_screen.queue_free()
		_tournament_screen = null
		_show_village(true)
		_view.sync_items()
		_open_tournament())
	_select(null)
	_show_village(false)
	add_child(_tournament_screen)


## window: the island window, which closes when the quest starts; or null.
func _on_island_chosen(quest_id: String, window: QuestListWindow) -> void:
	if not _load_quest_graphics():
		return
	var book := QuestBook.new(_village, _config)
	match book.refusal(quest_id, _now()):
		QuestBook.Refusal.LOCKED:
			_alert(_config.text("AVISO_QUEST_BLOQUEADA").strip_edges())
		QuestBook.Refusal.NOT_IN_PORT:
			_alert(QuestListWindow.NOT_IN_PORT_ALERT)
		QuestBook.Refusal.NO_ARMY:
			_alert(_config.text("AVISO_NAVEGAR_SIN_TROPAS").strip_edges())
		QuestBook.Refusal.LIMIT_REACHED:
			# The text of the client names its own wait of 6 hours; the port names its own.
			var text := _config.text("QUEST_COOLDOWN_REMINDER").replace("#0#", str(book.quests_per_window()))
			_alert(RegEx.create_from_string("\\d+ hours").sub(text, "%d hours" % (QuestBook.QUEST_WINDOW_SECONDS / 3600)))
		QuestBook.Refusal.NONE:
			if window != null:
				window.queue_free()
			_start_quest(quest_id)


## Leaves the village for the island: the army lands and the start window
## opens. On an island with teams the player first chooses the team (TeamWindow).
func _start_quest(quest_id: String) -> void:
	var island := QuestIsland.find(quest_id)
	if not island.team:
		_land(quest_id, _village.quest_army())
		return
	var window := TeamWindow.new(_ui, _config, island, _village.quest_army(), TeamWindow.Mode.QUEST, _village.attack_team("quest"), _village.tournament_formation())
	window.closed.connect(_open_quests)
	window.places_chosen.connect(func(places: Array[int], formation: int) -> void:
		_village.set_attack_team("quest", places, formation)
		_save())
	window.accepted.connect(func(team: Dictionary) -> void: _land(quest_id, team))
	_windows.add_child(window)


## army: unit id -> number, the units that go to the island.
func _land(quest_id: String, army: Dictionary) -> void:
	var map := Village.load_from_file(_data_dir.path_join("quests/%s.save.json" % quest_id), _config)
	if map == null:
		_alert("Cannot read the map of this island. Import the game files again.")
		return
	var quest := QuestBattle.create(QuestIsland.find(quest_id), map, army, _config, _village.quest_rank(quest_id), _sprites, _rng, _village.get_level(), _village.race)
	SoundPlayer.play_music(SoundPlayer.Music.QUEST)
	_quest_screen = QuestScreen.new(quest, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
	_goals.watch_battle(quest.sim)
	_quest_screen.village_changed.connect(_save)
	_quest_screen.started.connect(func(_stars: int) -> void:
		_village.start_quest(quest_id, _now())
		_save())
	_quest_screen.closed.connect(_on_quest_closed)
	_select(null)
	_show_village(false)
	add_child(_quest_screen)


## Saves the result of the quest and goes home. The client then opens the island window again.
func _on_quest_closed(result: Dictionary) -> void:
	var old_level := _village.get_level()
	for found in _quest_screen.quest.collectibles:
		_village.add_collectible(found)
	_village.end_quest(result)
	# The client loads the village map again: new enemies come, and a new level
	# of the quest brings no attacks of its own.
	_init_map()
	_quest_screen.queue_free()
	_quest_screen = null
	_show_village(true)
	_view.sync_items()
	_update_store()
	_update_production()
	_hud.show_message(_level_up_text(old_level).strip_edges())
	_open_quests()


func _show_village(shown: bool) -> void:
	for node: Node in [_view, _orders, _hud, _camera, _enemies] + ([_spell_book] if _spell_book != null else []):
		node.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	_view.visible = shown
	_hud.visible = shown
	if shown:
		SoundPlayer.play_music(SoundPlayer.town_music(_village.race))
	_spell_layer.visible = shown
	_camera.enabled = shown


## Loads the windows of the client, the graphics of the shots and spells, and
## how the spell graphics play, when the player first needs them. Returns false
## when the import does not have them.
func _load_quest_graphics() -> bool:
	if _ui == null:
		_ui = UiLibrary.load_from(_data_dir, _frames)
	if _cast_ui == null and _ui != null:
		_cast_ui = UiLibrary.load_from(_data_dir, _frames, "ui/cast")
	var graphics: Variant = BattleSpell.read_graphics(_data_dir.path_join("spells.json")) if _spell_graphics.is_empty() else _spell_graphics
	if _ui == null or _cast_ui == null or graphics == null:
		_hud.show_message("The quests and the spells need the windows of the client. Import the game files again; see godot/README.md.")
		return false
	_spell_graphics = graphics
	if _effects == null:
		_effects = SpriteLibrary.new(_data_dir, _frames, "fx")
	return true


func _alert(text: String) -> void:
	_windows.add_child(AlertWindow.new(_ui, _config, text))


func _on_item_selected(item: GameConfig.ItemDef) -> void:
	if not _tutorial.allows_build(item):
		return
	_tutorial.handle(Tutorial.Action.BUILD_ITEM_CHOSEN, item)
	_select(null)
	_placing_stored = false
	_view.begin_placement(item)
	_hud.show_message("Place %s." % item.name)


## With a unit selected, a click sends the unit to a free tile, into a building
## or to a resource that it can use. Otherwise a click on a ready building collects from it, as in the
## original game, and a click on an item selects it.
func _on_map_clicked(tile: Vector2i, placed: Village.PlacedItem) -> void:
	if placed != null and _village.quest_roles.get(placed) == Village.QuestRole.OBJECTIVE:
		_collect_town_quest(placed)
		return
	if (placed != null and (_village.is_enemy_unit(placed) or _village.quest_roles.get(placed) == Village.QuestRole.ENEMY)) \
			or _enemies.has_attacker_at(tile):
		if not _tutorial.allows_orders():
			return
		var attacker := _selected if _selected != null and _village.is_own_unit(_selected) else null
		_start_village_fight(attacker, tile)
		if attacker != null:
			_tutorial.handle(Tutorial.Action.ATTACK_ORDERED)
		return
	if not _group.is_empty() and not placed in _group:
		_order_group(tile, placed)
		return
	if placed != null and placed == _last_click and placed == _selected and _village.is_own_unit(placed) \
			and Time.get_ticks_msec() - _last_click_msec <= DOUBLE_CLICK_MSEC:
		_select_kind(placed)
		return
	_last_click = placed
	_last_click_msec = Time.get_ticks_msec()
	if _selected != null and _village.is_own_unit(_selected) and placed != _selected \
			and (placed == null or _village.can_enter(_selected, placed) or _village.can_harvest(_selected, placed) or _village.can_repair(_selected, placed)):
		if not _tutorial.allows_orders():
			return
		var error := _orders.order(_selected, tile, placed)
		_hud.show_message(error)
		if error.is_empty():
			SoundPlayer.play(SoundEffect.ROLL_OVER)  # The client plays it for each move order of the player.
			_select(null)
			_tutorial.handle(Tutorial.Action.UNIT_ORDERED, _config.get_item(placed.item_id) if placed != null else null)
		return
	if placed != null and _village.seconds_to_ready(placed, _now()) == 0:
		_collect(placed)
		if placed not in _village.items:
			return
	var area := IsoGrid.land_area_number(tile / IsoGrid.LAND_TILES)
	if placed == null and _village.can_buy_land(area) and _tutorial.allows_other():
		_specials.land_area = area
		_show_panel(SpecialActions.View.LAND)
		return
	var item := _config.get_item(placed.item_id) if placed != null else null
	if placed != null and not _tutorial.allows_select(item, _village.is_enemy_unit(placed)):
		return
	_select(placed)
	if placed != null:
		_tutorial.handle(Tutorial.Action.SELECTED, item)


func _select(placed: Village.PlacedItem) -> void:
	_selected = placed
	if not _group.is_empty():
		_group.clear()
		_view.show_group(_group)
	_panel = SpecialActions.View.BUILDING if placed != null else SpecialActions.View.NONE
	_view.show_selection(placed)
	var item := _config.get_item(placed.item_id) if placed != null else null
	_hud.selection.show_selection(item, _village.health(placed) if placed != null else 0, placed != null and _village.can_move(placed), placed != null and _village.can_sell(placed), placed != null and _village.can_rotate(placed), placed != null and _village.can_store(placed))
	_hud.show_panel(placed != null)
	var names: Array[String] = []
	if placed != null:
		for id in _village.units_in(placed):
			names.append(_config.get_item(id).name)
	_hud.selection.show_units(names)
	if placed != null and _village.is_own_unit(placed):
		_hud.show_message("%s: click a place to walk, a building to go into it, or a tree, stone or gold to harvest it." % item.name)
	elif placed != null and _village.is_wild_animal(placed):
		_hud.show_message("A wild %s. Walk one of your units near it to capture it." % item.name)
	if placed != null and placed.item_id == Village.UNIT_WAREHOUSE:
		var stored := []
		var units := _village.warehoused_units()
		for id: int in units:
			stored.append([id, _config.get_item(id).name, units[id]])
		var price := _config.warehouse_slot_price if _village.warehouse_capacity() < _config.warehouse_max_capacity else 0
		_hud.selection.show_warehouse(stored, _village.warehoused_count(), _village.warehouse_capacity(), price)
	else:
		_hud.selection.show_warehouse(null, 0, 0, 0)
	_update_production()


func _on_clock() -> void:
	var now := _now()
	var changed := false
	if _tutorial.is_active() and _tutorial.step == 26:
		changed = _speed_up_tutorial_farm(now)
	for placed in _village.items.duplicate():
		changed = _complete_training(placed, now) or changed
		var victim := _village.complete_sacrifice(placed, now)
		if victim != null:
			changed = true
			if placed == _selected:
				_select(placed)
			_hud.show_message("%s was sacrificed. You get %d %s." % [victim.name, Village.sell_refund(victim), VillageHud.RESOURCE_NAMES.get(victim.cost_type, victim.cost_type)])
	for change: Array in _village.regrow(now, _rng):
		changed = true
		_view.remove_placed(change[0])
		_view.add_placed(change[1])
	if changed:
		_save()
	_check_town_quest()
	_update_production()
	_update_store()
	_update_first_offer_icon(now)


## Puts the trained units of the building on the map. Returns true when a unit came out.
func _complete_training(building: Village.PlacedItem, now: int) -> bool:
	var unit := _village.complete_training(building, now)
	var trained := unit != null
	while unit != null:
		_view.add_placed(unit)
		SoundPlayer.play(SoundEffect.ROLL_OVER)  # The unit comes out of the building (IsoBuilding).
		_hud.show_message("%s is trained." % _config.get_item(unit.item_id).name)
		unit = _village.complete_training(building, now)
	return trained


## A unit arrived, went into a building or finished a harvest.
func _on_units_changed(message: String, old_level: int) -> void:
	if _selected != null and _selected not in _village.items:
		_select(null)
	elif _selected != null:
		_select(_selected)
	_update_store()
	if _save() and not message.is_empty():
		_hud.show_message(message + _level_up_text(old_level))


func _on_train_requested() -> void:
	if _selected == null:
		return
	var unit := _village.trained_unit(_selected)
	if not _tutorial.allows_training(unit):
		return
	var result := _village.train(_selected, _now())
	var texts := {
		Village.Training.QUEUE_FULL: "The training queue is full (%d units)." % Village.MAX_QUEUE,
		Village.Training.POPULATION_FULL: "The population is full. Build houses for more population.",
		Village.Training.UNIT_LIMIT_REACHED: "You have the maximum number of this unit.",
		Village.Training.NOT_ENOUGH_RESOURCES: "You do not have enough resources.",
	}
	if result != Village.Training.OK:
		_hud.show_message(texts.get(result, ""))
		return
	_update_store()
	_update_production()
	if _save():
		_hud.show_message("%s is in training." % unit.name)
	_tutorial.handle(Tutorial.Action.TRAINING_STARTED, unit)


func _on_speed_up_requested() -> void:
	if _selected == null:
		return
	var now := _now()
	var cost := _village.speed_up_cost(_selected, now)
	var result := _village.speed_up_training(_selected, now)
	if result != Village.Training.OK:
		_hud.show_message("You do not have enough cash." if result == Village.Training.NOT_ENOUGH_CASH else "No units are in training.")
		return
	_complete_training(_selected, now)
	if _village.queued_units(_selected) > 0:
		_hud.show_message("The training is finished, but there is no free place for all units.")
	_update_store()
	_update_production()
	if _save() and _village.queued_units(_selected) == 0:
		_hud.show_message("The training is finished for %d cash." % cost)


func _on_unqueue_requested() -> void:
	if _selected == null or _village.unqueue_unit(_selected) != Village.Training.OK:
		return
	_update_store()
	_update_production()
	if _save():
		_hud.show_message("%s left the training queue. You got its cost back." % _village.trained_unit(_selected).name)


func _on_unit_out_requested(index: int) -> void:
	if _selected == null:
		return
	var unit := _village.pop_unit(_selected, index, _now())
	if unit == null:
		_hud.show_message("There is no free place for the unit.")
		return
	_view.add_placed(unit)
	_select(_selected)
	if _save():
		_hud.show_message("%s came out." % _config.get_item(unit.item_id).name)


## Updates the resources and the build menu. The menu changes with the level
## and at the end of each period of the store rotation.
func _update_store() -> void:
	var now := _now()
	var key := [_village.get_level(), _store.rotation_end(now)]
	if key != _store_key:
		_store_key = key
		# The client gives the free buildings when it loads the map and at a
		# new level, but not during the tutorial, which gives a nest at its end.
		var free: Array[Village.PlacedItem] = []
		if not _tutorial.is_active():
			free = _village.add_free_buildings(now)
		for placed in free:
			_view.add_placed(placed)
		if not free.is_empty():
			_save()
			_hud.show_message("You got a free %s." % " and a free ".join(free.map(func(placed: Village.PlacedItem) -> String: return _config.get_item(placed.item_id).name)))
		# An import before this window has only the message above.
		if _ui != null and _ui.has_symbol("PopUpAlertaMC") and free.any(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Village.WIZARDRY):
			_windows.add_child(PictureAlertWindow.new(_ui, _config, _config.text("AVISO_GRIMORIO_TITULO"), _config.text("AVISO_GRIMORIO_DESCRIPCION"), "alert_magic.jpg"))
		var offered := {}
		for category_id in Store.CATEGORIES:
			offered[category_id] = _store.items(category_id, _village.race, _village.get_level(), now).filter(func(item: GameConfig.ItemDef) -> bool: return _sprites.get_sprite(item.img_name) != null)
		# The limited items show the days until the end of the rotation.
		_hud.store.set_items(offered, ceili((_store.rotation_end(now) - now) / 86400.0))
	_hud.refresh(_village)
	_hud.show_world_button(_village.race != "h" or _village.get_level() >= Village.SECOND_TOWN_LEVEL)
	_hud.show_goals(_goals.shown_goals().map(func(goal: GameConfig.GoalDef) -> Array: return [goal.id, _goals.text(goal.title), _goals.progress_text(goal)]))
	_hud.show_shield(_village.get_level(), _village.shield_seconds(now))


## Updates the marks of the ready buildings and the production of the selected building.
func _update_production() -> void:
	var now := _now()
	_view.update_production(now, _town_quests.open_items() if _town_quests != null else [] as Array[Village.PlacedItem])
	_view.update_damage()
	if _selected == null or not _village.is_producer(_selected):
		_hud.selection.show_production(null, 0, 0, "", 0, false, "")
	else:
		var item := _config.get_item(_selected.item_id)
		var requirement := ""
		if _selected.item_id == Village.NURSERY and _village.needs_units(_selected):
			requirement = "Breeds a new animal from two animals of the same kind. Select a captured animal, then click the nursery."
		elif _village.needs_units(_selected):
			requirement = "Works only with a unit in it. Select a unit, then click the building."
		_hud.selection.show_production(item, _village.seconds_to_ready(_selected, now), _village.production_seconds(_selected), _product_text(_selected), _village.collect_cost(_selected), _village.can_hurry(_selected, now), requirement)
	var unit := _village.trained_unit(_selected) if _selected != null else null
	if unit == null:
		_hud.selection.show_training(null, {}, 0, -1, 0)
	else:
		_hud.selection.show_training(unit, _village.training_costs(unit), _village.queued_units(_selected), _village.seconds_to_trained(_selected, now), _village.speed_up_cost(_selected, now))
	var panel := _specials.describe(_panel, _selected, now)
	_hud.selection.show_actions(panel[0], panel[1])


## Starts the quest in the town when it is due, spawns its boss waves and
## shows what the player does next. The tutorial comes first, and no quest
## starts while a fight or another screen is open.
func _check_town_quest() -> void:
	if _town_quests == null or _tutorial.is_active() or _village_fight != null or not _view.visible:
		return
	var now := _now()
	var was_active := _town_quests.is_active()
	var old_level := _village.get_level()
	if _town_quests.start(now):
		_view.sync_items()
		_save()
		var id := _town_quests.quest_id()
		_open_town_quest_window(_config.text("POPUP_QUEST_INFO_TITLE").replace("#0#", str(id + 1)) + ": " + _config.text(_town_quests.text_name("title")), _config.text(_town_quests.text_name("text")), id, false)
		_camera.position = IsoGrid.tile_to_map(Vector2(_town_quests.focus_tile()))
	elif _town_quests.update(now):
		_view.sync_items()
		_save()
		if was_active and not _town_quests.is_active():
			_end_town_quest(old_level)
	if _town_quests.is_active():
		_hud.show_town_quest(_town_quests.progress_text(), _village.race == "t")
	else:
		var left := _town_quests.seconds_to_next(now)
		_hud.show_town_quest("%s: %02d:%02d:%02d" % [_config.text("TIMER_CAMPAMENTO_ENEMIGO"), left / 3600, left / 60 % 60, left % 60] if left > 0 else "", _village.race == "t")


func _collect_town_quest(placed: Village.PlacedItem) -> void:
	var old_level := _village.get_level()
	var ended_text := _config.text(_town_quests.text_name("end_title"))
	var ended_body := _config.text(_town_quests.text_name("end_text"))
	var ended_id := _town_quests.quest_id()
	var result := _town_quests.collect(placed, _now())
	if result.is_empty():
		_select(placed)
		_hud.show_message(_town_quests.progress_text())
		return
	_select(null)
	_view.sync_items()
	_save()
	if _town_quests.is_active():
		_hud.show_message(result)
		_hud.show_town_quest(_town_quests.progress_text(), _village.race == "t")
	else:
		_open_town_quest_window(ended_text, ended_body, ended_id, true)
		_end_town_quest(old_level)
		_check_town_quest()


## The quest ended: the reward and the time of the next quest.
func _end_town_quest(old_level: int) -> void:
	var gold_xp := TownQuests.reward(old_level)
	_hud.show_message("%s You get %d gold and %d XP. %s%s" % [_config.text("AUX_COMPLETADO"), gold_xp.x, gold_xp.y, _config.text("POPUP_TESORO_DESCRIPCION"), _level_up_text(old_level)])
	_update_store()


func _open_town_quest_window(title: String, text: String, quest_id: int, completed: bool) -> void:
	for child in _hud.windows().get_children():
		if child is TownQuestWindow:
			child.queue_free()
	_hud.windows().add_child(TownQuestWindow.new(_ui, _config, title, text, TownQuestBook.picture(quest_id, _village.race), completed))


func _show_panel(panel: SpecialActions.View) -> void:
	_select(null)
	_panel = panel
	_update_production()


func _on_action_requested(id: String) -> void:
	if id == "spells":
		if _spell_book != null:
			_spell_book.open_shop()
		else:
			_hud.show_message("The spell window needs the windows of the client. Import the game files again; see godot/README.md.")
		return
	var outcome := _specials.run(id, _selected, _now())
	if outcome.sound >= 0:
		SoundPlayer.play(outcome.sound)
	if outcome.place != null:
		_select(null)
		_placing_stored = _view.begin_placement(outcome.place)
		if not _placing_stored:
			outcome.text = "The graphic of %s is not imported. Import the game files again; see README.md." % outcome.place.name
	elif outcome.changed:
		_view.sync_items()
		_update_store()
		if _selected != null:
			_select(_selected)
		if not _save():
			return
		if outcome.reload:
			_reload_map(outcome.text)
			return
		if outcome.redraw:
			_view.show_village(_village, _config, _sprites)
			_panel = SpecialActions.View.NONE
	_update_production()
	_hud.show_message(outcome.text)


## Loads the saved village again, as the client does with loadMap().
func _reload_map(message: String) -> void:
	_reload_message = message
	_reloaded = true
	get_tree().reload_current_scene.call_deferred()


## What a collection from the producing building gives, for example "250 food" or "1 Sheep".
func _product_text(placed: Village.PlacedItem) -> String:
	var born := _village.bred_unit(placed)
	if born != null:
		return "1 %s" % born.name
	if placed.item_id == Village.TREASURE_MINE:
		return "1 collection item"
	var collect_type := _config.get_item(placed.item_id).collect_type
	return "%d %s" % [_village.collect_amount(placed), VillageHud.RESOURCE_NAMES.get(collect_type, collect_type)]


## With hurry, the player pays cash to collect before the building is ready.
func _collect(placed: Village.PlacedItem, hurry: bool = false) -> void:
	var item := _config.get_item(placed.item_id)
	var old_level := _village.get_level()
	var product := _product_text(placed)
	var cost := _village.collect_cost(placed)
	var cash_before := _village.get_resource("c")
	var result := _village.hurry(placed, _now()) if hurry else _village.collect(placed, _now())
	match result:
		Village.Production.OK:
			if placed.item_id == Village.TREASURE_MINE:
				var found := _village.find_collectible(true, _rng)
				product = "nothing" if found == Vector2i.ZERO else SpecialActions.found_text(_config, found)
			_view.sync_items()
			_update_production()
		Village.Production.FARM_REMOVED:
			if _selected == placed:
				_select(null)
			_view.sync_items()
		Village.Production.NOT_READY:
			_hud.show_message("%s is not ready." % item.name)
			return
		Village.Production.NO_UNITS:
			_hud.show_message("%s works only with a unit in it." % item.name)
			return
		Village.Production.NOT_ENOUGH_CASH:
			_hud.show_message("You need %d cash to finish %s now." % [Village.HURRY_COST, item.name])
			return
		Village.Production.NO_FREE_TILE:
			_hud.show_message("There is no free place next to %s for the new animal." % item.name)
			return
		_:
			_hud.show_message("%s does not produce now." % item.name)
			return
	SoundPlayer.play(SoundEffect.COLLECTION)
	_update_store()
	if not _save():
		return
	if result == Village.Production.FARM_REMOVED:
		_hud.show_message("%s needs %d wood to collect. You do not have it, so the farm is gone." % [item.name, cost])
	else:
		var text := "Collected %s from %s." % [product, item.name]
		if cost > 0:
			text += " It cost %d wood." % cost
		if cash_before > _village.get_resource("c"):
			text += " It cost %d cash." % (cash_before - _village.get_resource("c"))
		_hud.show_message(text + _level_up_text(old_level))


func _on_work_time_chosen(work_time: int) -> void:
	if _selected == null or _village.start_work(_selected, work_time, _now()) != Village.Production.OK:
		return
	_update_production()
	if _save():
		_hud.show_message("%s works for %d minutes." % [_config.get_item(_selected.item_id).name, Village.WORK_MINUTES[work_time]])


func _on_rotate_requested() -> void:
	if _selected == null or _village.rotate(_selected) != Village.Placement.OK:
		return
	_view.update_placed(_selected)
	_save()


func _on_move_requested() -> void:
	if _selected != null and _view.begin_move(_selected):
		_hud.show_message("Move %s. Right-click cancels." % _config.get_item(_selected.item_id).name)


func _on_move_confirmed(placed: Village.PlacedItem, tile: Vector2i, frame: int) -> void:
	var result := _village.move(placed, tile, frame)
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.end_placement()
	_view.update_placed(placed)
	_select(placed)
	if _save():
		_hud.show_message("Moved %s." % _config.get_item(placed.item_id).name)


func _on_sell_confirmed() -> void:
	if _selected == null:
		return
	var placed := _selected
	var item := _config.get_item(placed.item_id)
	var result := _village.sell(placed, _now())
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_select(null)
	_view.sync_items()
	_update_store()
	if _save():
		_hud.show_message("Sold %s." % item.name)


func _on_warehouse_unit_out_requested(unit_id: int) -> void:
	if _selected == null:
		return
	var result := _village.place_warehoused(_selected, unit_id, _now())
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.sync_items()
	_select(_selected)
	_update_store()
	if _save():
		_hud.show_message("%s came out of the warehouse." % _config.get_item(unit_id).name)


func _on_warehouse_slot_requested() -> void:
	if _selected == null:
		return
	var result := _village.buy_warehouse_slot()
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_select(_selected)
	_update_store()
	if _save():
		_hud.show_message("The warehouse has %d places now." % _village.warehouse_capacity())


func _on_placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i, frame: int) -> void:
	if not _placing_stored and not _tutorial.allows_place(tile):
		_hud.show_message("Place it on the marked place.")
		return
	var old_level := _village.get_level()
	var result := _village.place_stored(item, tile, _now(), frame) if _placing_stored else _village.buy(item, tile, _now(), frame)
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.end_placement()
	_view.add_placed(_village.items.back())
	_start_construction(_village.items.back(), item)
	_update_store()
	if not _save():
		return
	_hud.show_message(("Placed %s from the item store." % item.name) if _placing_stored else "Built %s.%s" % [item.name, _level_up_text(old_level)])
	_placing_stored = false


## The client starts the map each time it loads it: at the start and after a
## quest, survival, a tournament match or an attack (MapInitializer.Init, then
## the end of Base.UpdateGame3). After a check of the goals, it clears the
## border, places the idle enemies, the resources and the wild animals,
## starts the attacks, gives the free buildings and, from
## Village.PUBLISH_SCORE_LEVEL, publishes the experience that it counts,
## which takes back the experience that the server gave for these items.
func _init_map() -> void:
	var now := _now()
	_known_level = _village.get_level()
	# The client checks the goals first, with the items before the clean.
	_goals.on_map_loaded()
	_village.clean_border(_rng)
	_enemies.on_map_loaded(now)
	_village.spawn_resources(now, _rng)
	_village.spawn_animals(now, _rng)
	_update_store()
	if _village.get_level() >= Village.PUBLISH_SCORE_LEVEL:
		_village.publish_score(_village.client_xp())
	_view.sync_items()
	_save()
	_show_daily_bonus()


## The client makes the icon panel when the map of the player opens after the
## login bonus is counted, and hides it for the session when the tutorial
## starts (GuiManager.createViralButtons, Base.tutorialCheck). The only icon
## that this server turns on is the first purchase offer.
func _show_first_offer_icon() -> void:
	if _tutorial.is_active() or not _village.first_offer_shown(_now()) or not FileAccess.file_exists(_data_dir.path_join("ui/viral/layout.json")):
		return
	var icons := UiLibrary.load_from(_data_dir, _frames, "ui/viral")
	if icons == null or not icons.has_symbol(FIRST_OFFER_ICON):
		return
	_hud.show_first_offer(icons.make(FIRST_OFFER_ICON))
	_update_first_offer_icon(_now())


## The icon shows "open me" until the first opening, then the time that is
## left. The client keeps the icon until the next start when the time ends.
func _update_first_offer_icon(now: int) -> void:
	_hud.set_first_offer_text(SurvivalWindow.time_text(_village.first_offer_seconds_left(now)) if _village.first_offer_opened() else _config.text("POPUP_FIRST_OFFER_VIRAL"))


## The first opening of the window starts the time of the offer
## ("set_first_purchase_timestamp"). After the purchase the client removes the
## icon and tells the player where the units are.
func _open_first_offer() -> void:
	_village.open_first_offer(_now())
	_save()
	_update_first_offer_icon(_now())
	var window := FirstOfferWindow.new(_ui, _config, _sprites, _village, _now)
	window.buy_requested.connect(func() -> void:
		var result := _village.buy_first_offer(_now())
		if result == Village.Placement.NOT_ENOUGH_RESOURCES:
			_windows.add_child(AlertWindow.new(_ui, _config, _config.text("AVISO_SUFICIENTE_CASH")))
			return
		window.queue_free()
		if result != Village.Placement.OK:
			return
		_save()
		_hud.remove_first_offer()
		_hud.refresh(_village)
		_windows.add_child(AlertWindow.new(_ui, _config, _config.text("POPUP_FIRST_OFFER_REWARD"))))
	_windows.add_child(window)


func _open_unit_list() -> void:
	var window := UnitListWindow.new(_ui, _config, _sprites, _unit_collections)
	window.packs_requested.connect(func() -> void: _show_panel(SpecialActions.View.PACKS))
	window.reward_requested.connect(func(collection: Dictionary) -> void:
		if _unit_collections.claim(collection) != Village.Placement.OK:
			return
		_save()
		_hud.refresh(_village)
		# The window of the reward replaces the unit list, as in the client.
		window.queue_free()
		_windows.add_child(UnitCollectionRewardWindow.new(_ui, _config, Village.UNIT_COLLECTION_CASH)))
	_windows.add_child(window)


## The client opens the window of the login bonus when it loads the game, or
## after the tutorial at the next start of the map (DailyBonusManager).
func _show_daily_bonus() -> void:
	if not _daily_bonus.get("shown", false) or _tutorial.is_active() or not _ui.has_symbol("PopupNewDailyBonusMC"):
		return
	var window := DailyBonusWindow.new(_ui, _config, _daily_bonus)
	_daily_bonus = {}
	if window.reward().has("u"):
		_village.add_daily_bonus_unit(int(window.reward()["u"]))
		_save()
	window.closed.connect(func(reward: Dictionary) -> void:
		var parts: Array[String] = []
		for code: String in reward:
			if code == "u":
				parts.append("a %s in the item store" % _config.get_item(int(reward[code])).name)
			else:
				parts.append("%d %s" % [int(reward[code]), VillageHud.RESOURCE_NAMES.get(code, code)])
		if not parts.is_empty():
			_hud.show_message("Login bonus: %s." % ", ".join(parts))
		_hud.refresh(_village))
	_windows.add_child(window)


## The client plays a sound for a new item, and builds a new building for
## CONSTRUCTION_SECONDS (a third of it in the tutorial) with the scaffold of
## its size and a bar, and with its own sounds (setGraphicConstruction and
## endConstruction). During this time the building takes no units.
func _start_construction(placed: Village.PlacedItem, item: GameConfig.ItemDef) -> void:
	SoundPlayer.play(SoundEffect.ROLL_OVER)
	if item.is_unit():
		return
	var seconds := CONSTRUCTION_SECONDS
	if _tutorial.is_active():
		seconds = (TUTORIAL_FARM_SECONDS if item.id == TUTORIAL_FARM else CONSTRUCTION_SECONDS) / 3.0
	else:
		SoundPlayer.play(SoundEffect.CONSTRUCTING)
	_village.start_construction(placed, Time.get_unix_time_from_system() + seconds)
	_view.show_construction(placed, _scaffold(item), seconds, item.width == 1)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		SoundPlayer.play(SoundEffect.CONSTRUCTION_END)
		_on_tutorial_construction_end())


## The tutorial goes on when the construction of the house (step 10) or the
## farm (step 19) ends. After the house, the client first moves the map to
## the knights and the trolls (TutorialMain.doPan), then goes to step 11.
func _on_tutorial_construction_end() -> void:
	if not _tutorial.is_active() or _tutorial.step not in [10, 19]:
		return
	if _tutorial.step == 19:
		_tutorial.handle(Tutorial.Action.CONSTRUCTED)
		return
	var knights := _village.items.filter(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Tutorial.KNIGHT and _village.is_own_unit(placed))
	if knights.is_empty():
		_tutorial.handle(Tutorial.Action.CONSTRUCTED)
		return
	var pan := create_tween()
	pan.tween_property(_camera, "position", IsoGrid.tile_to_map(knights[0].tile), TUTORIAL_PAN_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	pan.tween_callback(func() -> void: _tutorial.handle(Tutorial.Action.CONSTRUCTED))


## The scaffold of the client for the building: farms and ranches have their
## own; the others go by the width of the building, with the troll scaffolds
## in the troll town.
func _scaffold(item: GameConfig.ItemDef) -> String:
	if item.subcat_functional == SUBCAT_RANCH and item.id != Village.NURSERY:
		return "ConstructionRancho"
	if item.subcat_functional == SUBCAT_FARM:
		return "ConstructionGranja"
	var width := clampi(item.width, 1, 4)
	return "Construction%dx%d%s" % [width, width, "Trol" if _village.race == "t" and width > 1 else ""]


## The levels that the player reached since old_level, with their rewards.
func _level_up_text(old_level: int) -> String:
	var text := ""
	for level in range(old_level + 1, _village.get_level() + 1):
		var reached := _config.levels[level - 1]
		text += " Level %d, %s: you get %d %s" % [level, reached.name, reached.reward_amount, VillageHud.RESOURCE_NAMES.get(reached.reward_type, reached.reward_type)]
		if level >= _config.start_level_mana_reward:
			text += " and %d mana" % _config.mana_reward_per_level
		text += "."
	return text


## Enemies fight in the village (VillageBattle): the village shows as a battle
## until the fight ends. unit: a unit of the player that attacks the enemy on
## target, when the player started the fight with a click.
func _start_village_fight(unit: Village.PlacedItem = null, target := Vector2i.ZERO) -> void:
	if _village_fight != null or _quest_screen != null or _survival_screen != null or _tournament_screen != null or not _load_quest_graphics():
		return
	_orders.stop_walks()
	var battle := VillageBattle.new(_village, _enemies.take_groups(), _config, _sprites, _rng, _orders.is_busy)
	_goals.watch_battle(battle.sim)
	_village_fight = VillageBattleScreen.new(battle, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects, _camera.position)
	_village_fight.village_changed.connect(_save)
	_village_fight.closed.connect(_on_village_fight_closed)
	_select(null)
	_show_village(false)
	add_child(_village_fight)
	if unit != null:
		_village_fight.order_attack(unit, target)


## Writes the result of the fight to the village and shows the village again.
func _on_village_fight_closed() -> void:
	var battle := _village_fight.battle
	var old_level := _village.get_level()
	_enemies.set_groups(battle.apply())
	_camera.position = _village_fight.camera_position()
	_village_fight.queue_free()
	_village_fight = null
	_show_village(true)
	_view.sync_items()
	for placed in _village.items:
		_view.update_placed(placed)
	_update_store()
	_update_production()
	var text := "The fight is over. Enemies killed: %d. Units lost: %d." % [battle.kills, battle.losses]
	if _save():
		_hud.show_message(text + _level_up_text(old_level))
	_check_town_quest()


## Counts an event of the screens for the goals, and saves when a goal was
## completed. The events of the village come from the village itself.
func _record(kind: VillageEvent.Kind, data: Dictionary) -> void:
	_goals.record(kind, data)
	if _goal_done:
		_save()


## The events of the village that the tutorial waits for.
func _on_village_event(kind: VillageEvent.Kind, data: Dictionary) -> void:
	# The client tells the player to take the reward when a new unit completes a unit collection (UnitCollectionsManager).
	if kind == VillageEvent.Kind.UNIT_ARRIVED and _unit_collections.add_unit(data["unit"]):
		_alert(_config.text("ALERT_UNIT_COLLECTION_COMPLETED"))
	if not _tutorial.is_active():
		return
	var item := _config.get_item(int(data.get("item", data.get("unit", 0))))
	match kind:
		VillageEvent.Kind.COLLECTED:
			if item.subcat_functional == Tutorial.SUBCAT_TREE:
				_tutorial.handle(Tutorial.Action.HARVEST_DONE)
				_tutorial.handle(Tutorial.Action.TREE_HARVESTED)
			else:
				_tutorial.handle(Tutorial.Action.COLLECTED, item)
		VillageEvent.Kind.KILLED:
			_tutorial.handle(Tutorial.Action.ENEMY_KILLED)


func _show_tutorial() -> void:
	if _tutorial_box == null:
		return
	_tutorial_box.show_step(_tutorial.box(), _tutorial.arrow_text())
	var tiles: Array[Vector2i] = []
	if _tutorial.marked_tile() != Village.ANY_TILE:
		tiles.append(_tutorial.marked_tile())
	_view.show_marks(_tutorial.marked_items(), tiles)
	_hud.set_locked(_tutorial.is_active())


## The client gives a dragon nest at the end of the tutorial, and then the free buildings.
func _on_tutorial_finished() -> void:
	var nest := _village.add_tutorial_nest(_now())
	_tutorial_box.queue_free()
	_tutorial_box = null
	_view.show_marks([], [])
	_hud.set_locked(false)
	_store_key = []
	_view.sync_items()
	_update_store()
	if _save():
		_hud.show_message("The tutorial is over." + (" You got a %s." % _config.get_item(nest.item_id).name if nest != null else ""))


func _on_goal_completed(goal: GameConfig.GoalDef) -> void:
	_goal_done = true
	if _hud != null:
		_hud.show_message("%s %s. You get %d gold." % [_config.text("POPUP_GOAL_COMPLETED").strip_edges(), _goals.text(goal.title), goal.reward])
	if _goal_window != null and is_instance_valid(_goal_window):
		_goal_window.show_list()


func _open_goal(id: int) -> void:
	var tutorial_step := _tutorial.step if _tutorial.is_active() else -1
	if tutorial_step >= 0:
		# In the tutorial, the goal box opens only the goal of the step.
		id = _tutorial.goal_for_box()
		if id == 0:
			return
	if _goal_window != null and is_instance_valid(_goal_window):
		_goal_window.queue_free()
	_goal_window = GoalWindow.new(_ui, _goals, _config, tutorial_step < 0)
	_goal_window.do_it.connect(_on_goal_do_it)
	_goal_window.closed.connect(func() -> void: _tutorial.handle(Tutorial.Action.GOAL_WINDOW_CLOSED))
	if tutorial_step >= 0:
		_tutorial.handle(Tutorial.Action.GOAL_BOX)
	_hud.windows().add_child(_goal_window)
	for goal in _goals.active_goals():
		if goal.id == id:
			_goal_window.show_goal(goal)
			return
	_goal_window.show_list()


## The "DO IT" button of the client: it shows the player where to do the goal.
func _on_goal_do_it(goal: GameConfig.GoalDef) -> void:
	if not _tutorial.allows_other():
		return
	var hint := _goals.hint(goal)
	_goal_window.queue_free()
	_goal_window = null
	if hint.has("build"):
		_hud.show_build_item(hint["build"])
		_hud.show_message("Build %s: click it in the build menu, then a place." % hint["build"].name)
	elif hint.has("select"):
		_select(hint["select"])
		_camera.position = IsoGrid.tile_to_map(hint["select"].tile)
	elif hint.get("open") == "quests":
		_open_quests()
	elif hint.get("open") == "collections":
		_hud.collections_requested.emit()
	elif hint.get("open") == "packs":
		_show_panel(SpecialActions.View.PACKS)
	elif hint.get("open") == "rename":
		_hud.open_rename()
	elif hint.get("open") == "pvp":
		_open_pvp()
	elif hint.has("text"):
		_hud.show_message(hint["text"])


func _on_store_requested() -> void:
	if _selected == null:
		return
	var item := _config.get_item(_selected.item_id)
	var result := _village.store_item(_selected, _now())
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_select(null)
	_view.sync_items()
	_update_store()
	if _save():
		_hud.show_message("%s is in your item store." % item.name)


func _on_rename_requested(new_name: String) -> void:
	if _village.rename(new_name) != Village.Placement.OK:
		_hud.show_message("Give your empire a name.")
		return
	_update_store()
	if _save():
		_hud.show_message("Your empire is now %s." % _village.map_name())


## The normal mouse of the client (GuiManager.returnMouse): the placement
## and the selection tool stop, and nothing stays selected.
func _cancel_tool() -> void:
	if _view.is_placing():
		_view.end_placement()
	_view.selection_tool = false
	_camera.panning = true
	_select(null)


## The selection tool of the client: the next drag selects the units in a box.
func _start_selection_tool() -> void:
	_select(null)
	_view.selection_tool = true
	_camera.panning = false
	_hud.show_message("Drag a box over your units.")
	_record(VillageEvent.Kind.SELECTION_TOOL_USED, {})


func _on_units_boxed(units: Array[Village.PlacedItem]) -> void:
	_camera.panning = true
	var own: Array[Village.PlacedItem] = []
	own.assign(units.filter(func(placed: Village.PlacedItem) -> bool: return _village.is_own_unit(placed) and not _orders.is_busy(placed)))
	_select_group(own.slice(0, MAX_GROUP))


## A double click on a unit of the player selects the units of its kind near
## it, as the battle screen does (BattleScreen.kind_of()).
func _select_kind(unit: Village.PlacedItem) -> void:
	var kind := BattleScreen.kind_of_item(_config.get_item(unit.item_id))
	if kind == BattleScreen.Kind.NONE:
		return
	var found := []
	for placed in _village.items:
		var item := _config.get_item(placed.item_id)
		var squared := (placed.tile - unit.tile).length_squared()
		if item != null and _village.is_own_unit(placed) and not _orders.is_busy(placed) and squared <= BattleScreen.SAME_KIND_RADIUS * BattleScreen.SAME_KIND_RADIUS \
				and BattleScreen.kind_of_item(item) == kind:
			found.append([squared, found.size(), placed])
	found.sort()
	var group: Array[Village.PlacedItem] = []
	group.assign(found.slice(0, BattleScreen.SAME_KIND_MAX_UNITS).map(func(entry: Array) -> Village.PlacedItem: return entry[2]))
	if group.size() > 1:
		_record(VillageEvent.Kind.DOUBLE_CLICKED, {})
	_select_group(group)


func _select_group(units: Array[Village.PlacedItem]) -> void:
	_select(null)
	if units.size() == 1:
		_select(units[0])
		return
	_group = units
	_view.show_group(_group)
	if not units.is_empty():
		_hud.show_message("%d units selected. Click a place, a building or a resource." % units.size())


## Each unit of the group goes to its own free tile near the clicked tile, or
## to the clicked building or resource when it can.
func _order_group(tile: Vector2i, target: Village.PlacedItem) -> void:
	var taken: Array[Vector2i] = []
	var sent := 0
	for unit in _group:
		if not unit in _village.items:
			continue
		var error := ""
		if target != null and (_village.can_enter(unit, target) or _village.can_harvest(unit, target) or _village.can_repair(unit, target)):
			error = _orders.order(unit, tile, target)
		else:
			var free := _group_tile(tile, taken, unit)
			if free == Village.ANY_TILE:
				continue
			taken.append(free)
			error = _orders.order(unit, free, null)
		if error.is_empty():
			sent += 1
	_group.clear()
	_view.show_group(_group)
	if sent > 0:
		SoundPlayer.play(SoundEffect.ROLL_OVER)
	_hud.show_message("" if sent > 0 else "The units cannot go there.")


## The free tile nearest to tile that no other unit of the group takes.
func _group_tile(tile: Vector2i, taken: Array[Vector2i], unit: Village.PlacedItem) -> Vector2i:
	for ring in range(0, GROUP_RINGS):
		for y in range(tile.y - ring, tile.y + ring + 1):
			for x in range(tile.x - ring, tile.x + ring + 1):
				var candidate := Vector2i(x, y)
				if maxi(absi(x - tile.x), absi(y - tile.y)) == ring and not candidate in taken and _village.is_free(candidate, unit):
					return candidate
	return Village.ANY_TILE


## In step 26 of the tutorial, the farm with the villager produces faster. Returns true when it changed.
func _speed_up_tutorial_farm(now: int) -> bool:
	for placed in _village.items:
		var item := _config.get_item(placed.item_id)
		if item.subcat_functional == Tutorial.SUBCAT_FARM and _village.seconds_to_ready(placed, now) > 0:
			_village.advance_production(placed, Tutorial.FARM_SPEED - 1)
			if _village.seconds_to_ready(placed, now) == 0:
				_tutorial.handle(Tutorial.Action.FARM_READY)
			return true
	return false


# --- Neighbours and attacks on other players ---


func _update_neighbour_bar() -> void:
	var helped: Array[String] = []
	helped.assign(_visited.keys())
	_neighbour_bar.show_entries(NeighbourBar.entries(_neighbours.neighbours(_village.player_id()), _village, _config, _now(), helped))


## The client visits a neighbour from the neighbour bar; not during the tutorial.
func _visit_neighbour(entry: Dictionary) -> void:
	if not _tutorial.allows_other():
		return
	var pid: String = entry["pid"]
	var neighbour := _neighbours.load_village(pid, _now())
	if neighbour == null:
		_hud.show_message("The village of %s is not in the imported files." % entry["name"])
		return
	# The host has no help mark in the client, but can be helped once in a session.
	var can_help: bool = (entry["host"] or entry["assist"]) and not _visited.has(pid)
	_visit = VisitScreen.new(_ui, neighbour, entry, can_help, _config, _sprites, _start_position(neighbour))
	_visit.helped.connect(func() -> void: _record(VillageEvent.Kind.FRIEND_ASSISTED, {}))
	_visit.closed.connect(_on_visit_closed.bind(pid))
	_select(null)
	_show_village(false)
	add_child(_visit)
	_record(VillageEvent.Kind.FRIEND_VISITED, {"pid": pid})


## The player leaves the neighbour: the help goes to the save
## ("assist_neighbor_new"). The neighbour villages of the port do not
## receive it, as the server does not change fixed and friend villages.
func _on_visit_closed(clicks: Array, pid: String) -> void:
	_visited[pid] = true
	_village.assist_neighbour(pid, clicks.size(), _now())
	_save()
	_visit.queue_free()
	_visit = null
	_show_village(true)
	_update_neighbour_bar()


## The help of neighbours that the save has (receivedAssists): the client
## shows a cart for each neighbour, and the player accepts or declines it.
func _offer_received_assists() -> void:
	var assists := _village.received_assists()
	# The client offers the help of neighbours only in the human town.
	if assists.is_empty() or _tutorial.is_active() or _village.race != "h":
		return
	var pid: String = assists.keys()[0]
	var name := pid
	for entry in _neighbours.neighbours(_village.player_id()):
		if entry["pid"] == pid:
			name = entry["name"]
	var window := ConfirmWindow.new(_ui, _config, "%s: %s" % [name, _config.text("POPUP_AYUDA_AMIGO").strip_edges()])
	window.confirmed.connect(func() -> void:
		var helped := _village.accept_assist(pid)
		if not helped.is_empty():
			SoundPlayer.play(SoundEffect.COLLECTION)  # collectHurryUp
		_hud.show_message("%s helped %d of your buildings." % [name, helped.size()])
		_after_assist())
	window.declined.connect(func() -> void:
		_village.decline_assist(pid)
		_after_assist())
	_hud.windows().add_child(window)


## The window of the help frees itself; the next help, if any, opens after it.
func _after_assist() -> void:
	_save()
	_offer_received_assists.call_deferred()


## The PvP window; the client opens PvP from level VillageSocial.PVP_LEVEL.
func _open_pvp() -> void:
	if not _tutorial.allows_other():
		return
	if _village.get_level() < VillageSocial.PVP_LEVEL:
		_hud.show_message("Attacks on other players open at level %d." % VillageSocial.PVP_LEVEL)
		return
	var window := PvpWindow.new(_village, _config)
	window.search_requested.connect(func() -> void:
		window.queue_free()
		_search_enemy())
	window.shield_requested.connect(func(shield_id: int) -> void:
		var result := _village.buy_shield(shield_id, _now())
		_hud.show_placement_result(result)
		if result == Village.Placement.OK:
			_save()
			_hud.refresh(_village)
		window.show_main(_now()))
	window.attack_log_opened.connect(func() -> void: _record(VillageEvent.Kind.WINDOW_OPENED, {"window": "popups.PopupAttackLog"}))
	_hud.windows().add_child(window)
	window.show_main(_now())


## The town window: buy the troll town ("buy_map"), then travel to it, as the client does; or travel between the towns.
func _open_towns() -> void:
	if _tutorial.is_active():
		return
	var window := TownWindow.new(_ui, _village, _config)
	window.buy_requested.connect(func(with_cash: bool) -> void:
		var result := _village.buy_second_town(with_cash, _now())
		if result != Village.Placement.OK:
			_hud.show_message(_config.text("POPUP_RAZA_NIVEL_TROLL").strip_edges().replace("#0#", str(Village.SECOND_TOWN_LEVEL)) \
					if result == Village.Placement.LEVEL_TOO_LOW else VillageHud.PLACEMENT_MESSAGES.get(result, ""))
			return
		window.queue_free()
		_travel(Village.SECOND_TOWN, "You bought the troll town."))
	window.travel_requested.connect(func(index: int) -> void:
		window.queue_free()
		_travel(index, ""))
	_hud.windows().add_child(window)


## Saves, then loads the other town of the save (TownManager.loadTown of the client).
func _travel(index: int, message: String) -> void:
	if not _save():
		return
	_town = index
	_reload_map(message)


## Pays the search ("get_enemy_new") and shows the enemy that the search
## finds (the server's "pvp/enemy"), or a message.
func _search_enemy() -> void:
	_close_spy()
	var result := _village.pay_pvp_search()
	if result != Village.Placement.OK:
		_show_village(true)
		_hud.show_placement_result(result)
		return
	_save()
	var pid := _neighbours.find_enemy(_village.player_id(), _village.get_level(), _now(), _rng)
	var enemy := _neighbours.load_village(pid, _now()) if not pid.is_empty() else null
	if enemy == null:
		_show_village(true)
		_hud.refresh(_village)
		_hud.show_message("No enemy found. Try again later.")
		return
	_enemy = {"pid": pid, "village": enemy, "name": enemy.player_name(), "loot": PvpBattle.loot_of(enemy, _village.get_level(), _config, _rng)}
	_spy = SpyScreen.new(enemy, _enemy["name"], _enemy["loot"], _village.pvp_search_cost(), _config, _sprites, _start_position(enemy))
	_spy.next_requested.connect(_search_enemy)
	_spy.home_requested.connect(func() -> void:
		_close_spy()
		_show_village(true))
	_spy.attack_requested.connect(_on_attack_requested)
	_select(null)
	_show_village(false)
	add_child(_spy)


func _close_spy() -> void:
	if _spy != null:
		_spy.queue_free()
		_spy = null


## The client asks before an attack that ends the shield of the player.
func _on_attack_requested(start_tile: Vector2i) -> void:
	if _village.shield_seconds(_now()) == 0:
		_start_attack(start_tile)
		return
	var window := ConfirmWindow.new(_ui, _config, _config.text("PVP_SHIELDS_ATTACK_CONFIRMATION").strip_edges())
	window.confirmed.connect(func() -> void: _start_attack(start_tile))
	var layer := CanvasLayer.new()
	layer.layer = WINDOW_LAYER
	layer.add_child(window)
	window.tree_exited.connect(layer.queue_free)
	_spy.add_child(layer)


## The attack starts ("begin_attack_new"): the own shield ends, and the whole
## army of the player goes, as getCurrentArmy() of the client.
func _start_attack(start_tile: Vector2i) -> void:
	if not _load_quest_graphics():
		return
	var army := _village.quest_army()
	if army.is_empty():
		_hud.show_message(_config.text("PVP_NEED_ARMY").strip_edges())
		return
	_village.drop_shield()
	_record(VillageEvent.Kind.ASSAULT_STARTED, {"level": _enemy["village"].get_level()})
	_save()
	var battle := PvpBattle.create(_enemy["village"], army, _enemy["loot"], start_tile, _config, _sprites, _rng, _village.get_level())
	_goals.watch_battle(battle.sim)
	SoundPlayer.play_music(SoundPlayer.Music.ASSAULT)
	_pvp_screen = PvpScreen.new(battle, _enemy["village"], _enemy["name"], start_tile, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
	_pvp_screen.village_changed.connect(_save)
	_pvp_screen.closed.connect(_on_attack_closed)
	_close_spy()
	add_child(_pvp_screen)


## The end of the attack: the save of the player ("end_attack",
## "end_attack_new" and the attacker part of "pvp/attack/end"), and the
## village of the enemy (NeighbourSource.record_attack()).
func _on_attack_closed(result: Dictionary) -> void:
	var old_level := _village.get_level()
	_village.end_pvp_attack(result)
	if not _neighbours.record_attack(_enemy["pid"], {"name": _village.player_name(), "level": old_level, "id": _village.player_id()}, result["won"], result["loot"], _now()):
		push_warning("Cannot write the attack into the village of %s." % _enemy["pid"])
	if result["won"]:
		_record(VillageEvent.Kind.ASSAULT_WON, {"amount": _village.attacks_won()})
	_init_map()
	_pvp_screen.queue_free()
	_pvp_screen = null
	_enemy = {}
	_show_village(true)
	_view.sync_items()
	_update_store()
	_update_production()
	_hud.refresh(_village)
	_hud.show_message(_level_up_text(old_level).strip_edges())


## The server stores whole seconds.
static func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Saves the village after a change. Shows the error and returns false when the save fails.
func _save() -> bool:
	if _enemies != null and _known_level < _village.get_level():
		SoundPlayer.play(SoundEffect.LEVEL_UP)  # PopupLevelUp
	# The client spawns the attacks of a new level when the player reaches it in the village.
	while _enemies != null and _known_level < _village.get_level():
		_known_level += 1
		if _enemies.on_level_up(_known_level, _now()):
			_view.sync_items()
	_goal_done = false
	var error := _village.save_to_file(_village_path)
	if error != OK:
		var text := "Cannot save the village to %s: %s" % [_village_path, error_string(error)]
		_hud.show_message(text)
		push_error(text)
		return false
	# A change of the level or of the mana changes the spell book.
	if _spell_book != null:
		_spell_book.refresh()
	return true


## Centre of the owned land, or the map centre when the village owns no land.
func _start_position(village: Village) -> Vector2:
	if village.owned_land.is_empty():
		return IsoGrid.tile_to_map(Vector2.ONE * IsoGrid.MAP_TILES / 2.0)
	var total := Vector2.ZERO
	for number in village.owned_land:
		var area := Vector2(float((number - 1) % IsoGrid.LAND_AREAS), float((number - 1) / IsoGrid.LAND_AREAS))
		total += (area + Vector2(0.5, 0.5)) * IsoGrid.LAND_TILES
	return IsoGrid.tile_to_map(total / village.owned_land.size())


func _show_message(text: String) -> void:
	push_error(text)
	var label := Label.new()
	label.text = text
	label.position = Vector2(20, 20)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)


func _save_screenshot(path: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Cannot save screenshot '%s': %s" % [path, error_string(error)])


static func _parse_options(args: PackedStringArray) -> Dictionary:
	var options := {}
	var i := 0
	while i < args.size():
		if args[i].begins_with("--") and i + 1 < args.size():
			options[args[i].trim_prefix("--")] = args[i + 1]
			i += 2
		else:
			push_warning("Ignored command line option '%s'." % args[i])
			i += 1
	return options
