class_name VillageHud
extends CanvasLayer
## Village screen interface: resources, the build menu and a message line.

signal item_selected(item: GameConfig.ItemDef)
## The player wants to move the selected item.
signal move_requested
## The player confirmed the sale of the selected item.
signal sell_confirmed
## The player wants to turn the selected item.
signal rotate_requested
## The player wants to collect from the selected building.
signal collect_requested
## The player wants to pay cash to collect from the selected building at once.
signal hurry_requested
## The player chose Village.WORK_MINUTES[work_time] for the selected mill or mine.
signal work_time_chosen(work_time: int)
## The player wants to train a unit in the selected building.
signal train_requested
## The player wants to pay cash so that all units in training are ready at once.
signal speed_up_requested
## The player wants to take the last unit out of the training queue and get its cost back.
signal unqueue_requested
## The player wants to take Village.units_in(selected)[index] out of the selected building.
signal unit_out_requested(index: int)
## The player wants to take a unit with this item id out of the unit warehouse.
signal warehouse_unit_out_requested(unit_id: int)
## The player wants to buy one more place in the unit warehouse.
signal warehouse_slot_requested
## The player chose an action of the action panel; id is the id that show_actions() gave.
signal action_requested(id: String)
## The player wants to see the collections, or the items in the item store.
signal collections_requested
signal stored_items_requested
signal quests_requested

const PANEL_WIDTH := 340
const PANEL_MARGIN := 10.0
const ACTIONS_MAX_HEIGHT := 220  ## More actions than fit scroll.
const RESOURCE_NAMES := {"g": "gold", "w": "wood", "s": "stone", "f": "food", "c": "cash", "p": "potions"}
const PLACEMENT_MESSAGES := {
	Village.Placement.OUTSIDE_MAP: "The item does not fit on the map.",
	Village.Placement.NOT_OWNED_LAND: "You can build only on your own land.",
	Village.Placement.OCCUPIED: "Something is already on this place.",
	Village.Placement.MAX_COUNT_REACHED: "You cannot build more of this building.",
	Village.Placement.HOUSE_LIMIT_REACHED: "Your town hall allows no more houses. Upgrade the town hall to build more.",
	Village.Placement.TOWER_LIMIT_REACHED: "You can build only %d towers for each land area that you own." % ConstructionLimits.MAX_TOWERS_PER_LAND_AREA,
	Village.Placement.LAND_AREA_TOWER_LIMIT_REACHED: "This land area has the maximum number of towers.",
	Village.Placement.LEVEL_TOO_LOW: "Your level is too low for this item.",
	Village.Placement.NOT_ENOUGH_RESOURCES: "You do not have enough resources.",
	Village.Placement.UNKNOWN_RESOURCE: "This item has a cost type that the port does not support yet.",
	Village.Placement.NOT_ALLOWED: "You cannot do this with this item.",
	Village.Placement.POPULATION_FULL: "The population is full. Build houses for more population.",
	Village.Placement.UNIT_LIMIT_REACHED: "You have the maximum number of this unit.",
}

var _resources := Label.new()
var _message := Label.new()
var _menu := VBoxContainer.new()
var _category := OptionButton.new()
var _buttons: Dictionary = {}  # ItemDef -> Button
var _button_category: Dictionary = {}  # ItemDef -> category index
var _selection := HBoxContainer.new()
var _selection_name := Label.new()
var _move_button := Button.new()
var _sell_button := Button.new()
var _sell_dialog := ConfirmationDialog.new()
var _rotate_button := Button.new()
var _production := HBoxContainer.new()
var _production_text := Label.new()
var _collect_button := Button.new()
var _hurry_button := Button.new()
var _work_times := HBoxContainer.new()
var _units := HFlowContainer.new()
var _training := VBoxContainer.new()
var _training_text := Label.new()
var _train_button := Button.new()
var _speed_up_button := Button.new()
var _unqueue_button := Button.new()
var _warehouse := VBoxContainer.new()
var _warehouse_text := Label.new()
var _warehouse_units := HFlowContainer.new()
var _warehouse_slot_button := Button.new()
var _actions := VBoxContainer.new()
var _actions_text := Label.new()
var _action_buttons := VBoxContainer.new()
var _shown_actions := []  # The actions of the buttons, so that a refresh with the same actions keeps them.


func _init() -> void:
	var panel := PanelContainer.new()
	# At the top right, because the spell book of the client is at the bottom left.
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_MARGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_top = PANEL_MARGIN
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = PANEL_WIDTH
	panel.add_child(column)
	var title := Label.new()
	title.text = "Build: click an item, then a place. Space turns it. Right-click cancels."
	for label: Label in [_resources, title, _message]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_resources)
	column.add_child(title)
	column.add_child(_category)
	var lists := HBoxContainer.new()
	for pair: Array in [["Collections", collections_requested], ["Item store", stored_items_requested], ["Quests", quests_requested]]:
		var button := Button.new()
		button.text = pair[0]
		var requested: Signal = pair[1]
		button.pressed.connect(func() -> void: requested.emit())
		lists.add_child(button)
	column.add_child(lists)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 420)
	scroll.add_child(_menu)
	column.add_child(scroll)
	column.add_child(_message)
	_selection_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_name.clip_text = true
	_move_button.text = "Move"
	_move_button.pressed.connect(func() -> void: move_requested.emit())
	_rotate_button.text = "Turn"
	_rotate_button.pressed.connect(func() -> void: rotate_requested.emit())
	_sell_button.pressed.connect(_sell_dialog.popup_centered)
	_sell_dialog.confirmed.connect(func() -> void: sell_confirmed.emit())
	for control: Control in [_selection_name, _move_button, _rotate_button, _sell_button]:
		_selection.add_child(control)
	_selection.visible = false
	column.add_child(_selection)
	_production_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_production_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_collect_button.text = "Collect"
	_collect_button.pressed.connect(func() -> void: collect_requested.emit())
	_hurry_button.text = "Finish for %d cash" % Village.HURRY_COST
	_hurry_button.pressed.connect(func() -> void: hurry_requested.emit())
	_production.add_child(_production_text)
	_production.add_child(_collect_button)
	_production.add_child(_hurry_button)
	_production.visible = false
	column.add_child(_production)
	for work_time in Village.WORK_MINUTES.size():
		var button := Button.new()
		var minutes := Village.WORK_MINUTES[work_time]
		button.text = "%s ×%s" % ["%d min" % minutes if minutes < 60 else "%d h" % (minutes / 60), String.num(Village.WORK_MULTIPLIERS[work_time])]
		button.pressed.connect(func() -> void: work_time_chosen.emit(work_time))
		_work_times.add_child(button)
	_work_times.visible = false
	column.add_child(_work_times)
	_units.visible = false
	column.add_child(_units)
	_training_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_training_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_train_button.pressed.connect(func() -> void: train_requested.emit())
	_training.add_child(_training_text)
	_training.add_child(_train_button)
	_speed_up_button.pressed.connect(func() -> void: speed_up_requested.emit())
	_training.add_child(_speed_up_button)
	_unqueue_button.pressed.connect(func() -> void: unqueue_requested.emit())
	_training.add_child(_unqueue_button)
	_training.visible = false
	column.add_child(_training)
	_warehouse_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warehouse_slot_button.pressed.connect(func() -> void: warehouse_slot_requested.emit())
	for control: Control in [_warehouse_text, _warehouse_units, _warehouse_slot_button]:
		_warehouse.add_child(control)
	_warehouse.visible = false
	column.add_child(_warehouse)
	_actions_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(_action_buttons)
	_actions.add_child(_actions_text)
	_actions.add_child(action_scroll)
	_actions.visible = false
	column.add_child(_actions)
	add_child(_sell_dialog)
	add_child(panel)
	_category.item_selected.connect(_show_category)


## Replaces the items of the build menu and keeps the shown category. Call
## refresh() after it. categories: [name, Array[GameConfig.ItemDef]] for each store category.
func set_categories(categories: Array) -> void:
	var shown := maxi(_category.selected, 0)
	_category.clear()
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	_button_category.clear()
	for index in categories.size():
		_category.add_item(categories[index][0])
		for item: GameConfig.ItemDef in categories[index][1]:
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func() -> void: item_selected.emit(item))
			_menu.add_child(button)
			_buttons[item] = button
			_button_category[item] = index
	_category.select(mini(shown, categories.size() - 1))
	_show_category(_category.selected)


## Updates the resources and which items the player can buy.
func refresh(village: Village) -> void:
	var parts := ["Level %d" % village.get_level()]
	var next_level_xp := village.get_next_level_xp()
	parts.append("XP %d/%d" % [village.get_xp(), next_level_xp] if next_level_xp >= 0 else "XP %d" % village.get_xp())
	for code: String in RESOURCE_NAMES:
		parts.append("%s %d" % [RESOURCE_NAMES[code].capitalize(), village.get_resource(code)])
	parts.append("Population %d/%d" % [village.population(), village.max_population()])
	_resources.text = "  ".join(parts)
	for item: GameConfig.ItemDef in _buttons:
		var button: Button = _buttons[item]
		var cost := "%d %s" % [item.cost, RESOURCE_NAMES.get(item.cost_type, item.cost_type)]
		button.text = "%s  (%s)" % [item.name, cost]
		if village.get_level() < item.min_level:
			button.disabled = true
			button.text += "  level %d" % item.min_level
		else:
			button.disabled = village.check_limits(item) != Village.Placement.OK
			if button.disabled:
				button.text += "  limit reached"


func _show_category(index: int) -> void:
	for item: GameConfig.ItemDef in _buttons:
		_buttons[item].visible = _button_category[item] == index


## Shows the item that the player clicked on the map, or hides the section when item is null.
func show_selection(item: GameConfig.ItemDef, can_move: bool, can_sell: bool, can_rotate: bool) -> void:
	_selection.visible = item != null
	if item == null:
		return
	_selection_name.text = item.name
	_move_button.disabled = not can_move
	_rotate_button.disabled = not can_rotate
	_sell_button.disabled = not can_sell
	var refund := Village.sell_refund(item)
	_sell_button.text = "Sell"
	if can_sell and refund > 0:
		_sell_button.text = "Sell for %d %s" % [refund, RESOURCE_NAMES.get(item.cost_type, item.cost_type)]
	_sell_dialog.dialog_text = "Sell %s? You get %s." % [item.name, "nothing back" if refund == 0 else "%d %s" % [refund, RESOURCE_NAMES.get(item.cost_type, item.cost_type)]]


## Shows the production of the selected building. item is null when the
## selection does not produce. product is what a collection gives, for example
## "250 food". requirement tells which units the building needs, or is empty;
## seconds_left is -1 when the building needs units or a work time.
func show_production(item: GameConfig.ItemDef, seconds_left: float, product: String, wood_cost: int, can_hurry: bool, requirement: String) -> void:
	_production.visible = item != null
	_work_times.visible = item != null and seconds_left < 0 and requirement.is_empty()
	if item == null:
		return
	_collect_button.visible = seconds_left == 0
	_hurry_button.visible = can_hurry
	if not requirement.is_empty():
		_production_text.text = requirement
	elif seconds_left < 0:
		_production_text.text = "Choose a work time:"
	elif seconds_left > 0:
		_production_text.text = "%s in %s" % [product, duration(seconds_left)]
	else:
		_production_text.text = "Ready: %s" % product
	if wood_cost > 0 and seconds_left >= 0:
		_production_text.text += ", costs %d wood" % wood_cost


## Shows the units in the selected building, each with a button to take it out.
## names is empty when the building has no units or the selection is not a building.
func show_units(names: Array[String]) -> void:
	for child in _units.get_children():
		child.queue_free()
	_units.visible = not names.is_empty()
	for index in names.size():
		var button := Button.new()
		button.text = "Take out %s" % names[index]
		button.pressed.connect(func() -> void: unit_out_requested.emit(index))
		_units.add_child(button)


## Shows the unit warehouse when the player selected it. units is a list of
## [item id, name, number]; it is null when the selection is not the warehouse.
## slot_price is 0 when the player cannot buy more places.
func show_warehouse(units: Variant, used: int, capacity: int, slot_price: int) -> void:
	for child in _warehouse_units.get_children():
		child.queue_free()
	_warehouse.visible = units != null
	if units == null:
		return
	_warehouse_text.text = "Unit Warehouse: %d of %d places used. Units here do not count for the population. Send a unit in by selecting it and clicking the warehouse." % [used, capacity]
	for entry: Array in units:
		var button := Button.new()
		button.text = "Take out %s (%d)" % [entry[1], entry[2]]
		var unit_id: int = entry[0]
		button.pressed.connect(func() -> void: warehouse_unit_out_requested.emit(unit_id))
		_warehouse_units.add_child(button)
	_warehouse_slot_button.visible = slot_price > 0
	_warehouse_slot_button.text = "Buy 1 more place for %d cash" % slot_price


## Shows the training of the selected building. unit is null when the building
## does not train. seconds_left is -1 when the queue is empty. speed_up_cost
## is the cash that finishes the queue, or 0 when there is nothing to finish.
func show_training(unit: GameConfig.ItemDef, costs: Dictionary, queued: int, seconds_left: float, speed_up_cost: int) -> void:
	_training.visible = unit != null
	if unit == null:
		return
	var prices := []
	for code: String in costs:
		prices.append("%d %s" % [costs[code], RESOURCE_NAMES.get(code, code)])
	_train_button.text = "Train %s (%s)" % [unit.name, ", ".join(prices)]
	_training_text.text = "No units in training." if queued == 0 else "%d in training, next in %s" % [queued, duration(seconds_left)]
	_speed_up_button.visible = speed_up_cost > 0
	_speed_up_button.text = "Finish all for %d cash" % speed_up_cost
	_unqueue_button.visible = queued > 0
	_unqueue_button.text = "Cancel the last %s" % unit.name


## Shows a text and a button for each action, for example of a special
## building. actions is a list of [id, label, enabled]; a button press emits
## action_requested(id). An empty text and list hides the panel.
func show_actions(text: String, actions: Array) -> void:
	_actions.visible = not text.is_empty() or not actions.is_empty()
	_actions_text.text = text
	_actions_text.visible = not text.is_empty()
	if actions == _shown_actions:
		return
	_shown_actions = actions.duplicate(true)
	for child in _action_buttons.get_children():
		child.queue_free()
	for action: Array in actions:
		var button := Button.new()
		button.text = action[1]
		button.disabled = not action[2]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var id: String = action[0]
		button.pressed.connect(func() -> void: action_requested.emit(id))
		_action_buttons.add_child(button)
	_fit_actions()


## Sizes the scroll area of the actions to the buttons, which can wrap their
## text. The height is known when the containers have placed the buttons.
func _fit_actions() -> void:
	var scroll: ScrollContainer = _action_buttons.get_parent()
	scroll.custom_minimum_size.y = ACTIONS_MAX_HEIGHT
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.custom_minimum_size.y = minf(_action_buttons.get_combined_minimum_size().y, ACTIONS_MAX_HEIGHT)


static func duration(seconds: float) -> String:
	var total := ceili(seconds)
	if total >= 3600:
		return "%dh %02dm" % [total / 3600, total % 3600 / 60]
	if total >= 60:
		return "%dm %02ds" % [total / 60, total % 60]
	return "%ds" % total


func show_message(text: String) -> void:
	_message.text = text


func show_placement_result(result: Village.Placement) -> void:
	show_message(PLACEMENT_MESSAGES.get(result, ""))
