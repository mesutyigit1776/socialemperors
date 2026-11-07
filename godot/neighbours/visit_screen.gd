class_name VisitScreen
extends Node2D
## A visit to a neighbour (GameMode.NEIGHBOUR of the client): the village of
## the neighbour, which the player can look at and help, but not change.
##
## A click on a building that can be helped (VillageSocial.is_assistable())
## helps it, up to VillageSocial.ASSIST_CLICKS buildings in one visit, when
## the player can help the neighbour (VillageSocial.can_assist()) and did not
## help them in this session. A helped building gets a mark. The client shows
## gold and experience over it, but does not give them in a visit; it gives
## honour for the fifth building, which the owner applies at the end
## (VillageSocial.assist_neighbour()).

signal helped  ## One building was helped.
signal closed(clicks: Array)  ## The helped buildings, as [x, y, item id] entries.

var _neighbour: Village
var _config: GameConfig
var _can_help: bool
var _clicks: Array = []
var _marked: Array[Village.PlacedItem] = []
var _view := VillageView.new()
var _camera := MapCamera.new()
var _status := Label.new()
var _message := Label.new()


## entry: the entry of the neighbour bar, see NeighbourBar.entries().
func _init(neighbour: Village, entry: Dictionary, can_help: bool, config: GameConfig, sprites: SpriteLibrary, start_position: Vector2) -> void:
	_neighbour = neighbour
	_config = config
	_can_help = can_help
	add_child(_view)
	_view.show_village(neighbour, config, sprites)
	_view.map_clicked.connect(_on_map_clicked)
	_camera.position = start_position
	add_child(_camera)
	var layer := CanvasLayer.new()
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	var column := VBoxContainer.new()
	var title := Label.new()
	title.text = "%s  (level %d)" % [entry["name"], entry["level"]]
	title.add_theme_font_size_override("font_size", 20)
	var home := Button.new()
	home.text = "Return home"
	home.pressed.connect(func() -> void: closed.emit(_clicks))
	for control: Control in [title, _status, _message, home]:
		column.add_child(control)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 300
	panel.add_child(column)
	layer.add_child(panel)
	add_child(layer)
	_show_status()


func _on_map_clicked(_tile: Vector2i, placed: Village.PlacedItem) -> void:
	if placed == null or not VillageSocial.is_assistable(_config.get_item(placed.item_id)) or placed in _marked:
		return
	if not _can_help or _clicks.size() >= VillageSocial.ASSIST_CLICKS:
		_message.text = _config.text("AVISO_SIN_AYUDAS").strip_edges()
		return
	_clicks.append([placed.tile.x, placed.tile.y, placed.item_id])
	_marked.append(placed)
	_view.show_marks(_marked, [])
	_message.text = "You helped the %s." % _config.get_item(placed.item_id).name
	if _clicks.size() == VillageSocial.ASSIST_CLICKS:
		_message.text += " You get %d honour." % _config.honour_help_friend
	helped.emit()
	_show_status()


func _show_status() -> void:
	if _can_help:
		_status.text = "Help: %d of %d buildings left. Click a farm, a mill, a mine or a ranch." % [VillageSocial.ASSIST_CLICKS - _clicks.size(), VillageSocial.ASSIST_CLICKS]
	else:
		_status.text = "You cannot help this neighbour again today."
