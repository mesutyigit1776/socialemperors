class_name DragonBossAI
extends ThreatAI
## The AI of the dragon boss of the first dragon island (IADragon of the client).
##
## - Phase 1: the dragon fights by threat (ThreatAI). PHASE_1_FRAMES after the
##   fight starts, and again after each phase 3, phase 2 begins.
## - Phase 2: the dragon flies to one of the BOMB_COLUMNS at the top or the
##   bottom row of the arena and crosses it to the other side. On each tile on
##   the way it burns the tiles from 2 left to 2 right of it: a unit of the
##   player there dies. It crosses difficulty times (the stars), then flies to
##   a random free tile of the arena.
## - Phase 3: the dragon stays there and throws difficulty * 2 eggs, one every
##   EGG_FRAMES, in turning directions. Each egg becomes a summoned Draggy that
##   attacks the target of the dragon. Then phase 1 begins again.

const DRAGON_BOSS := 657
const DRAGGY := 638
const PHASE_1_FRAMES := 600  ## 20 seconds.
const EGG_FRAMES := 15  ## 500 ms.
const EGGS_PER_STAR := 2
const BOMB_COLUMNS: Array[int] = [42, 47, 52, 57]
const TOP_ROW := 20
const BOTTOM_ROW := 59
const FIRE_HALF_WIDTH := 2
const FIRE_DAMAGE := 10000
const ARENA := Rect2i(40, 20, 19, 39)  ## The random tiles of phase 3: x 40 to 58, y 20 to 58.
const FIRE_ACTION := UnitSprite.Action.SPECIAL + 2  ## The animation while it burns: special attack 3.
const EGG_GRAPHIC := "p.egg"
## The client turns the direction of the eggs by a quarter: up-right,
## down-right, up-left, down-left (its directions 2, 4, 6 and 8).
const EGG_STEPS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(-1, 1)]

var difficulty := 1
var _attacks_left := 0
var _bombing := false
var _goal := Vector2i.ZERO
var _arrival := Callable()
var _timer := 0  # Counts the phase timers, so that an old timer does nothing.
var _direction := 0  # Index in EGG_STEPS.


func _init(unit: GameConfig.ItemDef) -> void:
	super(unit)
	condition = Condition.DEFENSIVE


func update(sim: BattleSim, unit: BattleFighter) -> void:
	super(sim, unit)
	if unit.dead:
		quest_end()
		return
	if phase == 1:
		if not unit.moving and not unit.attacking:
			state = State.IDLE
		attack_threatening_target(sim, unit)


func quest_end() -> void:
	_timer += 1


func on_enter_tile(sim: BattleSim, unit: BattleFighter) -> void:
	if _bombing:
		_burn(sim, unit)


func on_arrived(sim: BattleSim, unit: BattleFighter) -> void:
	super(sim, unit)
	if _arrival.is_valid():
		var action := _arrival
		_arrival = Callable()
		action.call(sim, unit)


func _attack_started(sim: BattleSim, unit: BattleFighter) -> void:
	_start_phase_1(sim, unit)


func _switch_to(sim: BattleSim, unit: BattleFighter, next: int) -> void:
	# The end of the current phase.
	_timer += 1
	_bombing = false
	_arrival = Callable()
	unit.incapacitated = unit.frozen or unit.stunned or unit.in_air
	sim.stop_special(unit)
	phase = next
	match next:
		1:
			_start_phase_1(sim, unit)
		2:
			_start_phase_2(sim, unit)
		3:
			_start_phase_3(sim, unit)


func _start_phase_1(sim: BattleSim, unit: BattleFighter) -> void:
	state = State.IDLE
	condition = Condition.AGGRESSIVE
	var timer := _timer
	sim.after(PHASE_1_FRAMES, func() -> void:
		if timer == _timer and not unit.dead:
			_switch_to(sim, unit, 2))


func _start_phase_2(sim: BattleSim, unit: BattleFighter) -> void:
	_attacks_left = difficulty
	sim.set_target(unit, null)
	unit.attacking = false
	reset_threat()
	state = State.FORCED_MOVE
	condition = Condition.PASSIVE
	_fly_to_start(sim, unit)


func _fly_to_start(sim: BattleSim, unit: BattleFighter) -> void:
	var start := unit.tile
	while start == unit.tile:
		start = Vector2i(BOMB_COLUMNS[sim.rng.randi_range(0, BOMB_COLUMNS.size() - 1)], TOP_ROW if sim.rng.randf() < 0.5 else BOTTOM_ROW)
	_arrival = _start_bombing
	if not sim.walk(unit, start):
		_arrival = Callable()


func _start_bombing(sim: BattleSim, unit: BattleFighter) -> void:
	var goal := Vector2i(unit.tile.x, BOTTOM_ROW if unit.tile.y < 50 else TOP_ROW)
	_bombing = true
	sim.play_special(unit, FIRE_ACTION, 1 << 20)
	_burn(sim, unit)
	_arrival = _end_bombing
	sim.walk(unit, goal)


func _burn(sim: BattleSim, unit: BattleFighter) -> void:
	for x in range(unit.tile.x - FIRE_HALF_WIDTH, unit.tile.x + FIRE_HALF_WIDTH + 1):
		sim.particle(unit, Vector2i(x, unit.tile.y), MagicParticles.FIRE_RED, FIRE_DAMAGE, 0, func(_attacker: BattleFighter, target: BattleFighter, _value: int) -> void:
			if target != null:
				sim.kill(target))


func _end_bombing(sim: BattleSim, unit: BattleFighter) -> void:
	_bombing = false
	sim.stop_special(unit)
	_attacks_left -= 1
	if _attacks_left > 0:
		_fly_to_start(sim, unit)
		return
	var tile := unit.tile
	for i in 100:
		tile = ARENA.position + Vector2i(sim.rng.randi_range(0, ARENA.size.x - 1), sim.rng.randi_range(0, ARENA.size.y - 1))
		if sim.is_free(tile):
			break
	_arrival = func(s: BattleSim, u: BattleFighter) -> void: _switch_to(s, u, 3)
	if not sim.walk(unit, tile):
		_switch_to(sim, unit, 3)


func _start_phase_3(sim: BattleSim, unit: BattleFighter) -> void:
	unit.incapacitated = true
	_direction = 0
	var timer := _timer
	for i in difficulty * EGGS_PER_STAR:
		sim.after(EGG_FRAMES * (i + 1), func() -> void:
			if timer == _timer and not unit.dead:
				_throw_egg(sim, unit))
	sim.after(EGG_FRAMES * difficulty * EGGS_PER_STAR + 1, func() -> void:
		if timer == _timer and not unit.dead:
			_switch_to(sim, unit, 1))


## Throws an egg 2 to 4 tiles away in the current direction; the directions
## turn by a quarter after each egg.
func _throw_egg(sim: BattleSim, unit: BattleFighter) -> void:
	var step := EGG_STEPS[_direction]
	var tile := (unit.tile + Vector2i(step.x * sim.rng.randi_range(2, 3), step.y * sim.rng.randi_range(2, 3))).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
	var team := unit.team
	sim.shoot_at(unit, tile, EGG_GRAPHIC, func(_shot: BattleProjectile) -> void:
		var draggy := sim.spawn(sim.config_item(DRAGGY), tile, team)
		if draggy != null and unit.target != null and not unit.target.dead:
			sim.attack(draggy, unit.target))
	_direction = (_direction + 1) % EGG_STEPS.size()
