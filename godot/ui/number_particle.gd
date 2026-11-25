class_name NumberParticle
extends Control
## The numbers that float up and fade when the player pays or gets resources
## (NumberParticle of the client): one line for each value that is not 0, in
## the colour of its resource and with its icon (IconResourcesMC). The client
## moves the numbers once each frame at 30 frames a second: up at 2 pixels a
## frame, 0.01 faster each frame, and they fade in the second half of their life.
##
## The client scales the whole clip. The port scales the font size and the
## places instead, because a Label under a scaled node is drawn blurred.

const FRAME_SECONDS := 1.0 / 30.0
const START_SPEED := -2.0
const GRAVITY := -0.01
## The client makes each clip 10 % larger than the scale it gets.
const EXTRA_SCALE := 1.1
const LINE_SIZE := 19
const ICON_SCALE := 0.38
const ICON_X := 22.0
const ICON_Y := -28.0
const ICON_STEP := 23.0
## Resource code -> [text colour, frame (from 0) of IconResourcesMC].
const KINDS := {
	"c": [Color8(0x29, 0xE9, 0x00), 0],
	"g": [Color8(0xFF, 0xC4, 0x00), 1],
	"f": [Color8(0xC9, 0x00, 0x00), 2],
	"w": [Color8(0xC4, 0x75, 0x28), 3],
	"s": [Color8(0x80, 0x80, 0x80), 4],
	"x": [Color.BLACK, 7],
	"m": [Color8(0x27, 0x9A, 0x9C), 16],
	"p": [Color8(0x27, 0x9A, 0x9C), 19],
}

var _life: int
var _max_life: int
var _speed := START_SPEED
var _time := 0.0


## values: [resource code, amount] pairs in the order of the lines; an amount
## of 0 has no line. scale_factor and life (in frames) are those of the client.
func _init(ui: UiLibrary, values: Array, scale_factor: float, life: int) -> void:
	_life = life
	_max_life = life
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_factor := scale_factor * EXTRA_SCALE
	var clip := ui.make("NumberParticle2MC")
	add_child(clip)
	var score := clip.part("score") as Label
	var layout: FlashTextLayout = score.get_meta("text_layout")
	var line_height := layout.line_height(LINE_SIZE, score.get_meta("leading"))
	var origin := score.position
	var field: Vector2 = score.get_meta("field_size")
	var outline := score.get_theme_constant("outline_size")
	var line := 0
	for pair: Array in values:
		if int(pair[1]) == 0 or not KINDS.has(pair[0]):
			continue
		var label := score if line == 0 else score.duplicate() as Label
		if line > 0:
			clip.add_child(label)
		label.text = str(pair[1])
		label.add_theme_font_size_override("font_size", roundi(LINE_SIZE * size_factor))
		label.add_theme_color_override("font_color", KINDS[pair[0]][0])
		label.add_theme_constant_override("outline_size", roundi(outline * size_factor))
		label.position = (origin + Vector2(0, line * line_height)) * size_factor
		label.size = field * size_factor
		var icon := ui.make("IconResourcesMC")
		icon.show_frame(KINDS[pair[0]][1])
		icon.scale = Vector2.ONE * ICON_SCALE * size_factor
		icon.position = Vector2(ICON_X, ICON_Y + line * ICON_STEP) * size_factor
		clip.add_child(icon)
		line += 1
	score.visible = line > 0


func _ready() -> void:
	position = get_viewport_rect().size / 2


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS and _life > 0:
		_time -= FRAME_SECONDS
		modulate.a = minf(1.0, _life * 2.0 / _max_life)
		position.y += _speed
		_speed += GRAVITY
		_life -= 1
	if _life <= 0:
		queue_free()
