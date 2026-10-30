class_name BattleScreen
extends Node2D
## A battle on the screen. It runs the BattleSim at the frame rate of the client
## and turns the mouse into orders, as the client does:
##
## - A click on a unit of the player selects it. A second click on it within one
##   second selects the units of the same kind within 10 tiles of it.
## - A drag that starts on a unit, or after the space bar, draws a box and
##   selects the units of the player in it. Other drags move the map.
## - A click on the ground or on an enemy sends the selected units there, see
##   BattleSim.order(). A click on the ground without selected units, or on an
##   own building, changes the selection.
##
## The item under the mouse is the unit whose graphic is under it, else the
## building on the tile under it. The client tests the pixels of the graphics.

const FRAME_SECONDS := 1.0 / 30.0
const DOUBLE_CLICK_MSEC := 1000
const SAME_KIND_RADIUS := 10  ## Tiles.
const SAME_KIND_MAX_UNITS := 50

## Kinds of units for the double click, in the order in which the client tests
## them. A unit belongs to the first kind that fits it.
enum Kind { NONE, HEALER, ENGINEER, MONK, MELEE, WORKER, RANGED, SIEGE, KAMIKAZE, FOREST, LIGHT, FIRE, SOUL, WATER }
const HEALERS: Array[int] = [502, 590, 866, 886]
const ENGINEER := 570
const MONK := 569
const MELEE_SUBCATS: Array[int] = [72, 78, 79, 77]  # Clerics, footmen, mounted, special: with range 1
const RANGED_SUBCATS: Array[int] = [80, 79]  # Archers, mounted: with a longer range
const SUBCAT_PEASANT := 71
const SUBCAT_SIEGE := 81
const SUBCAT_KAMIKAZE := 89
const ELEMENT_KINDS := {96: Kind.FOREST, 92: Kind.LIGHT, 95: Kind.FIRE, 94: Kind.SOUL, 93: Kind.WATER}

var sim: BattleSim
var _view: BattleView
var _selected: Array[BattleFighter] = []
var _time := 0.0
var _press := Vector2.INF  # Screen position of the left button press, or INF.
var _press_map := Vector2.ZERO
var _boxing := false
var _selection_tool := false  # The space bar makes the next drag a selection box.
var _last_click: BattleFighter
var _last_click_msec := 0


func _init(battle: BattleSim, view: BattleView) -> void:
	sim = battle
	_view = view
	sim.removed.connect(func(fighter: BattleFighter) -> void: _selected.erase(fighter))


## A battle for trying the battle rules and controls until the quests come:
## the items of map are the enemies, except the neutral items, and the units of
## the player start in the middle of the land area with the fewest items.
static func practice_battle(map: Village, player: Village, config: GameConfig, rng: RandomNumberGenerator) -> BattleSim:
	var battle := BattleSim.new(rng)
	for placed in map.items:
		var def := config.get_item(placed.item_id)
		if def != null:
			var fighter := battle.add_item(def, placed.tile, BattleFighter.Team.NEUTRAL if def.race == "n" else BattleFighter.Team.ENEMY)
			fighter.frame = placed.frame
	var units := player.items.filter(func(placed: Village.PlacedItem) -> bool: return player.is_own_unit(placed))
	var counts := {}
	for placed in map.items:
		var area := placed.tile / IsoGrid.LAND_TILES
		counts[area] = counts.get(area, 0) + 1
	var emptiest := Vector2i.ZERO
	for y in IsoGrid.LAND_AREAS:
		for x in IsoGrid.LAND_AREAS:
			if counts.get(Vector2i(x, y), 0) < counts.get(emptiest, 0):
				emptiest = Vector2i(x, y)
	var start := emptiest * IsoGrid.LAND_TILES + Vector2i(IsoGrid.LAND_TILES / 2, IsoGrid.LAND_TILES / 2)
	var is_free := func(tile: Vector2i) -> bool: return battle.fighter_at(tile) == null and Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile)
	var tiles := BattleFormation.square_tiles(start, units.size(), is_free)
	for i in tiles.size():
		battle.add_item(config.get_item(units[i].item_id), tiles[i], BattleFighter.Team.PLAYER)
	return battle


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		sim.step()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_selection_tool = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var point: Vector2 = make_input_local(event).position
		_view.show_hovered(_item_at(point))
		if _boxing:
			_view.show_box(Rect2(_press_map, Vector2.ZERO).expand(point))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = make_input_local(event).position
		if event.pressed:
			_press = event.position
			_press_map = point
			var under := _item_at(point)
			_boxing = _selection_tool or (under != null and under.is_unit() and under.team == BattleFighter.Team.PLAYER)
		elif _press != Vector2.INF:
			var dragged: bool = event.position.distance_to(_press) > VillageView.CLICK_MAX_DISTANCE
			if dragged and _boxing:
				_select(_view.units_in_box(Rect2(_press_map, Vector2.ZERO).expand(point)).filter(_is_own_unit))
				_selection_tool = false
			elif not dragged:
				_click(point)
			_press = Vector2.INF
			_boxing = false
			_view.show_box(Rect2())


func _click(point: Vector2) -> void:
	var tile := IsoGrid.map_to_tile(point)
	var item := _item_at(point)
	if item != null and item.team == BattleFighter.Team.PLAYER:
		var double := item == _last_click and item in _selected and Time.get_ticks_msec() - _last_click_msec <= DOUBLE_CLICK_MSEC
		_last_click = item
		_last_click_msec = Time.get_ticks_msec()
		_select(_same_kind_units(item) if double and item.is_unit() else [item])
		return
	var group: Array[BattleFighter] = []
	group.assign(_selected.filter(func(fighter: BattleFighter) -> bool: return fighter.is_unit() and fighter.team == BattleFighter.Team.PLAYER))
	if not group.is_empty() and (item == null or item.team == BattleFighter.Team.ENEMY):
		sim.order(group, tile)
	elif item == null:
		_select([])
	else:
		# A click on an enemy without units of the player, or on a neutral
		# item, selects it, so that its health shows.
		_select([item])


## The living item under point, or null.
func _item_at(point: Vector2) -> BattleFighter:
	var unit := _view.unit_at(point)
	if unit != null:
		return unit
	var item := sim.fighter_at(IsoGrid.map_to_tile(point))
	return item if item != null and not item.dead and not item.is_unit() else null


func _select(fighters: Array) -> void:
	_selected.assign(fighters)
	_view.show_selection(_selected)


func _is_own_unit(fighter: BattleFighter) -> bool:
	return fighter.team == BattleFighter.Team.PLAYER


## The units of the player of the kind of unit within SAME_KIND_RADIUS tiles,
## nearest first. A unit of no kind selects nothing new.
func _same_kind_units(unit: BattleFighter) -> Array:
	var kind := kind_of(unit)
	if kind == Kind.NONE:
		return _selected
	var found := []
	for other in sim.fighters:
		var squared := (other.tile - unit.tile).length_squared()
		if other.is_unit() and not other.dead and other.team == unit.team and squared <= SAME_KIND_RADIUS * SAME_KIND_RADIUS and kind_of(other) == kind:
			found.append([squared, found.size(), other])
	found.sort()
	return found.slice(0, SAME_KIND_MAX_UNITS).map(func(entry: Array) -> BattleFighter: return entry[2])


static func kind_of(unit: BattleFighter) -> Kind:
	var def := unit.def
	var subcat := def.subcat_functional
	if def.id in HEALERS:
		return Kind.HEALER
	if def.id == ENGINEER:
		return Kind.ENGINEER
	if def.id == MONK:
		return Kind.MONK
	if subcat in MELEE_SUBCATS and unit.attack_range <= 1:
		return Kind.MELEE
	if subcat == SUBCAT_PEASANT:
		return Kind.WORKER
	if subcat in RANGED_SUBCATS and unit.attack_range > 1:
		return Kind.RANGED
	if subcat == SUBCAT_SIEGE:
		return Kind.SIEGE
	if subcat == SUBCAT_KAMIKAZE:
		return Kind.KAMIKAZE
	return ELEMENT_KINDS.get(subcat, Kind.NONE)
