class_name NecroAbominationAbility
extends NecroAbility
## The Necro Abomination (NecroAbominationDelegate of the client). Its attacks
## play an animation and hit at a frame of it:
## - every ninth attack a jump (special attack 2, it cannot act) at frame 21:
##   up to 20 enemy units within 4 tiles fly 5 tiles away and take its attack / 2.2;
## - else every fourth attack a sword blow (special attack 1) at frame 20 on
##   2 tiles in front of it: the enemy units within 1 tile of them fly 3 tiles
##   away and take 1.5 times its attack;
## - else a normal hit at frame 7.
## When it walks, the attack stops.

var _attacks := 0


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _attacks % 9 == 0 and _attacks > 0:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 35, {21: func() -> void:
			for unit in enemy_units_near(sim, fighter, fighter.tile, 4, 20):
				sim.push_in_air(unit, fighter, 5)
				sim.receive_attack(unit, int(fighter.attack / 2.2), fighter)}, Callable(), true)
	elif _attacks % 4 == 0 and _attacks > 0:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {20: func() -> void: _sword(sim, fighter)})
	else:
		play(sim, fighter, UnitSprite.Action.ATTACKING, 15, {7: func() -> void:
			if fighter.target != null and not fighter.target.dead:
				sim.receive_attack(fighter.target, fighter.attack, fighter)})
	_attacks += 1
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if busy and fighter.moving:
		sim.stop_special(fighter)


func _sword(sim: BattleSim, fighter: BattleFighter) -> void:
	var line: Array = GodzillaAbility.FIRE_LINES[direction(fighter)]
	var tile := fighter.tile
	var hit: Array[BattleFighter] = []
	for i in 2:
		hit.append_array(enemy_units_near(sim, fighter, tile, 1, 30))
		tile += line[1]
	for unit in hit:
		if unit.dead:
			continue
		sim.push_in_air(unit, fighter, 3)
		sim.receive_attack(unit, int(fighter.attack * 1.5), fighter)
		GodzillaAbility._take_target(sim, fighter, unit)
