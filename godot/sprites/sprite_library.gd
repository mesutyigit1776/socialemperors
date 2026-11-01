class_name SpriteLibrary
extends RefCounted
## Graphics that the importer writes: the items in <data>/sprites/<img_name>/,
## the shots and effects of battles in <data>/fx/<name>/. Each folder has a
## copy of the SWF file of the graphic and meta.json, see importer/import_assets.py.
##
## The port draws the frames from the SWF file while it runs, with the
## extension FlashArt (flash_art/). A frame is drawn when it is first shown
## and then kept.

## The copy of the SWF file in the folder of a graphic.
const GRAPHIC_FILE := "graphic.swf"


## The frames of one character of a SWF file, drawn when they are first asked for.
class Frames:
	var _art: FlashArt
	var _id: int
	var _textures: Array[Texture2D] = []
	var _drawn: Array[bool] = []
	var _ahead := false
	var origin: Vector2  ## Top-left of each frame image relative to the registration point.
	var _size: Vector2  # The size of the canvas, which each frame image has.

	func _init(art: FlashArt, id: int, count: int) -> void:
		_art = art
		_id = id
		_textures.resize(count)
		_drawn.resize(count)
		var canvas := art.canvas(id)
		origin = canvas.position
		_size = canvas.size

	func count() -> int:
		return _textures.size()

	## frame is 0-based. Null when the frame draws nothing.
	func get_frame(frame: int) -> Texture2D:
		frame = clampi(frame, 0, _textures.size() - 1)
		if not _drawn[frame]:
			_drawn[frame] = true
			var image := _art.render(_id, frame)
			if image != null:
				# The image covers only the part of the canvas that the frame
				# draws on; the margin keeps the size of the canvas.
				var area := _art.frame_area(_id, frame)
				var atlas := AtlasTexture.new()
				atlas.atlas = ImageTexture.create_from_image(image)
				atlas.region = Rect2(Vector2.ZERO, area.size)
				atlas.margin = Rect2(area.position, _size - Vector2(area.size))
				_textures[frame] = atlas
		return _textures[frame]

	## Starts to draw all frames on other threads, for an animation that starts to play.
	func draw_ahead() -> void:
		if _ahead:
			return
		_ahead = true
		var frames := PackedInt32Array()
		for frame in _textures.size():
			if not _drawn[frame]:
				frames.append(frame)
		_art.draw_ahead(_id, frames)


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
	sprite.frames = Frames.new(art, id, art.frame_count(id))
	sprite.origin = sprite.frames.origin
	for rect: Rect2 in art.frame_rects(id):
		sprite.frame_sizes.append(rect.size)
		sprite.frame_origins.append(rect.position)
	sprite.shot_points = art.shot_points(id)
	if meta["animated"]:
		var clips := {}
		for entry: Variant in art.frame_clips(id):
			if entry == null:
				sprite.frame_clips.append(null)
				continue
			var clip_id: int = entry[0]
			if not clips.has(clip_id):
				clips[clip_id] = Clip.new(Frames.new(art, clip_id, art.frame_count(clip_id)))
			var frame_clip := FrameClip.new()
			frame_clip.clip = clips[clip_id]
			frame_clip.transform = entry[1]
			sprite.frame_clips.append(frame_clip)
	return sprite
