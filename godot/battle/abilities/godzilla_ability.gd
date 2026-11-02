class_name GodzillaAbility
extends BattleAbility
## Godzilla (GodzillaDelegate of the client).
##
## - Next to its target (2 tiles or less) it stomps at frame 17 of its attack:
##   up to 10 enemy units within 3 tiles take half its attack and fly 2 tiles
##   away. Every eighth attack is a big stomp (special attack 1): up to 30
##   enemy units within 10 tiles take 1.2 times its attack and fly 6 tiles away.
## - Farther away in its range it breathes fire (special attack 2) at frame 19
##   along a line of 5 or 8 tiles in its direction: the enemy units within 1
##   tile of each tile of the line take its attack and burn (8 damage every
##   second, 3 times); a unit near two tiles of the line is hit twice.
## - It takes the first unit it hits as target when it has none. When it
##   walks, the attack stops.

## Direction -> [tiles of the fire line, step]. The client uses these lines.
const FIRE_LINES := {
	1: [5, Vector2i(-1, -1)], 2: [8, Vector2i(0, -1)], 6: [8, Vector2i(-1, 0)], 3: [5, Vector2i(1, -1)],
	7: [5, Vector2i(-1, 1)], 4: [8, Vector2i(1, 0)], 8: [8, Vector2i(0, 1)], 5: [5, Vector2i(1, 1)],
}

var _attacks := 0
var _in_special := false


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var distance := sim.distance(fighter, fighter.target)
	if distance <= 2:
		_attacks += 1
		_in_special = true
		var big := _attacks % 8 == 0
		play(sim, fighter, UnitSprite.Action.SPECIAL if big else UnitSprite.Action.ATTACKING, 30, {17: func() -> void: _stomp(sim, fighter, big)}, func() -> void: _in_special = false)
	elif distance <= fighter.attack_range:
		_in_special = true
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 35, {19: func() -> void: _fire(sim, fighter)}, func() -> void: _in_special = false)
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_in_special = false
		sim.stop_special(fighter)


func _stomp(sim: BattleSim, fighter: BattleFighter, big: bool) -> void:
	for unit in enemy_units_near(sim, fighter, fighter.tile, 10 if big else 3, 30 if big else 10):
		sim.push_in_air(unit, fighter, 6 if big else 2)
		sim.receive_attack(unit, int(fighter.attack * 1.2) if big else fighter.attack / 2, fighter)
		_take_target(sim, fighter, unit)


func _fire(sim: BattleSim, fighter: BattleFighter) -> void:
	var line: Array = FIRE_LINES[direction(fighter)]
	var tile := fighter.tile
	var hit: Array[BattleFighter] = []
	for i in line[0]:
		hit.append_array(enemy_units_near(sim, fighter, tile, 1, 30))
		tile += line[1]
	for unit in hit:
		if unit.dead:
			continue
		sim.receive_attack(unit, fighter.attack, fighter)
		sim.incinerate(unit, fighter, 8, 3, BattleSim.FRAMES_PER_SECOND)
		_take_target(sim, fighter, unit)


static func _take_target(sim: BattleSim, fighter: BattleFighter, unit: BattleFighter) -> void:
	if fighter.target == null and not unit.dead:
		sim.set_target(fighter, unit)
