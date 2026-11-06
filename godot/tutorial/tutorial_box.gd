class_name TutorialBox
extends CanvasLayer
## The box of the tutorial (TutorialPopup of the client): the title, the
## lesson, the page and, at the steps that have one, a button. For the steps
## without a box, it shows the port's short text. It stays over the village
## and the fights.

signal button_pressed

const LAYER := 8
const WIDTH := 420

var _panel := PanelContainer.new()
var _title := Label.new()
var _lesson := Label.new()
var _page := Label.new()
var _button := Button.new()


func _init() -> void:
	layer = LAYER
	var column := VBoxContainer.new()
	_title.add_theme_font_size_override("font_size", 20)
	for label: Label in [_title, _lesson, _page]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = WIDTH
		column.add_child(label)
	_button.text = "OK"
	_button.pressed.connect(func() -> void: button_pressed.emit())
	column.add_child(_button)
	_panel.add_child(column)
	add_child(_panel)


func _ready() -> void:
	# Under the goal box and left of the panel of the HUD, like the box of the client in the middle at the top.
	_panel.position = Vector2((get_viewport().get_visible_rect().size.x - WIDTH) / 2 - 100, 10)


## box: Tutorial.box(), or [] to show only text; an empty text and box hide it.
func show_step(box: Array, text: String) -> void:
	_panel.visible = not box.is_empty() or not text.is_empty()
	_panel.reset_size.call_deferred()
	if box.is_empty():
		_title.text = ""
		_lesson.text = text
		_page.text = ""
		_button.visible = false
		_title.visible = false
		_page.visible = false
		return
	_title.visible = true
	_page.visible = true
	_title.text = box[0]
	_lesson.text = box[1]
	_page.text = box[2]
	_button.visible = box[3]
