class_name TownWindow
extends Control
## The town window of the client (PopupRaceSelector), which the town selector
## of the HUD opens. Before the player has the second town, it sells the troll
## town for gold or cash; after, it has a Travel button under the picture of
## each town, and the button of the town that the player is in does nothing.

signal buy_requested(with_cash: bool)
signal travel_requested(map_index: int)

const PICTURES := ["townHuman.png", "townTroll.png"]
## PopupRaceSelector shows a travel button that does nothing at half alpha.
const OFF_ALPHA := 0.5

var _window: UiClip


func _init(ui: UiLibrary, village: Village, config: GameConfig) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupRaceSelectorMC")
	add_child(_window)
	_window.button("closeButt").pressed.connect(queue_free)
	if village.has_second_town():
		_window.set_text("titol", config.text("POPUP_RAZA_TITULO_CIUDAD"))
		for part in ["subtitol", "levelRequired", "txGold", "gold", "txCash", "cash", "btGold", "btCash"]:
			_window.set_part_visible(part, false)
		_add_picture(ui, "image_0", PICTURES[0])
		_add_picture(ui, "image_1", PICTURES[1])
		for index: int in [0, Village.SECOND_TOWN]:
			var button := _window.button("btTravel_%d" % mini(index, 1))
			var here := index == 0 if village.is_first_map() else index == Village.SECOND_TOWN
			button.modulate.a = OFF_ALPHA if here else 1.0
			if not here:
				button.pressed.connect(func() -> void: travel_requested.emit(index))
	else:
		_window.set_part_visible("subtitol2", false)
		_window.set_part_visible("btTravel_0", false)
		_window.set_part_visible("btTravel_1", false)
		_window.set_text("txGold", str(Village.TOWN_PRICE_GOLD))
		_window.set_text("txCash", str(Village.TOWN_PRICE_CASH))
		# The art of the client says level 30; the town opens at level 20.
		_window.set_text("levelRequired", "(Level %d required)" % Village.SECOND_TOWN_LEVEL)
		_window.set_part_visible("levelRequired", village.get_level() < Village.SECOND_TOWN_LEVEL)
		_add_picture(ui, "image_0", PICTURES[1])
		_window.button("btGold").pressed.connect(func() -> void: buy_requested.emit(false))
		_window.button("btCash").pressed.connect(func() -> void: buy_requested.emit(true))


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


## The client centres the pictures of its windows on their container.
func _add_picture(ui: UiLibrary, part: String, name: String) -> void:
	var texture := ui.image(name)
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.position = -texture.get_size() / 2
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.clip(part).add_child(picture)
