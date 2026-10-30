class_name SpriteLibrary
extends RefCounted
## Item graphics that the importer writes to <data>/sprites/<img_name>/.


class ItemSprite:
	var frames: Array[Texture2D] = []
	var frame_sizes: Array[Vector2] = []  ## Size of each frame as Flash measures it.
	var origin: Vector2  ## Top-left of each frame image relative to the symbol registration point.

	## frame is 0-based. A frame that the graphic does not have shows the last frame.
	func get_frame(frame: int) -> Texture2D:
		return frames[_index(frame)]

	func get_frame_size(frame: int) -> Vector2:
		return frame_sizes[_index(frame)]

	func _index(frame: int) -> int:
		return clampi(frame, 0, frames.size() - 1)


var _sprites_dir: String
var _cache: Dictionary = {}  # img_name -> ItemSprite, or null when the graphic is missing


func _init(data_dir: String) -> void:
	_sprites_dir = data_dir.path_join("sprites")


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
	return sprite
