class_name SpellShopWindow
extends Control
## The spell window of the client (PopupWizardry): six spells on each page,
## sorted by the level that they need, and the chosen spell on the right page
## of the book with its picture, its texts for the three spell levels, and its
## prices, or its stars and the casts to the next level when the player has it.
##
## Spells that the port does not have show the lock and "Not in the port yet",
## and the player cannot buy them.

signal closed
signal buy_requested(spell: GameConfig.SpellDef, with_cash: bool)
signal mana_requested
signal help_requested

const SPELLS_PER_PAGE := 6
const ENTRY_SCALE := 0.7
const ENTRY_HOVER_SCALE := 0.71
const ENTRY_GAP := Vector2(25, 15)
const AVAILABLE_COLOR := Color8(0xFF, 0xCC, 0x00)
const LOCKED_COLOR := Color8(0xCC, 0x33, 0x00)
const STAR_ON := 1

var _ui: UiLibrary
var _config: GameConfig
var _village: Village
var _window: UiClip
var _spells: Array[GameConfig.SpellDef] = []
var _page := 0
var _chosen: GameConfig.SpellDef


func _init(ui: UiLibrary, config: GameConfig, village: Village) -> void:
	_ui = ui
	_config = config
	_village = village
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupWizardryMC")
	add_child(_window)
	_add_picture(_window.clip("llibre"), "llibre.png", 1.0)
	_spells.assign(config.spells)
	# The client sorts by level; Array.sort_custom() keeps no order among equal levels, so the id decides.
	_spells.sort_custom(func(a: GameConfig.SpellDef, b: GameConfig.SpellDef) -> bool: return a.level < b.level or (a.level == b.level and a.id < b.id))
	_chosen = _spells[0]
	_window.button("btClose").pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	_window.button("butHelp").pressed.connect(func() -> void: help_requested.emit())
	_window.button("prevPage").pressed.connect(_turn.bind(-1))
	_window.button("nextPage").pressed.connect(_turn.bind(1))
	var mana := _window.clip("btnBuyMana")
	mana.make_button(true)
	mana.pressed.connect(func() -> void: mana_requested.emit())
	refresh()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


## Shows the mana, the page and the chosen spell again, for example after a purchase.
func refresh() -> void:
	_window.set_text("manaCounter/manaLeft", str(_village.get_resource("m")))
	_show_page()
	_show_chosen()


func _pages() -> int:
	return maxi(roundi(float(_spells.size()) / SPELLS_PER_PAGE), 1)


func _turn(step: int) -> void:
	_page = clampi(_page + step, 0, _pages() - 1)
	_show_page()


func _show_page() -> void:
	var holder := _window.clip("magicEntries")
	for child in holder.get_children():
		if child is UiClip and child.has_meta("spell"):
			child.queue_free()
	var shown := _spells.slice(_page * SPELLS_PER_PAGE, (_page + 1) * SPELLS_PER_PAGE)
	for i in shown.size():
		var entry := _entry(shown[i])
		var size := entry.bounds().size * ENTRY_SCALE
		entry.position = Vector2((i % 2) * (size.x + ENTRY_GAP.x), (i / 2) * (size.y + ENTRY_GAP.y))
		holder.add_child(entry)
	_window.button("prevPage").enabled = _page > 0
	_window.button("nextPage").enabled = _page < _pages() - 1
	_window.set_text("pageNum", _config.text("POPUP_GRIMORIO_PAGINA").replace("#0#", str(_page + 1)).replace("#1#", str(_pages())))


func _entry(spell: GameConfig.SpellDef) -> UiClip:
	var entry := _ui.make("MagicentryMC")
	entry.set_meta("spell", spell.id)
	entry.scale = Vector2.ONE * ENTRY_SCALE
	_add_picture(entry.clip("foto"), "%s.jpg" % spell.img_name, 1.0)
	entry.set_text("spellName", spell.name)
	entry.set_part_visible("lock", false)
	var status := entry.part("spellStatus") as Label
	if not BattleSpell.is_in_port(spell.id):
		status.text = SpellBookHud.NOT_IN_PORT
		status.add_theme_color_override("font_color", LOCKED_COLOR)
		entry.set_part_visible("lock", true)
		entry.set_part_visible("lock/level", false)
	elif _village.spell_uses().has(spell.id):
		status.text = _config.text("SPELL_ESTADO_APRENDIDO")
	elif _village.get_level() >= spell.level:
		status.text = _config.text("SPELL_ESTADO_DISPONIBLE")
		status.add_theme_color_override("font_color", AVAILABLE_COLOR)
	else:
		status.text = _config.text("SPELL_ESTADO_BLOQUEADO")
		status.add_theme_color_override("font_color", LOCKED_COLOR)
		entry.set_part_visible("lock", true)
		entry.set_text("lock/level", str(spell.level))
	entry.make_button()
	entry.mouse_entered.connect(func() -> void: entry.scale = Vector2.ONE * ENTRY_HOVER_SCALE)
	entry.mouse_exited.connect(func() -> void: entry.scale = Vector2.ONE * ENTRY_SCALE)
	entry.pressed.connect(func() -> void:
		_chosen = spell
		_show_chosen())
	return entry


func _show_chosen() -> void:
	var holder := _window.clip("selectedMagicCon")
	for child in holder.get_children():
		if child is UiClip:
			child.queue_free()
	var spell := _chosen
	var panel := _ui.make("SelectedMagicMC")
	holder.add_child(panel)
	panel.set_text("spellName", spell.name)
	panel.set_text("spellDesc", spell.description)
	panel.set_text("manaCost", str(spell.mana))
	var texts := BattleSpell.describe(spell, _config)
	for i in texts.size():
		panel.set_text(["rank1Desc", "ran2Desc", "rank3Desc"][i], texts[i])
	_add_picture(panel.clip("previewMagicMc"), "prev_%s.jpg" % spell.img_name, 1.0)
	var uses := _village.spell_uses()
	panel.set_part_visible("knownSpellZone", uses.has(spell.id))
	panel.set_part_visible("buySpellZone", not uses.has(spell.id))
	panel.set_part_visible("knownSpellZone/numTimesTooltip", false)
	if uses.has(spell.id):
		_show_known(panel.clip("knownSpellZone"), uses[spell.id])
		return
	var zone := panel.clip("buySpellZone")
	zone.set_text("priceGold", str(spell.gold))
	zone.set_text("priceCash", str(spell.cash))
	var can_buy := BattleSpell.is_in_port(spell.id) and _village.get_level() >= spell.level
	zone.set_part_visible("lockedSpellZone", not can_buy)
	zone.set_part_visible("btnBuyGold", can_buy)
	zone.set_part_visible("btnBuyCash", can_buy)
	if not BattleSpell.is_in_port(spell.id):
		zone.set_text("lockedSpellZone/level", "")
	else:
		zone.set_text("lockedSpellZone/level", str(spell.level))
	for pair: Array in [["btnBuyGold", false], ["btnBuyCash", true]]:
		var button := zone.clip(pair[0])
		button.make_button(true)
		button.pressed.connect(func() -> void: buy_requested.emit(spell, pair[1]))


## The stars of the spell level and the bar of the casts to the next level.
func _show_known(zone: UiClip, uses: int) -> void:
	var level := _config.spell_level(uses)
	for star in range(1, GameConfig.SPELL_LEVELS + 1):
		zone.clip("star%d" % star).show_frame(STAR_ON if level >= star else 0)
	var share := 0.0
	if uses >= _config.spell_uses_level3:
		share = 1.0
	elif uses >= _config.spell_uses_level2:
		share = float(uses - _config.spell_uses_level2) / (_config.spell_uses_level3 - _config.spell_uses_level2)
	elif uses > 0:
		share = float(uses) / _config.spell_uses_level2
	zone.set_part_visible("nextLevelText", level < GameConfig.SPELL_LEVELS)
	zone.set_part_visible("barraTiempo", level < GameConfig.SPELL_LEVELS)
	var mask := zone.clip("barraTiempo/percentMask")
	if mask != null:
		mask.scale.x = share
	zone.set_text("barraTiempo/percentText", "%d%%" % roundi(share * 100))
	for pair: Array in [[2, _config.spell_uses_level2], [3, _config.spell_uses_level3]]:
		var star := zone.clip("star%d" % pair[0])
		star.make_button()
		star.mouse_entered.connect(func() -> void:
			var tip := zone.clip("numTimesTooltip")
			tip.position = star.position
			tip.visible = true
			zone.set_text("numTimesTooltip/numTimes", str(pair[1])))
		star.mouse_exited.connect(func() -> void: zone.set_part_visible("numTimesTooltip", false))


## The client centres the pictures of its windows on their container.
func _add_picture(container: UiClip, image: String, picture_scale: float) -> void:
	if container == null:
		return
	var picture := TextureRect.new()
	picture.texture = _ui.image(image)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.texture != null:
		picture.scale = Vector2.ONE * picture_scale
		picture.position = -picture.texture.get_size() * picture_scale / 2
	container.add_child(picture)
