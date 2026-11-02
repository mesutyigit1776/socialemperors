class_name ThreatAI
extends BattleAI
## The AI of the bosses that fight by threat (IAWithAgro of the client): the
## boss keeps a list of the units that attacked it, with the damage that each
## did (the threat), and attacks the unit with the most threat. Damage by its
## current target counts AGGRO_FOCUS_MULTIPLIER times. Before the fight
## starts, the boss attacks only enemies within START_RANGE tiles; after that,
## enemies anywhere on the map.
##
## The client never takes a unit out of the list (its removal removes
## nothing); a dead unit leaves the list when the boss looks for its next target.

const AGGRO_FOCUS_MULTIPLIER := 1.5
const START_RANGE := 3

var phase := 1
var started := false
var _threat: Array[Array] = []  # [unit, threat], the most threat first.


## The client updates the base AI first, with the default condition.
func update(sim: BattleSim, unit: BattleFighter) -> void:
	super(sim, unit)


func on_attacked(_sim: BattleSim, unit: BattleFighter, attacker: BattleFighter, damage := 0) -> void:
	if not unit.dead:
		add_threat(attacker, damage)


func on_ally_attacked(_sim: BattleSim, _unit: BattleFighter, _attacker: BattleFighter) -> void:
	pass


func on_target_dead(sim: BattleSim, unit: BattleFighter, _tile: Vector2i) -> void:
	sim.set_target(unit, null)
	var next := next_target()
	if next != null:
		sim.attack(unit, next)


func add_threat(attacker: BattleFighter, damage: int) -> void:
	for i in _threat.size():
		if _threat[i][0] == attacker:
			_threat[i][1] += damage * (AGGRO_FOCUS_MULTIPLIER if i == 0 else 1.0)
			_sort()
			return
	_threat.append([attacker, float(damage)])
	_sort()


func reset_threat() -> void:
	_threat.clear()


## The living unit with the most threat, or null.
func next_target() -> BattleFighter:
	while not _threat.is_empty():
		var unit: BattleFighter = _threat[0][0]
		if not unit.dead:
			return unit
		_threat.pop_front()
	return null


## Attacks the unit with the most threat, or a new enemy when the list is empty.
func attack_threatening_target(sim: BattleSim, unit: BattleFighter) -> void:
	if state == State.FORCED_MOVE:
		return
	if _threat.is_empty():
		var enemy := sim.nearest_enemy(unit, unit.tile, START_RANGE if not started else IsoGrid.MAP_TILES)
		sim.set_target(unit, enemy)
		if enemy != null:
			add_threat(enemy, 0)
	else:
		sim.set_target(unit, next_target())
	if unit.target != null:
		sim.attack(unit, unit.target)
		if not started:
			set_started(sim, unit, true)


func set_started(sim: BattleSim, unit: BattleFighter, value: bool) -> void:
	if started == value:
		return
	started = value
	if value:
		_attack_started(sim, unit)


## Called when the fight starts.
func _attack_started(_sim: BattleSim, _unit: BattleFighter) -> void:
	pass


## Called when the quest ends; the boss stops its timers.
func quest_end() -> void:
	pass


func _sort() -> void:
	_threat.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
