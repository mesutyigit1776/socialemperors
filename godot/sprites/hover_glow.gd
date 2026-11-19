class_name HoverGlow
extends Node2D
## The white glow around the item under the mouse (IsoInteractiveElement.highlight
## of the client), on the map or on its portrait in the panel. The node goes
## behind the graphic of the item, a Sprite2D, and draws the glow of the
## frame that the graphic shows (for a ClipSprite, see ClipSprite.shown_node()).

const SHADER := preload("res://sprites/hover_glow.gdshader")
const PAD := 4.0  ## Screen pixels around the graphic.
const _NAME := &"HoverGlow"

var _glow := Sprite2D.new()


func _init() -> void:
	_glow.material = ShaderMaterial.new()
	_glow.material.shader = SHADER
	add_child(_glow)


## Puts the glow on node, or takes it away.
static func set_shown(node: Sprite2D, shown: bool) -> void:
	var glow := node.get_node_or_null(NodePath(_NAME))
	if shown and glow == null:
		glow = HoverGlow.new()
		glow.name = _NAME
		glow.show_behind_parent = true
		node.add_child(glow)
	elif not shown and glow != null:
		node.remove_child(glow)
		glow.queue_free()


func _process(_delta: float) -> void:
	var item := get_parent() as Sprite2D
	var source: Sprite2D = item.shown_node() if item is ClipSprite else item
	_glow.visible = source.texture != null
	if not _glow.visible:
		return
	_glow.texture = source.texture
	_glow.centered = source.centered
	_glow.offset = source.offset
	_glow.flip_h = source.flip_h
	_glow.flip_v = source.flip_v
	_glow.transform = Transform2D.IDENTITY if source == item else source.transform
	# The blur and the pad are in screen pixels, as the filters of the client.
	var texels := 1.0 / maxf(absf(source.get_global_transform_with_canvas().get_scale().x), 0.001)
	_glow.material.set_shader_parameter(&"step_size", texels)
	_glow.material.set_shader_parameter(&"pad", PAD * texels)
