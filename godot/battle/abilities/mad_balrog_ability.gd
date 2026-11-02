class_name MadBalrogAbility
extends BattleAbility
## The Mad Balrog (MadBalrogDelegate of the client). It hits its target at once
## at any distance in its range. Next to the target (2 tiles or less), the
## sixth attack is a smash (special attack 1, it cannot act) at frame 22: up
## to 10 enemies within 2 tiles, not on its tile, take its attack and units fly
## 4 tiles away. The twelfth attack is a fire rain (special attack 2) at frame
## 16: meteors on the 7 x 7 tiles around the target with its attack, after 7
## to 47 frames. When it dies, it smashes once more.

var _counter := 0


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) > 2:
		sim.receive_attack(fighter.target, fighter.attack, fighter)
		return false
	if _counter == 6:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 35, {22: func() -> void: _smash(sim, fighter)}, Callable(), true)
	elif _counter == 12:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, {16: func() -> void: storm_symmetric(sim, fighter, MagicParticles.FIRE_METEOR, 3, 1.0, 7, 40)}, Callable(), true)
	else:
		sim.receive_attack(fighter.target, fighter.attack, fighter)
	_counter += 1
	if _counter > 12:
		_counter = 0
	return false


func on_died(sim: BattleSim, fighter: BattleFighter) -> void:
	_smash(sim, fighter)


func _smash(sim: BattleSim, fighter: BattleFighter) -> void:
	for enemy in enemies_near(sim, fighter, fighter.tile, 2, 10, false):
		sim.receive_attack(enemy, fighter.attack, fighter)
		if enemy.is_unit():
			sim.push_in_air(enemy, fighter, 4)
