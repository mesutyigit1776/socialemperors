class_name UiClip
extends Control
## A sprite of a client window (see UiLibrary): the image of its frame without
## its named parts, and the parts as children, in the depth order of the
## client: a UiClip for a sprite, a UiButton for a button and a Label for a
## text field. The node sits on the registration point of the sprite, as in
## Flash. Parts can be scaled, mirrored and turned; the port does not skew them.
##
## A part keeps its text, visibility and frame when the clip shows another
## frame that has a part with the same name. Masks of the client are hidden.

signal pressed  ## The player clicked a clip that is a button, see make_button().

## Flash draws the text of a field 2 pixels inside its rectangle.
const TEXT_GUTTER := 2.0

var library: UiLibrary
var sprite_id: int
var frame := 0
var _base := TextureRect.new()
var _parts: Dictionary = {}  # Part name (or "#depth" for unnamed text) -> Control.
var _button := false
var _hover_frame := false


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
	_base.position = origin if origin != null else Vector2.ZERO
	_base.size = _base.texture.get_size() if _base.texture != null else Vector2.ZERO
	var shown := {}
	for part: Dictionary in library.clip_frames(sprite_id)[frame]:
		var key: String = part["name"] if part["name"] != null else "#%d" % int(part["depth"])
		shown[key] = true
		var node: Control = _parts.get(key)
		if node == null:
			node = _make_part(part)
			_parts[key] = node
			add_child(node)
		move_child(node, get_child_count() - 1)
		var m: Array = part["matrix"]
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
	for key: String in _parts.keys():
		if not shown.has(key):
			_parts[key].queue_free()
			_parts.erase(key)


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


func set_text(path: String, text: String) -> void:
	var label := part(path) as Label
	if label != null:
		label.text = text


func set_part_visible(path: String, shown: bool) -> void:
	var node := part(path)
	if node != null:
		node.visible = shown


## Makes the clip a button: a click on its images emits pressed. With
## hover_frame, the clip shows its second frame while the mouse is over it,
## as the buttons of the client do.
func make_button(hover_frame := false) -> void:
	_button = true
	_hover_frame = hover_frame and frame_count() > 1
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _hover_frame:
		mouse_entered.connect(func() -> void: show_frame(1))
		mouse_exited.connect(func() -> void: show_frame(0))


## The rectangle of the images and texts of the clip, in its own coordinates.
func bounds() -> Rect2:
	var result := Rect2(_base.position, _base.size) if _base.texture != null else Rect2()
	for node: Control in _parts.values():
		if not node.visible:
			continue
		var rect: Rect2 = node.bounds() if node is UiClip or node is UiButton else Rect2(Vector2.ZERO, node.size)
		if rect.size != Vector2.ZERO:
			rect = Transform2D(node.rotation, node.scale, 0.0, node.position) * rect
			result = rect if result.size == Vector2.ZERO else result.merge(rect)
	return result


func _has_point(point: Vector2) -> bool:
	return _button and bounds().has_point(point)


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
	label.size = Vector2(rect[2] - 2 * TEXT_GUTTER, rect[3] - 2 * TEXT_GUTTER)
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
	label.text = text.replace("\r", "\n")
	label.add_theme_font_override("font", library.font(settings["font_id"]))
	label.add_theme_font_size_override("font_size", int(round(size)))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = {"left": HORIZONTAL_ALIGNMENT_LEFT, "right": HORIZONTAL_ALIGNMENT_RIGHT, "center": HORIZONTAL_ALIGNMENT_CENTER}.get(settings["align"], HORIZONTAL_ALIGNMENT_FILL)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if settings["word_wrap"] else TextServer.AUTOWRAP_OFF
	# The client makes most fields grow with their text (autoSize), so the port does not cut the text.
	label.clip_text = false
	if part.has("glow"):
		# A glow filter with a high strength draws an outline around the text.
		label.add_theme_color_override("font_outline_color", Color.html(part["glow"][0]))
		label.add_theme_constant_override("outline_size", int(round(float(part["glow"][1]))) + 1)
	return label
