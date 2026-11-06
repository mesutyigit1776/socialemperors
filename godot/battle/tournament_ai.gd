class_name TournamentAI
extends GroupAI
## The AI of the army of the opponent in a tournament match (TournamentIA of
## the client). The player controls their own team.
##
## - SPAWN: the armies wait for the start.
## - FORMING: the opponent's units walk FORM_STEP_OWN tiles toward the
##   player, at the speed of their slowest unit, and the player's units walk
##   FORM_STEP_FOES tiles toward them.
## - WAITING: when all units of the opponent arrived, they wait
##   WAIT_FRAMES.
## - BATTLE: each unit of the opponent attacks a unit of the player in its
##   attack range plus 2, else the weakest one; its healers heal the first
##   unit of the army. The battle also starts when the player attacks first.
##   When a unit of the player dies, all units of the opponent choose again.
##
## The client also moves units that leave the middle of the map back into it
## (keep_inside()).

enum State { SPAWN, FORMING, WAITING, BATTLE, DONE }

const FORM_STEP_OWN := -20
const FORM_STEP_FOES := 10
const WAIT_FRAMES := 300  ## 10 seconds.
const TARGET_RANGE_EXTRA := 2
const INSIDE := Rect2i(20, 20, 60, 60)  ## The client moves units back into tiles 20 to 79.
const HEALERS: Array[int] = [590, 502, 866, 886]

var state := State.SPAWN
var units: Array[BattleFighter] = []  ## The opponent's army.
var foes: Array[BattleFighter] = []  ## The player's team, weakest first.
var started := false
var _forming := 0
var _wait_start := 0
var _marching := false
var _last_frame := -1


## own: the units of the opponent; enemies: the units of the player.
func _init(own: Array[BattleFighter], enemies: Array[BattleFighter]) -> void:
	for unit in own:
		units.append(unit)
		unit.ai.collective = self
		unit.ai.condition = BattleAI.Condition.DEFENSIVE
	foes = enemies.duplicate()
	# The client sorts with a sort that does not keep the order of equal values.
	foes.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool: return a.health < b.health)


func update(sim: BattleSim, _unit: BattleFighter) -> bool:
	if _last_frame != sim.frame:
		_last_frame = sim.frame
		match state:
			State.SPAWN:
				if started:
					_change_state(sim, State.FORMING)
			State.WAITING:
				if sim.frame > _wait_start + WAIT_FRAMES:
					_change_state(sim, State.BATTLE)
	return true


func on_arrived(sim: BattleSim, _unit: BattleFighter) -> void:
	if state == State.FORMING:
		_forming -= 1
		if _forming <= 0:
			_change_state(sim, State.WAITING)


func on_attacked(sim: BattleSim, unit: BattleFighter, _attacker: BattleFighter) -> void:
	_request_healers(sim, unit)
	if _marching:
		_break_formation(sim)
	if state != State.BATTLE:
		_change_state(sim, State.BATTLE)


## A unit died: a unit of the player leaves the foes and the opponent chooses
## its targets again; a unit of the opponent leaves its army.
func on_died(sim: BattleSim, unit: BattleFighter) -> void:
	if unit in foes:
		foes.erase(unit)
		_assign_targets(sim)
	units.erase(unit)


## The client moves units of both sides that are outside INSIDE to the free
## tile nearest to the edge of INSIDE. It does this every 10 seconds, but not
## while the opponent forms.
func keep_inside(sim: BattleSim) -> void:
	if state == State.FORMING or state == State.SPAWN:
		return
	for unit in foes + units:
		if unit.dead or INSIDE.has_point(unit.tile):
			continue
		var edge := unit.tile.clamp(INSIDE.position, INSIDE.end)
		var tile: Variant = BattleFormation.nearest_free_tile(edge, 4, sim.is_free)
		if tile != null:
			sim.walk(unit, tile)


func _change_state(sim: BattleSim, new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.FORMING:
			_arrange(sim, units, FORM_STEP_OWN)
			_arrange(sim, foes, FORM_STEP_FOES)
			_march(sim)
			_forming = units.size()
		State.WAITING:
			_wait_start = sim.frame
		State.BATTLE:
			_request_healers(sim, _healer_target())
			_assign_targets(sim)


func _arrange(sim: BattleSim, army: Array[BattleFighter], step: int) -> void:
	for unit in army:
		if unit.dead:
			continue
		var tile := Vector2i(unit.tile.x + step, unit.tile.y)
		unit.origin = tile
		sim.order_walk(unit, tile)


## The opponent's units walk at the speed of the slowest of them.
func _march(sim: BattleSim) -> void:
	_marching = true
	var slowest := -1
	for unit in units:
		slowest = unit.def.velocity if slowest < 0 else mini(slowest, unit.def.velocity)
	for unit in units:
		sim.set_speed(unit, slowest)


func _break_formation(sim: BattleSim) -> void:
	_marching = false
	for unit in units:
		sim.set_speed(unit, unit.def.velocity)


func _assign_targets(sim: BattleSim) -> void:
	for unit in units:
		if unit.dead:
			continue
		if unit.def.id in HEALERS:
			unit.ai.condition = BattleAI.Condition.SURVIVE
			if unit.target == null:
				var friend := _healer_target()
				if friend != null:
					sim.set_target(unit, friend)
			continue
		var found: BattleFighter = null
		for foe in foes:
			unit.ai.condition = BattleAI.Condition.AGGRESSIVE
			if not foe.dead and floori(Vector2(unit.tile).distance_to(Vector2(foe.tile))) <= unit.attack_range + TARGET_RANGE_EXTRA:
				found = foe
				break
		if found == null and unit.target == null and not foes.is_empty():
			found = foes[0]
		if found != null:
			sim.attack(unit, found)


## The healers of the opponent heal unit, when it has less life than the unit they heal now.
func _request_healers(sim: BattleSim, unit: BattleFighter) -> void:
	if unit == null or unit.dead:
		return
	for healer in units:
		if healer.def.id in HEALERS and (healer.target == null or unit.health < healer.target.health):
			sim.set_target(healer, unit)


## The first unit of the opponent that is not a healer.
func _healer_target() -> BattleFighter:
	for unit in units:
		if not unit.dead and not unit.def.id in HEALERS:
			return unit
	return null
