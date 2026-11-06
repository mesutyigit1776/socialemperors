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
var _known_level := 0  # The level for which the attacks of a new level came, see _save().
var _frames := FrameCache.new()  # The drawn frames of the map and the windows.


func _ready() -> void:
	_options = _parse_options(OS.get_cmdline_user_args())
	var data_dir: String = _options.get("data", OS.get_environment("SE_DATA_DIR"))
	if data_dir.is_empty():
		data_dir = "user://imported"
	_data_dir = data_dir
	add_child(_frames)
	_village_path = _options.get("village", data_dir.path_join("villages/initial.json"))

	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	_store = Store.load_from_file(data_dir.path_join("shop.json"), _config) if _config != null else null
	_village = Village.load_from_file(_village_path, _config) if _store != null else null
	if _village == null:
		_show_message("Cannot start. Import the game files first; see godot/README.md.\nData folder: %s" % ProjectSettings.globalize_path(data_dir))
	elif _options.has("battle"):
		_sprites = SpriteLibrary.new(data_dir, _frames)
		_start_battle(_options["battle"], SpriteLibrary.new(data_dir, _frames, "fx"))
	else:
		_sprites = SpriteLibrary.new(data_dir, _frames)
		_view = VillageView.new()
		add_child(_view)
		_view.show_village(_village, _config, _sprites)
		_view.placement_confirmed.connect(_on_placement_confirmed)
		_view.move_confirmed.connect(_on_move_confirmed)
		_view.map_clicked.connect(_on_map_clicked)
		_specials = SpecialActions.new(_village, _config, _rng)
		_orders = UnitOrders.new(_village, _view, _config, _rng)
		_orders.village_changed.connect(_on_units_changed)
		_orders.order_failed.connect(func(text: String) -> void: _hud.show_message(text))
		add_child(_orders)
		_camera = MapCamera.new()
		_camera.position = _start_position(_village)
		add_child(_camera)
		_hud = VillageHud.new()
		_hud.item_selected.connect(_on_item_selected)
		_hud.move_requested.connect(_on_move_requested)
		_hud.sell_confirmed.connect(_on_sell_confirmed)
		_hud.rotate_requested.connect(_on_rotate_requested)
		_hud.collect_requested.connect(func() -> void: _collect(_selected))
		_hud.hurry_requested.connect(func() -> void: _collect(_selected, true))
		_hud.work_time_chosen.connect(_on_work_time_chosen)
		_hud.train_requested.connect(_on_train_requested)
		_hud.speed_up_requested.connect(_on_speed_up_requested)
		_hud.unqueue_requested.connect(_on_unqueue_requested)
		_hud.unit_out_requested.connect(_on_unit_out_requested)
		_hud.warehouse_unit_out_requested.connect(_on_warehouse_unit_out_requested)
		_hud.warehouse_slot_requested.connect(_on_warehouse_slot_requested)
		_hud.action_requested.connect(_on_action_requested)
		_hud.collections_requested.connect(func() -> void: _show_panel(SpecialActions.View.COLLECTIONS))
		_hud.stored_items_requested.connect(func() -> void: _show_panel(SpecialActions.View.STORE))
		_hud.quests_requested.connect(_open_quests)
		_hud.survival_requested.connect(_open_survival)
		_hud.tournament_requested.connect(_open_tournament)
		add_child(_hud)
		_windows.layer = WINDOW_LAYER
		add_child(_windows)
		_spell_layer.layer = SPELL_LAYER
		add_child(_spell_layer)
		_add_spell_book()
		# The client spawns the wild animals when it loads the map.
		if not _village.spawn_animals(_now(), _rng).is_empty():
			_view.sync_items()
			_save()
		_enemies = VillageEnemies.new(_village, _view, _config, _rng, _orders.is_busy)
		_enemies.fight_needed.connect(func() -> void: _start_village_fight())
		add_child(_enemies)
		_known_level = _village.get_level()
		if _enemies.on_map_loaded(_now()):
			_view.sync_items()
			_save()
		var kinds := {"siege": CollectiveAI.Kind.SIEGE, "stampede": CollectiveAI.Kind.BIG_MOUNTS, "army": CollectiveAI.Kind.ARMY, "bandits": CollectiveAI.Kind.BANDITS}
		if kinds.has(_options.get("village-attack", "")):
			_enemies.add_due_attack(kinds[_options["village-attack"]])
		_update_store()
		var clock := Timer.new()
		clock.timeout.connect(_on_clock)
		add_child(clock)
		clock.start(1.0)
		_update_production()

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
	_survival_screen = SurvivalScreen.new(survival, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
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
	_known_level = _village.get_level()
	_enemies.on_map_loaded(_now())
	_save()
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
	_tournament_screen.village_changed.connect(_save)
	_tournament_screen.closed.connect(func(score: int, won: bool) -> void:
		_tournament_scores[bot_index] = [score, won]
		_known_level = _village.get_level()
		_enemies.on_map_loaded(_now())
		_save()
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
	_quest_screen = QuestScreen.new(quest, _village, _ui, _cast_ui, _spell_graphics, _config, _sprites, _effects)
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
	_known_level = _village.get_level()
	_enemies.on_map_loaded(_now())
	_save()
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
	_select(null)
	_placing_stored = false
	_view.begin_placement(item)
	_hud.show_message("Place %s." % item.name)


## With a unit selected, a click sends the unit to a free tile, into a building
## or to a resource that it can use. Otherwise a click on a ready building collects from it, as in the
## original game, and a click on an item selects it.
func _on_map_clicked(tile: Vector2i, placed: Village.PlacedItem) -> void:
	if (placed != null and _village.is_enemy_unit(placed)) or _enemies.has_attacker_at(tile):
		_start_village_fight(_selected if _selected != null and _village.is_own_unit(_selected) else null, tile)
		return
	if _selected != null and _village.is_own_unit(_selected) and placed != _selected \
			and (placed == null or _village.can_enter(_selected, placed) or _village.can_harvest(_selected, placed)):
		var error := _orders.order(_selected, tile, placed)
		_hud.show_message(error)
		if error.is_empty():
			_select(null)
		return
	if placed != null and _village.seconds_to_ready(placed, _now()) == 0:
		_collect(placed)
		if placed not in _village.items:
			return
	_select(placed)


func _select(placed: Village.PlacedItem) -> void:
	_selected = placed
	_panel = SpecialActions.View.BUILDING if placed != null else SpecialActions.View.NONE
	_view.show_selection(placed)
	var item := _config.get_item(placed.item_id) if placed != null else null
	_hud.show_selection(item, placed != null and _village.can_move(placed), placed != null and _village.can_sell(placed), placed != null and _village.can_rotate(placed))
	var names: Array[String] = []
	if placed != null:
		for id in _village.units_in(placed):
			names.append(_config.get_item(id).name)
	_hud.show_units(names)
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
		_hud.show_warehouse(stored, _village.warehoused_count(), _village.warehouse_capacity(), price)
	else:
		_hud.show_warehouse(null, 0, 0, 0)
	_update_production()


func _on_clock() -> void:
	var now := _now()
	var changed := false
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
	_update_production()
	_update_store()


## Puts the trained units of the building on the map. Returns true when a unit came out.
func _complete_training(building: Village.PlacedItem, now: int) -> bool:
	var unit := _village.complete_training(building, now)
	var trained := unit != null
	while unit != null:
		_view.add_placed(unit)
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
		# The client gives the free buildings when it loads the map and at a new level.
		var free := _village.add_free_buildings(now)
		for placed in free:
			_view.add_placed(placed)
		if not free.is_empty():
			_save()
			_hud.show_message("You got a free %s." % " and a free ".join(free.map(func(placed: Village.PlacedItem) -> String: return _config.get_item(placed.item_id).name)))
		# An import before this window has only the message above.
		if _ui != null and _ui.has_symbol("PopUpAlertaMC") and free.any(func(placed: Village.PlacedItem) -> bool: return placed.item_id == Village.WIZARDRY):
			_windows.add_child(PictureAlertWindow.new(_ui, _config, _config.text("AVISO_GRIMORIO_TITULO"), _config.text("AVISO_GRIMORIO_DESCRIPCION"), "alert_magic.jpg"))
		var categories := []
		for category_id in Store.CATEGORIES:
			var offered: Array[GameConfig.ItemDef] = []
			for item in _store.items(category_id, _village.race, _village.get_level(), now):
				if _sprites.get_sprite(item.img_name) != null:
					offered.append(item)
			var name: String = _config.category_names.get(category_id, str(category_id))
			if category_id == Store.CATEGORY_NEW:
				var end := Time.get_datetime_dict_from_unix_time(_store.rotation_end(now) + Time.get_time_zone_from_system()["bias"] * 60)
				name += " (until %04d-%02d-%02d %02d:%02d)" % [end["year"], end["month"], end["day"], end["hour"], end["minute"]]
			categories.append([name, offered])
		_hud.set_categories(categories)
	_hud.refresh(_village)


## Updates the marks of the ready buildings and the production of the selected building.
func _update_production() -> void:
	var now := _now()
	_view.update_production(now)
	if _selected == null or not _village.is_producer(_selected):
		_hud.show_production(null, 0, "", 0, false, "")
	else:
		var item := _config.get_item(_selected.item_id)
		var requirement := ""
		if _selected.item_id == Village.NURSERY and _village.needs_units(_selected):
			requirement = "Breeds a new animal from two animals of the same kind. Select a captured animal, then click the nursery."
		elif _village.needs_units(_selected):
			requirement = "Works only with a unit in it. Select a unit, then click the building."
		_hud.show_production(item, _village.seconds_to_ready(_selected, now), _product_text(_selected), _village.collect_cost(_selected), _village.can_hurry(_selected, now), requirement)
	var unit := _village.trained_unit(_selected) if _selected != null else null
	if unit == null:
		_hud.show_training(null, {}, 0, -1, 0)
	else:
		_hud.show_training(unit, _village.training_costs(unit), _village.queued_units(_selected), _village.seconds_to_trained(_selected, now), _village.speed_up_cost(_selected, now))
	var panel := _specials.describe(_panel, _selected, now)
	_hud.show_actions(panel[0], panel[1])


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
	_update_production()
	_hud.show_message(outcome.text)


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
	var old_level := _village.get_level()
	var result := _village.place_stored(item, tile, _now(), frame) if _placing_stored else _village.buy(item, tile, _now(), frame)
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.end_placement()
	_view.add_placed(_village.items.back())
	_update_store()
	if not _save():
		return
	_hud.show_message(("Placed %s from the item store." % item.name) if _placing_stored else "Built %s.%s" % [item.name, _level_up_text(old_level)])
	_placing_stored = false


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


## The server stores whole seconds.
static func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Saves the village after a change. Shows the error and returns false when the save fails.
func _save() -> bool:
	# The client spawns the attacks of a new level when the player reaches it in the village.
	while _enemies != null and _known_level < _village.get_level():
		_known_level += 1
		if _enemies.on_level_up(_known_level, _now()):
			_view.sync_items()
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
