class_name StartScreen
extends Control
## The first screen of the port, in place of the login page of the server
## (templates/login.html and new_empire.html): the saves of the player, each
## with a button to continue it, and a name field to start a new empire. The
## owner makes the empire (Village.new_empire()) and loads the chosen save.

signal save_chosen(path: String)
signal empire_requested(player_name: String)

## The text of the server's check_player_name().
const NAME_RULE := "The name must have 3 to 16 characters: letters, numbers and spaces."
const PICTURE := "townHuman.png"
const PICTURE_HEIGHT := 180

var _name_field := LineEdit.new()
var _error := Label.new()


## save_dir: the folder of the saves (<player id>.save.json).
func _init(ui: UiLibrary, save_dir: String) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ClientTheme.make(ui)
	var cover := ColorRect.new()
	cover.color = Color8(0x1e, 0x14, 0x0a)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	centre.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "Social Empires"
	title.add_theme_font_override("font", ui.named_font(ClientTheme.TITLE_FONT))
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var texture := ui.image(PICTURE)
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(0, PICTURE_HEIGHT)
		rows.add_child(picture)

	var saves := list_saves(save_dir)
	if not saves.is_empty():
		rows.add_child(_heading("Continue"))
		var list := VBoxContainer.new()
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, mini(saves.size(), 4) * 38)
		scroll.add_child(list)
		rows.add_child(scroll)
		for entry: Dictionary in saves:
			var line := HBoxContainer.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var label := Label.new()
			label.text = "%s ~ level %d (%d xp)" % [entry["name"], entry["level"], entry["xp"]]
			label.tooltip_text = entry["path"].get_file()
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(label)
			var play := Button.new()
			play.text = "Play"
			play.pressed.connect(func() -> void: save_chosen.emit(entry["path"]))
			line.add_child(play)
			list.add_child(line)

	rows.add_child(_heading("New empire"))
	var line := HBoxContainer.new()
	_name_field.placeholder_text = "Player name"
	_name_field.max_length = 16
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.text_submitted.connect(func(_text: String) -> void: _request_empire())
	line.add_child(_name_field)
	var start := Button.new()
	start.text = "Start"
	start.pressed.connect(_request_empire)
	line.add_child(start)
	rows.add_child(line)
	_error.add_theme_color_override("font_color", Color8(0xb0, 0x10, 0x10))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD
	_error.visible = false
	rows.add_child(_error)


## The saves in save_dir, the last changed first, as the login page of the
## server shows them: {"path", "name", "level", "xp"} of the town that the
## save names in default_map. Files that are not saves are left out.
static func list_saves(save_dir: String) -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(save_dir):
		return saves
	for file in DirAccess.get_files_at(save_dir):
		if not file.ends_with(".save.json"):
			continue
		var path := save_dir.path_join(file)
		var data := VillageMap.read_save(path)
		if data.is_empty():
			continue
		var maps: Array = data["maps"]
		var index: Variant = GameConfig.to_int(data["playerInfo"].get("default_map"))
		var town: Variant = maps[index] if index != null and index >= 0 and index < maps.size() else maps[0]
		if not town is Dictionary:
			continue
		var level: Variant = GameConfig.to_int(town.get("level"))
		var xp: Variant = GameConfig.to_int(town.get("xp"))
		saves.append({"path": path, "name": str(data["playerInfo"].get("name", "")), "level": level if level != null else 0,
			"xp": xp if xp != null else 0, "time": FileAccess.get_modified_time(path)})
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] > b["time"])
	return saves


## Shows that the empire could not be made.
func show_error(text: String) -> void:
	_error.text = text
	_error.visible = true


func _request_empire() -> void:
	if not Village.valid_player_name(_name_field.text):
		show_error(NAME_RULE)
		return
	empire_requested.emit(_name_field.text)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label
