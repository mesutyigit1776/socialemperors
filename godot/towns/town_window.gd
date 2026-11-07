class_name TownWindow
extends PanelContainer
## The town window of the client (PopupRaceSelector), which the World button
## opens. Before the player has the second town, it sells the troll town for
## gold or cash; after, it has a button for each town, and the button of the
## town that the player is in does nothing.

signal buy_requested(with_cash: bool)
signal travel_requested(map_index: int)

const WIDTH := 420

var _content := VBoxContainer.new()


func _init(village: Village, config: GameConfig) -> void:
	custom_minimum_size.x = WIDTH
	add_child(_content)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	_content.add_child(title)
	var buttons := HBoxContainer.new()
	if village.has_second_town():
		title.text = config.text("POPUP_RAZA_TITULO_CIUDAD").strip_edges()
		for index: int in [0, Village.SECOND_TOWN]:
			var button := Button.new()
			button.text = "Human town" if index == 0 else "Troll town"
			button.disabled = index == 0 if village.is_first_map() else index == Village.SECOND_TOWN
			button.pressed.connect(func() -> void: travel_requested.emit(index))
			buttons.add_child(button)
	else:
		title.text = "Troll town"
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = WIDTH  # Without a width, the wrapped text is as high as a column of single words.
		text.text = "A second town, in which you play the troll race. It has its own level, resources, land and army."
		if village.get_level() < Village.SECOND_TOWN_LEVEL:
			text.text += config.text("POPUP_RAZA_NIVEL_TROLL").replace("#0#", str(Village.SECOND_TOWN_LEVEL))
		_content.add_child(text)
		for with_cash: bool in [false, true]:
			var button := Button.new()
			button.text = "%d cash" % Village.TOWN_PRICE_CASH if with_cash else "%d gold" % Village.TOWN_PRICE_GOLD
			button.pressed.connect(func() -> void: buy_requested.emit(with_cash))
			buttons.add_child(button)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	buttons.add_child(close)
	_content.add_child(buttons)


func _ready() -> void:
	position = (get_viewport_rect().size - Vector2(WIDTH, 0)) / 2 - Vector2(0, 150)
