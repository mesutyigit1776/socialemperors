class_name InfoPopup
extends Node2D
## The label of the item under the mouse on the map (InfoPopup of the
## client, which IsoInteractiveElement.highlight shows): the name of the item
## and, for a building that produces, the time to the next collection and the
## share of the production that is done. It goes on the map 30 pixels above
## the place of the item and keeps its size on the screen at every zoom.
## Walls (category 2) get no label (see shows_for()).

const MAP_OFFSET := Vector2(0, -30)
const WALL_CATEGORY := 2
## The client shows the name only for this category, as for an item that does not produce.
const NAME_ONLY_CATEGORY := 6

var _clip: UiClip
var _name_only := false


func _init(ui: UiLibrary, item: GameConfig.ItemDef) -> void:
	_clip = ui.make("InfoPopupMC")
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.set_text("buildingName", item.name)
	_name_only = item.category_id == NAME_ONLY_CATEGORY
	add_child(_clip)
	show_production(-1, -1)


static func shows_for(ui: UiLibrary, item: GameConfig.ItemDef) -> bool:
	return ui != null and ui.has_symbol("InfoPopupMC") and item.category_id != WALL_CATEGORY


## Places the label for an item at map_position (map pixels).
func place(map_position: Vector2) -> void:
	position = map_position + MAP_OFFSET


## seconds_left and total_seconds of the production, or -1 for an item that
## does not produce now: then the label shows the name only.
func show_production(seconds_left: float, total_seconds: float) -> void:
	var produces := total_seconds > 0 and not _name_only
	_clip.set_part_visible("barBack", produces)
	_clip.set_part_visible("percentMask", produces)
	var done := clampf(1.0 - seconds_left / total_seconds, 0, 1) if produces else 0.0
	_clip.clip("percentMask").scale.x = done
	_clip.set_text("percentText", "%d%%" % roundi(done * 100) if produces else "")
	_clip.set_text("timeLeft", VillageHud.dhms(maxi(int(seconds_left), 0)) if produces else "")


func _process(_delta: float) -> void:
	scale = Vector2.ONE / get_canvas_transform().get_scale()
