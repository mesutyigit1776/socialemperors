class_name SpeechBubble
extends Node2D
## The speech bubble of a unit (BS_MC of IsoUnit.say), for example a line of
## a captain. The bubble grows with its text; it shows for SHOWN_SECONDS and
## then fades out in FADE_SECONDS. BattleView places it over the unit.

const SHOWN_SECONDS := 3.0  ## Config.TIMER_SPEECH_ACTIVE.
const FADE_SECONDS := 1.0
## The client makes the contour 20 pixels wider than the text field.
const CONTOUR_MARGIN := 20.0

var _seconds_left := SHOWN_SECONDS + FADE_SECONDS


func _init(ui: UiLibrary, text: String) -> void:
	var clip := ui.make("BS_MC")
	add_child(clip)
	var label := clip.part("sentence/text") as Label
	# The client sets autoSize LEFT before the text: the field grows to the
	# right with the text, and the text keeps the size of the art.
	var layout: FlashTextLayout = label.get_meta("text_layout")
	var field_width := layout.width(text, label.get_meta("art_font_size")) + 2 * UiClip.TEXT_GUTTER
	label.text = UiClip.drawable(label, text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size.x = field_width
	var contour := clip.clip("contour")
	contour.scale.x = (field_width + CONTOUR_MARGIN) / contour.bounds().size.x


## Fades the bubble; false when it is gone.
func step(delta: float) -> bool:
	_seconds_left -= delta
	modulate.a = clampf(_seconds_left / FADE_SECONDS, 0.0, 1.0)
	return _seconds_left > 0.0
