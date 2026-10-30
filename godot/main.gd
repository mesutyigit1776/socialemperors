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


func _ready() -> void:
	_options = _parse_options(OS.get_cmdline_user_args())
	var data_dir: String = _options.get("data", OS.get_environment("SE_DATA_DIR"))
	if data_dir.is_empty():
		data_dir = "user://imported"
	_village_path = _options.get("village", data_dir.path_join("villages/initial.json"))

	_config = GameConfig.load_from_file(data_dir.path_join("config.json"))
	_village = Village.load_from_file(_village_path, _config) if _config != null else null
	if _village == null:
		_show_message("Cannot start. Import the game files first; see godot/README.md.\nData folder: %s" % ProjectSettings.globalize_path(data_dir))
	else:
		_sprites = SpriteLibrary.new(data_dir)
		_view = VillageView.new()
		add_child(_view)
		_view.show_village(_village, _config, _sprites)
		_view.placement_confirmed.connect(_on_placement_confirmed)
		var camera := MapCamera.new()
		camera.position = _start_position(_village)
		add_child(camera)
		# Only decorations for now: the client limits the number of most other
		# buildings, and the port does not have these limits yet.
		var store_items: Array[GameConfig.ItemDef] = []
		for item in _config.store_items(GameConfig.CATEGORY_DECORATIONS):
			if _sprites.get_sprite(item.img_name) != null:
				store_items.append(item)
		_hud = VillageHud.new(store_items)
		_hud.item_selected.connect(_on_item_selected)
		add_child(_hud)
		_hud.refresh(_village)

	if _options.has("screenshot"):
		await _save_screenshot(_options["screenshot"])
		get_tree().quit()


func _on_item_selected(item: GameConfig.ItemDef) -> void:
	_view.begin_placement(item, _village, _sprites)
	_hud.show_message("Place %s." % item.name)


func _on_placement_confirmed(item: GameConfig.ItemDef, tile: Vector2i) -> void:
	var old_level := _village.get_level()
	var result := _village.buy(item, tile, int(Time.get_unix_time_from_system()))
	if result != Village.Placement.OK:
		_hud.show_placement_result(result)
		return
	_view.end_placement()
	_view.add_placed(_village.items.back(), _config, _sprites)
	_hud.refresh(_village)
	var error := _village.save_to_file(_village_path)
	if error != OK:
		var text := "Cannot save the village to %s: %s" % [_village_path, error_string(error)]
		_hud.show_message(text)
		push_error(text)
		return
	var text := "Built %s." % item.name
	for level in range(old_level + 1, _village.get_level() + 1):
		var reached := _config.levels[level - 1]
		text += " Level %d, %s: you get %d %s" % [level, reached.name, reached.reward_amount, VillageHud.RESOURCE_NAMES.get(reached.reward_type, reached.reward_type)]
		if level >= _config.start_level_mana_reward:
			text += " and %d mana" % _config.mana_reward_per_level
		text += "."
	_hud.show_message(text)


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
