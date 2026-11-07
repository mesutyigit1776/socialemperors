class_name SelectionPanel
extends Control
## The panel of the selected item (RecuadroInfoNew and the extended portraits
## of the client) in the bottom bar: EP_UnitMC for a unit, EP_NewBarracksMC
## for a building that trains, EP_Farm_MC for a building that produces and
## EP_House_MC for the others. Each shows the name, the picture, the health
## and the values of the item; the buttons sell the item, or open the tools
## to move, turn and store it.
##
## The port has actions that the client has in other windows: the work time
## of a mill, the units in a building, the unit warehouse and the actions of
## the special buildings. They are buttons in a box above the panel.

signal move_requested
signal sell_confirmed
signal rotate_requested
signal store_requested
signal collect_requested
signal hurry_requested
## The player chose Village.WORK_MINUTES[work_time] for the selected mill or mine.
signal work_time_chosen(work_time: int)
signal train_requested
signal speed_up_requested
signal unqueue_requested
## The player wants to take Village.units_in(selected)[index] out of the selected building.
signal unit_out_requested(index: int)
signal warehouse_unit_out_requested(unit_id: int)
signal warehouse_slot_requested
## The player chose an action of show_actions(); id is the id that it gave.
signal action_requested(id: String)

enum Kind { NONE, HOUSE, UNIT, FARM, BARRACKS }

const SYMBOLS := {Kind.HOUSE: "EP_House_MC", Kind.UNIT: "EP_UnitMC", Kind.FARM: "EP_Farm_MC", Kind.BARRACKS: "EP_NewBarracksMC"}
const QUEUE_PORTRAITS := 5
const EXTRAS_WIDTH := 330
const EXTRAS_MAX_HEIGHT := 260

var _ui: UiLibrary
var _config: GameConfig
var _windows: Control  # The node that gets the confirm windows of the panel.
var _kind := Kind.NONE
var _clip: UiClip
var _item: GameConfig.ItemDef
var _health := 0
var _can := {}  # "move", "sell", "rotate", "store" -> bool.
var _locked := false
var _production: Array = []  # The arguments of show_production(), or empty.
var _training: Array = []  # The arguments of show_training(), or empty.
var _extras_box := PanelContainer.new()
var _extras := VBoxContainer.new()
var _work_times := HFlowContainer.new()
var _collect_button := Button.new()
var _production_text := Label.new()
var _units := VBoxContainer.new()
var _warehouse := VBoxContainer.new()
var _actions := VBoxContainer.new()
var _actions_text := Label.new()
var _action_buttons := VBoxContainer.new()
var _shown_actions := []  # The actions of the buttons, so that a refresh with the same actions keeps them.


## windows: the node that gets the confirm windows of the panel.
func _init(ui: UiLibrary, config: GameConfig, windows: Control) -> void:
	_ui = ui
	_config = config
	_windows = windows
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_extras_box.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(EXTRAS_WIDTH, 0)
	scroll.add_child(_extras)
	_extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extras_box.add_child(scroll)
	add_child(_extras_box)
	for label: Label in [_production_text, _actions_text]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = EXTRAS_WIDTH - 20
	_collect_button.text = "Collect"
	_collect_button.pressed.connect(func() -> void: collect_requested.emit())
	for work_time in Village.WORK_MINUTES.size():
		var button := Button.new()
		var minutes := Village.WORK_MINUTES[work_time]
		button.text = "%s ×%s" % ["%d min" % minutes if minutes < 60 else "%d h" % (minutes / 60), String.num(Village.WORK_MULTIPLIERS[work_time])]
		button.pressed.connect(func() -> void: work_time_chosen.emit(work_time))
		_work_times.add_child(button)
	_actions.add_child(_actions_text)
	_actions.add_child(_action_buttons)
	for control: Control in [_production_text, _work_times, _collect_button, _units, _warehouse, _actions]:
		control.visible = false
		_extras.add_child(control)


## Shows the item that the player clicked on the map, or hides the panel when item is null.
func show_selection(item: GameConfig.ItemDef, health: int, can_move: bool, can_sell: bool, can_rotate: bool, can_store: bool) -> void:
	_item = item
	_health = health
	_can = {"move": can_move, "sell": can_sell, "rotate": can_rotate, "store": can_store}
	_production = []
	_training = []
	if item == null:
		_show_actions_now("", [])
		show_units([])
		show_warehouse(null, 0, 0, 0)
	_refresh()


## The production of the selected building, see VillageHud.duration(). item is
## null when the selection does not produce. product is what a collection
## gives, for example "250 food"; requirement tells which units the building
## needs, or is empty; seconds_left and total_seconds (see
## Village.production_seconds()) are -1 when the building needs units or a work time.
func show_production(item: GameConfig.ItemDef, seconds_left: float, total_seconds: float, product: String, wood_cost: int, can_hurry: bool, requirement: String) -> void:
	_production = [] if item == null else [seconds_left, product, wood_cost, can_hurry, requirement, total_seconds]
	_refresh()


## The training of the selected building. unit is null when the building does
## not train. seconds_left is -1 when the queue is empty. speed_up_cost is the
## cash that finishes the queue, or 0 when there is nothing to finish.
func show_training(unit: GameConfig.ItemDef, costs: Dictionary, queued: int, seconds_left: float, speed_up_cost: int) -> void:
	_training = [] if unit == null else [unit, costs, queued, seconds_left, speed_up_cost]
	_refresh()


## The units in the selected building, each with a button to take it out.
func show_units(names: Array[String]) -> void:
	_clear(_units)
	_units.visible = not names.is_empty()
	for index in names.size():
		_button(_units, "Take out %s" % names[index], func() -> void: unit_out_requested.emit(index))
	_fit_extras()


## The unit warehouse when the player selected it. units is a list of [item
## id, name, number]; it is null when the selection is not the warehouse.
## slot_price is 0 when the player cannot buy more places.
func show_warehouse(units: Variant, used: int, capacity: int, slot_price: int) -> void:
	_clear(_warehouse)
	_warehouse.visible = units != null
	if units != null:
		var text := Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = EXTRAS_WIDTH - 20
		text.text = "Unit Warehouse: %d of %d places used. Units here do not count for the population. Send a unit in by selecting it and clicking the warehouse." % [used, capacity]
		_warehouse.add_child(text)
		for entry: Array in units:
			var unit_id: int = entry[0]
			_button(_warehouse, "Take out %s (%d)" % [entry[1], entry[2]], func() -> void: warehouse_unit_out_requested.emit(unit_id))
		if slot_price > 0:
			_button(_warehouse, "Buy 1 more place for %d cash" % slot_price, func() -> void: warehouse_slot_requested.emit())
	_fit_extras()


## A text and a button for each action, for example of a special building.
## actions is a list of [id, label, enabled], or [id, label, enabled,
## question] for an action that asks the question first; a button press
## emits action_requested(id). An empty text and list hides them.
func show_actions(text: String, actions: Array) -> void:
	_show_actions_now(text, actions)


## During the tutorial, the client hides the tools and the sell button.
func set_locked(locked: bool) -> void:
	_locked = locked
	_refresh()


func _show_actions_now(text: String, actions: Array) -> void:
	_actions.visible = not text.is_empty() or not actions.is_empty()
	_actions_text.text = text
	_actions_text.visible = not text.is_empty()
	if actions == _shown_actions:
		_fit_extras()
		return
	_shown_actions = actions.duplicate(true)
	_clear(_action_buttons)
	for action: Array in actions:
		var id: String = action[0]
		var question: String = action[3] if action.size() > 3 else ""
		var button := _button(_action_buttons, action[1], func() -> void:
			if question.is_empty():
				action_requested.emit(id)
			else:
				_confirm(question, func() -> void: action_requested.emit(id)))
		button.disabled = not action[2]
	_fit_extras()


func _kind_now() -> Kind:
	if _item == null:
		return Kind.NONE
	if _item.is_unit():
		return Kind.UNIT
	if not _training.is_empty():
		return Kind.BARRACKS
	if not _production.is_empty():
		return Kind.FARM
	return Kind.HOUSE


func _refresh() -> void:
	var kind := _kind_now()
	if kind != _kind:
		_kind = kind
		if _clip != null:
			_clip.queue_free()
			_clip = null
		if kind != Kind.NONE:
			_clip = _ui.make(SYMBOLS[kind])
			add_child(_clip)
			move_child(_clip, 0)
			_connect_buttons()
	if _clip != null:
		_fill_common()
		match kind:
			Kind.UNIT, Kind.HOUSE:
				_fill_values()
			Kind.FARM:
				_fill_farm()
			Kind.BARRACKS:
				_fill_barracks()
	_production_text.visible = false
	_work_times.visible = false
	_collect_button.visible = false
	if kind == Kind.FARM:
		var seconds_left: float = _production[0]
		var requirement: String = _production[4]
		_work_times.visible = seconds_left < 0 and requirement.is_empty()
		_production_text.visible = _work_times.visible
		_production_text.text = "Choose a work time:"
		_collect_button.visible = seconds_left == 0
	_fit_extras()


func _connect_buttons() -> void:
	var sell := _clip.clip("btSell")
	if sell != null:
		sell.set_text("lbl", _config.text("AUX_VENDER"))
		sell.make_button(true)
		sell.pressed.connect(_ask_sell)
	var tools := _clip.button("btTools")
	if tools != null:
		_clip.set_part_visible("menuTools", false)
		tools.pressed.connect(func() -> void: _clip.set_part_visible("menuTools", not _clip.part("menuTools").visible))
	for pair: Array in [["menuTools/btMove", move_requested], ["menuTools/btFlip", rotate_requested], ["menuTools/btPutInStorage", store_requested]]:
		var button := _clip.button(pair[0])
		if button != null:
			var requested: Signal = pair[1]
			button.pressed.connect(func() -> void:
				_clip.set_part_visible("menuTools", false)
				requested.emit())
	# The port has no upgrades of buildings.
	_clip.set_part_visible("upgradeinfo", false)
	_clip.set_part_visible("menu", false)
	var hurry := _clip.button("btHurryup")
	if hurry != null:
		hurry.pressed.connect(func() -> void: hurry_requested.emit())
	var train := _clip.clip("trainUnit")
	if train != null:
		train.make_button()
		train.pressed.connect(func() -> void: train_requested.emit())
	var speed_up := _clip.clip("speedup")
	if speed_up != null:
		speed_up.make_button()
		speed_up.pressed.connect(func() -> void: speed_up_requested.emit())
	for index in range(1, QUEUE_PORTRAITS + 1):
		var portrait := _clip.clip("queuePortrait%d" % index)
		if portrait != null:
			portrait.make_button()
			portrait.pressed.connect(func() -> void: unqueue_requested.emit())
	var picture := TextureRect.new()
	picture.texture = _ui.thumb(_item.img_name)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip("mcImageSelected").add_child(picture)


func _fill_common() -> void:
	_clip.set_text("txNombre", _item.name)
	var life := maxi(_item.life, 1)
	_clip.set_text("mcVida/txVida", "%d/%d" % [_health, _item.life])
	var bar := _clip.clip("mcVida/barVida")
	if bar != null:
		bar.scale.x = clampf(float(_health) / life, 0.0, 1.0)
	_clip.set_part_visible("btSell", not _locked and _can.get("sell", false))
	_clip.set_part_visible("btTools", not _locked and (_can.get("move", false) or _can.get("rotate", false) or _can.get("store", false)))
	for pair: Array in [["menuTools/btMove", "move"], ["menuTools/btFlip", "rotate"], ["menuTools/btPutInStorage", "store"]]:
		var button := _clip.button(pair[0])
		if button != null:
			button.enabled = _can.get(pair[1], false)


## The values of a unit or a building, as the client shows them: the
## defense field shows the attack interval.
func _fill_values() -> void:
	for pair: Array in [["mcAttack/txAttack", _item.attack], ["mcDefense/txDefense", _item.attack_interval], ["mcRange/txRange", _item.attack_range], ["mcSpeed/txSpeed", _item.velocity], ["mcPop/txPop", _item.population]]:
		_clip.set_text(pair[0], str(pair[1]))
	_clip.set_part_visible("mcAttack", _item.attack > 0)
	_clip.set_part_visible("mcDefense", _item.attack > 0)
	_clip.set_part_visible("mcPop", _item.population > 0)
	_clip.set_text("tip", "")


func _fill_farm() -> void:
	var seconds_left: float = _production[0]
	var product: String = _production[1]
	var wood_cost: int = _production[2]
	var can_hurry: bool = _production[3]
	var requirement: String = _production[4]
	_clip.set_text("earns", product.get_slice(" ", 0))
	_clip.clip("iconResources").show_frame(StoreWindow.COST_FRAMES.get(_item.collect_type, 1))
	_clip.set_text("mcContained/txTip", requirement)
	_clip.set_text("txCapacity", "Costs %d wood" % wood_cost if wood_cost > 0 and seconds_left >= 0 else "")
	var bar := _clip.clip("barraTiempo")
	bar.visible = seconds_left >= 0 and requirement.is_empty()
	var total := maxf(_production[5], 1.0)
	var done := 1.0 if seconds_left == 0 else clampf(1.0 - seconds_left / total, 0.0, 1.0)
	bar.clip("percentMask").scale.x = done
	bar.set_text("percentText", "%d%%" % int(done * 100))
	bar.set_text("timeLeft", "Ready" if seconds_left == 0 else VillageHud.duration(seconds_left))
	_clip.set_part_visible("btHurryup", can_hurry)


func _fill_barracks() -> void:
	var unit: GameConfig.ItemDef = _training[0]
	var costs: Dictionary = _training[1]
	var queued: int = _training[2]
	var seconds_left: float = _training[3]
	var speed_up_cost: int = _training[4]
	_clip.set_text("txTrainingUnit", unit.name)
	var thumb := _clip.clip("mcImageTrainable/thumb")
	if thumb != null and thumb.get_node_or_null("picture") == null:
		# EP_SelfBarracksBuilding draws the unit at 64 × 64 pixels.
		var picture := TextureRect.new()
		picture.name = "picture"
		picture.texture = _ui.thumb(unit.img_name)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.size = Vector2(64, 64)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(picture)
	_clip.set_text("trainUnit/txtTitle", _config.text("BARRACKS_TRAIN_BUTTON"))
	# The client shows the first cost with its icon and the food below it.
	var codes := costs.keys().filter(func(code: String) -> bool: return code != "f")
	var first: String = codes[0] if not codes.is_empty() else "g"
	_clip.set_text("trainUnit/cost", _short(costs.get(first, 0)))
	_clip.clip("trainUnit/iconResources").show_frame(StoreWindow.COST_FRAMES.get(first, 1))
	_clip.set_text("trainUnit/costFood", _short(costs.get("f", 0)))
	_clip.set_text("trainUnit/txCostTime", VillageHud.duration(unit.training_time))
	for index in range(1, QUEUE_PORTRAITS + 1):
		var portrait := _clip.clip("queuePortrait%d" % index)
		if portrait != null:
			portrait.modulate.a = 1.0 if index <= queued else 0.35
	_clip.set_text("txRemaining", "" if queued == 0 else VillageHud.duration(seconds_left))
	_clip.set_part_visible("speedup", speed_up_cost > 0)
	_clip.set_text("speedup/txtSpeedUpTitle", _config.text("BARRACKS_SPEED_UP"))
	_clip.set_text("speedup/txSpeedupCost", str(speed_up_cost))


## The client writes 10000 and more as thousands: "12k".
static func _short(value: int) -> String:
	return "%dk" % (value / 1000) if value >= 10000 else str(value)


func _ask_sell() -> void:
	var refund := Village.sell_refund(_item)
	var question := "Sell %s? You get %s." % [_item.name, "nothing back" if refund == 0 else "%d %s" % [refund, VillageHud.RESOURCE_NAMES.get(_item.cost_type, _item.cost_type)]]
	_confirm(question, func() -> void: sell_confirmed.emit())


func _confirm(question: String, action: Callable) -> void:
	var window := ConfirmWindow.new(_ui, _config, question)
	window.confirmed.connect(action)
	_windows.add_child(window)


## Shows the box of the extra buttons when it has something, above the panel.
func _fit_extras() -> void:
	var shown := _item != null and _extras.get_children().any(func(child: Control) -> bool: return child.visible)
	_extras_box.visible = shown
	if not shown:
		return
	var scroll: ScrollContainer = _extras.get_parent()
	scroll.custom_minimum_size.y = minf(_extras.get_combined_minimum_size().y, EXTRAS_MAX_HEIGHT)
	_extras_box.reset_size()
	_extras_box.position = Vector2(0, -_extras_box.get_combined_minimum_size().y - 4)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _button(container: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	container.add_child(button)
	return button
