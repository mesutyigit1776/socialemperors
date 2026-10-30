class_name UnitOrders
extends Node
## Carries out the orders of the player to units: walk to a tile, go into a
## building, or harvest a tree or a deposit. The unit walks along its path in
## the view. The village changes when the unit arrives, because the client sends
## its commands then. Walks and harvests are not in the save: the client does not
## send them either.

## The village changed. old_level is the level before the change.
signal village_changed(message: String, old_level: int)
## A unit could not do what the player ordered.
signal order_failed(message: String)

## Tiles per second for each point of the velocity of a unit. Only the view uses it.
const SPEED_PER_VELOCITY := 0.8

enum Goal { TILE, ENTER, HARVEST }


class Walk:
	var unit: Village.PlacedItem
	var goal: Goal
	var target: Village.PlacedItem  ## The building or the resource, or null.
	var path: Array[Vector2i] = []  ## The tiles that are still in front of the unit.
	var tile: Vector2i  ## The tile where the current step starts.
	var progress := 0.0  ## From 0 to 1 along the current step.
	var direction := 5


class Harvest:
	var units: Array[Village.PlacedItem] = []
	var end_time: float


var _village: Village
var _view: VillageView
var _config: GameConfig
var _walks: Dictionary = {}  # Village.PlacedItem (unit) -> Walk
var _harvests: Dictionary = {}  # Village.PlacedItem (resource) -> Harvest
var _harvesting: Dictionary = {}  # Village.PlacedItem (unit) -> Village.PlacedItem (resource)


func _init(village: Village, view: VillageView, config: GameConfig) -> void:
	_village = village
	_view = view
	_config = config


func is_busy(unit: Village.PlacedItem) -> bool:
	return _harvesting.has(unit)


## Sends the unit to the tile, or into the building or to the resource target.
## Returns an empty text, or the reason why the unit cannot go.
func order(unit: Village.PlacedItem, tile: Vector2i, target: Village.PlacedItem) -> String:
	var unit_item := _config.get_item(unit.item_id)
	if is_busy(unit):
		return "%s is harvesting." % unit_item.name
	var walk := Walk.new()
	walk.unit = unit
	walk.goal = Goal.TILE
	var is_goal := func(candidate: Vector2i) -> bool: return candidate == tile
	if target != null and target != unit:
		var target_item := _config.get_item(target.item_id)
		if _village.can_harvest(unit, target):
			if _harvests.has(target) and _harvests[target].units.size() >= target_item.unit_capacity:
				return "%s has no room for more units." % target_item.name
			walk.goal = Goal.HARVEST
		elif _village.can_enter(unit, target):
			walk.goal = Goal.ENTER
		else:
			return "%s cannot go into %s." % [unit_item.name, target_item.name]
		walk.target = target
		var area := Village.footprint(target_item, target.tile)
		# The unit stops on a tile next to the target.
		is_goal = func(candidate: Vector2i) -> bool: return area.grow(1).has_point(candidate) and not area.has_point(candidate)
	elif not _village.is_free(tile, unit):
		return "%s cannot stand there." % unit_item.name
	walk.tile = _walks[unit].tile if _walks.has(unit) else unit.tile
	walk.path = Pathfinder.find_path(walk.tile, is_goal, func(candidate: Vector2i) -> bool: return _village.is_free(candidate, unit))
	if walk.path.is_empty() and not is_goal.call(walk.tile):
		return "%s cannot find a way there." % unit_item.name
	_walks[unit] = walk
	return ""


func _process(delta: float) -> void:
	for walk: Walk in _walks.values():
		_advance(walk, delta)
	var now := Time.get_unix_time_from_system()
	for resource: Village.PlacedItem in _harvests.keys():
		if now >= _harvests[resource].end_time:
			_finish_harvest(resource, int(now))


func _advance(walk: Walk, delta: float) -> void:
	walk.progress += delta * maxf(_config.get_item(walk.unit.item_id).velocity, 1) * SPEED_PER_VELOCITY
	while walk.progress >= 1 and not walk.path.is_empty():
		walk.tile = walk.path.pop_front()
		walk.progress -= 1
	if walk.path.is_empty():
		_arrive(walk)
		return
	walk.direction = VillageView.unit_direction(walk.tile, walk.path[0])
	var position := IsoGrid.tile_to_map(walk.tile).lerp(IsoGrid.tile_to_map(walk.path[0]), walk.progress)
	_view.show_unit(walk.unit, position, walk.direction, true)


func _arrive(walk: Walk) -> void:
	_walks.erase(walk.unit)
	var unit_name := _config.get_item(walk.unit.item_id).name
	var old_level := _village.get_level()
	var now := int(Time.get_unix_time_from_system())
	var stand := walk.tile
	# Another item can take the tile while the unit walks.
	if not _village.is_free(stand, walk.unit):
		stand = _village.free_tile_around(Rect2i(stand, Vector2i.ONE))
	var target_exists := walk.target != null and walk.target in _village.items
	if walk.goal == Goal.ENTER and target_exists and _village.push_unit(walk.unit, walk.target, now) == Village.Placement.OK:
		_view.remove_placed(walk.unit)
		village_changed.emit("%s went into %s." % [unit_name, _config.get_item(walk.target.item_id).name], old_level)
		return
	if stand != Village.ANY_TILE:
		_village.move_unit(walk.unit, stand, walk.direction)
	_view.update_placed(walk.unit)
	if walk.goal == Goal.TILE:
		village_changed.emit("", old_level)
	elif walk.goal == Goal.HARVEST and target_exists and _village.can_harvest(walk.unit, walk.target) \
			and (not _harvests.has(walk.target) or _harvests[walk.target].units.size() < _config.get_item(walk.target.item_id).unit_capacity):
		if not _harvests.has(walk.target):
			var harvest := Harvest.new()
			harvest.end_time = Time.get_unix_time_from_system() + _village.harvest_seconds(walk.target)
			_harvests[walk.target] = harvest
		_harvests[walk.target].units.append(walk.unit)
		_harvesting[walk.unit] = walk.target
		_view.set_item_visible(walk.unit, false)
		village_changed.emit("%s harvests %s." % [unit_name, _config.get_item(walk.target.item_id).name], old_level)
	else:
		village_changed.emit("", old_level)
		order_failed.emit("%s could not do it: the target is gone or full." % unit_name)


func _finish_harvest(resource: Village.PlacedItem, now: int) -> void:
	var harvest: Harvest = _harvests[resource]
	_harvests.erase(resource)
	var item := _config.get_item(resource.item_id)
	var old_level := _village.get_level()
	var amount := _village.harvest_amount(resource, harvest.units.size())
	var regrowth := _village.harvest(resource, harvest.units.size(), now)
	_view.remove_placed(resource)
	if regrowth != null:
		_view.add_placed(regrowth)
	for unit in harvest.units:
		_harvesting.erase(unit)
		_view.set_item_visible(unit, true)
	village_changed.emit("Harvested %d %s from %s." % [amount, VillageHud.RESOURCE_NAMES.get(item.collect_type, item.collect_type), item.name], old_level)
