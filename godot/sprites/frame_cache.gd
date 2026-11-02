class_name FrameCache
extends Node
## The frames that the extension FlashArt drew for the map and for the windows
## (see SpriteLibrary.Frames).
##
## Memory: all frames together use at most `limit` bytes. When a frame needs
## more, the cache removes the frames that were used least recently. A frame
## that a node shows is in use, and the cache does not remove it; it counts as
## used now. A removed frame is drawn again when the game asks for it.
##
## Zoom: the frames of the map are drawn at the scale of the view (the zoom of
## the camera), rounded up to one of SCALES, so that they stay sharp when the
## camera zooms in. When the scale changes, the threads of FlashArt draw the
## frames that nodes show again, and each frame changes when its new image is
## ready; until then it shows the old image, enlarged. The other frames are
## drawn again when the game next asks for them. The windows are not zoomed:
## their frames stay at scale 1.

## The scales at which the frames of the map are drawn. MapCamera zooms up to 2.
const SCALES: Array[float] = [1.0, 1.5, 2.0]
const DEFAULT_LIMIT := 512 << 20

## The memory that the frames can use, in bytes.
var limit := DEFAULT_LIMIT
## The scale at which the frames of the map are drawn now.
var map_scale := 1.0
## The memory that the frames use now, in bytes.
var used := 0
var _entries := {}  # Entry -> true, the least recently used first.
var _waiting := {}  # Entry -> true: frames that the threads draw again at map_scale.


## One frame that the cache keeps.
class Entry:
	var art: FlashArt
	var id: int
	var frame: int
	var on_map: bool
	## What the nodes show: an image of the canvas of the character, with the
	## size of the canvas at scale 1 at all scales. Null after the cache removed the frame.
	var texture: AtlasTexture
	var removed := false
	var scale: float  ## The scale of the image now.
	var bytes: int
	var references: int  # The references to texture while only the cache has it.


func _process(_delta: float) -> void:
	var scale := scale_for(_view_scale())
	if scale != map_scale:
		map_scale = scale
		_waiting.clear()
		for entry: Entry in _entries:
			if entry.on_map and entry.scale != scale and is_shown(entry):
				_draw_again(entry)
	for entry: Entry in _waiting.keys():
		# _replace() can remove frames that come later in this list.
		if entry.removed:
			continue
		var image :=entry.art.take_ahead(entry.id, entry.frame, map_scale)
		if image != null:
			_replace(entry, image)
		# Without an image and not drawn ahead, the limit of the extension
		# removed it; the next use asks for it again.
		if image != null or not entry.art.is_ahead(entry.id, entry.frame, map_scale):
			_waiting.erase(entry)


## The scale of the frames for a view scale: the smallest of SCALES that is not smaller.
static func scale_for(view_scale: float) -> float:
	for scale in SCALES:
		if view_scale <= scale + 0.001:
			return scale
	return SCALES[-1]


## The scale at which frames are drawn now: map_scale for the map, 1 for the windows.
func scale_of(on_map: bool) -> float:
	return map_scale if on_map else 1.0


## Draws a frame of a character. canvas_size: the size of the canvas of the
## character, which the texture has. Null when the frame draws nothing.
func draw(art: FlashArt, id: int, frame: int, on_map: bool, canvas_size: Vector2) -> Entry:
	var area := art.frame_area(id, frame)
	if area.size == Vector2i.ZERO:
		return null
	var scale := scale_of(on_map)
	var image := art.render(id, frame, scale)
	if image == null:
		return null
	var entry := Entry.new()
	entry.art = art
	entry.id = id
	entry.frame = frame
	entry.on_map = on_map
	entry.scale = scale
	entry.bytes = image.get_data_size()
	var pixels := ImageTexture.create_from_image(image)
	# The image has the size of the area times the scale; the nodes use the size at scale 1.
	pixels.set_size_override(area.size)
	entry.texture = AtlasTexture.new()
	entry.texture.atlas = pixels
	entry.texture.region = Rect2(Vector2.ZERO, area.size)
	# The image covers only the part of the canvas that the frame draws on;
	# the margin keeps the size of the canvas.
	entry.texture.margin = Rect2(area.position, canvas_size - Vector2(area.size))
	entry.references = _references(entry)
	used += entry.bytes
	_entries[entry] = true
	_trim(entry)
	return entry


## Records that the game shows the frame now. A frame of the map at an old scale is drawn again.
func use(entry: Entry) -> void:
	_entries.erase(entry)
	_entries[entry] = true
	if entry.on_map and entry.scale != map_scale and not _waiting.has(entry):
		_draw_again(entry)


## True when a node shows the frame.
func is_shown(entry: Entry) -> bool:
	return not entry.removed and _references(entry) > entry.references


# The count includes the temporary references of this call. A caller that
# reads entry.texture before can keep one more reference in a temporary value,
# so is_shown() and draw() read entry.texture only here.
static func _references(entry: Entry) -> int:
	return entry.texture.get_reference_count()


func _view_scale() -> float:
	var view := get_viewport()
	return view.canvas_transform.get_scale().x * view.get_final_transform().get_scale().x


func _draw_again(entry: Entry) -> void:
	entry.art.draw_ahead(entry.id, PackedInt32Array([entry.frame]), map_scale)
	_waiting[entry] = true


## Puts a new image of the frame in its texture. The nodes that show it keep the same texture.
func _replace(entry: Entry, image: Image) -> void:
	var pixels: ImageTexture = entry.texture.atlas
	var size := Vector2i(pixels.get_size())
	pixels.set_image(image)
	pixels.set_size_override(size)
	used += image.get_data_size() - entry.bytes
	entry.bytes = image.get_data_size()
	entry.scale = map_scale
	_trim(entry)


## Removes the frames used least recently, but not keep, until the frames fit in the limit.
func _trim(keep: Entry) -> void:
	if used <= limit:
		return
	for entry: Entry in _entries.keys():
		if used <= limit:
			return
		if entry == keep:
			continue
		_entries.erase(entry)
		if is_shown(entry):
			_entries[entry] = true
		else:
			used -= entry.bytes
			entry.removed = true
			entry.texture = null
			_waiting.erase(entry)
