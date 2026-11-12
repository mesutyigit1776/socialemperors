class_name AssaultStartWindow
extends Control
## The window before a PvP attack (popupLoadingAssault of the client, with
## FEATURE_SELECT_STARTING_POINT): the player chooses where the army lands on
## a map of the 16 edge points of a 5 × 5 grid, then Start Loading plays the
## animation, and after the load Start Battle emits start_requested with the
## tile of the point. Battle Help opens the help of the client (PopupPvpHelp).

signal start_requested(start_tile: Vector2i)

## The window is 50 pixels above the middle of the screen.
const OFFSET := Vector2(0, -50)
## The client cuts the animation with a rectangle, an unnamed mask at depth 2
## of PopupLoadingAssaultMC that the import does not keep (it keeps only named
## masks); the rectangle in the coordinates of the window.
const ANIMATION_MASK := Rect2(-255.0, -172.5, 526.5, 422.0)
## A point btnStartingPoint<column><row> is the tile 10 + 20 × column, 10 + 20 × row.
const POINT_PREFIX := "btnStartingPoint"
const GRID := 5
const FIRST_POINT := 10
const POINT_STEP := 20
const FIRST_SELECTED := "btnStartingPoint00"
## The frames of a point: normal, under the mouse, chosen, chosen under the mouse.
const FRAME_NORMAL := 0
const FRAME_HOVER := 1
const FRAME_CHOSEN := 2
const FRAME_CHOSEN_HOVER := 3
const FRAME_SECONDS := 1.0 / 30.0
## The client checks each second whether the map has loaded and then waits
## 2 seconds more before it shows Start Battle; the port loads at once.
const READY_SECONDS := 3.0
const HELP_TIPS: Array[String] = ["PVP_HELP_TIP_1", "PVP_HELP_TIP_2", "PVP_HELP_TIP_3", "PVP_HELP_TIP_4"]
const HELP_BACKGROUND := "generic_bg.png"
const HELP_PICTURES := "popup_elements/popup_pvp_help/tip_%d.png"
## PopupPvpHelp puts each tip text 3 pixels above its picture.
const HELP_TEXT_GAP := 3.0

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip
var _map: UiClip
var _points: Dictionary = {}  # Name -> UiClip.
var _chosen := FIRST_SELECTED
var _hovered := ""
var _animation: UiClip
var _time := 0.0


func _init(ui: UiLibrary, config: GameConfig) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The client locks the map while the window is open; it does not darken it.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_window = ui.make("PopupLoadingAssaultMC")
	add_child(_window)
	_window.set_text("title", config.text("POPUP_ASALTO_TITULO"))
	_window.set_text("armyReady", config.text("POPUP_ASALTO_ARMADA_LISTA_NEW"))
	for name in ["mcHelp", "armyReady", "btnStartBattle", "imageEagle"]:
		_window.set_part_visible(name, false)
	_animation = _window.clip("animacion")
	_animation.visible = false
	var mask := Control.new()
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.position = ANIMATION_MASK.position
	mask.size = ANIMATION_MASK.size
	_window.add_child(mask)
	_window.move_child(mask, _animation.get_index())
	_animation.reparent(mask, false)
	_animation.position -= mask.position
	set_process(false)
	_map = _window.clip("map")
	_map.set_text("header1", config.text("POPUP_ASALTO_MAPA_HEADER"))
	for column in GRID:
		for row in GRID:
			if column in [0, GRID - 1] or row in [0, GRID - 1]:
				var name := "%s%d%d" % [POINT_PREFIX, column, row]
				_points[name] = _map.clip(name)
	_show_points()
	# The points are diamonds that overlap in their rectangles, so the map
	# finds the point under the mouse by its shape.
	var hit := Control.new()
	hit.size = _map.bounds().end
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.gui_input.connect(_on_map_input)
	hit.mouse_exited.connect(func() -> void: _hover(""))
	_map.add_child(hit)
	_button("btnStartLoading", _start_loading)
	_button("btnStartBattle", func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		start_requested.emit(_tile()))
	_button("btnBattleHelp", _open_help)


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2 + OFFSET


## The texts of the three buttons are in the art of the client.
func _button(path: String, action: Callable) -> void:
	var button := _window.clip(path)
	button.make_button(true)
	button.pressed.connect(action)


## The hit area is at the origin of the map, so the positions of its events are in map coordinates.
func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover(_point_at(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# The client chooses a point when the button goes down.
		var name := _point_at(event.position)
		if not name.is_empty():
			_chosen = name
			_show_points()


## The point whose diamond holds the position, or "".
func _point_at(position_in_map: Vector2) -> String:
	for name: String in _points:
		var point: UiClip = _points[name]
		# The rectangle of a point also holds its flag above the tile; the
		# tile is the lower part, twice as wide as high.
		var bounds := point.bounds()
		var tile := Rect2(bounds.position.x, bounds.end.y - bounds.size.x / 2, bounds.size.x, bounds.size.x / 2)
		var rect := Transform2D(0.0, point.scale, 0.0, point.position) * tile
		var offset := (position_in_map - rect.get_center()).abs()
		if offset.x / (rect.size.x / 2) + offset.y / (rect.size.y / 2) <= 1.0:
			return name
	return ""


func _hover(name: String) -> void:
	if name != _hovered:
		_hovered = name
		_show_points()


func _show_points() -> void:
	for name: String in _points:
		var chosen := name == _chosen
		var hovered := name == _hovered
		_points[name].show_frame(FRAME_CHOSEN_HOVER if chosen and hovered else FRAME_CHOSEN if chosen else FRAME_HOVER if hovered else FRAME_NORMAL)


func _tile() -> Vector2i:
	var digits := _chosen.substr(POINT_PREFIX.length())
	return Vector2i(FIRST_POINT + POINT_STEP * digits.substr(0, 1).to_int(), FIRST_POINT + POINT_STEP * digits.substr(1, 1).to_int())


func _start_loading() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	_map.visible = false
	_window.set_part_visible("btnStartLoading", false)
	_animation.show_frame(0)
	_animation.visible = true
	set_process(true)
	await get_tree().create_timer(READY_SECONDS).timeout
	if is_inside_tree():
		_window.set_part_visible("armyReady", true)
		_window.set_part_visible("btnStartBattle", true)


## The animation plays once and stays on its last frame.
func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		if _animation.frame + 1 >= _animation.frame_count():
			set_process(false)
			return
		_animation.show_frame(_animation.frame + 1)


func _open_help() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var help := _ui.make("PopupPvpHelpMC")
	help.position = get_viewport_rect().size / 2
	help.show_picture("bg/bgAnchor", _ui.image(HELP_BACKGROUND), false)
	help.button("btnClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		cover.queue_free())
	cover.add_child(help)
	add_child(cover)
	# A Label counts its lines only inside the tree.
	for index in HELP_TIPS.size():
		var tip := "tip%d" % (index + 1)
		var label := "lblTip%d" % (index + 1)
		help.show_picture(tip, _ui.image(HELP_PICTURES % (index + 1)), false)
		help.set_text(label, _config.text(HELP_TIPS[index]))
		var field: Label = help.part(label)
		var text_height := field.get_line_count() * field.get_line_height()
		# The client moves the field (its y in Flash); the port keeps the offset of the text in the field.
		var offset: Vector2 = field.get_meta("offset", Vector2.ZERO) * field.scale
		field.position.y = help.part(tip).position.y - (text_height + HELP_TEXT_GAP) + offset.y
