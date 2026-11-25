class_name NumberParticle
extends Control
## The numbers and short texts that float up and fade (NumberParticle of the
## client): when the player pays or gets resources, damage and healing in
## battles, and messages such as "Not ready yet!". One line for each value
## that is not 0, in the colour of its kind and, for a resource, with its icon
## (IconResourcesMC). A NumberLayer moves them.
##
## The client scales the whole clip. The port scales the font size and the
## places instead, because a Label under a scaled node is drawn blurred.

const START_SPEED := -2.0
const GRAVITY := -0.01
## The client makes each clip 10 % larger than the scale it gets.
const EXTRA_SCALE := 1.1
const LINE_SIZE := 19
const ICON_SCALE := 0.38
const ICON_X := 22.0
const ICON_Y := -28.0
const ICON_STEP := 23.0
const NO_ICON := -1
const LIFE := 30  ## Frames, when the caller gives no other life.

## The kinds of value. The resource codes are those of the game; the others
## are the codes of the client (Constants.COST_* and TEXT_*), except HONOR,
## which has the empty code in the client.
const XP := "x"
const DAMAGE_SELF := "ds"  ## Damage to a unit of the player.
const DAMAGE_ENEMY := "de"  ## Damage to an enemy unit.
const ABSORBED := "abs"
const HEAL := "h"
const TIME := "t"
const MANA := "m"
const POTIONS := "p"
const MULTIPLE := "all"
const HONOR := "honor"
const TEXT_RED := "tr"
const TEXT_GREEN := "tg"
const TEXT_BLACK := "tb"

## Kind -> [text colour, frame (from 0) of IconResourcesMC or NO_ICON, text before the value].
const KINDS := {
	"c": [Color8(0x29, 0xE9, 0x00), 0, ""],
	"g": [Color8(0xFF, 0xC4, 0x00), 1, ""],
	"f": [Color8(0xC9, 0x00, 0x00), 2, ""],
	"w": [Color8(0xC4, 0x75, 0x28), 3, ""],
	"s": [Color8(0x80, 0x80, 0x80), 4, ""],
	XP: [Color.BLACK, 7, ""],
	TIME: [Color.BLACK, 14, ""],
	MANA: [Color8(0x27, 0x9A, 0x9C), 16, ""],
	POTIONS: [Color8(0x27, 0x9A, 0x9C), 19, ""],
	MULTIPLE: [Color8(0x27, 0x9A, 0x9C), 20, ""],
	HONOR: [Color8(0xFF, 0xC4, 0x00), 21, "+"],
	DAMAGE_SELF: [Color8(0xFF, 0x00, 0x00), NO_ICON, "-"],
	DAMAGE_ENEMY: [Color.BLACK, NO_ICON, "-"],
	ABSORBED: [Color8(0x00, 0xAF, 0xAF), NO_ICON, ""],
	HEAL: [Color8(0x00, 0xFF, 0x00), NO_ICON, "+"],
	TEXT_RED: [Color8(0xFF, 0x00, 0x00), NO_ICON, ""],
	TEXT_GREEN: [Color8(0x00, 0xFF, 0x00), NO_ICON, ""],
	TEXT_BLACK: [Color.BLACK, NO_ICON, ""],
}

var dead := false
var _life: int
var _max_life: int
var _speed := START_SPEED


## at: the start point on the screen. values: [kind, value] pairs in the order
## of the lines; the value is a number or a text. As in the client, a value
## that is 0 (also a text such as "0" or "") has no line. scale_factor and
## life (in frames) are those of the client.
func _init(ui: UiLibrary, at: Vector2, values: Array, scale_factor := 1.0, life := LIFE) -> void:
	position = at
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
		if _is_zero(pair[1]):
			continue
		var kind: Array = KINDS.get(pair[0], [Color.BLACK, NO_ICON, ""])
		var label := score if line == 0 else score.duplicate() as Label
		if line > 0:
			clip.add_child(label)
		label.text = kind[2] + _text(pair[1])
		label.add_theme_font_size_override("font_size", roundi(LINE_SIZE * size_factor))
		label.add_theme_color_override("font_color", kind[0])
		label.add_theme_constant_override("outline_size", roundi(outline * size_factor))
		# The field grows to the left with its text (TextFieldAutoSize.RIGHT).
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.position = (origin + Vector2(0, line * line_height)) * size_factor
		label.size = field * size_factor
		if kind[1] != NO_ICON:
			var icon := ui.make("IconResourcesMC")
			icon.show_frame(kind[1])
			icon.scale = Vector2.ONE * ICON_SCALE * size_factor
			icon.position = Vector2(ICON_X, ICON_Y + line * ICON_STEP) * size_factor
			clip.add_child(icon)
		line += 1
	score.visible = line > 0


## One frame of the client: up, a little faster each frame, and fading in the
## second half of the life.
func step() -> void:
	modulate.a = minf(1.0, _life * 2.0 / _max_life)
	position.y += _speed
	_speed += GRAVITY
	_life -= 1
	dead = _life <= 0


## A value as ActionScript writes it: a whole number without a decimal
## point. A text loses its line break at the end.
static func _text(value: Variant) -> String:
	if value is float and value == floorf(value) and absf(value) < 1e15:
		return str(int(value))
	return str(value).strip_edges(false, true)


## The client compares each value with 0 with the loose equality of
## ActionScript, so a text that reads as 0 also has no line.
static func _is_zero(value: Variant) -> bool:
	if value is int or value is float:
		return value == 0
	var text := str(value).strip_edges()
	return text.is_empty() or (text.is_valid_float() and text.to_float() == 0.0)
