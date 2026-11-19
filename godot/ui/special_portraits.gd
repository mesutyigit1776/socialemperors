class_name SpecialPortraits
extends Control
## The portraits of the special units of the player above the panel of the
## bottom bar (RecuadroInfoNew.addSpecialUnitSelectorPortrait and
## redrawSpecialUnitSelectorPortraits): one for each special unit that the
## player selected, from x = LEFT, each the width of a portrait plus GAP
## after the first one apart, standing on the anchor. The owner keeps the
## list of units and shows the portraits only while the panel shows.
##
## The node goes into the "specialUnitsAnchor" part of the panel.

## The player clicked the portrait of units[index] of show_units().
signal portrait_pressed(index: int)
## The mouse went over the portrait of units[index] (entered true) or left it.
signal portrait_hovered(index: int, entered: bool)

const LEFT := 175.0
const GAP := 5.0

var _ui: UiLibrary
var _portraits: Array[SelectionPortraits.Portrait] = []


func _init(ui: UiLibrary) -> void:
	_ui = ui
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## units: a list of [img_name, life share from 0 to 1]. Empty hides all portraits.
func show_units(units: Array) -> void:
	while _portraits.size() < units.size():
		var portrait := SelectionPortraits.Portrait.new(_ui)
		var index := _portraits.size()
		portrait.pressed.connect(func() -> void: portrait_pressed.emit(index))
		portrait.hovered.connect(func(entered: bool) -> void: portrait_hovered.emit(index, entered))
		add_child(portrait)
		_portraits.append(portrait)
	for index in _portraits.size():
		var portrait := _portraits[index]
		portrait.visible = index < units.size()
		if portrait.visible:
			var unit: Array = units[index]
			portrait.show_unit(unit[0])
			portrait.show_life(unit[1])
			var art := portrait.art_size()
			portrait.position = Vector2(LEFT + index * art.x + (GAP if index != 0 else 0.0), -art.y)
