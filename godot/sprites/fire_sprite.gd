class_name FireSprite
extends Node2D
## The fire of a damaged building (FireMC of the client). The client shows
## frame 1 to 4 of FireMC by the life of the building (state()); each frame
## places 1 to 4 copies of one animated flame. The port plays the flame at
## each place; the importer writes the places to fx/fire_flames.json.

const FRAME_SECONDS := 1.0 / 30.0
const FLAMES_FILE := "fx/fire_flames.json"
const SYMBOL := "FireMC"

var _clip: SpriteLibrary.Clip
var _nodes: Array[Sprite2D] = []
var _frame := 0
var _time := 0.0


## The frame of FireMC (1 to 4) for the life of a building, or 0 without fire,
## as the client chooses it: below 100%, 67%, 34%, and at 0%.
static func state(life: int, max_life: int) -> int:
	var percent := int(float(life) / maxi(max_life, 1) * 100)
	if percent == 0:
		return 4
	if percent < 34:
		return 3
	if percent < 67:
		return 2
	return 1 if percent < 100 else 0


## The places of the flames in each frame of FireMC: Array of Array[Transform2D], or [] without the import.
static func read_flames(data_dir: String) -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join(FLAMES_FILE))) if FileAccess.file_exists(data_dir.path_join(FLAMES_FILE)) else null
	var result := []
	for frame: Variant in data.get("frames", []) if data is Dictionary else []:
		var places: Array[Transform2D] = []
		for m: Array in frame:
			places.append(Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5])))
		result.append(places)
	return result


## fire: the imported FireMC graphic; its first frame has the flame clip.
## places: the places of the flames of the frame, see read_flames().
func _init(fire: SpriteLibrary.ItemSprite, places: Array[Transform2D]) -> void:
	var first := fire.get_frame_clip(0)
	_clip = first.clip if first != null else null
	if _clip == null:
		return
	_clip.draw_ahead()
	for place in places:
		var node := Sprite2D.new()
		node.centered = false
		node.transform = place
		node.offset = _clip.origin
		node.texture = _clip.get_frame(0)
		add_child(node)
		_nodes.append(node)


func _process(delta: float) -> void:
	if _clip == null:
		return
	_time += delta
	if _time < FRAME_SECONDS:
		return
	_time = fmod(_time, FRAME_SECONDS)
	_frame = (_frame + 1) % _clip.frame_count()
	var texture := _clip.get_frame(_frame)
	for node in _nodes:
		node.texture = texture
