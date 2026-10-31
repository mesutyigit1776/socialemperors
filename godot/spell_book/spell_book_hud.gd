class_name SpellBookHud
extends Control
## The spell book of the client (PopupMagic) at the bottom left of the screen:
## the book, the mana of the player, and the button of the spell window.
##
## A click on the closed book opens it and shows up to three of the spells
## that the player has, with arrows to the others. A click on a spell chooses
## it; the book then offers to cancel the cast. A click on the open book closes
## it and cancels the cast. A click on the mana buys mana.
##
## Spells that the port does not have show grey, with the sign "Not in the
## port yet" under the mouse, and the player cannot choose them.

signal spell_chosen(spell: GameConfig.SpellDef)
signal cancel_requested
signal shop_requested
signal mana_requested

## The client places the book 80 pixels above the bottom left corner of the screen.
const PLACE_FROM_BOTTOM := 80.0
## Places of the three spells on the open book.
const SPELL_PLACES: Array[Vector2] = [Vector2(51.5, -112), Vector2(126.65, -97), Vector2(154.5, -29)]
const SPELLS_SHOWN := 3
const SPELL_PICTURE_SCALE := 0.55
const SPELL_OPEN_SECONDS := 0.5
const HOVER_SCALE := 1.1
const BOOK_HOVER_SCALE := 1.07
const SHOP_BUTTON_SCALE := 0.65
const SHOP_BUTTON_HOVER_SCALE := 0.72
## The client breaks a name of more than this many letters at its first space.
const TOOLTIP_LINE := 10
const NOT_IN_PORT_GREY := Color(0.55, 0.55, 0.55)
const NOT_IN_PORT := "Not in the port yet"

var _ui: UiLibrary
var _config: GameConfig
var _village: Village
var _book: UiClip
var _open := false
var _first_spell := 0
var _buttons: Array[UiClip] = []


func _init(ui: UiLibrary, config: GameConfig, village: Village) -> void:
	_ui = ui
	_config = config
	_village = village
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book = ui.make("PopupMagicMC")
	add_child(_book)
	_book.set_part_visible("manaPointsTooltip", false)
	_book.set_part_visible("book/bookTexts", false)
	_book.clip("book/spellBook").show_label("closed")
	var book := _book.clip("book")
	book.make_button()
	_hover_scale(book, BOOK_HOVER_SCALE)
	book.pressed.connect(_on_book_pressed)
	var mana := _book.clip("manaCounter")
	mana.make_button()
	_hover_scale(mana, BOOK_HOVER_SCALE)
	mana.mouse_entered.connect(func() -> void: _book.set_part_visible("manaPointsTooltip", true))
	mana.mouse_exited.connect(func() -> void: _book.set_part_visible("manaPointsTooltip", false))
	mana.pressed.connect(func() -> void: mana_requested.emit())
	var shop := _book.clip("btnOpenSpellbook")
	shop.make_button()
	shop.mouse_entered.connect(func() -> void: shop.scale = Vector2.ONE * SHOP_BUTTON_HOVER_SCALE)
	shop.mouse_exited.connect(func() -> void: shop.scale = Vector2.ONE * SHOP_BUTTON_SCALE)
	shop.pressed.connect(func() -> void: shop_requested.emit())
	for arrow in ["butPrev", "butNext"]:
		_book.button(arrow).visible = false
	_book.button("butPrev").pressed.connect(_turn.bind(-1))
	_book.button("butNext").pressed.connect(_turn.bind(1))
	refresh()


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_place()


## Shows the mana and the spells of the player again, for example after a purchase.
func refresh() -> void:
	_book.set_text("manaCounter/manaLeft", str(_village.get_resource("m")))
	if _open:
		_show_spells()


## The book offers to cancel the cast while the player aims a spell.
func show_casting(casting: bool) -> void:
	if casting:
		_book.set_part_visible("book/bookTexts", true)
		_book.clip("book/bookTexts").show_label("cancel")
		_book.set_text("book/bookTexts/btnText", _config.text("SPELL_BOOK_CANCEL_CASTING"))
	else:
		_close()


func _place() -> void:
	_book.position = Vector2(0, get_viewport_rect().size.y - PLACE_FROM_BOTTOM)


func _on_book_pressed() -> void:
	if _open:
		_close()
		cancel_requested.emit()
		return
	_open = true
	_book.clip("book/spellBook").show_label("open")
	_book.set_part_visible("book/bookTexts", true)
	_book.clip("book/bookTexts").show_label("choose")
	_book.set_text("book/bookTexts/btnText", _config.text("SPELL_BOOK_SELECT_SPELL"))
	_show_spells()


func _close() -> void:
	_open = false
	_book.clip("book/spellBook").show_label("closed")
	_book.set_part_visible("book/bookTexts", false)
	for arrow in ["butPrev", "butNext"]:
		_book.button(arrow).visible = false
	for button in _buttons:
		button.queue_free()
	_buttons.clear()


## The spells of the player, by id, as the client lists the keys of its save.
func _spells() -> Array[GameConfig.SpellDef]:
	var ids := _village.spell_uses().keys()
	ids.sort()
	var spells: Array[GameConfig.SpellDef] = []
	for id: int in ids:
		if _config.get_spell(id) != null:
			spells.append(_config.get_spell(id))
	return spells


func _show_spells() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	var spells := _spells()
	_first_spell = clampi(_first_spell, 0, maxi(spells.size() - SPELLS_SHOWN, 0))
	for i in mini(SPELLS_SHOWN, spells.size() - _first_spell):
		var button := _spell_button(spells[_first_spell + i])
		_book.add_child(button)
		_buttons.append(button)
		button.scale = Vector2.ZERO
		var tween := create_tween().set_parallel()
		tween.tween_property(button, "position", SPELL_PLACES[i], SPELL_OPEN_SECONDS)
		tween.tween_property(button, "scale", Vector2.ONE, SPELL_OPEN_SECONDS)
	var previous := _book.button("butPrev")
	var next := _book.button("butNext")
	previous.visible = true
	next.visible = true
	previous.enabled = _first_spell > 0
	next.enabled = spells.size() > SPELLS_SHOWN and _first_spell + SPELLS_SHOWN < spells.size()


func _spell_button(spell: GameConfig.SpellDef) -> UiClip:
	var button := _ui.make("SpellButtonMC")
	button.set_part_visible("marco", false)
	button.set_text("manaCost", str(spell.mana))
	var picture := TextureRect.new()
	picture.texture = _ui.image("%s.jpg" % spell.img_name)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.texture != null:
		# The client centres the pictures of its windows on their container.
		picture.scale = Vector2.ONE * SPELL_PICTURE_SCALE
		picture.position = -picture.texture.get_size() * SPELL_PICTURE_SCALE / 2
	button.clip("image").add_child(picture)
	button.make_button()
	var in_port := BattleSpell.is_in_port(spell.id)
	if not in_port:
		button.modulate = NOT_IN_PORT_GREY
	var tooltip := [null]
	button.mouse_entered.connect(func() -> void:
		button.scale = Vector2.ONE * HOVER_SCALE
		tooltip[0] = _ui.make("InfoPopupManaMc")
		tooltip[0].set_text("popupText", _tooltip_text(spell.name) + ("" if in_port else "\n" + NOT_IN_PORT))
		button.add_child(tooltip[0]))
	button.mouse_exited.connect(func() -> void:
		button.scale = Vector2.ONE
		if tooltip[0] != null:
			tooltip[0].queue_free()
			tooltip[0] = null)
	if in_port:
		button.pressed.connect(func() -> void: spell_chosen.emit(spell))
	return button


func _turn(step: int) -> void:
	_first_spell += step
	_show_spells()


static func _tooltip_text(name: String) -> String:
	if name.length() <= TOOLTIP_LINE:
		return name
	var space := name.left(TOOLTIP_LINE).find(" ")
	return name if space <= 0 else name.left(space) + "\n" + name.substr(space + 1)


static func _hover_scale(clip: UiClip, hover: float) -> void:
	clip.mouse_entered.connect(func() -> void: clip.scale = Vector2.ONE * hover)
	clip.mouse_exited.connect(func() -> void: clip.scale = Vector2.ONE)
