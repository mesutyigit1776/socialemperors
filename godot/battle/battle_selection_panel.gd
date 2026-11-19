class_name BattleSelectionPanel
extends Control
## The panel of the selected items in a battle (RecuadroInfoNew of the
## client, with refreshRecuadroPVP). It goes into the recuadroInfo part of
## the bottom bar and slides up over the neighbour bar while something is
## selected, as in the village (GuiManager.showRecuadro).
##
## - One item: its extended portrait with the name, the picture, the life and
##   the values (EP_EnemyUnit, EP_EnemyBuilding, EP_SelfUnit). A special unit of
##   the player gets EP_SpecialUnitMc with its attack buttons (EP_SelfSpecialUnit).
## - Two or more units: a portrait for each (SelectionPortraits). A click on
##   a portrait selects only its unit. The mouse over a portrait lights its
##   unit on the map (BattleScreen.hover_unit()).
## - Each special unit of the player that was selected in the battle keeps a
##   portrait above the panel while the panel shows and the unit lives
##   (addSpecialUnitSelectorPortrait). A click on it selects only that unit.

var _ui: UiLibrary
var _screen: BattleScreen
var _recuadro: UiClip
var _unit_clip: UiClip  # EP_UnitMC
var _special_clip: UiClip  # EP_SpecialUnitMc
var _shown_clip: UiClip
var _portraits: SelectionPortraits
var _special_portraits: SpecialPortraits
var _specials: Array[BattleFighter] = []
var _selected: Array[BattleFighter] = []
var _tween: Tween


## recuadro: the recuadroInfo part of the bottom bar. buttons: the attack
## buttons of the special units, which go into EP_SpecialUnitMc.
func _init(ui: UiLibrary, screen: BattleScreen, recuadro: UiClip, buttons: UnitButtonPanel) -> void:
	_ui = ui
	_screen = screen
	_recuadro = recuadro
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	recuadro.position.y = VillageHud.PANEL_HIDDEN_Y
	recuadro.take_mouse()
	recuadro.add_child(self)
	var ri := recuadro.clip("ri")
	_unit_clip = _extended_portrait("EP_UnitMC")
	_special_clip = _extended_portrait("EP_SpecialUnitMc")
	buttons.put_buttons_in(_special_clip.clip("attacksMc"))
	_special_clip.set_text("timeRemaining", "")
	_portraits = SelectionPortraits.new(ui)
	_portraits.portrait_pressed.connect(func(index: int) -> void: _screen.select_units([_selected[index]]))
	_portraits.portrait_hovered.connect(func(index: int, entered: bool) -> void: _screen.hover_unit(_selected[index] if entered else null))
	ri.add_child(_portraits)
	_special_portraits = SpecialPortraits.new(ui)
	_special_portraits.portrait_pressed.connect(func(index: int) -> void: _screen.select_units([_specials[index]]))
	_special_portraits.portrait_hovered.connect(func(index: int, entered: bool) -> void: _screen.hover_unit(_specials[index] if entered else null))
	recuadro.part("specialUnitsAnchor").add_child(_special_portraits)
	screen.selection_changed.connect(_show_selection)
	screen.stepped.connect(_refresh)


func _extended_portrait(symbol: String) -> UiClip:
	var clip := _ui.make(symbol)
	clip.visible = false
	var picture := TextureRect.new()
	picture.name = "picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip("mcImageSelected").add_child(picture)
	_recuadro.clip("ri").add_child(clip)
	return clip


func _show_selection(selected: Array[BattleFighter]) -> void:
	_selected = selected.duplicate()
	for fighter in _selected:
		if _has_buttons(fighter) and fighter not in _specials:
			_specials.append(fighter)
	var single: BattleFighter = _selected[0] if _selected.size() == 1 else null
	var clip: UiClip = null
	if single != null:
		clip = _special_clip if _has_buttons(single) else _unit_clip
	if clip != _shown_clip:
		if _shown_clip != null:
			_shown_clip.visible = false
		_shown_clip = clip
	if single != null:
		_fill_extended(clip, single)
	_tween = VillageHud.slide_panel(_recuadro, not _selected.is_empty(), _tween)
	_refresh()


## The attack buttons show for a unit of the player with buttons, see UnitButtonPanel.
func _has_buttons(fighter: BattleFighter) -> bool:
	return fighter.team == BattleFighter.Team.PLAYER and fighter.ability != null and not fighter.ability.buttons.is_empty()


## AbstractEpFightingElement.updateStats: a value of 0 hides its part.
func _fill_extended(clip: UiClip, fighter: BattleFighter) -> void:
	clip.visible = true
	clip.set_text("txNombre", fighter.def.name)
	var picture: TextureRect = clip.clip("mcImageSelected").get_node("picture")
	picture.texture = _ui.thumb(fighter.def.img_name)
	for row: Array in [["mcAttack", "txAttack", fighter.def.attack], ["mcDefense", "txDefense", fighter.def.attack_interval],
			["mcRange", "txRange", fighter.def.attack_range], ["mcSpeed", "txSpeed", fighter.def.velocity]]:
		clip.set_part_visible(row[0], row[2] != 0)
		clip.set_text("%s/%s" % [row[0], row[1]], str(row[2]))


## The life in the panel and the portraits follow the battle.
func _refresh() -> void:
	if _shown_clip != null and _selected.size() == 1:
		var fighter := _selected[0]
		SelectionPanel.show_life(_shown_clip, maxi(fighter.health, 0), fighter.max_life())
	_portraits.show_units(_selected.map(func(fighter: BattleFighter) -> Array: return [fighter.def.img_name, 0.0 if fighter.dead else _share(fighter)]))
	_refresh_specials()


func _share(fighter: BattleFighter) -> float:
	return float(fighter.health) / maxi(fighter.max_life(), 1)


func _refresh_specials() -> void:
	_specials = _specials.filter(func(fighter: BattleFighter) -> bool: return not fighter.dead and fighter in _screen.sim.fighters)
	var shown := [] if _selected.is_empty() else _specials.map(func(fighter: BattleFighter) -> Array: return [fighter.def.img_name, _share(fighter)])
	_special_portraits.show_units(shown)
