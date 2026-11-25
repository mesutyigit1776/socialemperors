class_name FlashFilters
extends CanvasGroup
## A GlowFilter of Flash and the _brightness of Tweener (ColorShortcuts) on a
## node with its children, for example an item of a window that the client
## makes bright and gives a glow. The group goes in the place of the node, and
## the node becomes its child at the same position. Tweens can change the
## properties.

const SHADER := preload("res://ui/flash_filters.gdshader")

## The colour of the glow.
var glow_color := Color.WHITE:
	set(value):
		glow_color = value
		_material.set_shader_parameter(&"glow_color", value)
## The alpha of the GlowFilter; Flash takes at most 1. 0 draws no glow.
var glow_alpha := 0.0:
	set(value):
		glow_alpha = value
		_material.set_shader_parameter(&"glow_alpha", value)
## The blur of the GlowFilter in pixels of the client (blurX = blurY).
var glow_blur := 0.0:
	set(value):
		glow_blur = value
		_update_blur()
var glow_strength := 2.0:
	set(value):
		glow_strength = value
		_material.set_shader_parameter(&"strength", value)
## The _brightness of Tweener: 0 normal; 1 adds 100 of 255 to each colour.
var brightness := 0.0:
	set(value):
		brightness = value
		_material.set_shader_parameter(&"brightness", value)

var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = SHADER
	material = _material


## The group of node: the one that it has, or a new one in its place.
static func of(node: Control) -> FlashFilters:
	if node.get_parent() is FlashFilters:
		return node.get_parent()
	var parent := node.get_parent()
	var group := FlashFilters.new()
	parent.add_child(group)
	parent.move_child(group, node.get_index())
	node.reparent(group, false)
	return group


## A GlowFilter(colour, alpha, blur, blur, strength) of Flash.
func set_glow(colour: Color, alpha: float, blur: float, strength := 2.0) -> void:
	glow_color = colour
	glow_alpha = alpha
	glow_blur = blur
	glow_strength = strength


func _process(_delta: float) -> void:
	_update_blur()


## The blur is in screen pixels in the shader, and the group needs room for the glow.
func _update_blur() -> void:
	var screen_scale := get_viewport().get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x if is_inside_tree() else 1.0
	_material.set_shader_parameter(&"blur", glow_blur * screen_scale)
	fit_margin = maxf(glow_blur, 1.0)
	clear_margin = fit_margin
