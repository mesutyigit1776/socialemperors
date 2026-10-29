extends Node2D
## Loads the imported data and shows a village.
##
## Command line options (after "--"):
##   --data <dir>          folder that importer/import_assets.py wrote
##                         (default: the SE_DATA_DIR environment variable, then user://imported)
##   --village <file>      village save (default: <data>/villages/initial.json)
##   --screenshot <png>    save the first frames as an image and quit; used for checks

var _options: Dictionary = {}


func _ready() -> void:
	_options = _parse_options(OS.get_cmdline_user_args())
	var data_dir: String = _options.get("data", OS.get_environment("SE_DATA_DIR"))
	if data_dir.is_empty():
		data_dir = "user://imported"
	var village_path: String = _options.get("village", data_dir.path_join("villages/initial.json"))

	var config := GameConfig.load_from_file(data_dir.path_join("config.json"))
	var village := Village.load_from_file(village_path) if config != null else null
	if village == null:
		_show_message("Cannot start. Import the game files first; see godot/README.md.\nData folder: %s" % ProjectSettings.globalize_path(data_dir))
	else:
		var view := VillageView.new()
		add_child(view)
		view.show_village(village, config, SpriteLibrary.new(data_dir))
		var camera := MapCamera.new()
		camera.position = _start_position(village)
		add_child(camera)

	if _options.has("screenshot"):
		await _save_screenshot(_options["screenshot"])
		get_tree().quit()


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
