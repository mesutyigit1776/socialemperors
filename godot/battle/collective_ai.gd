class_name CollectiveAI
extends GroupAI
## The group AI of the enemies that attack the own village (CollectiveIA of the
## client). The group goes through steps: it waits near its spawn tile, then
## attacks, and some kinds retreat to the spawn tile and leave the map. Each
## step lasts a number of frames (step_frames); a step without a length lasts
## until a rule of the kind ends it, or for ever.
##
## The battle calls update() from the AI of each unit of the group, every
## BattleAI.UPDATE_INTERVAL frames. When it returns false, the unit skips its
## own search for targets in that update, as in the client.
##
## Kinds, as VillageAttacks makes them:
## - BANDITS: bandits from the edge of the map. After the wait they attack
##   buildings and units of the player until they have destroyed enough of
##   both, then they retreat.
## - SIEGE: a siege with a captain. The siege engines attack the building
##   nearest to the spawn tile, the first squad follows them, the second squad
##   and the captain attack the nearest item of the player, and after two
##   minutes all retreat.
## - BIG_MOUNTS: a stampede of big mounts with a captain. The two groups attack
##   the units of the player near the centre of the map, or else a building.
##   They do not retreat.
## - ARMY: an army from the left edge, announced by a villager of the player,
##   who runs to the village. The siege engines and the first group attack the
##   items of the player nearest to the centres of the owned land. The army
##   does not retreat.
##
## The client only shows a captain's line when the unit is on the screen; the
## port sends each line with said, and the screen shows it over the unit.

signal said(unit: BattleFighter, text: String)

enum Kind { BANDITS, SIEGE, BIG_MOUNTS, ARMY }

const FRAMES_PER_MINUTE := 1800  ## The client: minutes * 60 * 1000 * 0.03.
## The steps of each kind, in order. The client uses the same numbers for the
## steps of all kinds.
const WAIT := 0
const ATTACK := 1  ## BANDITS
const BANDITS_RETREAT := 2
const ATTACK_1 := 1  ## SIEGE, BIG_MOUNTS, ARMY
const ATTACK_2 := 2
const ATTACK_3 := 3  ## SIEGE, ARMY
const SIEGE_RETREAT := 4
## Frames of each step after the wait.
const SIEGE_STEP_FRAMES: Array[int] = [150, 450, 2 * FRAMES_PER_MINUTE]
const BIG_MOUNTS_STEP_FRAMES: Array[int] = [300]
const ARMY_STEP_FRAMES: Array[int] = [150, 300]
## The client finds targets for the whole map: width plus height.
const WHOLE_MAP := IsoGrid.MAP_TILES
## Bandits destroy this many buildings and units by the level of the player
## (up to 5, up to 10, up to 15, more) before they retreat.
const BANDIT_TARGETS: Array[int] = [1, 2, 3, 4]
## The stampede looks for up to this many units of the player within this
## range of the centre of the map, and else for a building within the second range.
const STAMPEDE_CENTRE := Vector2i(50, 50)
const STAMPEDE_UNITS := 10
const STAMPEDE_UNIT_RANGE := 30
const STAMPEDE_BUILDING_RANGE := 40
## The land areas whose centre the army attacks, by the areas that the player owns.
const ARMY_FIRST_AREAS := [[7, Vector2i(1, 1)], [8, Vector2i(2, 1)]]
const ARMY_SECOND_AREAS := [[12, Vector2i(1, 2)]]
const ARMY_DEFAULT_AREA := Vector2i(2, 2)
const ARMY_AREA_CENTRE := 10  ## Tiles from the corner of the area to the point that the army attacks.
const ARMY_CAPTAIN_RUN := Vector2i(15, 15)  ## The villager runs to this tile of the area...
const ARMY_CAPTAIN_RUN_2 := Vector2i(2, 15)  ## ...or else to this one.

var kind: Kind
var spawn: Vector2i
var units: Array[BattleFighter] = []
var siege: Array[BattleFighter] = []
var group_1: Array[BattleFighter] = []
var group_2: Array[BattleFighter] = []
var captain: BattleFighter
var step := WAIT
## The frame of the battle at which the current step began. VillageBattle sets
## it from the frames that the group already waited in the village.
var step_start := 0
var wait_frames := FRAMES_PER_MINUTE
var _owned_land: Array[int] = []  # ARMY: the land areas of the player.
var _race := "h"  # The race of the player: the captain's lines.
var _to_destroy := 0  # BANDITS
var _destroyed_buildings := 0
var _destroyed_units := 0
var _forward := true  # The captain walks to the second point of the wait next.
var _line := 0  # ARMY: the next line of the villager.
var _breaking_defenses := false  # BIG_MOUNTS
var _objective: BattleFighter  # SIEGE: the building that the siege engines attack.
var _last_frame := -1


## level and race: of the player. owned_land: the numbers of the land areas
## that the player owns (1 to 25), for the army.
func _init(group_kind: Kind, spawn_tile: Vector2i, minutes: int, level: int, race: String, owned_land: Array[int]) -> void:
	kind = group_kind
	spawn = spawn_tile
	wait_frames = minutes * FRAMES_PER_MINUTE
	_race = race
	_owned_land = owned_land
	_to_destroy = BANDIT_TARGETS[clampi((level - 1) / 5, 0, BANDIT_TARGETS.size() - 1)]


func add(unit: BattleFighter, role: Array[BattleFighter] = []) -> void:
	units.append(unit)
	role.append(unit)
	unit.ai.collective = self


## The frames of the current step, or -1 when only a rule ends the step.
func step_frames() -> int:
	if step == WAIT:
		return wait_frames
	var lengths: Array[int] = []
	match kind:
		Kind.SIEGE:
			lengths = SIEGE_STEP_FRAMES
		Kind.BIG_MOUNTS:
			lengths = BIG_MOUNTS_STEP_FRAMES
		Kind.ARMY:
			lengths = ARMY_STEP_FRAMES
	return lengths[step - 1] if step - 1 < lengths.size() else -1


func is_waiting() -> bool:
	return step == WAIT


## True when the current step has a length and ends at or before frame.
func is_step_due(frame: int) -> bool:
	var length := step_frames()
	return length >= 0 and frame >= step_start + length


## True when a unit of the group walks or fights. A captain that walks during
## the wait does not count.
func is_busy() -> bool:
	for unit in _alive():
		if step == WAIT and unit == captain:
			continue
		if unit.walk_point != null or not unit.path.is_empty() or (unit.target != null and not unit.target.dead):
			return true
	return false


func update(sim: BattleSim, unit: BattleFighter) -> bool:
	var first := _last_frame != sim.frame
	var result := true
	var length := step_frames()
	if length >= 0 and sim.frame >= step_start + length:
		step += 1
		step_start = sim.frame
		result = _begin_step(sim, first)
	match kind:
		Kind.BANDITS:
			_update_bandits(sim, first)
		Kind.SIEGE:
			_update_with_captain(sim, unit, Vector2i(0, -2))
		Kind.BIG_MOUNTS:
			_update_with_captain(sim, unit, Vector2i(0, -3))
		Kind.ARMY:
			_update_army(sim)
	_last_frame = sim.frame
	return result


## A unit of the group killed its target.
func on_target_dead(sim: BattleSim, _unit: BattleFighter, target: BattleFighter) -> void:
	match kind:
		Kind.BANDITS:
			# Each unit that had the target counts it, as in the client.
			if step == ATTACK:
				if target.is_unit():
					_destroyed_units += 1
				else:
					_destroyed_buildings += 1
		Kind.BIG_MOUNTS:
			if step in [ATTACK_1, ATTACK_2] and _breaking_defenses:
				_attack_units_near_centre(sim, group_1, STAMPEDE_CENTRE)
				_attack_units_near_centre(sim, group_2, STAMPEDE_CENTRE)


## A unit of the group reached the end of its walk. A unit that retreated to
## the spawn tile leaves the map.
func on_arrived(sim: BattleSim, unit: BattleFighter) -> void:
	var retreating := (kind == Kind.BANDITS and step == BANDITS_RETREAT) or (kind == Kind.SIEGE and step == SIEGE_RETREAT)
	if retreating and unit.tile == spawn:
		units.erase(unit)
		sim.remove_item(unit)


## Starts a step; returns false when the units skip their own search for targets.
func _begin_step(sim: BattleSim, first: bool) -> bool:
	match kind:
		Kind.SIEGE:
			_begin_siege_step(sim, first)
		Kind.BIG_MOUNTS:
			if step in [ATTACK_1, ATTACK_2]:
				if _captain_alive() and first:
					_say(sim, "ASALTO_CAPITAN_%s_MASTODONTES")
					sim.walk(captain, spawn + Vector2i(5, -2))
				var from := captain.tile if captain != null else spawn
				return _attack_units_near_centre(sim, group_1 if step == ATTACK_1 else group_2, from)
		Kind.ARMY:
			_begin_army_step(sim)
	return true


func _begin_siege_step(sim: BattleSim, first: bool) -> void:
	var any := _any_unit()
	match step:
		ATTACK_1:
			if _captain_alive() and first:
				_say(sim, "ASALTO_CAPITAN_%s_ASEDIO_1")
				sim.walk(captain, spawn + Vector2i(5, -2))
			_objective = _nearest(sim, any, spawn, WHOLE_MAP, _is_building)
			if _objective != null:
				sim.order(_alive_of(siege), _objective.tile)
		ATTACK_2:
			if _captain_alive() and first:
				_say(sim, "ASALTO_CAPITAN_%s_ASEDIO_2")
			if _objective != null:
				var tile: Variant = BattleFormation.nearest_free_tile(_objective.tile, 4, sim.is_free)
				if tile != null:
					sim.order(_alive_of(group_1), tile)
				else:
					# The client sends the siege engines here, not the first squad.
					var enemy := _nearest(sim, any, spawn, WHOLE_MAP, _is_any)
					if enemy != null:
						sim.order(_alive_of(siege), enemy.tile)
		ATTACK_3:
			if _captain_alive() and first:
				_say(sim, "ASALTO_CAPITAN_%s_ASEDIO_3")
			var enemy := _nearest(sim, any, spawn, WHOLE_MAP, _is_any)
			if enemy != null:
				if _captain_alive():
					var alone: Array[BattleFighter] = [captain]
					sim.order(alone, enemy.tile)
				sim.order(_alive_of(group_2), enemy.tile)
		SIEGE_RETREAT:
			if _captain_alive() and first:
				_say(sim, "ASALTO_CAPITAN_%s_RETIRADA")


func _begin_army_step(sim: BattleSim) -> void:
	var any := _any_unit()
	match step:
		ATTACK_1:
			var corner := _army_area(ARMY_FIRST_AREAS) * IsoGrid.LAND_TILES
			var objective := _nearest(sim, any, corner + Vector2i.ONE * ARMY_AREA_CENTRE, WHOLE_MAP, _is_any)
			if objective != null:
				sim.order(_alive_of(siege), objective.tile)
		ATTACK_2:
			var corner := _army_area(ARMY_SECOND_AREAS) * IsoGrid.LAND_TILES
			var objective := _nearest(sim, any, corner + Vector2i.ONE * ARMY_AREA_CENTRE, WHOLE_MAP, _is_any)
			if objective != null:
				sim.order(_alive_of(group_1), objective.tile)


## SIEGE and BIG_MOUNTS: the captain walks between two points while the group
## waits; all units go home in the retreat.
func _update_with_captain(sim: BattleSim, unit: BattleFighter, back: Vector2i) -> void:
	if step == WAIT:
		if unit == captain and _captain_alive() and not captain.moving and captain.walk_point == null:
			_say(sim, "ASALTO_CAPITAN_%s_PREPARADOS_1" if _forward else "ASALTO_CAPITAN_%s_PREPARADOS_2")
			var point := spawn + back + (Vector2i.ZERO if _forward else Vector2i(10, 0))
			var tile: Variant = BattleFormation.nearest_free_tile(point, 4, sim.is_free)
			if tile != null:
				sim.walk(captain, tile)
			_forward = not _forward
	elif kind == Kind.SIEGE and step == SIEGE_RETREAT:
		_go_home(sim, unit)


func _update_bandits(sim: BattleSim, first: bool) -> void:
	if not first:
		return
	match step:
		ATTACK:
			for unit in _alive():
				unit.ai.condition = BattleAI.Condition.AGGRESSIVE
				if unit.target == null:
					_bandit_target(sim, unit)
			if _destroyed_buildings >= _to_destroy and _destroyed_units >= _to_destroy:
				step += 1
				step_start = sim.frame
		BANDITS_RETREAT:
			for unit in _alive():
				_go_home(sim, unit)


## ARMY: the villager runs to the village and calls its lines during the wait.
func _update_army(sim: BattleSim) -> void:
	if step != WAIT or captain == null:
		return
	var corner := _army_area(ARMY_SECOND_AREAS) * IsoGrid.LAND_TILES
	var ran := false
	if not captain.dead and not captain.moving and captain.walk_point == null:
		ran = sim.walk(captain, corner + ARMY_CAPTAIN_RUN)
	if not ran:
		ran = sim.walk(captain, corner + ARMY_CAPTAIN_RUN_2)
	# The client says a line at each update of each unit of the group.
	var key := "ASALTO_ALDEANO_%s_%d" % ["H" if _race == "h" else "T", _line + 1]
	said.emit(captain, sim.config.text(key) if sim.config != null else key)
	_line = (_line + 1) % 4


## A bandit takes the nearest building or unit of the player, whichever the
## group still has to destroy; at random when it needs both.
func _bandit_target(sim: BattleSim, unit: BattleFighter) -> void:
	var needs_buildings := _destroyed_buildings < _to_destroy
	var needs_units := _destroyed_units < _to_destroy
	var target: BattleFighter = null
	if needs_buildings and needs_units:
		target = _nearest(sim, unit, unit.tile, WHOLE_MAP, _is_building if sim.rng.randf() < 0.5 else _is_free_unit)
	elif needs_buildings:
		target = _nearest(sim, unit, unit.tile, WHOLE_MAP, _is_building)
	elif needs_units:
		target = _nearest(sim, unit, unit.tile, WHOLE_MAP, _is_free_unit)
	sim.set_target(unit, target)
	if target != null:
		sim.attack(unit, target)


## BIG_MOUNTS: each unit of group walks to one of the units of the player
## nearest to the centre and attacks it. When the walk of the last unit fails,
## the group attacks the building of the player nearest to from instead.
## Returns false when the player has units near the centre.
func _attack_units_near_centre(sim: BattleSim, group: Array[BattleFighter], from: Vector2i) -> bool:
	var targets := _player_units_near(sim, STAMPEDE_CENTRE, STAMPEDE_UNIT_RANGE, STAMPEDE_UNITS)
	if targets.is_empty():
		return true
	var walked := false
	for i in range(group.size() - 1, -1, -1):
		var unit := group[i]
		var target := targets[i % targets.size()]
		walked = sim.walk(unit, target.tile)
		if walked:
			sim.attack(unit, target)
	_breaking_defenses = not walked
	if not walked:
		var any := _any_unit()
		var building := _nearest(sim, any, from, STAMPEDE_BUILDING_RANGE, _is_building) if any != null else null
		if building != null:
			for i in range(group.size() - 1, -1, -1):
				sim.attack(group[i], building)
	return false


## The units of the player within range tiles of tile, nearest first, at most count.
func _player_units_near(sim: BattleSim, tile: Vector2i, range_tiles: int, count: int) -> Array[BattleFighter]:
	var found: Array[BattleFighter] = []
	var squares := {}
	for other in sim.fighters:
		var offset := other.tile - tile
		var squared := offset.x * offset.x + offset.y * offset.y
		if other.team == BattleFighter.Team.PLAYER and other.is_unit() and not other.dead and squared <= range_tiles * range_tiles:
			found.append(other)
			squares[other] = squared
	found.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool: return squares[a] < squares[b])
	return found.slice(0, count)


## The unit walks back to the spawn tile and does not fight on the way.
func _go_home(sim: BattleSim, unit: BattleFighter) -> void:
	if unit.dead or unit.moving or unit.walk_point != null:
		return
	sim.order_walk(unit, spawn)
	unit.ai.condition = BattleAI.Condition.PASSIVE


## The first area of areas that the player owns, else ARMY_DEFAULT_AREA.
func _army_area(areas: Array) -> Vector2i:
	for entry: Array in areas:
		if int(entry[0]) in _owned_land:
			return entry[1]
	return ARMY_DEFAULT_AREA


## The best target of the player for the client's search from tile; item gives the side.
func _nearest(sim: BattleSim, item: BattleFighter, tile: Vector2i, range_tiles: int, filter: Callable) -> BattleFighter:
	if item == null:
		return null
	return sim.nearest_target(item, tile, range_tiles, filter, false)


## The captain says the line of the game texts; the pattern gets H or T for its race.
func _say(sim: BattleSim, key_pattern: String) -> void:
	if not _captain_alive():
		return
	var key := key_pattern % ("H" if captain.def.race == "h" else "T")
	said.emit(captain, sim.config.text(key) if sim.config != null else key)


func _captain_alive() -> bool:
	return captain != null and not captain.dead


func _any_unit() -> BattleFighter:
	var alive := _alive()
	return alive[0] if not alive.is_empty() else null


func _alive() -> Array[BattleFighter]:
	return _alive_of(units)


func _alive_of(group: Array[BattleFighter]) -> Array[BattleFighter]:
	return group.filter(func(unit: BattleFighter) -> bool: return not unit.dead and unit.team == BattleFighter.Team.ENEMY)


static func _is_building(item: BattleFighter) -> bool:
	return not item.is_unit()


static func _is_free_unit(item: BattleFighter) -> bool:
	return item.is_unit()


static func _is_any(_item: BattleFighter) -> bool:
	return true
