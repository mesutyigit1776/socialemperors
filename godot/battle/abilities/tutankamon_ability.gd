class_name TutankamonAbility
extends BattleAbility
## Tutankamon (TutankamonDelegate of the client). Its normal attack is an
## electric beam after 13 frames, which lasts 0.5 seconds.
##
## - Next to its target (2 tiles or less), each fifth attack (special attack 1)
##   hits around it at frames 55, 60, 65 and 70: up to 10 enemies within 2
##   tiles take half its attack; units fly 4 tiles away and burn when they
##   land (5 damage every second, 5 times). The client stops a hit at the
##   first unit that cannot act; the port does the same.
## - Farther away, each sixth attack (special attack 2) throws an energy ball
##   every 200 ms for 3 seconds from frame 41. Each ball that lands on the
##   target takes half the attack of Tutankamon.

const BEAM := "p.electricityBeam"
const BALL := "p.energyBall"
const CIRCLE_FRAMES: Array[int] = [55, 60, 65, 70]
const BALLS_FRAME := 41
const BALL_INTERVAL := 6  ## 200 ms.
const BALLS_FRAMES := 90  ## 3 seconds.

var _short_attacks := 1
var _long_attacks := 1
var _in_special := false


func _init() -> void:
	shot_graphic = BEAM
	shot_delay = 13
	beam = true
	beam_frames = 15


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special or busy:
		return false
	var normal := true
	if sim.distance(fighter, fighter.target) <= 2:
		if _short_attacks == 5:
			normal = false
			_in_special = true
			var events := {}
			for frame in CIRCLE_FRAMES:
				events[frame] = func() -> void: _circle(sim, fighter)
			play(sim, fighter, UnitSprite.Action.SPECIAL, CIRCLE_FRAMES[-1] + 5, events, _end)
		_short_attacks = _short_attacks % 5 + 1
	else:
		if _long_attacks == 6:
			normal = false
			_in_special = true
			var events := {}
			for frame in range(BALLS_FRAME, BALLS_FRAME + BALLS_FRAMES, BALL_INTERVAL):
				events[frame] = func() -> void: _ball(sim, fighter)
			sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, BALLS_FRAME + BALLS_FRAMES, events, _end)
		_long_attacks = _long_attacks % 6 + 1
	return normal


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_in_special = false
		sim.stop_special(fighter)


func _end() -> void:
	_in_special = false


func _circle(sim: BattleSim, fighter: BattleFighter) -> void:
	for item in enemies_near(sim, fighter, fighter.tile, 2, 10):
		if item.is_unit() and item.incapacitated:
			return
		sim.receive_attack(item, fighter.attack / 2, fighter)
		if item.is_unit():
			sim.push_in_air(item, fighter, 4)
			sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void: sim.incinerate(item, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND))


func _ball(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.target == null or fighter.target.dead:
		return
	sim.shoot(fighter, fighter.target, BALL, fighter.attack / 2)
