class_name FlashClip
extends Node2D
## Plays a sprite of the mini-game as a MovieClip of Flash does: a frame (from
## 0), playing or stopped, and the parts of the frame as children.
##
## Flash keeps a part from one frame to the next while the sprite places the
## same character at the same depth from the same frame; a new part starts at
## its first frame. A part with more frames plays in a loop. A part is one
## picture for each of its frames, unless its name is in `expand` or it has
## parts that stop (RiderArt.needs_own_timeline()): then it is a FlashClip
## itself, so that the game can play, stop or turn it. The game calls tick()
## once for each frame of Flash (30 per second).
##
## A mask of Flash shows the parts above it, up to its clip depth, only where
## it draws: those parts are its children, and it clips them. A colour
## transform with an added colour uses color_material().

## The shader of a colour transform of Flash: colour times multiply, plus add.
const COLOR_SHADER := "shader_type canvas_item;\nuniform vec4 multiply;\nuniform vec4 add;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = clamp(vec4(c.rgb * multiply.rgb + add.rgb, c.a * multiply.a + add.a), 0.0, 1.0);\n\tCOLOR.a = min(COLOR.a, c.a > 0.0 ? 1.0 : 0.0);\n}\n"
static var _shader: Shader
static var _materials := {}  # [multiply, add] -> ShaderMaterial.

var art: RiderArt
var id: int
var frame := 0
var playing := true
var _expand: Dictionary  # Part name -> true.
var _parts := {}  # Depth -> Part.
var _new_parts: Array[Part] = []  # Parts that came in this frame; they do not move on in it.
var _overrides := {}  # Part name -> {property: value}, see set_part().
var _entered: Array[int] = []  # The frames that the clip entered since take_entered().


class Part:
	var id: int
	var start: int
	var name: String
	var frame := 0
	var count := 1
	var clip_depth := 0  # A mask: the last depth that it clips.
	var node: Node2D  # A FlashClip, or a Sprite2D that shows `frame`.


func _init(rider_art: RiderArt, sprite_id: int, expand: Dictionary = {}) -> void:
	art = rider_art
	id = sprite_id
	_expand = expand
	_show_parts()


func frame_count() -> int:
	return art.frame_count(id)


## The frame of a label (String) or a frame (int); -1 for an unknown label.
func frame_of(target: Variant) -> int:
	return art.label_frame(id, target) if target is String else int(target)


## gotoAndPlay or gotoAndStop of Flash. A go to the frame that the clip
## shows now only plays or stops it.
func go_to(target: Variant, play_on: bool) -> void:
	var to := frame_of(target)
	if to < 0:
		push_error("FlashClip: no label %s in sprite %d" % [target, id])
		return
	playing = play_on
	if to != frame:
		_enter(to)


## The frames that the clip entered since the last call, in their order, for
## the scripts of the frames of the game.
func take_entered() -> Array[int]:
	var result := _entered
	_entered = []
	return result


## One frame of Flash: the next frame when the clip plays, and each part that
## did not come in this frame moves on.
func tick() -> void:
	for part: Part in _parts.values():
		if part in _new_parts:
			continue
		if part.node is FlashClip:
			(part.node as FlashClip).tick()
		elif part.count > 1:
			part.frame = (part.frame + 1) % part.count
			_show_picture(part)
	_new_parts.clear()
	if playing and frame_count() > 1:
		_enter((frame + 1) % frame_count())


## The part with this instance name, or null.
func part(name: String) -> Part:
	for found: Part in _parts.values():
		if found.name == name:
			return found
	return null


## Sets a property of a part by its name, as the code of the client does,
## also for the parts with this name in later frames: "alpha", "visible",
## "scale_x" (scaleX of Flash), "rotation" (degrees), "x" or "y".
func set_part(name: String, property: String, value: Variant) -> void:
	if not _overrides.has(name):
		_overrides[name] = {}
	_overrides[name][property] = value
	var found := part(name)
	if found != null:
		_apply_overrides(found)


## The FlashClip of an expanded part, or null.
func clip(name: String) -> FlashClip:
	var found := part(name)
	return found.node as FlashClip if found != null else null


## Shows a frame (from 0) of a part that plays in a loop, from which it plays on.
func set_part_frame(name: String, part_frame: int) -> void:
	var found := part(name)
	if found == null:
		return
	if found.node is FlashClip:
		(found.node as FlashClip).go_to(part_frame, true)
	else:
		found.frame = posmod(part_frame, found.count)
		_show_picture(found)


## Starts a part again from its first frame (gotoAndPlay(1) of the part).
func restart(name: String) -> void:
	var found := part(name)
	if found == null:
		return
	if found.node is FlashClip:
		(found.node as FlashClip).go_to(0, true)
	else:
		found.frame = 0
		_show_picture(found)


## The rectangle on `space` that a part covers, as hitTestObject of Flash
## measures it: the bounds of the part in its frame now, turned into `space`.
## path names the part and the parts in it, for example ["In", "shablya_1"].
## Empty when a part of the path is not in the frame now.
func part_rect(path: PackedStringArray, space: Node2D) -> Rect2:
	var found := part(path[0])
	if found == null:
		return Rect2()
	if found.node is FlashClip:
		return (found.node as FlashClip).part_rect(path.slice(1), space) if path.size() > 1 else (found.node as FlashClip).rect_in(space)
	var to_space := FlashClip.transform_to(found.node, space)
	var char_id := found.id
	var frame_now := found.frame
	for name in path.slice(1):
		var inner: Dictionary = {}
		for candidate: Dictionary in art.parts(char_id, frame_now):
			if candidate.name == name:
				inner = candidate
				break
		if inner.is_empty():
			return Rect2()
		to_space *= inner.transform as Transform2D
		frame_now = frame_now - int(inner.start) if art.frame_count(inner.id) > 1 else 0
		char_id = inner.id
	return RiderArt.transformed(art.frame_bounds(char_id, frame_now), to_space)


## The rectangle on `space` that the clip covers in its frame now.
func rect_in(space: Node2D) -> Rect2:
	var result := Rect2()
	for found: Part in _parts.values():
		var rect: Rect2
		if found.node is FlashClip:
			rect = (found.node as FlashClip).rect_in(space)
		else:
			rect = RiderArt.transformed(art.frame_bounds(found.id, found.frame), FlashClip.transform_to(found.node, space))
		if rect.has_area():
			result = rect if not result.has_area() else result.merge(rect)
	return result


## The transform from a node to one of its parents, from the transforms of
## the nodes between them. The game moves nodes many times between two
## frames of Godot, so it does not use the global transforms, which Godot
## updates later.
static func transform_to(node: Node2D, ancestor: Node2D) -> Transform2D:
	var result := Transform2D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node2D:
		result = (current as Node2D).transform * result
		current = current.get_parent()
	return result


## A material that draws the colour transform of Flash: colour times multiply, plus add (0 to 1).
static func color_material(multiply: Color, add: Color) -> ShaderMaterial:
	var key := [multiply, add]
	if not _materials.has(key):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = COLOR_SHADER
		var material := ShaderMaterial.new()
		material.shader = _shader
		material.set_shader_parameter("multiply", multiply)
		material.set_shader_parameter("add", add)
		_materials[key] = material
	return _materials[key]


func _enter(to: int) -> void:
	frame = to
	_entered.append(to)
	_show_parts()
	if art.stops_at(id, frame):
		playing = false


func _show_parts() -> void:
	var kept := {}
	var mask: Part = null
	for info: Dictionary in art.parts(id, frame):
		var depth: int = info.depth
		var found: Part = _parts.get(depth)
		if found == null or found.id != info.id or found.start != info.start:
			if found != null:
				_drop(found.node)
			found = _make_part(info)
		if mask != null and depth > mask.clip_depth:
			mask = null
		var holder: Node2D = mask.node if mask != null else self
		if found.node.get_parent() != holder:
			if found.node.get_parent() != null:
				found.node.get_parent().remove_child(found.node)
			holder.add_child(found.node)
		found.node.transform = info.transform if mask == null else mask.node.transform.affine_inverse() * (info.transform as Transform2D)
		var add: Color = info.add
		if add == Color(0, 0, 0, 0) or not found.node is Sprite2D:
			found.node.modulate = info.multiply
			found.node.material = null
		else:
			found.node.modulate = Color.WHITE
			found.node.material = color_material(info.multiply, add)
		found.clip_depth = info.clip_depth
		found.node.clip_children = CanvasItem.CLIP_CHILDREN_ONLY if found.clip_depth > 0 else CanvasItem.CLIP_CHILDREN_DISABLED
		_apply_overrides(found)
		kept[depth] = found
		if found.clip_depth > 0 and mask == null:
			mask = found
	for depth: int in _parts:
		if not kept.has(depth):
			_drop((_parts[depth] as Part).node)
	_parts = kept
	# The children in the order of the depths, as Flash draws them.
	var depths := _parts.keys()
	depths.sort()
	var places := {}  # Holder -> next index.
	for depth: int in depths:
		var node := (_parts[depth] as Part).node
		var holder := node.get_parent()
		var index: int = places.get(holder, 0)
		holder.move_child(node, index)
		places[holder] = index + 1


func _apply_overrides(found: Part) -> void:
	var values: Dictionary = _overrides.get(found.name, {})
	for property: String in values:
		var value: Variant = values[property]
		match property:
			"alpha":
				found.node.modulate.a = value
			"visible":
				found.node.visible = value
			"scale_x":
				found.node.scale = Vector2(float(value) * (-1.0 if found.node.scale.x < 0.0 else 1.0), found.node.scale.y)
			"rotation":
				found.node.rotation_degrees = value
			"x":
				found.node.position.x = value
			"y":
				found.node.position.y = value


func _drop(node: Node2D) -> void:
	# The parts that a mask held go back to the clip first, or they would go with it.
	for child in node.get_children():
		if child is Node2D and _owns(child as Node2D):
			node.remove_child(child)
			add_child(child)
	node.get_parent().remove_child(node)
	node.queue_free()


func _owns(node: Node2D) -> bool:
	for found: Part in _parts.values():
		if found.node == node:
			return true
	return false


func _make_part(info: Dictionary) -> Part:
	var made := Part.new()
	made.id = info.id
	made.start = info.start
	made.name = info.name
	made.count = maxi(art.frame_count(made.id), 1)
	if _expand.has(made.name) or art.needs_own_timeline(made.id):
		made.node = FlashClip.new(art, made.id, _expand)
	else:
		var picture := Sprite2D.new()
		picture.centered = false
		made.node = picture
		_show_picture(made)
	made.node.name = made.name if not made.name.is_empty() else "part%d" % info.depth
	add_child(made.node)
	_new_parts.append(made)
	return made


func _show_picture(found: Part) -> void:
	var frames := art.frames(found.id)
	var picture := found.node as Sprite2D
	picture.offset = frames.origin
	picture.texture = frames.get_frame(found.frame)
