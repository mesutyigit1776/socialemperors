class_name HalloweenUnitsAbility
extends BattleAbility
## The Halloween units whose delegates change the normal attack.
##
## - frankenstein (FrankensteinDelegate) and pumpkin (PumpkinMonsterDelegate):
##   next to the target (1 tile) they hit, and the target unit is stunned one
##   time in two. Farther away in range they start a rain of screws (pumpkins
##   for the Pumpkin Monster): every 750 ms, 6 times, the 10 nearest enemies
##   within the range + 2 tiles take 5 points. The rain stops when no enemy is
##   in that area, when the target comes next to it or leaves the range, and
##   when it walks.
## - witch (WitchDelegate): a shot 11 frames after the attack. 5 seconds after
##   its first attack, the next attack is a beam (8 frames) that does no
##   damage and turns a target unit into a frog for 120 frames: the unit
##   cannot act and nobody can attack it. Then the 5 seconds start again.

const UNITS := {
	732: "frankenstein",
	746: "pumpkin",
	731: "witch",
}
const SP1 := UnitSprite.Action.SPECIAL
const SCREW_INTERVAL := 22  ## 750 ms.
const SCREWS := 6
const SCREW_DAMAGE := 5
const SCREW_COUNT := 10
const WITCH_SPECIAL_FRAMES := 150  ## 5 seconds.
const FROG_FRAMES := 120

var _kind := ""
var _raining := false
var _rain := 0  # Counts the rains, so that an old rain stops.
var _witch_ready_frame := -1  # The frame from which the next attack is the frog beam.
var _frogged: BattleFighter


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	if _kind == "witch":
		shot_delay = 11


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var distance := sim.distance(fighter, target)
	match _kind:
		"frankenstein", "pumpkin":
			if _raining and (distance <= 1 or distance > fighter.attack_range):
				_stop_rain(sim, fighter)
			if _raining:
				return false
			if distance <= 1:
				sim.receive_attack(target, fighter.attack, fighter)
				if target.is_unit() and not target.dead and sim.rng.randi_range(1, 2) == 1:
					sim.stun(target)
			elif distance <= fighter.attack_range:
				_start_rain(sim, fighter)
			return false
		"witch":
			if _witch_ready_frame < 0:
				_witch_ready_frame = sim.frame + WITCH_SPECIAL_FRAMES
			if sim.frame < _witch_ready_frame:
				return true
			_witch_ready_frame = -1
			sim.play_special(fighter, SP1, 8 + 15, {8: func() -> void: _frog_beam(sim, fighter, target)}, Callable(), true)
			return false
	return true


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _raining and fighter.moving:
		_stop_rain(sim, fighter)


func _start_rain(sim: BattleSim, fighter: BattleFighter) -> void:
	_raining = true
	_rain += 1
	var rain := _rain
	sim.play_special(fighter, SP1, SCREWS * SCREW_INTERVAL + 1)
	for i in range(1, SCREWS + 1):
		sim.after(i * SCREW_INTERVAL, func() -> void:
			if rain != _rain or not _raining or fighter.dead:
				return
			var enemies := sim.items_near(fighter.tile, fighter.attack_range + 2, SCREW_COUNT, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return not item.dead and item.is_valid_target())
			if enemies.is_empty():
				_stop_rain(sim, fighter)
				return
			var graphic := MagicParticles.MAGMA if _kind == "pumpkin" else MagicParticles.SCREW
			for n in enemies.size():
				var enemy: BattleFighter = enemies[n]
				sim.receive_attack(enemy, SCREW_DAMAGE, fighter)
				var tile := enemy.tile
				sim.after(n * 5 + 1, func() -> void: SpecialUnit.show_particle(sim, fighter, tile, graphic))
			if i == SCREWS:
				_stop_rain(sim, fighter))


func _stop_rain(sim: BattleSim, fighter: BattleFighter) -> void:
	_raining = false
	_rain += 1
	sim.stop_special(fighter)


func _frog_beam(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	# The client fires a beam without a graphic (the delegate has no shot).
	if fighter.dead or target.dead:
		return
	if not target.is_unit() or _frogged != null:
		return
	var frog := target
	_frogged = frog
	SpecialUnit.show_particle(sim, fighter, frog.tile, MagicParticles.FROG)
	frog.incapacitated = true
	frog.invisible = true
	frog.swallowed = true
	sim.state_changed.emit(frog)
	sim.set_target(fighter, null)
	sim.after(FROG_FRAMES, func() -> void:
		_frogged = null
		if frog.dead:
			return
		frog.invisible = false
		frog.swallowed = false
		frog.incapacitated = frog.frozen or frog.stunned or frog.in_air
		sim.state_changed.emit(frog))
