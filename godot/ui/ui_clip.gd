class_name UiClip
extends Control
## A sprite of a client window (see UiLibrary): the image of its frame without
## its named parts, and the parts as children, in the depth order of the
## client: a UiClip for a sprite, a UiButton for a button and a Label for a
## text field. The node sits on the registration point of the sprite, as in
## Flash. Parts can be scaled, mirrored, turned and skewed. A Control cannot
## skew, so a skewed part is the child of a Node2D with the matrix of Flash.
##
## A part keeps its text, visibility and frame when the clip shows another
## frame that has a part with the same name. Masks of the client are hidden.

signal pressed  ## The player clicked a clip that is a button, see make_button().

## Flash draws the text of a field 2 pixels inside its rectangle.
const TEXT_GUTTER := 2.0
## The smallest font size to which TextFieldUtil.resizeText makes a text smaller.
const MIN_FIT_SIZE := 8
## A matrix whose axes are further than this from a right angle (the cosine
## of their angle) skews; see _is_skewed().
const SKEW_LIMIT := 0.001
## The key in _parts of the shapes under a mask, after the key of the mask.
const MASKED_SUFFIX := "#masked"
## Godot draws no visible ring around the text below this outline_size, see glow_outline_size().
const GLOW_OUTLINE_BASE := 7

## The buttons that play SoundEffect.ROLL_OVER when the mouse comes over them.
const ROLL_OVER_BUTTONS: Array[String] = ["yesBtn", "okButton"]

var library: UiLibrary
var sprite_id: int
var frame := 0
var _base := TextureRect.new()
var _layered := false  # The image of the frame has layers that mix with the screen.
var _parts: Dictionary = {}  # Part name (or "#depth" for an unnamed text or button) -> Control.
var _button := false
var _hover_frame := false
static var _colour_materials := {}  # Color -> ShaderMaterial, see set_colour().
var _kept := false  # keep_at() places the clip.
var _screen_anchor := Vector2.ZERO
var _screen_offset := Vector2.ZERO


## Keeps the clip at a point of the screen: anchor is the point as a part of
## the screen size (0.5, 0.5 is the middle), plus offset. The clip moves when
## the size of the screen changes: a new window size, or UiScale.
func keep_at(anchor: Vector2, offset := Vector2.ZERO) -> void:
	var first := not _kept
	_kept = true
	_screen_anchor = anchor
	_screen_offset = offset
	if first:
		tree_entered.connect(_follow_screen.bind(true))
		tree_exiting.connect(_follow_screen.bind(false))
		if is_inside_tree():
			_follow_screen(true)
	elif is_inside_tree():
		_place_on_screen()


## Keeps the clip at the middle of the screen plus offset, see keep_at().
func keep_centred(offset := Vector2.ZERO) -> void:
	keep_at(Vector2(0.5, 0.5), offset)


func _init(ui_library: UiLibrary, id: int) -> void:
	library = ui_library
	sprite_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)
	show_frame(0)


func frame_count() -> int:
	return library.clip_frames(sprite_id).size()


## Shows frame (from 0) of the sprite, as gotoAndStop(frame + 1) in Flash.
func show_frame(new_frame: int) -> void:
	frame = clampi(new_frame, 0, frame_count() - 1)
	var origin: Variant = library.clip_origin(sprite_id)
	_base.texture = library.clip_image(sprite_id, frame)
	var layered := _base.texture != null and _base.texture.has_meta(&"blend_modes")
	if layered or _layered:
		FrameMaterial.apply(_base, _base.texture)
		_layered = layered
	_base.position = origin if origin != null else Vector2.ZERO
	_base.size = _base.texture.get_size() if _base.texture != null else Vector2.ZERO
	var shown := {}
	for part: Dictionary in library.clip_frames(sprite_id)[frame]:
		var key: String = part["name"] if part["name"] != null else "#%d" % int(part["depth"])
		# Flash finds the first child with a name; a later part with the same
		# name (for example a mask) gets a node of its own.
		if shown.has(key):
			key = "%s#%d" % [key, int(part["depth"])]
		shown[key] = true
		var node: Control = _parts.get(key)
		# A field that the timeline removed and placed again is a new field
		# with the text of its frame, for example "You've lost the battle" in
		# the second frame of the result of the attack log. The client writes
		# its texts again after a change of frame (the labels of its buttons),
		# so a field with a text from the code keeps it, also with its font
		# size from set_text(). Only text fields: the port keeps the clips and
		# buttons that the code holds.
		var shown_before := true
		if node is Label and int(node.get_meta("start", 0)) != int(part.get("start", 0)) and node.text == node.get_meta("art_text") and not node.has_meta("written"):
			shown_before = node.visible
			_holder(node).queue_free()
			_parts.erase(key)
			node = null
		# A frame can have the field with another colour, for example a lit
		# number; the field keeps its text, and the port changes its colour.
		if node is Label and part.has("text") and not part["text"]["html"] and node.get_meta("frame_colour", "") != part["text"]["color"]:
			node.set_meta("frame_colour", part["text"]["color"])
			node.add_theme_color_override("font_color", Color.html(part["text"]["color"]))
		var m: Array = part["matrix"]
		if node == null:
			node = _make_part(part)
			node.set_meta("part", key)
			node.set_meta("start", int(part.get("start", 0)))
			if node is Label:
				node.set_meta("art_text", node.text)
				# The code hides some fields, for example the key help of the square tool.
				node.visible = shown_before
			_parts[key] = node
			if part.has("clip_rect") and node is UiClip:
				# The mask of the part, in the coordinates of the part; see show_picture().
				var r: Array = part["clip_rect"]
				var to_part := Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5])).affine_inverse()
				node.set_meta("clip_rect", to_part * Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]))
			if _is_skewed(m):
				var holder := Node2D.new()
				holder.add_child(node)
				add_child(holder)
			else:
				add_child(node)
		var in_clip: CanvasItem = _holder(node)
		# The parts come in the order of their depths, above the base image,
		# except the parts under all shapes of the base image.
		move_child(in_clip, get_child_count() - 1)
		if part.get("under", false):
			move_child(in_clip, _base.get_index())
		if in_clip != node:
			(in_clip as Node2D).transform = Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))
			node.position = node.get_meta("offset", Vector2.ZERO)
		else:
			# The matrix of Flash is [a, b, c, d, x, y]: a turn, then a scale.
			var x_scale := Vector2(m[0], m[1]).length()
			node.rotation = atan2(m[1], m[0])
			node.scale = Vector2(x_scale, (m[0] * m[3] - m[1] * m[2]) / x_scale if x_scale != 0 else m[3])
			# A text field keeps the offset of its rectangle, see _make_part().
			node.position = Vector2(m[4], m[5]) + (node.get_meta("offset", Vector2.ZERO) * node.scale).rotated(node.rotation)
		# A part that the clip fades gets its full alpha back in the frames without a fade.
		if part.has("alpha"):
			node.modulate.a = part["alpha"]
			node.set_meta("faded", true)
		elif node.has_meta("faded"):
			node.modulate.a = 1.0
		if part.get("mask", false):
			node.visible = false
			if part.has("masked"):
				_show_masked(key, node, int(part["masked"]))
	for key: String in _parts.keys():
		if not shown.has(key) and not shown.has(key.trim_suffix(MASKED_SUFFIX)):
			_holder(_parts[key]).queue_free()
			_parts.erase(key)


## True when the matrix [a, b, c, d, x, y] of Flash skews: its axes are not at right angles.
static func _is_skewed(m: Array) -> bool:
	var x_axis := Vector2(m[0], m[1])
	var y_axis := Vector2(m[2], m[3])
	return x_axis.length() > 0 and y_axis.length() > 0 and absf(x_axis.normalized().dot(y_axis.normalized())) > SKEW_LIMIT


## The node of a part that is a child of the clip: the part, or the Node2D of a skewed part.
func _holder(node: Control) -> CanvasItem:
	return node.get_parent() if node.get_parent() is Node2D else node


## The shapes under a named mask (see importer/ui_import.py) show only
## inside the rectangle of the mask, which the client moves or scales, for
## example to fill a bar.
func _show_masked(key: String, mask: Control, layer_id: int) -> void:
	var layer_key := key + MASKED_SUFFIX
	var layer: MaskedLayer = _parts.get(layer_key)
	if layer == null:
		layer = MaskedLayer.new(mask, UiClip.new(library, layer_id))
		_parts[layer_key] = layer
		add_child(layer)
	move_child(layer, mask.get_index() + 1)


class MaskedLayer:
	extends Control
	var _mask: Control
	var _content: UiClip

	func _init(mask: Control, content: UiClip) -> void:
		_mask = mask
		_content = content
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content)

	func _process(_delta: float) -> void:
		var rect: Rect2 = Transform2D(_mask.rotation, _mask.scale, 0.0, _mask.position) * (_mask as UiClip).bounds()
		position = rect.position
		size = rect.size.abs()
		_content.position = -rect.position


## Gives the image of the clip one colour, as the color of a ColorTransform
## in Flash: each pixel takes the colour and keeps its alpha.
func set_colour(colour: Color) -> void:
	if not _colour_materials.has(colour):
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nuniform vec4 colour : source_color;\nvoid fragment() {\n\tCOLOR = vec4(colour.rgb, texture(TEXTURE, UV).a * COLOR.a);\n}\n"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("colour", colour)
		_colour_materials[colour] = material
	_base.material = _colour_materials[colour]


## The part at path, for example "message1/yesBtn", or null.
func part(path: String) -> Control:
	var node: Control = self
	for name in path.split("/"):
		if not node is UiClip or not node._parts.has(name):
			return null
		node = node._parts[name]
	return node


func clip(path: String) -> UiClip:
	return part(path) as UiClip


func button(path: String) -> UiButton:
	return part(path) as UiButton


## Shows the frame with this label, as gotoAndStop(label) in Flash.
func show_label(label: String) -> void:
	var labelled := library.clip_label(sprite_id, label)
	if labelled >= 0:
		show_frame(labelled)


## Writes a text into a field as the client's TextFieldUtil.setHTML does: the
## font gets smaller, to MIN_FIT_SIZE at most, while the text does not fit the
## field (see _fits()). The client writes most of its fields so. It starts from
## the size that the field has now; the port starts from the size of the art,
## so that a field that the port uses again for other texts (a page of a list)
## does not keep the size of an earlier text.
## fit is false for a field that the client writes with TextField.text or with
## an auto size: its font keeps the size of the art. An auto size field grows
## with its text, so resizeText finds no text outside it.
## clip is true for a field that has no auto size and that the client writes
## with TextField.text: Flash shows only the part of the text inside the
## field, so a line that is too wide is cut at the right edge and the lines
## below the bottom are not shown. Other fields show all of their text.
func set_text(path: String, text: String, fit := true, clip := false) -> void:
	var label := part(path) as Label
	if label == null:
		return
	label.set_meta("written", true)
	label.clip_text = clip
	var size: int = label.get_meta("art_font_size")
	_show_text(label, text, size)
	while fit and size > MIN_FIT_SIZE and not _fits(label, size):
		size -= 1
		_show_text(label, text, size)
	if clip:
		# The minimum size of the Label can have made it larger than the field.
		label.size = label.get_meta("field_size")
		# A line that is wider than its field starts at the left edge in Flash, also in a centred field.
		var too_wide: bool = not label.get_meta("word_wrap") and not _fits(label, label.get_theme_font_size("font_size"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if too_wide else label.get_meta("art_align")


## Shows a text in a field at a font size. In a field with word wrap, the
## port breaks the lines as Flash does (FlashTextLayout), and the Label does
## not wrap them again. The lines are as far apart as in Flash.
static func _show_text(label: Label, text: String, size: int) -> void:
	var layout: FlashTextLayout = label.get_meta("text_layout")
	label.set_meta("flash_text", text)
	label.add_theme_font_size_override("font_size", size)
	var godot_line := label.get_theme_font("font").get_height(size)
	label.add_theme_constant_override("line_spacing", roundi(layout.line_height(size, label.get_meta("leading")) - godot_line))
	if label.get_meta("word_wrap"):
		label.text = drawable(label, "\n".join(layout.wrap(text, size, label.get_meta("field_size").x)))
	else:
		label.text = drawable(label, text)


## The text without the characters that the font of the label does not have.
## Flash gives such a character no width and draws nothing (FlashTextLayout
## measures it so); Godot would draw another font's glyph or an empty box.
## The fonts of the client embed only some glyphs; for example the font of the
## mini-game has no digits, so "Level 4 failed" shows as "Level  failed".
static func drawable(label: Label, text: String) -> String:
	var font := label.get_theme_font("font")
	var result := ""
	for character in text:
		if character == "\n" or font.has_char(character.unicode_at(0)):
			result += character
	return result


## Whether the text of a field fits it at this font size, as Flash measures
## it. TextFieldUtil.resizeText makes the font smaller while maxScrollH > 0,
## that is a field without word wrap has a line at least 1 pixel wider than
## the field, or maxScrollV > 1, that is the layout has more than one line and
## the lines are higher than the field. In a field with more lines, the "</p>"
## that setHTML puts after the text starts an empty last line, so one line of
## text that is higher than the field is enough (Ruffle, html/layout.rs and
## display_object/edit_text.rs).
static func _fits(label: Label, size: int) -> bool:
	var field: Vector2 = label.get_meta("field_size")
	var layout: FlashTextLayout = label.get_meta("text_layout")
	var text: String = label.get_meta("flash_text")
	var line_count: int
	if label.get_meta("word_wrap"):
		line_count = layout.wrap(text, size, field.x).size()
	else:
		var lines := text.split("\n")
		for line in lines:
			if layout.width(line, size) - field.x >= 1.0:
				return false
		line_count = lines.size()
	var layout_lines := line_count + (1 if label.get_meta("multiline") else 0)
	return layout_lines < 2 or line_count * layout.line_height(size, label.get_meta("leading")) <= field.y


## The rectangle of a text field as Flash measures it, in the coordinates of
## this clip. The Label of the port can be taller than the field.
func field_rect(path: String) -> Rect2:
	var label := part(path) as Label
	if label == null:
		return Rect2()
	var field: Vector2 = label.get_meta("field_size")
	return Rect2(label.position - Vector2(TEXT_GUTTER, TEXT_GUTTER), field + Vector2(TEXT_GUTTER, TEXT_GUTTER) * 2)


## Puts a picture in the part at path, in place of the pictures there. The
## client centres a picture on the part, except the small pictures of items,
## which it puts at the top left (ImageManagerResource.ONLY_ADJUST_SIZE).
func show_picture(path: String, texture: Texture2D, centred := true, picture_scale := 1.0) -> TextureRect:
	var anchor := part(path)
	if anchor == null:
		return null
	for child in anchor.get_children():
		if child.has_meta("picture"):
			child.queue_free()
	var picture := TextureRect.new()
	picture.set_meta("picture", true)
	picture.texture = texture
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.scale = Vector2.ONE * picture_scale
	if centred and texture != null:
		picture.position = -texture.get_size() * picture_scale / 2
	if anchor.has_meta("clip_rect"):
		# A shape of the art masks the anchor, for example the frame of a
		# unit picture (ArmyUnitCellMC); the picture shows only inside it.
		var rect: Rect2 = anchor.get_meta("clip_rect")
		var window := Control.new()
		window.set_meta("picture", true)
		window.clip_contents = true
		window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.position = rect.position
		window.size = rect.size
		picture.position -= rect.position
		window.add_child(picture)
		anchor.add_child(window)
	else:
		anchor.add_child(picture)
	return picture


func set_part_visible(path: String, shown: bool) -> void:
	var node := part(path)
	if node != null:
		node.visible = shown


## Makes the clip a button: a click on its images emits pressed. With
## hover_frame, the clip shows its second frame while the mouse is over it,
## as the buttons of the client do.
func make_button(hover_frame := false) -> void:
	_button = true
	# A sprite of the client that is a button often has a Flash button as its
	# image, unnamed or named "button", which takes the clicks. In Flash the
	# click also reaches the sprite.
	for key: String in _parts:
		if (key.begins_with("#") or key == "button") and _parts[key] is UiButton:
			_parts[key].pressed.connect(func() -> void: pressed.emit())
	_hover_frame = hover_frame and frame_count() > 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _hover_frame:
		mouse_entered.connect(func() -> void: show_frame(1))
		mouse_exited.connect(func() -> void: show_frame(0))
	# The client plays a sound when the mouse comes over a Yes or OK button (GameStatic.startFloat).
	if get_meta("part", "") in ROLL_OVER_BUTTONS:
		mouse_entered.connect(func() -> void: SoundPlayer.play(SoundEffect.ROLL_OVER))


## The image of the clip takes the clicks on its rectangle, so that they do
## not reach the nodes below it, for example the map below a bar.
func take_mouse() -> void:
	_base.mouse_filter = Control.MOUSE_FILTER_STOP


## The rectangle of the shown frame and its parts in the coordinates of the
## clip, as Flash measures the width and height of a display object: without
## the space of filters, and without the other frames. with_pictures: also the
## pictures of show_picture(), without their masks.
func bounds(with_pictures := false) -> Rect2:
	return _measure(with_pictures, false)


## The rectangle of bounds(), or with images: of the frame images, which cover
## all frames of a sprite and the space of its filters.
func _measure(with_pictures: bool, images: bool) -> Rect2:
	var own := Rect2(_base.position, _base.size) if images else library.clip_rect(sprite_id, frame)
	var result := own if _base.texture != null else Rect2()
	if with_pictures:
		for child in get_children():
			if child.has_meta("picture"):
				var picture: TextureRect = child if child is TextureRect else child.get_child(0)
				var size := picture.texture.get_size() if picture.texture != null else Vector2.ZERO
				var rect := Rect2(picture.position + (child.position if child != picture else Vector2.ZERO), size * picture.scale)
				result = rect if result.size == Vector2.ZERO else result.merge(rect)
	for node: Control in _parts.values():
		if not node.visible:
			continue
		var rect: Rect2 = (node as UiClip)._measure(with_pictures, images) if node is UiClip else node.bounds() if node is UiButton else Rect2(Vector2.ZERO, node.size)
		if rect.size != Vector2.ZERO:
			rect = Transform2D(node.rotation, node.scale, 0.0, node.position) * rect
			if _holder(node) != node:
				rect = (_holder(node) as Node2D).transform * rect
			result = rect if result.size == Vector2.ZERO else result.merge(rect)
	return result


## The mouse is over a button in the rectangle of its frame images, so that
## its area does not change when a frame under the mouse changes.
func _has_point(point: Vector2) -> bool:
	return _button and _measure(false, true).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if _button and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		accept_event()
		pressed.emit()


func _make_part(part: Dictionary) -> Control:
	if part.has("clip"):
		return UiClip.new(library, int(part["clip"]))
	if part.has("button"):
		return UiButton.new(library, int(part["button"]))
	var settings: Dictionary = part["text"]
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect: Array = settings["rect"]
	label.set_meta("offset", Vector2(rect[0] + TEXT_GUTTER, rect[1] + TEXT_GUTTER))
	# Godot can make the Label taller than the field (its minimum size), so the size of the field is kept apart.
	label.set_meta("field_size", Vector2(rect[2] - 2 * TEXT_GUTTER, rect[3] - 2 * TEXT_GUTTER))
	label.size = label.get_meta("field_size")
	var text := str(settings["text"])
	var size := float(settings["size"])
	var color := Color.html(settings["color"])
	if settings["html"]:
		# An HTML field of the client sets its size and color in a font tag.
		var font_tag := RegEx.create_from_string("<font[^>]*>").search(text)
		if font_tag != null:
			var size_value := RegEx.create_from_string("size=\"(\\d+)\"").search(font_tag.get_string())
			var color_value := RegEx.create_from_string("color=\"#([0-9a-fA-F]{6})\"").search(font_tag.get_string())
			if size_value != null:
				size = size_value.get_string(1).to_float()
			if color_value != null:
				color = Color.html(color_value.get_string(1))
		text = RegEx.create_from_string("<[^>]*>").sub(text.replace("<br>", "\n").replace("</p><p", "\n<p"), "", true)
		text = text.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&apos;", "'").replace("&amp;", "&")
	# Flash does not count the spaces at the end of a line; a Label does, for
	# example in the place of a centred line.
	var lines := text.replace("\r", "\n").split("\n")
	for i in lines.size():
		lines[i] = lines[i].rstrip(" ")
	label.add_theme_font_override("font", library.font(settings["font_id"]))
	label.set_meta("art_font_size", int(round(size)))
	label.set_meta("text_layout", library.text_layout(settings["font_id"]))
	label.set_meta("leading", float(settings["leading"]))
	label.set_meta("multiline", bool(settings["multiline"]))
	label.set_meta("word_wrap", bool(settings["word_wrap"]))
	_show_text(label, "\n".join(lines), int(round(size)))
	label.add_theme_color_override("font_color", color)
	label.set_meta("frame_colour", settings["color"])
	label.horizontal_alignment = {"left": HORIZONTAL_ALIGNMENT_LEFT, "right": HORIZONTAL_ALIGNMENT_RIGHT, "center": HORIZONTAL_ALIGNMENT_CENTER}.get(settings["align"], HORIZONTAL_ALIGNMENT_FILL)
	label.set_meta("art_align", label.horizontal_alignment)
	# The client makes most fields grow with their text (autoSize), so the port does not cut the text.
	label.clip_text = false
	if part.has("glow"):
		# A glow filter with a high strength draws an outline around the text.
		label.add_theme_color_override("font_outline_color", Color.html(part["glow"][0]))
		label.add_theme_constant_override("outline_size", UiClip.glow_outline_size(float(part["glow"][1]), float(part["glow"][2])))
	return label


## The outline_size of a Label for a glow filter of Flash with this blur and
## strength. The solid part of a Flash glow grows with blur × (1 − 1 / strength);
## the numbers come from a comparison with Ruffle: the title of the PvP window
## (blur 5, strength 10) needs 12, and the title of the attack log (blur 7,
## strength 16) 13 to 14.
static func glow_outline_size(blur: float, strength: float) -> int:
	return roundi(blur * (1.0 - 1.0 / maxf(strength, 1.0))) + GLOW_OUTLINE_BASE


func _follow_screen(entered: bool) -> void:
	if entered:
		get_viewport().size_changed.connect(_place_on_screen)
		_place_on_screen()
	else:
		get_viewport().size_changed.disconnect(_place_on_screen)


func _place_on_screen() -> void:
	position = get_viewport_rect().size * _screen_anchor + _screen_offset
