class_name UnitListWindow
extends Control
## The unit list of the Gift menu (PopupAllUnits of the client): the unit
## collections of GameConfig.unit_collections, ROWS on a page, each with its
## name, the pictures of its units and the number that the player has. The
## pictures of the units that the player does not have are grey. A complete
## collection shows the button of its reward until the player takes it, then
## "COMPLETED!". The mouse over a unit shows its card (UnitCard).
##
## The configuration has a cash price for each unit, and the client has the
## code that sells a unit, but the client of 1.4.07 does not call it: a click
## on a unit does nothing (seen in Ruffle).

signal reward_requested(collection: Dictionary)
signal packs_requested
signal closed

const COLUMNS := 5
const ROWS := 4
const COLUMN_WIDTH := 104.0
## The client puts the picture of a unit 6 pixels to the right in its place.
const PICTURE_X := 6.0
## The card is 10 pixels to the right of its holder. In the first row the
## card is below the unit, with the background frame that points up.
const CARD_X := 10.0
const CARD_Y_FIRST_ROW := -10.0
const FIRST_ROW_LIMIT := 50.0
## An arrow that leads nowhere shows at half alpha.
const ARROW_DISABLED_ALPHA := 0.5
## The client makes the pictures grey with weights for red, green and blue
## (ColorMatrixFilter of setSaturation).
const GREY_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float light = dot(colour.rgb, vec3(0.114, 0.299, 0.587));
	COLOR = vec4(vec3(light), colour.a);
}
"""

var _ui: UiLibrary
var _config: GameConfig
var _sprites: SpriteLibrary
var _collections: UnitCollections
var _window: UiClip
var _places: Array[Array] = []  # [row][column] -> UiClip (UnitListMC)
var _first := 0  # The index in GameConfig.unit_collections of the first row.
var _place_height := 0.0  # The height of a place as Flash measures it.
var _grey := ShaderMaterial.new()
var _card: UiClip


func _init(ui: UiLibrary, config: GameConfig, sprites: SpriteLibrary, collections: UnitCollections) -> void:
	_ui = ui
	_config = config
	_sprites = sprites
	_collections = collections
	_grey.shader = Shader.new()
	_grey.shader.code = GREY_SHADER
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupAllUnitsMC")
	add_child(_window)
	_window.set_text("txTitle", config.text("POPUP_ALL_UNITS_TITLE"))
	_window.set_text("lblObtained", config.text("POPUP_ALL_UNITS_OBTAINED"))
	_window.set_text("progressBar/percentText", "%d / %d" % [collections.owned_count(), collections.total()])
	_window.clip("progressBar/percentMask").scale.x = float(collections.owned_count()) / maxi(collections.total(), 1)
	var ok := _window.clip("btnOk")
	ok.set_text("lbl", config.text("AUX_OK"))
	ok.make_button(true)
	ok.pressed.connect(_close)
	var packs := _window.clip("btnOpenUnitPacks")
	packs.fit_text("lbl", config.text("UNITS_PACKS_OPEN_UNITS_PACKS"))
	packs.make_button(true)
	packs.pressed.connect(func() -> void:
		_close()
		packs_requested.emit())
	_window.button("closeButt").pressed.connect(_close)
	_window.button("left").pressed.connect(_turn_page.bind(-1))
	_window.button("right").pressed.connect(_turn_page.bind(1))
	_make_places()
	_show_page()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _make_places() -> void:
	var content := _window.clip("content")
	for row in ROWS:
		var places: Array[UiClip] = []
		for column in COLUMNS:
			var place := _ui.make("UnitListMC")
			# Only the first place of a row has the name, the reward button and "COMPLETED!".
			if column > 0:
				for part_name in ["lblCategory", "butGetReward", "lblCompleted"]:
					place.set_part_visible(part_name, false)
			var picture := TextureRect.new()
			picture.name = "picture"
			picture.position.x = PICTURE_X
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			place.add_child(picture)
			place.move_child(picture, 0)
			var frame := place.clip("frame")
			var area := Control.new()
			area.name = "area"
			area.position = frame.position + frame.bounds().position
			area.size = frame.bounds().size
			area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			area.mouse_entered.connect(_show_card.bind(row, column))
			area.mouse_exited.connect(_remove_card)
			place.add_child(area)
			# The client places the rows by the height of a place: from the top
			# of its frame to the bottom of the field of the name.
			if _place_height == 0.0:
				_place_height = place.field_rect("lblName").end.y - area.position.y
			place.position = Vector2(column * COLUMN_WIDTH, row * _place_height)
			content.add_child(place)
			places.append(place)
		_places.append(places)
		var reward := places[0].clip("butGetReward")
		reward.set_text("lbl", _config.text("POPUP_RECLUTAMIENTO_RECOMPENSA"))
		reward.make_button(true)
		reward.pressed.connect(func() -> void:
			var collection := _collection(row)
			if not collection.is_empty():
				reward_requested.emit(collection))


func _collection(row: int) -> Dictionary:
	var index := _first + row
	return _config.unit_collections[index] if index < _config.unit_collections.size() else {}


func _turn_page(direction: int) -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	_first = clampi(_first + direction * ROWS, 0, maxi(_config.unit_collections.size() - 1, 0))
	_show_page()


func _show_page() -> void:
	_remove_card()
	for row in ROWS:
		var collection := _collection(row)
		var units: Array = collection.get("units", [])
		for column in COLUMNS:
			var place: UiClip = _places[row][column]
			place.visible = column < units.size()
			if not place.visible:
				continue
			var item := _config.get_item(units[column])
			var picture: TextureRect = place.get_node("picture")
			picture.texture = _ui.thumb(item.img_name) if item != null else null
			picture.material = null if _collections.is_owned(units[column]) else _grey
			place.fit_text("lblName", item.name if item != null else "")
			place.set_part_visible("lblCounter", column == units.size() - 1)
			place.set_text("lblCounter", "%d/%d" % [_collections.owned_in(collection), units.size()])
		if collection.is_empty():
			continue
		var first: UiClip = _places[row][0]
		first.set_text("lblCategory", collection["name"])
		var claimed := _collections.is_claimed(collection)
		first.set_part_visible("butGetReward", _collections.is_complete(collection) and not claimed)
		first.set_part_visible("lblCompleted", claimed)
		first.set_text("lblCompleted", _config.text("AUX_COMPLETADO"))
	_set_arrow("left", _first > 0)
	_set_arrow("right", _first + ROWS < _config.unit_collections.size())


func _set_arrow(name: String, enabled: bool) -> void:
	var arrow := _window.button(name)
	arrow.enabled = enabled
	if not enabled:
		arrow.modulate.a = ARROW_DISABLED_ALPHA


func _show_card(row: int, column: int) -> void:
	_remove_card()
	var unit_id: int = _collection(row)["units"][column]
	var item := _config.get_item(unit_id)
	if item == null:
		return
	var place: UiClip = _places[row][column]
	# The place comes above the other places, so that its card covers them.
	place.get_parent().move_child(place, -1)
	_card = _ui.make("InfoButtonUnitCollectionMC" if _collections.is_owned(unit_id) else "InfoButtonUnitCollectionBuyMC")
	_card.set_text("txNombre", item.name)
	if place.position.y < FIRST_ROW_LIMIT:
		_card.position.y = _place_height + CARD_Y_FIRST_ROW + _card.bounds().size.y / 2
		_card.clip("background").show_frame(1)
	_card.position.x += CARD_X
	place.clip("bufHolder").add_child(_card)
	UnitCard.fill(_card, item, _sprites, true)


func _remove_card() -> void:
	if _card != null:
		_card.queue_free()
	_card = null


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
