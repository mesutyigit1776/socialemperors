class_name SpiderAbility
extends BattleAbility
## The Tiger Spider (SpiderDelegate of the client).
##
## - Next to its target (1 tile), every fifth attack (from the first) it turns
##   (special attack 3) and every eighth attack it blows (special attack 1):
##   at frame 19 or 13 and then every second, 3 times, up to 20 enemy units
##   within 3 tiles fly away (3 or 1 tiles) and take its attack / 2.2 or 1.3
##   times its attack. The other attacks hit at once.
## - At 2 tiles it walks to its target.
## - Farther away in its range it shoots a web (special attack 4) after 16
##   frames, a beam of 0.5 seconds. It does not choose a target that cannot
##   act. A web holds the unit it hits, which takes 1 damage every 500 ms,
##   until the web goes away after 120 frames; the spider then looks for
##   another target.

const WEB := "p.spiderWeb"
const WEB_DELAY := 16
const WEB_FRAMES := 120
const WEB_DAMAGE := 1
const WEB_TICK := 15

var _attacks := 0
var _in_special := false
var _special := 0


func _init() -> void:
	shot_graphic = WEB
	beam = true
	beam_frames = 15


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var distance := sim.distance(fighter, fighter.target)
	if distance > 1 and distance <= 2:
		sim.walk(fighter, fighter.target.tile)
		return false
	if distance <= 1:
		if _attacks % 5 == 0:
			_whirl(sim, fighter, UnitSprite.Action.SPECIAL + 2, 19, 3, fighter.attack / 2.2)
		elif _attacks % 8 == 0:
			_whirl(sim, fighter, UnitSprite.Action.SPECIAL, 13, 1, fighter.attack * 1.3)
		else:
			sim.receive_attack(fighter.target, fighter.attack, fighter)
		_attacks += 1
		return false
	if fighter.target.is_unit() and fighter.target.incapacitated:
		var other := sim.nearest_target(fighter, fighter.tile, fighter.attack_range, func(item: BattleFighter) -> bool: return not item.incapacitated, false)
		sim.set_target(fighter, other)
		if other == null:
			return false
	_in_special = true
	_special += 1
	var id := _special
	sim.play_special(fighter, UnitSprite.Action.SPECIAL + 3, 1 << 20)
	var target := fighter.target
	sim.after(WEB_DELAY, func() -> void:
		if id != _special or fighter.dead or target.dead:
			_end(sim, fighter, id)
			return
		sim.shoot(fighter, target, WEB, fighter.attack, func(_shot: BattleProjectile) -> void:
			_end(sim, fighter, id)
			if target.is_unit() and not target.dead:
				_web(sim, fighter, target)
				sim.set_target(fighter, null)))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_end(sim, fighter, _special)


func _whirl(sim: BattleSim, fighter: BattleFighter, action: int, frame: int, push: int, damage: float) -> void:
	_in_special = true
	_special += 1
	var id := _special
	sim.play_special(fighter, action, 1 << 20)
	for i in 3:
		sim.after(frame + i * BattleSim.FRAMES_PER_SECOND, func() -> void:
			if id != _special or fighter.dead:
				return
			for unit in enemy_units_near(sim, fighter, fighter.tile, 3, 20):
				sim.push_in_air(unit, fighter, push)
				sim.receive_attack(unit, int(damage), fighter)
				GodzillaAbility._take_target(sim, fighter, unit))
	sim.after(frame + 3 * BattleSim.FRAMES_PER_SECOND, func() -> void: _end(sim, fighter, id))


func _end(sim: BattleSim, fighter: BattleFighter, id: int) -> void:
	if id != _special:
		return
	_special += 1
	_in_special = false
	sim.stop_special(fighter)


func _web(sim: BattleSim, fighter: BattleFighter, unit: BattleFighter) -> void:
	sim.particle(fighter, unit.tile, MagicParticles.SPIDERWEB, 0, 0)
	unit.incapacitated = true
	unit.walk_point = null
	unit.path.clear()
	unit.moving = false
	for i in range(1, WEB_FRAMES / WEB_TICK + 1):
		sim.after(i * WEB_TICK, func() -> void:
			if not unit.dead:
				sim.receive_attack(unit, WEB_DAMAGE, fighter if fighter in sim.fighters else null))
	sim.after(WEB_FRAMES, func() -> void:
		unit.incapacitated = unit.frozen or unit.stunned or unit.in_air or unit.electrocuted)
