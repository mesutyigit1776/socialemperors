class_name SpriteLibrary
extends RefCounted
## Graphics that the importer writes: the items in <data>/sprites/<img_name>/,
## the shots and effects of battles in <data>/fx/<name>/. Each folder has a
## copy of the SWF file of the graphic and meta.json, see importer/import_assets.py.
##
## The port draws the frames from the SWF file while it runs, with the
## extension FlashArt (flash_art/), at the zoom of the camera. A frame is
## drawn when it is first shown; a FrameCache keeps it.

## The copy of the SWF file in the folder of a graphic.
const GRAPHIC_FILE := "graphic.swf"


## The frames of one character of a SWF file, drawn when they are first asked
## for. A FrameCache keeps them; it can remove them and draw them again.
class Frames:
	var origin: Vector2  ## Top-left of each frame image relative to the registration point.
	var _art: FlashArt
	var _id: int
	var _cache: FrameCache
	var _on_map: bool
	var _size: Vector2  # The size of the canvas, which each frame image has.
	var _entries: Array[FrameCache.Entry] = []
	var _empty: Array[bool] = []  # Frames that draw nothing.

	## on_map: the frames are drawn at the scale of the map (see FrameCache).
	func _init(art: FlashArt, id: int, count: int, cache: FrameCache, on_map: bool) -> void:
		_art = art
		_id = id
		_cache = cache
		_on_map = on_map
		_entries.resize(count)
		_empty.resize(count)
		var canvas := art.canvas(id)
		origin = canvas.position
		_size = canvas.size

	func count() -> int:
		return _entries.size()

	## frame is 0-based. Null when the frame draws nothing.
	func get_frame(frame: int) -> Texture2D:
		frame = clampi(frame, 0, _entries.size() - 1)
		var entry := _entries[frame]
		if entry != null and not entry.removed:
			_cache.use(entry)
			return entry.texture
		if _empty[frame]:
			return null
		entry = _cache.draw(_art, _id, frame, _on_map, _size)
		_entries[frame] = entry
		_empty[frame] = entry == null
		return entry.texture if entry != null else null

	## Starts to draw the frames that the cache does not have on other
	## threads, for an animation that starts to play.
	func draw_ahead() -> void:
		var frames := PackedInt32Array()
		for frame in _entries.size():
			if not _empty[frame] and (_entries[frame] == null or _entries[frame].removed):
				frames.append(frame)
		if not frames.is_empty():
			_art.draw_ahead(_id, frames, _cache.scale_of(_on_map))


class ItemSprite:
	var frames: Frames
	var frame_sizes: Array[Vector2] = []  ## Size of each frame as Flash measures it.
	## Top-left of the bounds of each frame relative to the registration point,
	## as Flash measures them.
	var frame_origins: Array[Vector2] = []
	## For each frame, the point where the shots of the item start, relative to
	## the registration point, or null.
	var shot_points: Array = []
	var origin: Vector2  ## Top-left of each frame image relative to the symbol registration point.
	## For each frame of a unit graphic, the FrameClip that it plays, or null.
	var frame_clips: Array = []
	var _art: FlashArt
	var _id: int
	var _cache: FrameCache
	var _still_clips: Array = []  # The FrameClip of each frame of a still graphic, see still_clip().

	## The clip in frame of a graphic that does not play its clips, or null.
	## The client shows another frame of such a clip for some items, for
	## example the tree of each map style.
	func still_clip(frame: int) -> FrameClip:
		if _still_clips.is_empty() and _art != null:
			for entry: Variant in _art.frame_clips(_id):
				var frame_clip: FrameClip = null
				if entry != null:
					frame_clip = FrameClip.new()
					frame_clip.clip = Clip.new(Frames.new(_art, entry[0], _art.frame_count(entry[0]), _cache, true))
					frame_clip.transform = entry[1]
				_still_clips.append(frame_clip)
		frame = _index(frame)
		return _still_clips[frame] if frame < _still_clips.size() else null

	## The clip of frame, or null when the frame is a still image.
	func get_frame_clip(frame: int) -> FrameClip:
		return frame_clips[frame] if frame >= 0 and frame < frame_clips.size() else null

	func frame_count() -> int:
		return frame_sizes.size()

	## frame is 0-based. A frame that the graphic does not have shows the last frame.
	func get_frame(frame: int) -> Texture2D:
		return frames.get_frame(_index(frame))

	func get_frame_size(frame: int) -> Vector2:
		return frame_sizes[_index(frame)]

	## The bounds of frame relative to the registration point, as Flash
	## measures them. Needs frame_origins.
	func get_frame_rect(frame: int) -> Rect2:
		return Rect2(frame_origins[_index(frame)], frame_sizes[_index(frame)])

	## The shot point of frame (Vector2), or null.
	func get_shot_point(frame: int) -> Variant:
		return shot_points[_index(frame)]

	func _index(frame: int) -> int:
		return clampi(frame, 0, frame_sizes.size() - 1)


## A nested animation of a unit graphic, for example the walk in one direction.
class Clip:
	var origin: Vector2  ## Top-left of each frame image relative to the clip registration point.
	var _frames: Frames

	func _init(frames: Frames) -> void:
		_frames = frames
		origin = frames.origin

	func frame_count() -> int:
		return _frames.count()

	## frame is 0-based.
	func get_frame(frame: int) -> Texture2D:
		return _frames.get_frame(frame)

	## Starts to draw the frames on other threads, so that the clip plays without waits.
	func draw_ahead() -> void:
		_frames.draw_ahead()


## A clip in a frame of a unit graphic, and where the frame places it.
class FrameClip:
	var clip: Clip
	var transform: Transform2D


var _sprites_dir: String
var _frames: FrameCache
var _cache: Dictionary = {}  # img_name -> ItemSprite, or null when the graphic is missing


## folder: "sprites" for the items, "fx" for the shots and effects.
func _init(data_dir: String, frames: FrameCache, folder := "sprites") -> void:
	_sprites_dir = data_dir.path_join(folder)
	_frames = frames


## Returns null when the graphic was not imported. Reports each missing graphic once.
func get_sprite(img_name: String) -> ItemSprite:
	if not _cache.has(img_name):
		_cache[img_name] = _load(img_name)
	return _cache[img_name]


func _load(img_name: String) -> ItemSprite:
	var dir := _sprites_dir.path_join(img_name)
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json"))) if FileAccess.file_exists(dir.path_join("meta.json")) else null
	if not (meta is Dictionary and meta.get("animated") is bool):
		push_warning("Graphic '%s' is not imported, or is from an older import. Import the files again." % img_name)
		return null
	var art := FlashArt.open(dir.path_join(GRAPHIC_FILE))
	var id := art.symbol(img_name) if art != null else -1
	if id < 0 or art.frame_count(id) == 0:
		push_warning("Graphic '%s' has no symbol in its SWF file. Import the files again." % img_name)
		return null
	var sprite := ItemSprite.new()
	sprite.frames = Frames.new(art, id, art.frame_count(id), _frames, true)
	sprite.origin = sprite.frames.origin
	for rect: Rect2 in art.frame_rects(id):
		sprite.frame_sizes.append(rect.size)
		sprite.frame_origins.append(rect.position)
	sprite.shot_points = art.shot_points(id)
	sprite._art = art
	sprite._id = id
	sprite._cache = _frames
	if meta["animated"]:
		var clips := {}
		for entry: Variant in art.frame_clips(id):
			if entry == null:
				sprite.frame_clips.append(null)
				continue
			var clip_id: int = entry[0]
			if not clips.has(clip_id):
				clips[clip_id] = Clip.new(Frames.new(art, clip_id, art.frame_count(clip_id), _frames, true))
			var frame_clip := FrameClip.new()
			frame_clip.clip = clips[clip_id]
			frame_clip.transform = entry[1]
			sprite.frame_clips.append(frame_clip)
	return sprite
