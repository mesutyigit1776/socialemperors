class_name UnitButtonPanel
extends Control
## The portrait buttons of a special unit (PortraitSpecialAttack of the
## client): when the player selects one unit of their own with buttons, its
## buttons show at the bottom of the screen with the pictures of the client.
## A dark mask over a button shows the time of the cast and of the cooldown;
## the limit button shows how full the limit bar is. A click uses the button
## (BattleSim.use_button()); the name of the attack, or the reason why it
## cannot be used, shows over the unit for a short time.
##
## The buttons are in a row at the bottom of the screen, or in the panel of a
## special unit of the bottom bar after put_buttons_in().
##
## In the village outside a fight there is no battle: show_idle() shows the
## buttons of a unit without their state, and a click emits idle_pressed. The
## owner then starts a fight in which the unit uses the button, as the client
## also uses the buttons in the village.

## A button of show_idle() was clicked.
signal idle_pressed(id: int)

const BUTTON_SIZE := 52.0
const GAP := 6.0
## In the panel (EP_SelfSpecialUnit.drawSpecialAttacks): the four attacks in
## two rows of two, 50 pixels apart, and the limit attack at the left of
## them. A button is the 52-pixel picture in the image part of PortraitMC,
## which has a scale of 0.83.
const PANEL_BUTTON_SIZE := 43.0
const PANEL_ROW_SPACE := 50.0
## The columns are the width of the attack portrait apart. That width
## includes its hidden counter of attacks (a GiftCounter at x 43), so it is
## larger than the button: 59 pixels in Ruffle.
const PANEL_COLUMN_SPACE := 59.0
const PANEL_LIMIT_POSITION := Vector2(-60, 4)
const BOTTOM_MARGIN := 70.0
const MASK_COLOR := Color(0, 0, 0, 0.6)
const LIMIT_COLOR := Color(1.0, 0.8, 0.1)

var _sim: BattleSim
var _ui: UiLibrary
var _config: GameConfig
var _unit: BattleFighter
var _idle: BattleAbility  # The ability of show_idle(), or null.
var _row := Control.new()
var _in_panel := false
var _size := BUTTON_SIZE
var _masks := {}  # Button id -> ColorRect.
var _bars := {}  # Button id -> ColorRect (the limit bar).


func _init(sim: BattleSim, ui: UiLibrary, config: GameConfig) -> void:
	_sim = sim
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)


func _ready() -> void:
	get_viewport().size_changed.connect(_place)


## Moves the buttons into holder, the attacksMc part of the panel of a special unit (EP_SpecialUnitMc).
func put_buttons_in(holder: Control) -> void:
	_in_panel = true
	_size = PANEL_BUTTON_SIZE
	_row.reparent(holder, false)
	_row.position = Vector2.ZERO


## Shows the buttons of the only selected unit, when it is a unit of the player with buttons.
func show_selection(selected: Array[BattleFighter]) -> void:
	var unit: BattleFighter = selected[0] if selected.size() == 1 else null
	if unit != null and (unit.ability == null or unit.ability.buttons.is_empty() or unit.team != BattleFighter.Team.PLAYER):
		unit = null
	if unit == _unit and _idle == null:
		return
	_unit = unit
	_idle = null
	_show_buttons(unit.ability if unit != null else null)


## Shows the buttons of ability, of a unit that is not in a battle, or none for null.
func show_idle(ability: BattleAbility) -> void:
	if ability == _idle and _unit == null:
		return
	_unit = null
	_idle = ability
	_show_buttons(ability)


func _show_buttons(ability: BattleAbility) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_masks.clear()
	_bars.clear()
	if ability == null:
		return
	var ids: Array = ability.buttons.keys()
	ids.sort()
	for index in ids.size():
		var node := _make_button(ability.buttons[ids[index]])
		node.position = _button_position(ids[index], index)
		_row.add_child(node)
	_place.call_deferred()


func _button_position(id: int, index: int) -> Vector2:
	if not _in_panel:
		return Vector2(index * (BUTTON_SIZE + GAP), 0)
	if id == BattleAbility.LIMIT_BUTTON:
		return PANEL_LIMIT_POSITION
	return Vector2((id % 2) * PANEL_COLUMN_SPACE + 2, (id / 2) * PANEL_ROW_SPACE + 4)


func _make_button(button: BattleAbility.UnitButton) -> Control:
	var node := TextureButton.new()
	node.texture_normal = _ui.thumb(button.thumb) if button.thumb != "" else null
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.size = Vector2(_size, _size)
	node.tooltip_text = button.name
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(_on_pressed.bind(button.id))
	if node.texture_normal == null:
		var back := ColorRect.new()
		back.color = Color(0.3, 0.2, 0.1)
		back.size = Vector2(_size, _size)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(back)
	if button.id == BattleAbility.LIMIT_BUTTON:
		var bar := ColorRect.new()
		bar.color = LIMIT_COLOR
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(bar)
		_bars[button.id] = bar
	var mask := ColorRect.new()
	mask.color = MASK_COLOR
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(mask)
	_masks[button.id] = mask
	return node


func _place() -> void:
	if _in_panel:
		return
	var screen := get_viewport_rect().size
	var width := _row.get_child_count() * (BUTTON_SIZE + GAP) - GAP
	_row.position = Vector2((screen.x - width) / 2, screen.y - BOTTOM_MARGIN - BUTTON_SIZE)


## Uses button id of the shown unit, as a click on it does.
func press(id: int) -> void:
	_on_pressed(id)


func _on_pressed(id: int) -> void:
	if _unit == null:
		if _idle != null:
			idle_pressed.emit(id)
		return
	var button: BattleAbility.UnitButton = _unit.ability.buttons[id]
	# PortraitSpecialAttack: the name of the attack floats over the unit for
	# the cast time, a refusal in red for the normal life.
	if _sim.use_button(_unit, id):
		_sim.show_numbers(_unit, [[NumberParticle.TEXT_BLACK, button.name]], 1.0, button.cast_seconds * BattleSim.FRAMES_PER_SECOND)
	elif _unit.ability.button_state != BattleAbility.ButtonState.IDLE and id != BattleAbility.LIMIT_BUTTON:
		_sim.show_numbers(_unit, [[NumberParticle.TEXT_RED, _config.text("AUX_NO_ESTA_LISTO")]])
	elif button.uses != 0:
		# The text can hold text keys of the client, as "4 MINIONS_MAX".
		_sim.show_numbers(_unit, [[NumberParticle.TEXT_RED, " ".join(Array(button.cant_text.split(" ")).map(_config.text))]])


func _process(_delta: float) -> void:
	if _unit == null:
		return
	if _unit.dead:
		show_selection([])
		return
	var ability := _unit.ability
	for id: int in _masks:
		var part := 0.0
		var active := ability.active_button
		if active != null and ability.button_state == BattleAbility.ButtonState.CASTING and active.cast_seconds > 0:
			part = 1.0 - float(ability.button_seconds) / active.cast_seconds
		elif active != null and ability.button_state == BattleAbility.ButtonState.COOLDOWN and active.cooldown_seconds > 0:
			part = float(ability.button_seconds) / active.cooldown_seconds
		if id == BattleAbility.LIMIT_BUTTON:
			part = 1.0 - float(ability.limit) / ability.limit_max
			var bar: ColorRect = _bars[id]
			bar.size = Vector2(_size * float(ability.limit) / ability.limit_max, 5)
			bar.position = Vector2(0, _size - 5)
		var mask: ColorRect = _masks[id]
		mask.size = Vector2(_size, _size * clampf(part, 0, 1))
		mask.position = Vector2(0, _size - mask.size.y)
