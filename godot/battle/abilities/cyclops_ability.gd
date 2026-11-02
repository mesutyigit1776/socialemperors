class_name CyclopsAbility
extends BattleAbility
## The Cyclops (CiclopeDelegate of the client).
##
## - Next to the target, it spins in 40 of 100 attacks (special attack 3): at
##   frame SPIN_FRAME a whirlwind (BattleSim.whirlwind()); at frame END_FRAME it
##   ends. The other attacks hit at once.
## - Farther away in its range it fires its eye laser (special attack 1), a
##   beam after LASER_DELAY frames, and stays LASER_FRAMES in the attack.
## - Out of range it walks to the target.

const LASER := "p.laser"
const LASER_DELAY := 5
const LASER_FRAMES := 21  ## 700 ms.
const SPIN_FRAME := 9
const END_FRAME := 26

var _in_special := false
var _attack_id := 0


func _init() -> void:
	shot_graphic = LASER
	beam = true
	beam_frames = 21  ## The client lets the laser last 0.7 seconds.


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	_attack_id += 1
	var id := _attack_id
	var target := fighter.target
	var distance := sim.distance(fighter, target)
	if distance <= 1:
		if sim.rng.randf() > 0.6:
			_in_special = true
			sim.play_special(fighter, UnitSprite.Action.SPECIAL + 2, END_FRAME, {SPIN_FRAME: func() -> void: sim.whirlwind(fighter)}, func() -> void: _in_special = false)
		else:
			sim.receive_attack(target, fighter.attack, fighter)
		return false
	if distance <= fighter.attack_range:
		_in_special = true
		sim.play_special(fighter, UnitSprite.Action.SPECIAL, LASER_FRAMES, {}, func() -> void: _in_special = false)
		sim.after(LASER_DELAY, func() -> void:
			if id == _attack_id and not fighter.dead and fighter.target == target and not target.dead:
				sim.shoot(fighter, target, LASER, fighter.attack))
		return false
	sim.walk(fighter, target.tile)
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_attack_id += 1
		_in_special = false
		sim.stop_special(fighter)
