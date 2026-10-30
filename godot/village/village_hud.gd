class_name VillageHud
extends CanvasLayer
## Village screen interface: resources, the build menu and a message line.

signal item_selected(item: GameConfig.ItemDef)
## The player wants to move the selected item.
signal move_requested
## The player confirmed the sale of the selected item.
signal sell_confirmed

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


## categories: [name, Array[GameConfig.ItemDef]] for each store category.
func _init(categories: Array) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = PANEL_WIDTH
	panel.add_child(column)
	var title := Label.new()
	title.text = "Build: click an item, then a place. Right-click cancels."
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
	_sell_button.pressed.connect(_sell_dialog.popup_centered)
	_sell_dialog.confirmed.connect(func() -> void: sell_confirmed.emit())
	for control: Control in [_selection_name, _move_button, _sell_button]:
		_selection.add_child(control)
	_selection.visible = false
	column.add_child(_selection)
	add_child(_sell_dialog)
	add_child(panel)
	for index in categories.size():
		_category.add_item(categories[index][0])
		for item: GameConfig.ItemDef in categories[index][1]:
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(func() -> void: item_selected.emit(item))
			_menu.add_child(button)
			_buttons[item] = button
			_button_category[item] = index
	_category.item_selected.connect(_show_category)
	_show_category(0)


## Updates the resources and which items the player can buy.
func refresh(village: Village) -> void:
	var parts := ["Level %d" % village.get_level()]
	var next_level_xp := village.get_next_level_xp()
	parts.append("XP %d/%d" % [village.get_xp(), next_level_xp] if next_level_xp >= 0 else "XP %d" % village.get_xp())
	for code: String in RESOURCE_NAMES:
		parts.append("%s %d" % [RESOURCE_NAMES[code].capitalize(), village.get_resource(code)])
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
func show_selection(item: GameConfig.ItemDef, can_move: bool, can_sell: bool) -> void:
	_selection.visible = item != null
	if item == null:
		return
	_selection_name.text = item.name
	_move_button.disabled = not can_move
	_sell_button.disabled = not can_sell
	var refund := Village.sell_refund(item)
	_sell_button.text = "Sell"
	if can_sell and refund > 0:
		_sell_button.text = "Sell for %d %s" % [refund, RESOURCE_NAMES.get(item.cost_type, item.cost_type)]
	_sell_dialog.dialog_text = "Sell %s? You get %s." % [item.name, "nothing back" if refund == 0 else "%d %s" % [refund, RESOURCE_NAMES.get(item.cost_type, item.cost_type)]]


func show_message(text: String) -> void:
	_message.text = text


func show_placement_result(result: Village.Placement) -> void:
	show_message(PLACEMENT_MESSAGES.get(result, ""))
