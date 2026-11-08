class_name RockdrillerAI
extends ThreatAI
## The AI of the Rockdriller boss (IARockdriller of the client).
##
## - The boss starts with INIT_LIFE life, attack and attack interval, and
##   attacks by threat (ThreatAI). It does not walk while it fights.
## - Every PHASE_FRAMES after the fight starts, it changes phase. In phase 2 it
##   digs into the ground: the units that attack it lose it as target, it does
##   not fight, it walks to random tiles near the centre, and a Sanddriller
##   comes out next to it. In phase 1 it fights again where it is.
## - ENRAGE_FRAMES after the fight starts, it stays in phase 1 and attacks much
##   faster and harder.
## - When its target is out of its range in phase 1, the fight starts again:
##   the boss gets its full life, the Sanddrillers leave, and it walks back to
##   the centre.
## - Its shots leave slime on the tile of the target for SLIME_FRAMES. A
##   Sanddriller on slime dies.

const ROCKDRILLER_BOSS := 566
const SANDDRILLER := 567
const INIT_LIFE := 25000
const INIT_ATTACK := 22
const INIT_ATTACK_INTERVAL := 20
const ENRAGED_ATTACK := 100
const ENRAGED_ATTACK_INTERVAL := 5
const ENRAGE_FRAMES := 9000  ## 300 seconds.
const PHASE_FRAMES := 450  ## 15 seconds.
const DIG_SPEED := 12
const CENTRE := Vector2i(49, 49)
const PHASE_2_AREA := Rect2i(40, 40, 20, 20)
const SLIME_FRAMES := 1200

var _fight := 0  # Counts the fights, so that the timers of an old fight do nothing.
var _sanddrillers: Array[BattleFighter] = []
var _slime := {}  # Tile -> the frame at which its slime goes away.


func _init(unit: GameConfig.ItemDef) -> void:
	super(unit)
	condition = Condition.DEFENSIVE


func on_added(_sim: BattleSim, unit: BattleFighter) -> void:
	unit.max_health = INIT_LIFE
	unit.health = INIT_LIFE
	unit.attack = INIT_ATTACK
	unit.attack_interval = INIT_ATTACK_INTERVAL


func update(sim: BattleSim, unit: BattleFighter) -> void:
	super(sim, unit)
	if unit.dead:
		quest_end()
		return
	if phase == 1:
		if not unit.moving and not unit.attacking:
			state = State.IDLE
		attack_threatening_target(sim, unit)
		if unit.target != null and sim.distance(unit, unit.target) > unit.attack_range:
			_reset_fight(sim, unit)
	elif not unit.moving:
		sim.walk(unit, PHASE_2_AREA.position + Vector2i(sim.rng.randi_range(0, PHASE_2_AREA.size.x - 1), sim.rng.randi_range(0, PHASE_2_AREA.size.y - 1)))


func on_target_dead(sim: BattleSim, unit: BattleFighter, tile: Vector2i) -> void:
	super(sim, unit, tile)


func quest_end() -> void:
	_fight += 1


## The tile has slime of the boss now.
func has_slime(sim: BattleSim, tile: Vector2i) -> bool:
	return _slime.get(tile, -1) > sim.frame


## A shot of the boss hit target.
func on_shot_hit(sim: BattleSim, _unit: BattleFighter, target: BattleFighter) -> void:
	if not has_slime(sim, target.tile):
		_slime[target.tile] = sim.frame + SLIME_FRAMES
		sim.particle(null, target.tile, MagicParticles.SLIME, 0, 0)


func _attack_started(sim: BattleSim, unit: BattleFighter) -> void:
	sim.set_speed(unit, 0)
	var fight := _fight
	sim.after(ENRAGE_FRAMES, func() -> void:
		if fight == _fight and not unit.dead:
			_enrage(sim, unit))
	_schedule_phase(sim, unit, fight)


func _schedule_phase(sim: BattleSim, unit: BattleFighter, fight: int) -> void:
	sim.after(PHASE_FRAMES, func() -> void:
		if fight != _fight or unit.dead:
			return
		_change_phase(sim, unit)
		_schedule_phase(sim, unit, fight))


func _change_phase(sim: BattleSim, unit: BattleFighter) -> void:
	if phase == 1:
		phase = 2
		sim.set_target(unit, null)
		for other in unit.targeted_by.duplicate():
			sim.set_target(other, null)
		reset_threat()
		state = State.FORCED_MOVE
		condition = Condition.PASSIVE
		sim.set_speed(unit, DIG_SPEED)
		unit.attacking = false
		var driller := sim.spawn(sim.config_item(SANDDRILLER), unit.tile, unit.team, false)
		if driller != null:
			_sanddrillers.append(driller)
			if driller.ai is SanddrillerAI:
				driller.ai.boss = self
	else:
		phase = 1
		sim.sound_played.emit(SoundEffect.ROCKDRILLER, -1)  # It comes out of the ground.
		state = State.IDLE
		condition = Condition.AGGRESSIVE
		sim.set_speed(unit, 0)


func _enrage(sim: BattleSim, unit: BattleFighter) -> void:
	phase = 1
	sim.set_speed(unit, 0)
	_fight += 1  # The phases stop.
	unit.attack_interval = ENRAGED_ATTACK_INTERVAL
	unit.attack = ENRAGED_ATTACK
	sim.state_changed.emit(unit)


func _reset_fight(sim: BattleSim, unit: BattleFighter) -> void:
	phase = 1
	reset_threat()
	started = false
	unit.max_health = INIT_LIFE
	unit.health = INIT_LIFE
	for driller in _sanddrillers:
		if not driller.dead:
			sim.remove_item(driller)
	_sanddrillers.clear()
	quest_end()
	unit.attack_interval = INIT_ATTACK_INTERVAL
	unit.attack = INIT_ATTACK
	state = State.FORCED_MOVE
	sim.set_target(unit, null)
	sim.set_speed(unit, DIG_SPEED)
	sim.walk(unit, CENTRE)
	sim.state_changed.emit(unit)
