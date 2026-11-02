class_name VulcanoGolemAbility
extends BattleAbility
## The Volcano Golem (VulcanoGolemDelegate of the client). Its normal attack
## throws a fire ball 500 ms after the attack starts.
##
## Within 3 tiles of its target it counts its attacks from 1 to 8:
## - Attack 4 (special attack 1): at frames 15, 20, 25 and 30 it smashes the
##   ground 2 tiles in front of it: up to 5 enemy units within 2 tiles of that
##   tile take its attack and fly 3 tiles away. Units that cannot fly take no
##   damage.
## - Attack 8 (special attack 2): at frames 15, 25, 35 and 45, up to 5 enemy
##   units within 3 tiles of it that do not burn take its attack and burn (5
##   damage every second, 5 times).
## - The other attacks are normal.

const FIREBALL := "p.catapultFireball"
const FIREBALL_DELAY := 15
const ATTACK_FREQUENCY := 4
## The client uses these steps for the tile in front of it, by direction.
const FRONT := {1: Vector2i(0, -1), 2: Vector2i(1, -1), 3: Vector2i(1, -1), 4: Vector2i(1, 1), 5: Vector2i(0, 1), 6: Vector2i(-1, -1), 7: Vector2i(-1, 0), 8: Vector2i(-1, 1)}

var _attacks := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if busy:
		return false
	if sim.distance(fighter, fighter.target) <= 3:
		if _attacks == ATTACK_FREQUENCY:
			var events := {}
			for frame in [15, 20, 25, 30]:
				events[frame] = func() -> void: _smash(sim, fighter)
			play(sim, fighter, UnitSprite.Action.SPECIAL, 35, events)
		elif _attacks == ATTACK_FREQUENCY * 2:
			var events := {}
			for frame in [15, 25, 35, 45]:
				events[frame] = func() -> void: _flames(sim, fighter)
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 50, events)
		else:
			_throw(sim, fighter)
		_attacks = _attacks % (ATTACK_FREQUENCY * 2) + 1
	else:
		_throw(sim, fighter)
	return false


func _throw(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	sim.after(FIREBALL_DELAY, func() -> void:
		if not fighter.dead and not busy and fighter.target == target and not target.dead:
			sim.shoot(fighter, target, FIREBALL, fighter.attack))


func _smash(sim: BattleSim, fighter: BattleFighter) -> void:
	var tile: Vector2i = fighter.tile + FRONT[direction(fighter)] * 2
	for unit in enemy_units_near(sim, fighter, tile, 2, 5):
		if unit.def.subcat_functional == BattleSim.SUBCAT_BOSS or (unit.ability != null and unit.ability.immune_to_push):
			continue
		sim.receive_attack(unit, fighter.attack, fighter)
		sim.push_in_air(unit, fighter, 3)


func _flames(sim: BattleSim, fighter: BattleFighter) -> void:
	for unit in enemy_units_near(sim, fighter, fighter.tile, 3, 5):
		if unit.burning or (unit.ability != null and unit.ability.immune_to_burn):
			continue
		sim.receive_attack(unit, fighter.attack, fighter)
		sim.incinerate(unit, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND)
