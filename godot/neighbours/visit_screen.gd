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

## The parts of the HUD that a visit does not show (StateNeighbour of the client).
const HIDDEN := ["barraAttackArriba", "questProgressButton", "panelCollection", "options_panel", "topRight/hudShield", "bgBar/btnExit",
		"bgBar/iconMenu", "bgBar/iconMenuGift", "bgBar/iconMenuWorld", "bgBar/iconMenuGames", "bgBar/btnSelectAll", "bgBar/btnSelectSpecials",
		"bgBar/bulldozer", "bgBar/recolectaRapido", "bgBar/mcTrolls", "bgBar/giftCounter", "bgBar/normalMouse/btnNoArrow", "bgBar/gamesButton",
		"bgBar/recuadroInfo"]
## The frame of topLeft for a visit (GameMode.NEIGHBOUR).
const NEIGHBOUR_FRAME := 1

var _neighbour: Village
var _config: GameConfig
var _can_help: bool
var _clicks: Array = []
var _marked: Array[Village.PlacedItem] = []
var _view := VillageView.new()
var _camera := MapCamera.new()
var _gui: UiClip
var _top_y: Dictionary
var _message := Label.new()


## entry: the entry of the neighbour bar, see NeighbourBar.entries().
func _init(ui: UiLibrary, neighbour: Village, entry: Dictionary, can_help: bool, config: GameConfig, sprites: SpriteLibrary, start_position: Vector2) -> void:
	_neighbour = neighbour
	_config = config
	_can_help = can_help
	add_child(_view)
	_view.show_village(neighbour, config, sprites)
	_view.map_clicked.connect(_on_map_clicked)
	_camera.position = start_position
	add_child(_camera)
	var layer := CanvasLayer.new()
	# The HUD of the client shows the neighbour: the resources, the name and
	# level in the experience bar, and the bolts of the help that is left.
	_gui = ui.make("GuiMC")
	_top_y = VillageHud.top_positions(_gui)
	for path: String in HIDDEN:
		_gui.set_part_visible(path, false)
	for path: String in ["bgBar", "topLeft", "topRight", "experienceBar", "cash"]:
		_gui.clip(path).take_mouse()
	_gui.clip("topLeft").show_frame(NEIGHBOUR_FRAME)
	for field: Array in VillageHud.RESOURCE_FIELDS:
		_gui.set_text(field[0], VillageHud.formatted(neighbour.get_resource(field[1])))
	_gui.set_text("experienceBar/exp", entry["name"])
	_gui.set_text("experienceBar/levelText", str(entry["level"]))
	_gui.clip("experienceBar/expMask").scale.x = 0.0
	_gui.set_text("topRight/nameText", neighbour.map_name())
	_gui.set_text("topRight/visitorsText", "%d/%d" % [neighbour.population(), neighbour.max_population()])
	_gui.set_text("bgBar/herramientaCuadrado/cuadradoText", config.text("ICON_SQUARE_TOOL"))
	_gui.set_part_visible("bgBar/herramientaCuadrado/spaceKeyText", false)
	var home := _gui.clip("bgBar/returnHome")
	home.visible = true
	home.make_button()
	home.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # GuiManager.returnHome
		closed.emit(_clicks))
	layer.add_child(_gui)
	_message.add_theme_font_override("font", ui.named_font(ClientTheme.BODY_FONT))
	_message.add_theme_font_size_override("font_size", 15)
	_message.add_theme_color_override("font_color", Color.WHITE)
	_message.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0, 1))
	_message.add_theme_constant_override("outline_size", 5)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_message)
	add_child(layer)
	_show_status()


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	VillageHud.place_gui(_gui, _top_y, size)
	_message.position = Vector2(_gui.position.x + 60, size.y - VillageHud.BAR_HEIGHT - 70)
	_message.size = Vector2(VillageHud.CLIENT_WIDTH - 120, 60)


func _on_map_clicked(_tile: Vector2i, placed: Village.PlacedItem) -> void:
	if placed == null or not VillageSocial.is_assistable(_config.get_item(placed.item_id)) or placed in _marked:
		return
	if not _can_help or _clicks.size() >= VillageSocial.ASSIST_CLICKS:
		_message.text = _config.text("AVISO_SIN_AYUDAS").strip_edges()
		return
	_clicks.append([placed.tile.x, placed.tile.y, placed.item_id])
	SoundPlayer.play(SoundEffect.COLLECTION)  # At the end of the help bar (FauxBar2).
	_marked.append(placed)
	_view.show_marks(_marked, [])
	_message.text = "You helped the %s." % _config.get_item(placed.item_id).name
	if _clicks.size() == VillageSocial.ASSIST_CLICKS:
		_message.text += " You get %d honour." % _config.honour_help_friend
	helped.emit()
	_show_status()


## GuiManager.refreshNeighbourStats: a bolt for each building that the player can still help.
func _show_status() -> void:
	var left := VillageSocial.ASSIST_CLICKS - _clicks.size() if _can_help else 0
	for index in range(1, VillageSocial.ASSIST_CLICKS + 1):
		_gui.set_part_visible("topLeft/rayoNeighbour_%02d" % index, index <= left)
	if _message.text.is_empty():
		_message.text = "Click a farm, a mill, a mine or a ranch to help it." if _can_help else "You cannot help this neighbour again today."
