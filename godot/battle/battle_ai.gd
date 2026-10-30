class_name BattleAI
extends RefCounted
## The behaviour of one unit in a battle, as in the original client. The battle
## runs update() every UPDATE_INTERVAL frames and tells the AI about attacks,
## deaths and arrivals. It gives the unit to each call, so that the AI does not
## keep a reference to the unit or to the battle.
##
## The condition of a unit says how it fights: aggressive units look for
## enemies, defensive units also stay near their start, passive units do not
## fight back, and survivors run away when an enemy attacks them. The state says
## what the unit does: a forced move (an order of the player) has priority over
## attacks.

enum State { IDLE, FORCED_MOVE }
enum Condition { DEFENSIVE, AGGRESSIVE, PASSIVE, SURVIVE }

const UPDATE_INTERVAL := 61
const AGGRO_RANGE := 10  ## Tiles in which a unit looks for an enemy.
const CLERIC_RANGE := 10  ## Tiles in which an engineer looks for siege units to repair.
## A defensive unit that is farther than this from its start (in straight steps) walks back.
const DEFENSIVE_RANGE := 20
const FLEE_TILES := 5  ## A fleeing unit runs this far toward the centre of the map.
const HEAL_CANDIDATES := 30
const IDLE_TURN_CHANCE := 0.04
## A unit changes its target to a new attacker that is more than this many times nearer.
const NEAR_ATTACKER_FACTOR := 2

const SUBCAT_PEASANT := 71
const SURVIVE_SUBCATS: Array[int] = [71, 72, 73, 74, 75, 76, 87, 88, 90]  # Villagers, clerics, settlers, animals, carts, pets
const FIGHTER_SUBCATS: Array[int] = [77, 78, 79, 80, 81, 82]  # Special, footmen, mounted, archers, siege, animals
const PASSIVE_SUBCATS: Array[int] = [86, 89]  # Eagles, kamikaze units
const CLERIC_MONK := 569
const CLERIC_ENGINEER := 570
## Healers that look for wounded units of their side.
const HEALERS: Array[int] = [502, 590, 866, 886]
const PASSIVE_UNITS: Array[int] = [575, 582]  # Kamikaze, boat
const SURVIVE_UNITS: Array[int] = [604, 866, 886]  # Troll drummer and two healers

var state := State.IDLE
var condition: Condition


func _init(unit: GameConfig.ItemDef) -> void:
	var subcat := unit.subcat_functional
	if unit.id == CLERIC_MONK:
		condition = Condition.AGGRESSIVE
	elif subcat in FIGHTER_SUBCATS and unit.id in PASSIVE_UNITS:
		condition = Condition.PASSIVE
	elif subcat in FIGHTER_SUBCATS and unit.id in SURVIVE_UNITS:
		condition = Condition.SURVIVE
	elif subcat in SURVIVE_SUBCATS:
		condition = Condition.SURVIVE
	elif subcat in PASSIVE_SUBCATS:
		condition = Condition.PASSIVE
	else:
		condition = Condition.AGGRESSIVE


func update(sim: BattleSim, unit: BattleFighter) -> void:
	if not unit.moving and not unit.attacking:
		_turn_now_and_then(sim, unit)
	match condition:
		Condition.DEFENSIVE:
			var away := (unit.origin - unit.tile).abs()
			if away.x + away.y > DEFENSIVE_RANGE:
				sim.set_target(unit, null)
				state = State.FORCED_MOVE
				sim.walk(unit, unit.origin)
			_look_for_enemy(sim, unit)
		Condition.AGGRESSIVE:
			_look_for_enemy(sim, unit)
	if unit.def.id in HEALERS or unit.def.id == CLERIC_ENGINEER:
		_cleric_update(sim, unit)


## attacker hit the unit.
func on_attacked(sim: BattleSim, unit: BattleFighter, attacker: BattleFighter) -> void:
	if unit.dead:
		return
	match condition:
		Condition.DEFENSIVE, Condition.AGGRESSIVE:
			if state == State.FORCED_MOVE:
				return
			if unit.target == null or unit.target.attack == 0:
				sim.attack(unit, attacker)
			elif NEAR_ATTACKER_FACTOR * sim.distance(unit, attacker) < sim.distance(unit, unit.target):
				sim.attack(unit, attacker)
		Condition.SURVIVE:
			var centre := Vector2(IsoGrid.MAP_TILES / 2, IsoGrid.MAP_TILES / 2)
			var away := centre - Vector2(unit.tile)
			if away == Vector2.ZERO:
				return
			var flee := Vector2i((Vector2(unit.tile) + away.normalized() * FLEE_TILES + Vector2(0.5, 0.5)).floor())
			sim.set_target(unit, null)
			sim.walk(unit, flee.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1)))


## An enemy attacked a unit or building of the unit's side near the unit.
func on_ally_attacked(sim: BattleSim, unit: BattleFighter, attacker: BattleFighter) -> void:
	if unit.dead or state == State.FORCED_MOVE or unit.target != null:
		return
	if condition in [Condition.DEFENSIVE, Condition.AGGRESSIVE]:
		sim.attack(unit, attacker)


## The target of the unit died at tile.
func on_target_dead(sim: BattleSim, unit: BattleFighter, tile: Vector2i) -> void:
	sim.set_target(unit, null)
	if condition != Condition.AGGRESSIVE:
		return
	var enemy: BattleFighter = sim.nearest_enemy(unit, tile, AGGRO_RANGE)
	sim.set_target(unit, enemy)
	if enemy != null and state != State.FORCED_MOVE:
		sim.attack(unit, enemy)


func on_arrived() -> void:
	if state == State.FORCED_MOVE:
		state = State.IDLE


func _look_for_enemy(sim: BattleSim, unit: BattleFighter) -> void:
	if unit.target != null or state == State.FORCED_MOVE:
		return
	var enemy: BattleFighter = sim.nearest_enemy(unit, unit.tile, AGGRO_RANGE)
	sim.set_target(unit, enemy)
	if enemy != null:
		sim.attack(unit, enemy)


## Healers and engineers choose units of their own side that need help.
func _cleric_update(sim: BattleSim, unit: BattleFighter) -> void:
	if unit.target != null:
		if unit.target.team != unit.team or (unit.target.is_unit() and unit.target.health >= unit.target.max_life()):
			sim.set_target(unit, null)
	if state == State.FORCED_MOVE:
		return
	if unit.target == null:
		var chosen: BattleFighter = null
		if unit.def.id in HEALERS:
			# The wounded unit with the least life; among equal ones the farthest.
			var wounded := sim.nearest_units(unit, unit.attack_range, HEAL_CANDIDATES, sim.needs_healing)
			for i in range(wounded.size() - 1, -1, -1):
				if chosen == null or wounded[i].health < chosen.health:
					chosen = wounded[i]
		else:
			chosen = sim.nearest_target(unit, unit.tile, CLERIC_RANGE, sim.is_wounded_siege, true)
		if chosen != null:
			sim.attack(unit, chosen)
	elif not unit.moving and not unit.attacking:
		sim.attack(unit, unit.target)


func _turn_now_and_then(sim: BattleSim, unit: BattleFighter) -> void:
	if sim.rng.randf() < IDLE_TURN_CHANCE:
		var turn := Vector2i(roundi(sim.rng.randf() * 2) - 1, roundi(sim.rng.randf() * 2) - 1)
		unit.face_point = IsoGrid.tile_to_map(unit.tile + turn)
