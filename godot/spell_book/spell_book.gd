class_name SpellBook
extends Node2D
## The spells of the player on a screen, as MagicManager of the client runs them:
## the book at the bottom left, the spell window, the mana window, aiming and
## casting.
##
## 1. The player chooses a spell in the book. Without its mana, the mana window
##    opens instead.
## 2. While the player aims, the marker of the area (AOEMC) follows the tile
##    under the mouse, and mark shows the items that the spell marks.
## 3. A click casts the spell on the tile: the cast costs the mana and counts
##    (Village.use_spell()), cast_on applies it with the level of the cast,
##    and the banner shows the name of the spell. A right click, the Escape key
##    or a click on the book cancels.
##
## The node goes on the map, after the nodes that take clicks on the map, so
## that it gets the mouse first while the player aims. changed tells the owner
## to save the village.

signal changed  ## The mana, the spells or the casts of the village changed.

## The client puts the centre of the marker half a tile below the tile point,
## and scales it to the area: its frame 5 has the size of 4 tiles.
const MARKER_FRAME := 4
const MARKER_OFFSET := Vector2(0, 27)
const MARKER_AREA := 5.0
## The client shows the book to human players from level 15, and always to trolls.
const MIN_LEVEL := 15
const HUMAN_RACE := "h"

## Called with (spell, tile, level) when the player casts a spell.
var cast_on: Callable
## Called with (tile, area, team or null) while the player aims, and with
## (null, 0, null) when the aim ends. The spell marks the items of team on the
## area tiles from tile to the left and up.
var mark: Callable
## The node of the marker of the area, on the map; the client puts it under
## the items. By default the spell book itself.
var marker_layer: Node2D

var _ui: UiLibrary
var _cast_ui: UiLibrary
var _config: GameConfig
var _village: Village
var _windows: Node
var _hud: SpellBookHud
var _aimed: GameConfig.SpellDef
var _marker: UiClip
var _shop: SpellShopWindow


## cast_ui: the banner of a cast, see UiLibrary.load_from(). windows: the node
## that holds the book and the windows, over the map.
func _init(ui: UiLibrary, cast_ui: UiLibrary, config: GameConfig, village: Village, windows: Node) -> void:
	_ui = ui
	_cast_ui = cast_ui
	_config = config
	_village = village
	_windows = windows
	_hud = SpellBookHud.new(ui, config, village)
	_hud.spell_chosen.connect(_on_spell_chosen)
	_hud.cancel_requested.connect(_stop_aiming)
	_hud.shop_requested.connect(_open_shop)
	_hud.mana_requested.connect(_open_mana_window)
	_hud.visible = is_shown(village)


## The client shows the book from MIN_LEVEL for human players.
static func is_shown(village: Village) -> bool:
	return village.race != HUMAN_RACE or village.get_level() >= MIN_LEVEL


func _enter_tree() -> void:
	if _hud.get_parent() == null:
		_windows.add_child(_hud)


func _exit_tree() -> void:
	_stop_aiming()


## Shows the book again, for example when the level of the village changes.
func refresh() -> void:
	_hud.visible = is_shown(_village)
	_hud.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _aimed == null:
		return
	if event is InputEventMouseMotion:
		_aim_at(_mouse_tile())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if not event.pressed:
			_cast(_mouse_tile())
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_stop_aiming()


func _on_spell_chosen(spell: GameConfig.SpellDef) -> void:
	if _village.get_resource("m") < spell.mana:
		_open_mana_window()
		return
	_stop_aiming()
	_aimed = spell
	_hud.show_casting(true)
	_marker = _ui.make("AOEMC")
	_marker.show_frame(MARKER_FRAME)
	_marker.scale = Vector2.ONE * (spell.areas[0] + 1) / MARKER_AREA
	(marker_layer if marker_layer != null else self).add_child(_marker)
	_aim_at(_mouse_tile())


func _aim_at(tile: Vector2i) -> void:
	var side := _area(_aimed)
	_marker.scale = Vector2.ONE * (side + 1) / MARKER_AREA
	_marker.position = IsoGrid.tile_to_map(tile) + MARKER_OFFSET
	if mark.is_valid():
		mark.call(tile, side, _team(_aimed))


func _cast(tile: Vector2i) -> void:
	var spell := _aimed
	_stop_aiming()
	var level := _village.use_spell(spell)
	if level == 0:
		_open_mana_window()
		return
	if cast_on.is_valid():
		cast_on.call(spell, tile, level)
	_windows.add_child(CastBanner.new(_cast_ui, spell))
	_hud.refresh()
	changed.emit()


func _stop_aiming() -> void:
	if _aimed == null:
		return
	_aimed = null
	if _marker != null:
		_marker.queue_free()
		_marker = null
	if mark.is_valid():
		mark.call(null, 0, null)
	_hud.show_casting(false)


## The area of the spell at the level of its next cast, as the client marks it.
func _area(spell: GameConfig.SpellDef) -> int:
	return spell.areas[_config.spell_level(_village.spell_uses().get(spell.id, 0)) - 1]


## The side that the spell marks: 1 is the player, 2 the enemy, 0 nobody.
static func _team(spell: GameConfig.SpellDef) -> Variant:
	match spell.target:
		1:
			return BattleFighter.Team.PLAYER
		2:
			return BattleFighter.Team.ENEMY
	return null


func _mouse_tile() -> Vector2i:
	return IsoGrid.map_to_tile(get_local_mouse_position())


func _open_shop() -> void:
	_stop_aiming()
	if _shop != null:
		return
	_shop = SpellShopWindow.new(_ui, _config, _village)
	_shop.closed.connect(func() -> void: _shop = null)
	_shop.buy_requested.connect(_buy_spell)
	_shop.mana_requested.connect(_open_mana_window)
	_shop.help_requested.connect(func() -> void:
		_windows.add_child(AlertWindow.new(_ui, _config, "%s\n\n%s" % [_config.text("SPELLBOOK_TITLE"), _config.text("SPELLBOOK_EXPLANATION")])))
	_windows.add_child(_shop)


func _open_mana_window() -> void:
	var window := BuyManaWindow.new(_ui, _config)
	window.buy_requested.connect(func(with_cash: bool) -> void:
		if _village.buy_mana(with_cash) != Village.Placement.OK:
			_not_enough(with_cash)
			return
		_updated())
	_windows.add_child(window)


func _buy_spell(spell: GameConfig.SpellDef, with_cash: bool) -> void:
	if _village.buy_spell(spell, with_cash) != Village.Placement.OK:
		_not_enough(with_cash)
		return
	_updated()


func _updated() -> void:
	_hud.refresh()
	if _shop != null:
		_shop.refresh()
	changed.emit()


## The client asks the player to get more gold or cash; the port has no shop for them.
func _not_enough(with_cash: bool) -> void:
	_windows.add_child(AlertWindow.new(_ui, _config, _config.text("AVISO_SUFICIENTE_CASH" if with_cash else "AVISO_SUFICIENTE_ORO")))
