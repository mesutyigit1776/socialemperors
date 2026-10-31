class_name CastBanner
extends Control
## The banner of the client that crosses the bottom of the screen with the name
## of a spell that the player casts (MagicCastMarquee). Its band has the colour
## of the spell. It plays once and leaves.

const FRAME_SECONDS := 1.0 / 30.0
## The client places it at x 0 and at y 611 of its stage of 760 x 600 pixels;
## the banner draws above that point.
const STAGE_SIZE := Vector2(760, 600)
const PLACE := Vector2(0, 611)
## The frame of the band for each spell; the client has no colour for the
## other spells and shows the first frame.
const COLOR_FRAMES := {2: 1, 3: 3, 4: 4, 5: 2, 6: 6, 7: 3, 8: 7, 9: 0, 10: 6, 11: 5}

var _banner: UiClip
var _time := 0.0


func _init(ui: UiLibrary, spell: GameConfig.SpellDef) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = ui.make("magic_cast")
	add_child(_banner)
	_banner.set_text("texte/texte", spell.name)
	_banner.clip("cast").show_frame(COLOR_FRAMES.get(spell.id, 0))


func _ready() -> void:
	var screen := get_viewport_rect().size
	_banner.position = Vector2((screen.x - STAGE_SIZE.x) / 2, screen.y - STAGE_SIZE.y) + PLACE


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		if _banner.frame + 1 >= _banner.frame_count():
			queue_free()
			return
		_banner.show_frame(_banner.frame + 1)
