class_name DomeRange
extends Node2D
## The range of a dome building (DomeDelegate of the client), on the dome
## node: while the player points at the dome, its range on the ground
## (DomeRangeBottom, alpha 0.85, under the graphic); while it is selected, also
## a dome over it (blue_dome of swf/blue_dome.swf, alpha 0.5), red for the
## Tower Enhancer. Both are 108 × 1.5 pixels wide for each tile of range; the
## art of the client is 600 pixels wide.

const PIXELS_PER_RANGE := 108 * 1.5
const ART_WIDTH := 600.0
const BOTTOM_ALPHA := 0.85
const TOP_ALPHA := 0.5
const FRAME_SECONDS := 1.0 / 30.0
## The client colours the dome of the Tower Enhancer red (colorize 0xFF0000, amount 1).
const ENHANCER_COLOUR := Color(1, 0, 0)
const _COLORIZE := preload("res://battle/colorize.gdshader")

var _bottom: UiClip
var _top := Sprite2D.new()
var _clip: SpriteLibrary.Clip
var _frame := 0
var _time := 0.0


static func is_dome(def: GameConfig.ItemDef) -> bool:
	return def.subcat_functional == BattleSim.SUBCAT_DOMES


## Adds the range to the node of a dome. map_ui: the windows for the map
## (UiLibrary.for_map()); dome_ui: the library of ui/dome, or null.
static func attach(node: Node2D, def: GameConfig.ItemDef, map_ui: UiLibrary, dome_ui: UiLibrary) -> DomeRange:
	var dome := DomeRange.new()
	var width := PIXELS_PER_RANGE * def.attack_range
	if map_ui != null and map_ui.has_symbol("DomeRangeBottom"):
		dome._bottom = map_ui.make("DomeRangeBottom")
		dome._bottom.scale = Vector2(width / ART_WIDTH, width / 2 / ART_WIDTH)
		dome._bottom.modulate.a = BOTTOM_ALPHA
		dome._bottom.show_behind_parent = true
		node.add_child(dome._bottom)
	var graphic := dome_ui.map_graphic("blue_dome") if dome_ui != null and dome_ui.has_symbol("blue_dome") else null
	var frame_clip := graphic.get_frame_clip(0) if graphic != null else null
	if frame_clip != null:
		dome._clip = frame_clip.clip
		dome._top.centered = false
		dome._top.offset = dome._clip.origin
		dome._top.transform = frame_clip.transform
		dome._top.modulate.a = TOP_ALPHA
		if def.id == BattleSim.TOWER_ENHANCER_DOME:
			var material := ShaderMaterial.new()
			material.shader = _COLORIZE
			material.set_shader_parameter(&"colour", ENHANCER_COLOUR)
			dome._top.material = material
		dome.add_child(dome._top)
		dome.scale = Vector2.ONE * width / ART_WIDTH
	node.add_child(dome)
	dome.show_state(false, false)
	return dome


func show_state(selected: bool, pointed: bool) -> void:
	if _bottom != null:
		_bottom.visible = selected or pointed
	visible = selected
	set_process(selected and _clip != null)
	if selected and _clip != null and _top.texture == null:
		_top.texture = _clip.get_frame(_frame)


# The range on the ground is a child of the dome node, so that it is under
# the graphic; it goes with this node.
func _exit_tree() -> void:
	if is_queued_for_deletion() and is_instance_valid(_bottom):
		_bottom.queue_free()


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		_frame = (_frame + 1) % _clip.frame_count()
	_top.texture = _clip.get_frame(_frame)
