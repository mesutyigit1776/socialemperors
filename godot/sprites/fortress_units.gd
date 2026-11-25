class_name FortressUnits
extends Node2D
## The units in a building whose graphic has places for them (FortressDelegate
## of the client): unit n of the building is a child of the place "unit<n>" of
## the graphic (1 to 6), in its idle animation looking right. The node is a
## child of the node of the building.
##
## As in the client, each unit has the transform of its place, so a unit in a
## mirrored frame looks left, and the units are drawn in the order of the
## depths of their places. In the Fortress no part of the graphic is above the
## places, so only other units cover a unit.

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
	if building == null or unit_ids.is_empty():
		return
	var names: Array[String] = []
	for i in mini(PLACES, unit_ids.size()):
		names.append("unit%d" % (i + 1))
	var places := building.named_parts(frame, names)
	if places.is_empty():
		return
	var group := FortressUnits.new()
	group.name = NODE_NAME
	# The places are relative to the registration point of the graphic.
	group.position = node.offset - building.origin
	for name: String in places:
		var item := config.get_item(unit_ids[names.find(name)])
		var sprite := sprites.get_sprite(item.img_name) if item != null else null
		if sprite == null:
			continue
		var place := Node2D.new()
		place.transform = places[name]
		var unit := UnitSprite.new(sprite)
		place.add_child(unit)
		group.add_child(place)
		unit.show_action(UnitSprite.Action.IDLE, LOOK)
	node.add_child(group)
