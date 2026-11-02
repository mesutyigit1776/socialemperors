class_name TitanPyrosAbility
extends BattleAbility
## Titan Pyros (TitanPyrosDelegate of the client), a ranged unit that hits
## like a melee unit.
##
## - Next to its target (2 tiles or less) it counts its attacks. The client
##   does not set the count back to 0, so each of these attacks comes once:
##   - Attack 4 (special attack 1): at frame 20 it stomps: up to 10 enemy units
##     within 10 tiles take half its attack and fly 4 tiles away.
##   - Attack 8 (special attack 3): a magma hole under the target. The enemy
##     units within 3 tiles of the target (at most 10) burn: 6 damage in each
##     frame, 6 times.
##   - Attack 12 (special attack 3): an explosion after 16 frames. The enemies
##     within 2 tiles of it take 1.5 times its attack; units also burn (a fifth
##     of its attack every second, 5 times) and fly 4 tiles away.
##   - Other attacks: a normal hit.
## - Farther away in its range (special attack 2), two big fire balls at frames
##   18 and 29, each with its attack.
## - When it dies, it stomps once more, and the units also burn (3 damage in
##   each frame, 3 times).

const FIRE := "p.hugeFire"
const EXPLOSION_FRAME := 16

var _attacks := 0
var _in_special := false


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var target := fighter.target
	var distance := sim.distance(fighter, target)
	if distance <= 2:
		_attacks += 1
		match _attacks:
			4:
				_in_special = true
				play(sim, fighter, UnitSprite.Action.SPECIAL, 40, {20: func() -> void: _stomp(sim, fighter, false)}, _end)
				return false
			8:
				_magma(sim, fighter, target)
				return false
			12:
				sim.after(EXPLOSION_FRAME, func() -> void: _explode(sim, fighter))
				return false
		return true
	if distance <= fighter.attack_range:
		_in_special = true
		var events := {}
		for frame in [18, 29]:
			events[frame] = func() -> void:
				if fighter.target != null and not fighter.target.dead:
					sim.shoot(fighter, fighter.target, FIRE, fighter.attack)
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, events, _end)
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_in_special = false
		sim.stop_special(fighter)


func on_died(sim: BattleSim, fighter: BattleFighter) -> void:
	_stomp(sim, fighter, true)


func _end() -> void:
	_in_special = false


func _stomp(sim: BattleSim, fighter: BattleFighter, dying: bool) -> void:
	for unit in enemy_units_near(sim, fighter, fighter.tile, 10, 10):
		sim.receive_attack(unit, fighter.attack / 2, fighter)
		sim.push_in_air(unit, fighter, 4)
		if dying:
			sim.incinerate(unit, fighter, 3, 3, 1)


func _magma(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	var tile := target.tile
	sim.particle(fighter, tile, MagicParticles.MAGMA, 0, 0, func(_attacker: BattleFighter, _item: BattleFighter, _value: int) -> void:
		for unit in enemy_units_near(sim, fighter, tile, 3, 10):
			sim.incinerate(unit, fighter, 6, 6, 1), true)


func _explode(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.dead:
		return
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			for item in enemies_near(sim, fighter, fighter.tile + Vector2i(dx, dy), 0, 1):
				sim.receive_attack(item, int(fighter.attack * 1.5), fighter)
				if item.is_unit():
					sim.incinerate(item, fighter, int(fighter.attack * 0.2), 5, BattleSim.FRAMES_PER_SECOND)
					sim.push_in_air(item, fighter, 4)
