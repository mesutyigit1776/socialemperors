class_name TutorialBox
extends CanvasLayer
## The box of the tutorial (TutorialPopup of the client): the title, the
## lesson, the page and, at the steps that have one, the Next button. For the
## steps without a box, it shows the port's short text in the same bubble. It
## stays over the village and the fights.

signal button_pressed

const LAYER := 8
## The client puts the box at a place of each step; the port puts it at the
## top, right of the middle, where it covers the least of the village.
const PLACE := Vector2(-130, 270)

var _box: UiClip


func _init(ui: UiLibrary) -> void:
	layer = LAYER
	_box = ui.make("TutorialPopupMC")
	_box.set_part_visible("yesBtn", false)
	var next := _box.clip("noBtn")
	next.make_button()
	next.pressed.connect(func() -> void: button_pressed.emit())
	add_child(_box)


func _ready() -> void:
	_box.position = Vector2(get_viewport().get_visible_rect().size.x / 2, 0) + PLACE


## box: Tutorial.box(), or [] to show only text; an empty text and box hide it.
func show_step(box: Array, text: String) -> void:
	_box.visible = not box.is_empty() or not text.is_empty()
	var has_box := not box.is_empty()
	_box.set_text("title", box[0] if has_box else "")
	_box.set_text("confirmText", box[1] if has_box else text)
	_box.set_text("step", box[2] if has_box else "")
	_box.set_part_visible("noBtn", has_box and box[3])
