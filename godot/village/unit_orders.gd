class_name UnitOrders
extends Node
## Carries out the orders of the player to units: walk to a tile, go into a
## building, or harvest a tree or a deposit. The unit walks along its path in
## the view. The village changes when the unit arrives, because the client sends
## its commands then. Walks and harvests are not in the save: the client does not
## send them either. A unit of the player that comes near a wild animal
## captures it, and the animal walks to its ranch by itself.
##
## Idle units do not walk by themselves. Like in the client, they now and then
## turn toward a neighbouring tile, which only the view shows, and a unit of the
## player that stands on a building or on another unit walks to a free tile.

## The village changed. old_level is the level before the change.
signal village_changed(message: String, old_level: int)
## A unit could not do what the player ordered.
signal order_failed(message: String)

## Walks move in frames of the client, see IsoGrid.step_toward().
const FRAME_SECONDS := 1.0 / 30.0
## The client runs the AI of the units every 61 frames, at 30 frames per second.
const AI_INTERVAL := 61.0 / 30.0
## The chance at each AI run that an idle unit turns.
const IDLE_TURN_CHANCE := 0.04

enum Goal { TILE, ENTER, HARVEST }


class Walk:
	var unit: Village.PlacedItem
	var goal: Goal
	var target: Village.PlacedItem  ## The building or the resource, or null.
	var path: Array[Vector2i] = []  ## The tiles after the one that the unit walks to.
	var tile: Vector2i  ## The tile nearest to the unit.
	var position: Vector2  ## Map pixels.
	var point: Vector2  ## The point of the tile that the unit walks to.
	var speed: int  ## Pixels per frame.
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
var _rng: RandomNumberGenerator
var _ai_time := 0.0  # Seconds since the last AI run.
var _frame_time := 0.0  # Seconds that the walks have not moved yet.


func _init(village: Village, view: VillageView, config: GameConfig, rng: RandomNumberGenerator) -> void:
	_village = village
	_view = view
	_config = config
	_rng = rng


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
	walk.position = _walks[unit].position if _walks.has(unit) else IsoGrid.tile_to_map(unit.tile)
	walk.point = walk.position
	if not walk.path.is_empty():
		walk.direction = VillageView.unit_direction(walk.tile, walk.path[0])
		walk.point = IsoGrid.tile_to_map(walk.path.pop_front())
	walk.speed = maxi(_village.walking_speed(unit), 1)
	_walks[unit] = walk
	return ""


func _process(delta: float) -> void:
	_capture_animals()
	_ai_time += delta
	if _ai_time >= AI_INTERVAL:
		_ai_time = fmod(_ai_time, AI_INTERVAL)
		_update_idle_units()
	_frame_time += delta
	while _frame_time >= FRAME_SECONDS:
		_frame_time -= FRAME_SECONDS
		for walk: Walk in _walks.values():
			_advance(walk)
	for walk: Walk in _walks.values():
		_view.show_unit(walk.unit, walk.position, walk.direction, true)
	var now := Time.get_unix_time_from_system()
	for resource: Village.PlacedItem in _harvests.keys():
		if now >= _harvests[resource].end_time:
			_finish_harvest(resource, int(now))


## The client checks for each wild animal whether a unit of the player is near.
## Units in buildings and units that harvest do not capture.
func _capture_animals() -> void:
	var units := []  # [unit, tile where it is now]
	var animals: Array[Village.PlacedItem] = []
	for placed in _village.items:
		if _village.is_wild_animal(placed):
			animals.append(placed)
		elif _village.is_own_unit(placed) and not is_busy(placed):
			units.append([placed, _walks[placed].tile if _walks.has(placed) else placed.tile])
	for animal in animals:
		for entry: Array in units:
			if _village.can_capture(entry[0], entry[1], animal):
				_village.capture(animal)
				_send_home(animal)
				village_changed.emit("You captured a %s." % _config.get_item(animal.item_id).name, _village.get_level())
				break


## Units that do not walk and do not harvest. A unit that stands on a building or
## on another unit walks away; the others sometimes turn.
func _update_idle_units() -> void:
	for placed in _village.items:
		var item := _config.get_item(placed.item_id)
		if item == null or not item.is_unit() or _walks.has(placed) or is_busy(placed):
			continue
		# The client moves wild animals too, but it does not send their moves to
		# the server. The port keeps them in place, so that the village and the
		# save show the same tile.
		if _village.is_own_unit(placed) and _village.is_crowded(placed):
			var tile := _village.random_free_tile_near(placed.tile, Village.CROWD_SEARCH_RINGS, _rng)
			if tile != Village.ANY_TILE:
				order(placed, tile, null)
		elif _rng.randf() < IDLE_TURN_CHANCE:
			var toward := placed.tile + Vector2i(roundi(_rng.randf() * 2) - 1, roundi(_rng.randf() * 2) - 1)
			if toward != placed.tile:
				_view.show_unit(placed, IsoGrid.tile_to_map(placed.tile), VillageView.unit_direction(placed.tile, toward), false)


## A captured animal walks into the nearest building of its kind. When that
## building is full, it walks next to it; when there is none, next to the town hall.
func _send_home(animal: Village.PlacedItem) -> void:
	var home := _village.animal_home(animal)
	if home != null and _village.can_enter(animal, home):
		order(animal, home.tile, home)
		return
	var goal := home if home != null else _village.town_hall()
	if goal == null:
		return
	var tile := _village.free_tile_around(Village.footprint(_config.get_item(goal.item_id), goal.tile))
	if tile != Village.ANY_TILE:
		order(animal, tile, null)


## One frame of a walk. Like in the client, the unit stops for one frame at
## each tile of its path.
func _advance(walk: Walk) -> void:
	if walk.position != walk.point:
		walk.position = IsoGrid.step_toward(walk.position, walk.point, walk.speed)
		walk.tile = IsoGrid.nearest_tile(walk.position)
	elif walk.path.is_empty():
		_arrive(walk)
	else:
		var next: Vector2i = walk.path.pop_front()
		walk.direction = VillageView.unit_direction(IsoGrid.nearest_tile(walk.point), next)
		walk.point = IsoGrid.tile_to_map(next)


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
	if walk.goal == Goal.ENTER and target_exists and _village.can_mount(walk.unit, walk.target):
		var mounted := _village.mount(walk.unit, walk.target, stand, now)
		if mounted != null:
			_view.remove_placed(walk.unit)
			_view.add_placed(mounted)
			village_changed.emit("%s took a horse and is now a %s." % [unit_name, _config.get_item(mounted.item_id).name], old_level)
			return
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
	var text := "Harvested %d %s from %s." % [amount, VillageHud.RESOURCE_NAMES.get(item.collect_type, item.collect_type), item.name]
	var found := _village.find_collectible(false, _rng)
	if found != Vector2i.ZERO:
		text += " You found %s." % SpecialActions.found_text(_config, found)
	village_changed.emit(text, old_level)
