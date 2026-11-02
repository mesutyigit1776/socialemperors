class_name DeathWarriorAbility
extends BattleAbility
## The Death Warrior (DeathWarriorDelegate of the client).
##
## - Near the target (2 tiles or less) it hits at once; every eighth attack is
##   a mega slash instead (special attack 1, it cannot act meanwhile): at
##   frame SLASH_FRAME up to 5 units of the other side within 2 tiles of the
##   target take 0.75 times its attack and fly 4 tiles away.
## - Farther away it fires a red beam (special attack 2) at frame BEAM_FRAME,
##   when the target is within 3 times its range; the target takes 1.2 times
##   its attack when the beam ends.

const BEAM := "p.redBeam"
const SLASH_FRAME := 29
const BEAM_FRAME := 25
const SPECIAL_EVERY := 8

var _counter := 0


func _init() -> void:
	ranged_melee = true
	shot_graphic = BEAM
	beam = true
	beam_frames = 30  ## The client lets the beam last 1 second.


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if sim.distance(fighter, target) <= 2:
		if _counter == SPECIAL_EVERY:
			var last_target := target
			play(sim, fighter, UnitSprite.Action.SPECIAL, 40, {SLASH_FRAME: func() -> void: _slash(sim, fighter, last_target)}, Callable(), true)
		else:
			sim.receive_attack(target, fighter.attack, fighter)
		_counter += 1
		if _counter > SPECIAL_EVERY:
			_counter = 1
	else:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {BEAM_FRAME: func() -> void: _beam(sim, fighter)}, Callable(), true)
	return false


func _slash(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	for unit in sim.items_near(target.tile, 2, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
		if unit.ability != null and unit.ability.immune_to_push:
			continue
		sim.receive_attack(unit, int(fighter.attack * 0.75), fighter)
		sim.push_in_air(unit, fighter, 4)


func _beam(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead or sim.distance(fighter, target) > fighter.attack_range * 3:
		return
	sim.shoot(fighter, target, BEAM, int(fighter.attack * 1.2))
