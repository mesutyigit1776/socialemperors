class_name UiLibrary
extends RefCounted
## The windows of the client that importer/ui_import.py wrote to <data>/ui:
## their sprites without the named parts, the named parts, the named buttons,
## the fonts of the text fields and the pictures of the windows. The port draws
## the sprites, buttons and fonts from windows.swf with the extension FlashArt.
## UiClip shows a window.

## The copy of the SWF file with the windows, see importer/ui_import.py.
const WINDOWS_FILE := "windows.swf"
const BUTTON_STATES := {"up": 0, "over": 1, "down": 2}

var _dir: String
var _art: FlashArt
var _frames: Dictionary = {}  # Sprite id -> SpriteLibrary.Frames.
var _button_images: Dictionary = {}  # [button id, state] -> Texture2D, or null.
var _symbols: Dictionary = {}  # Symbol name -> sprite id.
var _clips: Dictionary = {}  # Sprite id (int) -> {"origin": Vector2 or null, "frames": [[part, ...], ...], "labels": {label: frame}}
var _buttons: Dictionary = {}  # Button id (int) -> top-left of its images (Vector2).
var _textures: Dictionary = {}  # Path -> Texture2D, or null for a missing file.
var _fonts: Dictionary = {}  # Font id -> Font.


## Returns null and reports an error when <data_dir>/<folder>/layout.json is
## missing or not valid. The folder "ui/cast" has the banner of a cast spell.
static func load_from(data_dir: String, folder := "ui") -> UiLibrary:
	var path := data_dir.path_join(folder).path_join("layout.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary and data.get("symbols") is Dictionary and data.get("clips") is Dictionary):
		push_error("Cannot read the windows of the client from '%s'. Import the game files again." % path)
		return null
	var library := UiLibrary.new()
	library._dir = data_dir.path_join(folder)
	for name: String in data["symbols"]:
		library._symbols[name] = int(data["symbols"][name])
	for key: String in data["clips"]:
		var clip: Variant = data["clips"][key]
		if not (key.is_valid_int() and clip is Dictionary and clip.get("frames") is Array):
			push_error("'%s' has an incorrect sprite %s." % [path, key])
			return null
		var origin: Variant = clip.get("origin")
		library._clips[key.to_int()] = {
			"origin": Vector2(origin[0], origin[1]) if origin is Array and origin.size() == 2 else null,
			"frames": clip["frames"],
			"labels": clip.get("labels", {}) if clip.get("labels", {}) is Dictionary else {},
		}
	library._art = FlashArt.open(library._dir.path_join(WINDOWS_FILE)) if FileAccess.file_exists(library._dir.path_join(WINDOWS_FILE)) else null
	if library._art == null:
		push_error("'%s' is missing. Import the game files again." % library._dir.path_join(WINDOWS_FILE))
		return null
	var buttons: Variant = data.get("buttons", {})
	for key: String in buttons if buttons is Dictionary else {}:
		if not key.is_valid_int():
			push_error("'%s' has an incorrect button %s." % [path, key])
			return null
		library._buttons[key.to_int()] = library._art.canvas(key.to_int()).position
	for name: String in library._symbols:
		if not library._clips.has(library._symbols[name]):
			push_error("'%s' has no sprite for the window %s." % [path, name])
			return null
	return library


func has_symbol(name: String) -> bool:
	return _symbols.has(name)


## A new node that shows the window or part of the client with this name, see importer/ui_import.py.
func make(symbol: String) -> UiClip:
	return UiClip.new(self, _symbols[symbol])


## A picture of the windows, for example "quests_manager_img_1.jpg", or null.
func image(name: String) -> Texture2D:
	return _texture(_dir.path_join("images").path_join(name))


## The small picture of a unit that the windows show, for example a lost unit, or null.
func thumb(img_name: String) -> Texture2D:
	return _texture(_dir.path_join("thumbs/%s.jpg" % img_name))


func clip_frames(sprite_id: int) -> Array:
	return _clips[sprite_id]["frames"]


## The top-left corner of the frame images of the sprite, relative to its
## registration point, or null when the sprite has nothing besides its parts.
func clip_origin(sprite_id: int) -> Variant:
	return _clip_frames(sprite_id).origin if _clips[sprite_id]["origin"] != null else null


## The frame (from 0) of the sprite with this label, or -1.
func clip_label(sprite_id: int, label: String) -> int:
	return int(_clips[sprite_id]["labels"].get(label, -1))


## The image of a button in state "up", "over" or "down", or null.
func button_image(button_id: int, state: String) -> Texture2D:
	var key := [button_id, state]
	if not _button_images.has(key):
		var image := _art.render_button(button_id, BUTTON_STATES[state])
		_button_images[key] = ImageTexture.create_from_image(image) if image != null else null
	return _button_images[key]


## The top-left corner of the images of a button, relative to its registration point.
func button_origin(button_id: int) -> Vector2:
	return _buttons.get(button_id, Vector2.ZERO)


## The image of frame (from 0) of the sprite without its parts, or null.
func clip_image(sprite_id: int, frame: int) -> Texture2D:
	if _clips[sprite_id]["origin"] == null:
		return null
	return _clip_frames(sprite_id).get_frame(frame)


## The font of a text field, or the default font when the import has no file for it.
func font(font_id: Variant) -> Font:
	if font_id == null:
		return ThemeDB.fallback_font
	if not _fonts.has(font_id):
		var data := _art.font_data(int(font_id))
		var file := FontFile.new()
		file.data = data
		_fonts[font_id] = file if not data.is_empty() else ThemeDB.fallback_font
	return _fonts[font_id]


func _clip_frames(sprite_id: int) -> SpriteLibrary.Frames:
	if not _frames.has(sprite_id):
		_frames[sprite_id] = SpriteLibrary.Frames.new(_art, sprite_id, _art.frame_count(sprite_id))
	return _frames[sprite_id]


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var image := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_textures[path] = ImageTexture.create_from_image(image) if image != null else null
		if image == null:
			push_warning("The window image '%s' is missing. Import the game files again." % path)
	return _textures[path]
