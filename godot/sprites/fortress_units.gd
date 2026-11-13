class_name FortressUnits
extends Node2D
## The units in a building whose graphic has places for them (FortressDelegate
## of the client): unit n of the building stands at the place "unit<n>" of
## the graphic (1 to 6), in its idle animation looking right. The node is a
## child of the node of the building.
##
## The client puts each unit into its place in the graphic, so the parts of
## the graphic in front of the place cover it; the port draws the units over
## the whole graphic.

const PLACES := 6
const LOOK := 3  ## ORIENTATION_RIGHT of the client.
const NODE_NAME := &"FortressUnits"


## Shows unit_ids (item ids) in the building of node, which shows frame of
## building; replaces the units that it showed before. Does nothing for a
## graphic without places.
static func show_in(node: Sprite2D, building: SpriteLibrary.ItemSprite, frame: int, sprites: SpriteLibrary, config: GameConfig, unit_ids: Array[int]) -> void:
	var old := node.get_node_or_null(NodePath(NODE_NAME))
	if old != null:
		old.queue_free()
	if building == null or unit_ids.is_empty() or building.named_point(frame, "unit1") == null:
		return
	var group := FortressUnits.new()
	group.name = NODE_NAME
	# The places are relative to the registration point of the graphic.
	group.position = node.offset - building.origin
	for i in mini(PLACES, unit_ids.size()):
		var place: Variant = building.named_point(frame, "unit%d" % (i + 1))
		var item := config.get_item(unit_ids[i])
		var sprite := sprites.get_sprite(item.img_name) if item != null and place != null else null
		if sprite == null:
			continue
		var unit := UnitSprite.new(sprite)
		unit.position = place
		group.add_child(unit)
		unit.show_action(UnitSprite.Action.IDLE, LOOK)
	node.add_child(group)
