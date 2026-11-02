class_name TitanHydrosAbility
extends BattleAbility
## Titan Hydros (TitanHydrosDelegate of the client).
##
## - Next to its target (1 tile) it hits at once.
## - Farther away in its range, its attacks go in turn (the first attack has
##   number 0):
##   - Each fifth attack (special attack 2): 6 water balls, two in each loop
##     of the animation, at frames 2 and 8.
##   - Each eighth attack, when it has no hurricanes (special attack 3): at
##     frame 13, 3 hurricanes come near it for 20 seconds. The client puts
##     them on the side of the player, also when the titan is an enemy; the
##     port does the same.
##   - The other attacks (special attack 1): a freeze beam after 35 frames.
##     When the beam starts, the target freezes and takes half the attack of
##     the titan every second, 5 times. The beam lasts 1 second.
## - When it walks, the attack stops.

const BALL := "p.ballTitanHydros"
const BEAM := "p.freezeBeam"
const BEAM_DELAY := 35
const BEAM_FRAMES := 30
const BALLS := 6
const BALL_FRAMES: Array[int] = [2, 8]
const HURRICANE := 728  ## ID_UNIT_HURRICANE_WATER_WIZARD
const HURRICANES := 3
const HURRICANE_FRAME := 13
const HURRICANE_LIFE_FRAMES := 600  ## 20 seconds.

var _attacks := 0
var _in_special := false
var _attack_id := 0
var _hurricanes: Array[BattleFighter] = []


func _init() -> void:
	# The freeze beam is the only shot with this graphic; beam is true only
	# while it leaves, so the water balls are normal shots.
	shot_graphic = BEAM


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var target := fighter.target
	var distance := sim.distance(fighter, target)
	if distance <= 1:
		sim.receive_attack(target, fighter.attack, fighter)
		return false
	if distance > fighter.attack_range:
		return false
	_attack_id += 1
	var id := _attack_id
	if _attacks % 5 == 0:
		_in_special = true
		var loop := sim.animation_frames(fighter, UnitSprite.Action.SPECIAL + 1, 20)
		var events := {}
		for i in BALLS:
			events[(i / 2) * loop + BALL_FRAMES[i % 2]] = func() -> void:
				if fighter.target != null and not fighter.target.dead:
					sim.shoot(fighter, fighter.target, BALL, fighter.attack)
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, (BALLS / 2 - 1) * loop + BALL_FRAMES[1], events, _end)
	elif _attacks % 8 == 0 and _hurricanes.is_empty():
		_in_special = true
		play(sim, fighter, UnitSprite.Action.SPECIAL + 2, 30, {HURRICANE_FRAME: func() -> void: _spawn_hurricanes(sim, fighter)}, _end)
	else:
		if fighter.moving:
			return false
		_in_special = true
		sim.play_special(fighter, UnitSprite.Action.SPECIAL, BEAM_DELAY + BEAM_FRAMES, {}, _end)
		sim.after(BEAM_DELAY, func() -> void:
			if id != _attack_id or fighter.dead or fighter.target != target or target.dead:
				return
			beam = true
			beam_frames = BEAM_FRAMES
			sim.shoot(fighter, target, BEAM, fighter.attack)
			beam = false
			if target.is_unit():
				sim.freeze_with_damage(target, fighter, fighter.attack / 2, 5, BattleSim.FRAMES_PER_SECOND))
	_attacks += 1
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_attack_id += 1
		_in_special = false
		sim.stop_special(fighter)


func _end() -> void:
	_in_special = false


func _spawn_hurricanes(sim: BattleSim, fighter: BattleFighter) -> void:
	for i in HURRICANES:
		var unit := sim.spawn(sim.config_item(HURRICANE), fighter.tile, BattleFighter.Team.PLAYER)
		if unit != null:
			_hurricanes.append(unit)
	if _hurricanes.is_empty():
		return
	sim.after(HURRICANE_LIFE_FRAMES, func() -> void:
		for unit in _hurricanes:
			if not unit.dead:
				sim.remove_item(unit)
		_hurricanes.clear())
