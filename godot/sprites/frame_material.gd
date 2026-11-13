class_name FrameMaterial
## Shows a frame of the map on a Sprite2D with the material that it needs: the
## shader of the layers for a frame whose parts mix with the map (see
## FlashArt.render), and a colour that is added to the graphic.
##
## A frame of layers reads the screen behind the node. A BackBufferCopy child,
## drawn before the node, copies the screen, so that the copy also has the
## graphics drawn just before the node. It copies the whole screen: with
## COPY_MODE_RECT the OpenGL renderer of Godot 4.7 gave a black copy when the
## rectangle started above the node.

const _LAYERS := preload("res://sprites/blend_layers.gdshader")
const _TINT := preload("res://sprites/tint.gdshader")
const _COPY_NAME := &"BlendBackground"

static var _materials := {}  # [blend modes, added colour] -> ShaderMaterial


## Shows texture on node. added: the colour added to the graphic, black for none.
static func show(node: Sprite2D, texture: Texture2D, added := Color.BLACK) -> void:
	node.texture = texture
	var modes: PackedByteArray = texture.get_meta(&"blend_modes", PackedByteArray()) if texture != null else PackedByteArray()
	node.material = _material(modes, added)
	var copy: BackBufferCopy = node.get_node_or_null(NodePath(_COPY_NAME))
	if modes.is_empty():
		if copy != null:
			copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		return
	if copy == null:
		copy = BackBufferCopy.new()
		copy.name = _COPY_NAME
		copy.show_behind_parent = true
		node.add_child(copy)
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT


static func _material(modes: PackedByteArray, added: Color) -> ShaderMaterial:
	if modes.is_empty() and added == Color.BLACK:
		return null
	var key := [modes, added]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = _TINT if modes.is_empty() else _LAYERS
		material.set_shader_parameter(&"added", added)
		if not modes.is_empty():
			var codes := PackedInt32Array()
			for mode in modes:
				codes.append(mode)
			material.set_shader_parameter(&"count", modes.size())
			material.set_shader_parameter(&"modes", codes)
		_materials[key] = material
	return _materials[key]
