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
## The player wants to take Village.units_in(selected)[index] out of the selected building.
signal unit_out_requested(index: int)

const PANEL_WIDTH := 340
const RESOURCE_NAMES := {"g": "gold", "w": "wood", "s": "stone", "f": "food", "c": "cash"}
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
var _training := HBoxContainer.new()
var _training_text := Label.new()
var _train_button := Button.new()


func _init() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
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
	_training.visible = false
	column.add_child(_training)
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
## selection does not produce. seconds_left is -1 when the building needs a
## unit (needs_units) or a work time.
func show_production(item: GameConfig.ItemDef, seconds_left: float, amount: int, wood_cost: int, can_hurry: bool, needs_units: bool) -> void:
	_production.visible = item != null
	_work_times.visible = item != null and seconds_left < 0 and not needs_units
	if item == null:
		return
	var resource: String = RESOURCE_NAMES.get(item.collect_type, item.collect_type)
	_collect_button.visible = seconds_left == 0
	_hurry_button.visible = can_hurry
	if needs_units:
		_production_text.text = "Works only with a unit in it. Select a unit, then click the building."
	elif seconds_left < 0:
		_production_text.text = "Choose a work time:"
	elif seconds_left > 0:
		_production_text.text = "%d %s in %s" % [amount, resource, _duration(seconds_left)]
	else:
		_production_text.text = "Ready: %d %s" % [amount, resource]
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


## Shows the training of the selected building. unit is null when the building
## does not train. seconds_left is -1 when the queue is empty.
func show_training(unit: GameConfig.ItemDef, costs: Dictionary, queued: int, seconds_left: float) -> void:
	_training.visible = unit != null
	if unit == null:
		return
	var prices := []
	for code: String in costs:
		prices.append("%d %s" % [costs[code], RESOURCE_NAMES.get(code, code)])
	_train_button.text = "Train %s (%s)" % [unit.name, ", ".join(prices)]
	_training_text.text = "No units in training." if queued == 0 else "%d in training, next in %s" % [queued, _duration(seconds_left)]


static func _duration(seconds: float) -> String:
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
