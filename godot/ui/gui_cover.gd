class_name GuiCover
extends ColorRect
## The cover of the client under a window (GuiManager.addGuiCover): the black
## GuiCover at alpha 0.85 over the map and the HUD. It takes their clicks.
##
## The client has one cover and a stack of its places. A window opens with the
## cover over the HUD and under all windows (UNDER_WINDOWS, the place Base.Gui),
## or over the windows that are open (OVER_WINDOWS, the popup layer). When that
## window closes, the cover goes back to its last place. So the port shows only
## one of the covers of its open windows: the newest one when it is
## OVER_WINDOWS, else the lowest one on the screen.

enum Place { UNDER_WINDOWS, OVER_WINDOWS }

const COLOUR := Color(0, 0, 0, 0.85)

## The covers that show in the tree, in the order in which they started to show.
static var _open: Array[GuiCover] = []

var _place: Place


## Add the cover to the window as its first child, under the art.
func _init(place := Place.UNDER_WINDOWS) -> void:
	_place = place
	color = COLOUR
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what not in [NOTIFICATION_ENTER_TREE, NOTIFICATION_EXIT_TREE, NOTIFICATION_VISIBILITY_CHANGED]:
		return
	_open.erase(self)
	if what != NOTIFICATION_EXIT_TREE and is_visible_in_tree():
		_open.append(self)
	_update_open()


static func _update_open() -> void:
	if _open.is_empty():
		return
	var shown: GuiCover = _open[-1]
	if shown._place == Place.UNDER_WINDOWS:
		for cover in _open:
			if _drawn_below(cover, shown):
				shown = cover
	for cover in _open:
		var on := cover == shown
		cover.color = COLOUR if on else Color.TRANSPARENT
		cover.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


static func _drawn_below(a: CanvasItem, b: CanvasItem) -> bool:
	var layer_a := a.get_canvas_layer_node()
	var layer_b := b.get_canvas_layer_node()
	var depth_a := layer_a.layer if layer_a != null else 0
	var depth_b := layer_b.layer if layer_b != null else 0
	if depth_a != depth_b:
		return depth_a < depth_b
	return b.is_greater_than(a)
