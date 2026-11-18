class_name SelectionPortraits
extends Control
## The portraits of a selection of several units in the panel of the bottom
## bar (RecuadroInfoNew.refreshRecuadro and Portrait of the client): up to 20
## places in two rows of 10, each with the picture of a unit and its health
## bar. The client shows them only for two or more units; for one unit it
## shows the extended portrait. With exactly 20 units all places have a
## portrait; with more, the last place shows the mark for more units
## (PortraitMorUnitsMC). A unit without life has no portrait in its place.
##
## The node goes into the "ri" part of the panel, where the client puts the portraits.

## The player clicked the portrait of units[index] of show_units().
signal portrait_pressed(index: int)

const MAX_PORTRAITS := 20  ## Config.MAX_SELECTED_OBJECTS
const COLUMNS := MAX_PORTRAITS / 2
const LEFT := 17.0  ## Config.LEFT_MARGIN_SELECTED_ELEMENTS
const TOP := 20.0  ## Config.TOP_MARGIN_SELECTED_ELEMENTS
const SPACE := 50.0  ## Config.SPACE_SELECTED_ELEMENTS and SPACEY_SELECTED_ELEMENTS

var _places: Array[Portrait] = []
var _more: UiClip


func _init(ui: UiLibrary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in MAX_PORTRAITS:
		var portrait := Portrait.new(ui)
		portrait.position = Vector2(LEFT + (index % COLUMNS) * SPACE, TOP + (index / COLUMNS) * SPACE)
		portrait.visible = false
		portrait.pressed.connect(func() -> void: portrait_pressed.emit(index))
		_places.append(portrait)
		add_child(portrait)
	_more = ui.make("PortraitMorUnitsMC")
	_more.position = _places[MAX_PORTRAITS - 1].position
	_more.visible = false
	add_child(_more)


## units: a list of [img_name, life share from 0 to 1], in the order of the selection.
func show_units(units: Array) -> void:
	var count := units.size()
	for index in MAX_PORTRAITS:
		var portrait := _places[index]
		var shown := count > 1 and index < count and (index < MAX_PORTRAITS - 1 or count == MAX_PORTRAITS)
		if shown:
			var unit: Array = units[index]
			portrait.show_unit(unit[0])
			portrait.show_life(unit[1])
		portrait.visible = shown and units[index][1] > 0
	_more.visible = count > MAX_PORTRAITS


## One portrait (PortraitMC): the picture of the unit in a frame, with a
## health bar. Under the mouse it gets a white edge (Portrait.overItem: a
## white glow filter of blur 3 and strength 50). A press of the left button
## emits pressed, as the client acts on MOUSE_DOWN.
class Portrait:
	extends Control

	signal pressed

	## The client draws the thumb of the unit at 45 × 45 pixels in the image part.
	const PICTURE_SIZE := 45.0
	const EDGE := 3.0

	var _ui: UiLibrary
	var _clip: UiClip
	var _picture := TextureRect.new()
	var _edge := ColorRect.new()
	var _img_name := ""
	var _bar_width := 0.0
	var _red_width := 0.0

	func _init(ui: UiLibrary) -> void:
		_ui = ui
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip = ui.make("PortraitMC")
		_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_picture.size = Vector2(PICTURE_SIZE, PICTURE_SIZE)
		_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clip.clip("image").add_child(_picture)
		var bar := _clip.clip("barraVida")
		_bar_width = bar.bounds().size.x
		_red_width = bar.clip("barraRoja").bounds().size.x
		var rect := _clip.bounds()
		_edge.color = Color.WHITE
		_edge.position = rect.position - Vector2(EDGE, EDGE)
		_edge.size = rect.size + Vector2(EDGE, EDGE) * 2
		_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edge.visible = false
		add_child(_edge)
		add_child(_clip)
		# The clip takes no mouse; this node over it does.
		var hit := Control.new()
		hit.position = rect.position
		hit.size = rect.size
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.mouse_entered.connect(func() -> void: _edge.visible = true)
		hit.mouse_exited.connect(func() -> void: _edge.visible = false)
		hit.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				hit.accept_event()
				pressed.emit())
		add_child(hit)

	## The width and height of the portrait in the art.
	func art_size() -> Vector2:
		return _clip.bounds().size

	func show_unit(img_name: String) -> void:
		if img_name != _img_name:
			_img_name = img_name
			_picture.texture = _ui.thumb(img_name)

	## share: the life left, from 0 to 1. The red part covers the share that the unit lost.
	func show_life(share: float) -> void:
		if _red_width > 0:
			_clip.clip("barraVida/barraRoja").scale.x = (1 - clampf(share, 0, 1)) * _bar_width / _red_width
