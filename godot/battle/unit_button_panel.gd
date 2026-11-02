class_name UnitButtonPanel
extends Control
## The portrait buttons of a special unit (PortraitSpecialAttack of the
## client): when the player selects one unit of their own with buttons, its
## buttons show at the bottom of the screen with the pictures of the client.
## A dark mask over a button shows the time of the cast and of the cooldown;
## the limit button shows how full the limit bar is. A click uses the button
## (BattleSim.use_button()); the name of the attack, or the reason why it
## cannot be used, shows over the unit for a short time.

const BUTTON_SIZE := 52.0
const GAP := 6.0
const BOTTOM_MARGIN := 70.0
const MASK_COLOR := Color(0, 0, 0, 0.6)
const LIMIT_COLOR := Color(1.0, 0.8, 0.1)
const TEXT_SECONDS := 1.5

var _sim: BattleSim
var _ui: UiLibrary
var _config: GameConfig
var _unit: BattleFighter
var _row := HBoxContainer.new()
var _masks := {}  # Button id -> ColorRect.
var _bars := {}  # Button id -> ColorRect (the limit bar).
var _message := Label.new()
var _message_seconds := 0.0


func _init(sim: BattleSim, ui: UiLibrary, config: GameConfig) -> void:
	_sim = sim
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GAP))
	add_child(_row)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 4)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.visible = false
	add_child(_message)


## Shows the buttons of the only selected unit, when it is a unit of the player with buttons.
func show_selection(selected: Array[BattleFighter]) -> void:
	var unit: BattleFighter = selected[0] if selected.size() == 1 else null
	if unit != null and (unit.ability == null or unit.ability.buttons.is_empty() or unit.team != BattleFighter.Team.PLAYER):
		unit = null
	if unit == _unit:
		return
	_unit = unit
	for child in _row.get_children():
		child.queue_free()
	_masks.clear()
	_bars.clear()
	if unit == null:
		return
	var ids: Array = unit.ability.buttons.keys()
	ids.sort()
	for id: int in ids:
		_row.add_child(_make_button(unit.ability.buttons[id]))
	_place.call_deferred()


func _make_button(button: BattleAbility.UnitButton) -> Control:
	var node := TextureButton.new()
	node.texture_normal = _ui.thumb(button.thumb) if button.thumb != "" else null
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	node.tooltip_text = button.name
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(_on_pressed.bind(button.id))
	if node.texture_normal == null:
		var back := ColorRect.new()
		back.color = Color(0.3, 0.2, 0.1)
		back.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
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
	var screen := get_viewport_rect().size
	_row.size = _row.get_combined_minimum_size()
	_row.position = Vector2((screen.x - _row.size.x) / 2, screen.y - BOTTOM_MARGIN - BUTTON_SIZE)


func _on_pressed(id: int) -> void:
	if _unit == null:
		return
	var button: BattleAbility.UnitButton = _unit.ability.buttons[id]
	if _sim.use_button(_unit, id):
		_say(button.name, Color.BLACK)
	elif _unit.ability.button_state != BattleAbility.ButtonState.IDLE and id != BattleAbility.LIMIT_BUTTON:
		_say(_config.text("AUX_NO_ESTA_LISTO"), Color.RED)
	else:
		# The text can hold text keys of the client, as "4 MINIONS_MAX".
		_say(" ".join(Array(button.cant_text.split(" ")).map(_config.text)), Color.RED)


func _say(text: String, colour: Color) -> void:
	if text == "":
		return
	_message.text = text
	_message.add_theme_color_override("font_color", colour)
	_message.visible = true
	_message_seconds = TEXT_SECONDS


func _process(delta: float) -> void:
	if _message_seconds > 0:
		_message_seconds -= delta
		_message.visible = _message_seconds > 0
		if _unit != null:
			var camera := get_viewport().get_camera_2d()
			var screen_point := get_viewport().get_canvas_transform() * _unit.position if camera != null else _unit.position
			_message.position = screen_point - Vector2(_message.size.x / 2, 90)
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
			part = 1.0 - float(ability.limit) / BattleAbility.LIMIT_MAX
			var bar: ColorRect = _bars[id]
			bar.size = Vector2(BUTTON_SIZE * float(ability.limit) / BattleAbility.LIMIT_MAX, 5)
			bar.position = Vector2(0, BUTTON_SIZE - 5)
		var mask: ColorRect = _masks[id]
		mask.size = Vector2(BUTTON_SIZE, BUTTON_SIZE * clampf(part, 0, 1))
		mask.position = Vector2(0, BUTTON_SIZE - mask.size.y)
