class_name TownQuestWindow
extends PanelContainer
## The window of a quest in the town (PopupQuestInfo2 of the client): the
## chapter, the title and the text of the quest at its start, or of its end.

const WIDTH := 420


func _init(title: String, text: String) -> void:
	custom_minimum_size.x = WIDTH
	var content := VBoxContainer.new()
	add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 20)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x = WIDTH  # Without a width, wrapped text is as high as a column of single words.
	content.add_child(heading)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = WIDTH
	content.add_child(body)
	var close := Button.new()
	close.text = "OK"
	close.pressed.connect(queue_free)
	content.add_child(close)


func _ready() -> void:
	position = (get_viewport_rect().size - Vector2(WIDTH, 0)) / 2 - Vector2(0, 150)
