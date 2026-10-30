extends Node2D
## Loads the imported data and shows a village.
##
## Command line options (after "--"):
##   --data <dir>          folder that importer/import_assets.py wrote
##                         (default: the SE_DATA_DIR environment variable, then user://imported)
##   --village <file>      village save (default: <data>/villages/initial.json)
##   --screenshot <png>    save the first frames as an image and quit; used for checks

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
var _rng := RandomNumberGenerator.new()  # Kinds of the deposits that grow again.


func _ready() -> void:
	_options = _parse_options(OS.get_cmdline_user_args())
	var data_dir: String = _options.get("data", OS.get_environment("SE_DATA_DIR"))
	if data_dir.is_empty():
		data_dir = "user://imported"
	_village_path = _options.get("village", data_dir.path_join("villages/initial.json"))

	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	_store = Store.load_from_file(data_dir.path_join("shop.json"), _config) if _config != null else null
	_village = Village.load_from_file(_village_path, _config) if _store != null else null
	if _village == null:
		_show_message("Cannot start. Import the game files first; see godot/README.md.\nData folder: %s" % ProjectSettings.globalize_path(data_dir))
	else:
		_sprites = SpriteLibrary.new(data_dir)
		_view = VillageView.new()
		add_child(_view)
		_view.show_village(_village, _config, _sprites)
		_view.placement_confirmed.connect(_on_placement_confirmed)
		_view.move_confirmed.connect(_on_move_confirmed)
		_view.map_clicked.connect(_on_map_clicked)
		_orders = UnitOrders.new(_village, _view, _config)
		_orders.village_changed.connect(_on_units_changed)
		_orders.order_failed.connect(func(text: String) -> void: _hud.show_message(text))
		add_child(_orders)
		var camera := MapCamera.new()
		camera.position = _start_position(_village)
		add_child(camera)
		_hud = VillageHud.new()
		_hud.item_selected.connect(_on_item_selected)
		_hud.move_requested.connect(_on_move_requested)
		_hud.sell_confirmed.connect(_on_sell_confirmed)
		_hud.rotate_requested.connect(_on_rotate_requested)
		_hud.collect_requested.connect(func() -> void: _collect(_selected))
		_hud.hurry_requested.connect(func() -> void: _collect(_selected, true))
		_hud.work_time_chosen.connect(_on_work_time_chosen)
		_hud.train_requested.connect(_on_train_requested)
		_hud.unit_out_requested.connect(_on_unit_out_requested)
		add_child(_hud)
		_update_store()
		var clock := Timer.new()
		clock.timeout.connect(_on_clock)
		add_child(clock)
		clock.start(1.0)
		_update_production()

	if _options.has("screenshot"):
		await _save_screenshot(_options["screenshot"])
		get_tree().quit()


func _on_item_selected(item: GameConfig.ItemDef) -> void:
	_select(null)
	_view.begin_placement(item)
	_hud.show_message("Place %s." % item.name)


## With a unit selected, a click sends the unit to a free tile, into a building
## or to a resource that it can use. Otherwise a click on a ready building collects from it, as in the
## original game, and a click on an item selects it.
func _on_map_clicked(tile: Vector2i, placed: Village.PlacedItem) -> void:
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
	_view.show_selection(placed)
	var item := _config.get_item(placed.item_id) if placed != null else null
	_hud.show_selection(item, placed != null and _village.can_move(placed), placed != null and _village.can_sell(placed), placed != null and _village.can_rotate(placed))
	var names: Array[String] = []
	if placed != null:
		for id in _village.units_in(placed):
			names.append(_config.get_item(id).name)
	_hud.show_units(names)
	if placed != null and _village.is_own_unit(placed):
		_hud.show_message("%s: click a place to walk, a building to work in it, or a tree, stone or gold to harvest it." % item.name)
	_update_production()


func _on_clock() -> void:
	var now := _now()
	var changed := false
	for placed in _village.items.duplicate():
		var unit := _village.complete_training(placed, now)
		while unit != null:
			changed = true
			_view.add_placed(unit)
			_hud.show_message("%s is trained." % _config.get_item(unit.item_id).name)
			unit = _village.complete_training(placed, now)
	for change: Array in _village.regrow(now, _rng):
		changed = true
		_view.remove_placed(change[0])
		_view.add_placed(change[1])
	if changed:
		_save()
	_update_production()
	_update_store()


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
		_hud.show_production(null, 0, 0, 0, false, false)
	else:
		_hud.show_production(_config.get_item(_selected.item_id), _village.seconds_to_ready(_selected, now), _village.collect_amount(_selected), _village.collect_cost(_selected), _village.can_hurry(_selected, now), _village.needs_units(_selected))
	var unit := _village.trained_unit(_selected) if _selected != null else null
	if unit == null:
		_hud.show_training(null, {}, 0, -1)
	else:
		_hud.show_training(unit, _village.training_costs(unit), _village.queued_units(_selected), _village.seconds_to_trained(_selected, now))


## With hurry, the player pays cash to collect before the building is ready.
func _collect(placed: Village.PlacedItem, hurry: bool = false) -> void:
	var item := _config.get_item(placed.item_id)
	var old_level := _village.get_level()
	var amount := _village.collect_amount(placed)
	var cost := _village.collect_cost(placed)
	var cash_before := _village.get_resource("c")
	var result := _village.hurry(placed, _now()) if hurry else _village.collect(placed, _now())
	match result:
		Village.Production.OK:
			_update_production()
		Village.Production.FARM_REMOVED:
			if _selected == placed:
				_select(null)
			_view.remove_placed(placed)
		Village.Production.NOT_READY:
			_hud.show_message("%s is not ready." % item.name)
			return
		Village.Production.NO_UNITS:
			_hud.show_message("%s works only with a unit in it." % item.name)
			return
		Village.Production.NOT_ENOUGH_CASH:
			_hud.show_message("You need %d cash to finish %s now." % [Village.HURRY_COST, item.name])
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
		var text := "Collected %d %s from %s." % [amount, VillageHud.RESOURCE_NAMES.get(item.collect_type, item.collect_type), item.name]
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
	var result := _village.sell(placed)
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_select(null)
	_view.remove_placed(placed)
	_update_store()
	if _save():
		_hud.show_message("Sold %s." % item.name)


func _on_placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i, frame: int) -> void:
	var old_level := _village.get_level()
	var result := _village.buy(item, tile, _now(), frame)
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.end_placement()
	_view.add_placed(_village.items.back())
	_update_store()
	if not _save():
		return
	_hud.show_message("Built %s.%s" % [item.name, _level_up_text(old_level)])


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


## The server stores whole seconds.
static func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Saves the village after a change. Shows the error and returns false when the save fails.
func _save() -> bool:
	var error := _village.save_to_file(_village_path)
	if error != OK:
		var text := "Cannot save the village to %s: %s" % [_village_path, error_string(error)]
		_hud.show_message(text)
		push_error(text)
		return false
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
