class_name ImportScreen
extends Control
## The screen of the first start: the port has no data folder yet, or an
## import into it did not finish. The player selects the socialemperors folder
## (a clone or a release download); the screen runs the import (AssetImport)
## with a progress bar, and then emits finished. The import runs some steps
## in each frame (FRAME_MSEC), so that the window stays open to input. The
## client art is not there yet, so the screen uses the controls of Godot.

signal finished

const TEXT := "Social Empires needs the game files of the original game. Select your socialemperors folder (a clone or a release download of the server). The port reads the game files from it and writes its data folder:\n%s"
const CONTINUE_TEXT := "The last import did not finish. Select the same folder to continue it."
const PADDING := 24
const FRAME_MSEC := 25  ## The time of the import in each frame.

var _data_dir: String
var _folder := LineEdit.new()
var _browse := Button.new()
var _start := Button.new()
var _stop := Button.new()
var _progress := ProgressBar.new()
var _status := Label.new()
var _dialog := FileDialog.new()
var _import: AssetImport  ## The import that runs, or null.
var _step_text := ""  ## The last step of the import.


func _init(data_dir: String) -> void:
	_data_dir = data_dir
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color8(0x1e, 0x14, 0x0a)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Social Empires: import the game files"
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	var text := Label.new()
	text.text = TEXT % ProjectSettings.globalize_path(data_dir)
	var unfinished := AssetImport.unfinished_source(data_dir)
	if not unfinished.is_empty():
		text.text += "\n\n" + CONTINUE_TEXT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(text)

	var line := HBoxContainer.new()
	_folder.placeholder_text = "socialemperors folder"
	_folder.text = unfinished if not unfinished.is_empty() else _suggested_folder()
	_folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_folder)
	_browse.text = "Browse..."
	_browse.pressed.connect(func() -> void:
		if DirAccess.dir_exists_absolute(_folder.text):
			_dialog.current_dir = _folder.text
		_dialog.popup_centered_ratio(0.7))
	line.add_child(_browse)
	rows.add_child(line)

	var buttons := HBoxContainer.new()
	_start.text = "Import"
	_start.pressed.connect(_on_start)
	buttons.add_child(_start)
	_stop.text = "Stop"
	_stop.disabled = true
	_stop.tooltip_text = "The import stops after the graphic that it does. Start it again to continue."
	_stop.pressed.connect(func() -> void:
		_import.stop_requested = true
		_stop.disabled = true
		_status.text = "Stopping...")
	buttons.add_child(_stop)
	rows.add_child(buttons)
	_progress.custom_minimum_size = Vector2(0, 24)
	rows.add_child(_progress)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 48)
	rows.add_child(_status)

	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.title = "Select the socialemperors folder"
	_dialog.dir_selected.connect(func(dir: String) -> void: _folder.text = dir)
	add_child(_dialog)


## The folder above the project when the port runs from a clone of the repository; else "".
static func _suggested_folder() -> String:
	var folder := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	return folder if AssetImport.check_source(folder).is_empty() else ""


func _on_start() -> void:
	var folder := _folder.text.strip_edges()
	var error := AssetImport.check_source(folder)
	if not error.is_empty():
		_status.text = error
		return
	for control: BaseButton in [_start, _browse]:
		control.disabled = true
	_folder.editable = false
	_status.text = "Reading the configuration..."
	_progress.value = 0
	# The first part of the import takes about a second; the text shows before it.
	await RenderingServer.frame_post_draw
	_import = AssetImport.new(folder, _data_dir)
	_import.on_progress = func(_done: int, _total: int, text: String) -> void: _step_text = text
	error = _import.begin()
	if not error.is_empty():
		_on_done(error)
		return
	_progress.max_value = _import.total
	_stop.disabled = false


func _process(_delta: float) -> void:
	if _import == null:
		return
	var start := Time.get_ticks_msec()
	var more := true
	while more and Time.get_ticks_msec() - start < FRAME_MSEC:
		more = _import.step()
	_progress.value = _import.done
	_status.text = "%d of %d: %s" % [_import.done, _import.total, _step_text]
	if not more:
		_on_done(_import.finish())


func _on_done(error: String) -> void:
	for control: BaseButton in [_start, _browse]:
		control.disabled = false
	_folder.editable = true
	_stop.disabled = true
	var import := _import
	_import = null
	if error == "stopped":
		_status.text = "The import stopped. Press Import to continue it."
	elif not error.is_empty():
		_status.text = error
	else:
		for failure in import.failed:
			push_warning("not imported: " + failure)
		finished.emit()
