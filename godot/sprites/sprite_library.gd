class_name SpriteLibrary
extends RefCounted
## Graphics that the importer writes: the items in <data>/sprites/<img_name>/,
## the shots and effects of battles in <data>/fx/<name>/.


class ItemSprite:
	var frames: Array[Texture2D] = []
	var frame_sizes: Array[Vector2] = []  ## Size of each frame as Flash measures it.
	## Top-left of the bounds of each frame relative to the registration point,
	## as Flash measures them. Empty in data of an older import.
	var frame_origins: Array[Vector2] = []
	## For each frame, the point where the shots of the item start, relative to
	## the registration point, or null. Empty in data of an older import.
	var shot_points: Array = []
	var origin: Vector2  ## Top-left of each frame image relative to the symbol registration point.
	## For each frame of a unit graphic, the FrameClip that it plays, or null.
	var frame_clips: Array = []

	## The clip of frame, or null when the frame is a still image.
	func get_frame_clip(frame: int) -> FrameClip:
		return frame_clips[frame] if frame >= 0 and frame < frame_clips.size() else null

	## frame is 0-based. A frame that the graphic does not have shows the last frame.
	func get_frame(frame: int) -> Texture2D:
		return frames[_index(frame)]

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
		return clampi(frame, 0, frames.size() - 1)


## A nested animation of a unit graphic, for example the walk in one direction.
## Its frames load when they are first shown.
class Clip:
	var origin: Vector2  ## Top-left of each frame image relative to the clip registration point.
	var _dir: String
	var _count: int
	var _frames: Array[Texture2D] = []

	func _init(dir: String, count: int, clip_origin: Vector2) -> void:
		_dir = dir
		_count = count
		origin = clip_origin

	func frame_count() -> int:
		return _count

	## frame is 0-based. A frame that cannot load is empty.
	func get_frame(frame: int) -> Texture2D:
		if _frames.is_empty():
			for i in _count:
				var image := Image.load_from_file(_dir.path_join("%d.png" % (i + 1)))
				_frames.append(ImageTexture.create_from_image(image) if image != null else null)
		return _frames[clampi(frame, 0, _count - 1)]


## A clip in a frame of a unit graphic, and where the frame places it.
class FrameClip:
	var clip: Clip
	var transform: Transform2D


var _sprites_dir: String
var _cache: Dictionary = {}  # img_name -> ItemSprite, or null when the graphic is missing


## folder: "sprites" for the items, "fx" for the shots and effects.
func _init(data_dir: String, folder := "sprites") -> void:
	_sprites_dir = data_dir.path_join(folder)


## Returns null when the graphic was not imported. Reports each missing graphic once.
func get_sprite(img_name: String) -> ItemSprite:
	if not _cache.has(img_name):
		_cache[img_name] = _load(img_name)
	return _cache[img_name]


func _load(img_name: String) -> ItemSprite:
	var dir := _sprites_dir.path_join(img_name)
	if not FileAccess.file_exists(dir.path_join("meta.json")):
		push_warning("Graphic '%s' is not imported." % img_name)
		return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("meta.json")))
	if not (meta is Dictionary and meta.get("frame_sizes") is Array and not meta["frame_sizes"].is_empty()):
		push_warning("Graphic '%s' is not imported." % img_name)
		return null
	var sprite := ItemSprite.new()
	sprite.origin = Vector2(float(meta.get("origin_x", 0)), float(meta.get("origin_y", 0)))
	for i in meta["frame_sizes"].size():
		var size: Variant = meta["frame_sizes"][i]
		var image := Image.load_from_file(dir.path_join("%d.png" % (i + 1)))
		if not (size is Array and size.size() == 2) or image == null:
			push_warning("Graphic '%s' has no correct frame %d." % [img_name, i + 1])
			return null
		sprite.frame_sizes.append(Vector2(float(size[0]), float(size[1])))
		sprite.frames.append(ImageTexture.create_from_image(image))
	if meta.has("frame_clips"):
		sprite.frame_clips = _load_clips(img_name, dir, meta)
	_load_shot_data(img_name, sprite, meta)
	return sprite


## Reads frame_origins and shot_points. Keeps both empty when the meta data
## does not have them, as from an older import, or is not correct.
func _load_shot_data(img_name: String, sprite: ItemSprite, meta: Dictionary) -> void:
	var origins: Variant = meta.get("frame_origins")
	var points: Variant = meta.get("shot_points")
	if origins == null and points == null:
		return
	var count := sprite.frames.size()
	if not (origins is Array and points is Array and origins.size() == count and points.size() == count):
		push_warning("Graphic '%s' has no correct shot data." % img_name)
		return
	var frame_origins: Array[Vector2] = []
	var shot_points := []
	for i in count:
		var corner: Variant = origins[i]
		var point: Variant = points[i]
		if not (_is_point(corner) and (point == null or _is_point(point))):
			push_warning("Graphic '%s' has no correct shot data." % img_name)
			return
		frame_origins.append(Vector2(corner[0], corner[1]))
		shot_points.append(null if point == null else Vector2(point[0], point[1]))
	sprite.frame_origins = frame_origins
	sprite.shot_points = shot_points


static func _is_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int)


## Returns the FrameClip or null for each frame. Returns no clips when the meta
## data is not correct, so that the unit shows its still frames.
func _load_clips(img_name: String, dir: String, meta: Dictionary) -> Array:
	var entries: Variant = meta["frame_clips"]
	var clip_meta: Variant = meta.get("clips")
	if not (entries is Array and entries.size() == meta["frame_sizes"].size() and clip_meta is Dictionary):
		push_warning("Graphic '%s' has no correct clips." % img_name)
		return []
	var clips := {}
	var result := []
	for entry: Variant in entries:
		if entry == null:
			result.append(null)
			continue
		var info: Variant = clip_meta.get(str(int(entry[0]))) if entry is Array and entry.size() == 7 else null
		if not (info is Dictionary and info.get("frames") is float and info["frames"] > 0):
			push_warning("Graphic '%s' has no correct clips." % img_name)
			return []
		var id := str(int(entry[0]))
		if not clips.has(id):
			clips[id] = Clip.new(dir.path_join("clips").path_join(id), int(info["frames"]), Vector2(float(info.get("origin_x", 0)), float(info.get("origin_y", 0))))
		var frame_clip := FrameClip.new()
		frame_clip.clip = clips[id]
		# Flash matrix [a, b, c, d, tx, ty]: x' = a x + c y + tx, y' = b x + d y + ty.
		frame_clip.transform = Transform2D(Vector2(entry[1], entry[2]), Vector2(entry[3], entry[4]), Vector2(entry[5], entry[6]))
		result.append(frame_clip)
	return result
