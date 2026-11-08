class_name ConstructionSprite
extends Node2D
## The construction of a new building (IsoElement.setGraphicConstruction of
## the client): the scaffold of the size of the building instead of the
## building, and the bar of the client (FauxBar3 with FauxBarMC) with the share
## of the time that passed. The bar keeps its size on the screen at all zooms.

signal finished

const FRAME_SECONDS := 1.0 / 30.0
## The bar is 10 pixels of the map above the place of the building.
const BAR_OFFSET := Vector2(0, -10)

var _scaffold: SpriteLibrary.ItemSprite
var _picture := Sprite2D.new()
var _bar: UiClip
var _small := false
var _seconds: float
var _time := 0.0
var _frame := 0
var _frame_time := 0.0


## scaffold: the imported Construction... graphic, or null. small: a building
## one tile wide, for which the client shows only the percentage.
func _init(scaffold: SpriteLibrary.ItemSprite, ui: UiLibrary, seconds: float, small: bool) -> void:
	_scaffold = scaffold
	_seconds = seconds
	if scaffold != null:
		_picture.centered = false
		_picture.texture = scaffold.get_frame(0)
		_picture.offset = VillageView.building_offset(scaffold, 0)
		add_child(_picture)
	if ui != null and ui.has_symbol("FauxBarMC"):
		_bar = ui.make("FauxBarMC")
		_bar.position = BAR_OFFSET
		_small = small
		if small:
			_bar.set_part_visible("barBack", false)
		add_child(_bar)
		_show_share(0.0)


func _process(delta: float) -> void:
	_time += delta
	if _bar != null:
		_bar.scale = Vector2.ONE / get_global_transform_with_canvas().get_scale()
		_show_share(_time / _seconds)
	if _scaffold != null and _scaffold.frame_count() > 1:
		_frame_time += delta
		if _frame_time >= FRAME_SECONDS:
			_frame_time = fmod(_frame_time, FRAME_SECONDS)
			_frame = (_frame + 1) % _scaffold.frame_count()
			_picture.texture = _scaffold.get_frame(_frame)
			_picture.offset = VillageView.building_offset(_scaffold, _frame)
	if _time >= _seconds:
		set_process(false)
		finished.emit()


func _show_share(share: float) -> void:
	_bar.clip("percentMask").scale.x = 0.0 if _small else minf(share, 1.0)
	_bar.set_text("percentText", "%d%%" % mini(int(share * 100), 100))
