class_name RiderArt
extends RefCounted
## The art of the mini-game of the Dragon Riding and the Rider Academy: the
## copy of its SWF file that the import (AssetImport) wrote to
## <data>/rider_game/game.swf, read with the extension FlashArt. FlashClip
## plays its sprites; the frames are drawn at the scale of the windows (see FrameCache).

const GAME_FILE := "rider_game/game.swf"
## The sprites of the file with a stop() in some frames (the classes
## SagaOTDC_fla.* of the file): class name -> those frames (from 0).
const STOP_FRAMES := {
	"SagaOTDC_fla.blood_all_23": [1, 11, 22, 31, 41],
	"SagaOTDC_fla.cb_cooldown_counter_4": [0],
	"SagaOTDC_fla.cb_tips_19": [0],
	"SagaOTDC_fla.final_boss_Death_81": [20],
	"SagaOTDC_fla.music_sign_15": [0],
	"SagaOTDC_fla.pit_black_370": [0, 11],
	"SagaOTDC_fla.shablya_appear_282": [9],
	"SagaOTDC_fla.shablya_disappear_275": [12],
	"SagaOTDC_fla.sound_sign_18": [0],
}

var flash: FlashArt
var _cache: FrameCache
var _frames := {}  # Sprite id -> SpriteLibrary.Frames.
var _labels := {}  # Sprite id -> {label: frame}.
var _parts := {}  # Vector2i(id, frame) -> Array of the parts of FlashArt.frame_parts().
var _bounds := {}  # Id -> Rect2.
var _frame_bounds := {}  # Vector2i(id, frame) -> Rect2.
var _stops := {}  # Sprite id -> Array of frames with stop().
var _own_timeline := {}  # Id -> bool, see needs_own_timeline().


## Null, with an error, when the import has no mini-game.
static func load_from(data_dir: String, cache: FrameCache) -> RiderArt:
	var flash_art := FlashArt.open(data_dir.path_join(GAME_FILE))
	if flash_art == null:
		return null
	var art := RiderArt.new()
	art.flash = flash_art
	art._cache = cache
	for name: String in STOP_FRAMES:
		var id := flash_art.symbol(name)
		if id >= 0:
			art._stops[id] = STOP_FRAMES[name]
	return art


## The character id of an exported symbol, for example "main.myhero"; -1 when the file has none.
func symbol(name: String) -> int:
	return flash.symbol(name)


func frame_count(id: int) -> int:
	return flash.frame_count(id)


## The frame (from 0) of a label of a sprite, or -1.
func label_frame(id: int, label: String) -> int:
	if not _labels.has(id):
		_labels[id] = flash.frame_labels(id)
	return _labels[id].get(label, -1)


## The display list of a frame of a sprite, see FlashArt.frame_parts().
func parts(id: int, frame: int) -> Array:
	var key := Vector2i(id, frame)
	if not _parts.has(key):
		_parts[key] = flash.frame_parts(id, frame)
	return _parts[key]


## The bounds of a character in pixels, as Flash measures them; empty when it draws nothing.
func bounds(id: int) -> Rect2:
	if not _bounds.has(id):
		_bounds[id] = flash.bounds(id)
	return _bounds[id]


## The bounds of one frame of a sprite, as Flash measures a clip that shows
## this frame: its parts in their frames now, a nested sprite in the frame
## that it plays from where it was placed. Another character: bounds().
func frame_bounds(id: int, frame: int) -> Rect2:
	var count := frame_count(id)
	if count <= 1 and parts(id, 0).is_empty():
		return bounds(id)
	frame = posmod(frame, maxi(count, 1))
	var key := Vector2i(id, frame)
	if _frame_bounds.has(key):
		return _frame_bounds[key]
	_frame_bounds[key] = Rect2()  # Stops the recursion in a file in which a sprite contains itself.
	var result := Rect2()
	for part: Dictionary in parts(id, frame):
		var part_frame: int = frame - int(part.start) if frame_count(part.id) > 1 else 0
		var rect := transformed(frame_bounds(part.id, part_frame), part.transform)
		if rect.has_area():
			result = rect if not result.has_area() else result.merge(rect)
	_frame_bounds[key] = result
	return result


## The rectangle that covers rect after a transform.
static func transformed(rect: Rect2, transform: Transform2D) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var result := Rect2(transform * rect.position, Vector2.ZERO)
	for corner in [rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
		result = result.expand(transform * corner)
	return result


func stops_at(id: int, frame: int) -> bool:
	return frame in _stops.get(id, [])


## The frames of a character, drawn at the scale of the windows.
func frames(id: int) -> SpriteLibrary.Frames:
	if not _frames.has(id):
		_frames[id] = SpriteLibrary.Frames.new(flash, id, maxi(frame_count(id), 1), _cache, false)
	return _frames[id]


## True when a sprite, or a sprite in it, stops in some frame. Such a sprite
## cannot be drawn as one picture for each frame: FlashArt plays the nested
## sprites of a frame in a loop, from the frame that placed them.
func needs_own_timeline(id: int) -> bool:
	if _own_timeline.has(id):
		return _own_timeline[id]
	_own_timeline[id] = _stops.has(id)  # Stops the recursion in a file in which a sprite contains itself.
	var result: bool = _stops.has(id)
	for frame in frame_count(id) if not result else 0:
		for part: Dictionary in parts(id, frame):
			if needs_own_timeline(part.id):
				result = true
				break
		if result:
			break
	_own_timeline[id] = result
	return result
