class_name LightningDragonAbility
extends BattleAbility
## The Stormy Dragon (LightningDragonDelegate of the client). It shoots an
## electric beam that holds its target for 1 second (10 ticks of 100 ms) when
## it starts. Its cycle has three special attacks:
## 1. Up to 4 enemies in its range, not on its tile, take half its attack and
##    units fly 2 tiles away.
## 2. It throws an egg, from which a summoned Lightning Draggy comes, while it
##    has fewer than 3 of them alive.
## 3. A huge lightning strikes the tile of its target with twice its attack.
##
## Its limit attack (smash) starts only from the button of the player, see
## roadmap step 3.2.

const BEAM := "p.electricityBeam"
const LIGHTNING_DRAGGY := 651
const MAX_DRAGGIES := 3

var _draggies := 0


func _init() -> void:
	special_intervals = [90, 90, 90]
	special_durations = [20, 60, 40]
	shot_graphic = BEAM
	shot_delay = 12
	beam = true
	beam_frames = 30


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0):
		for enemy in enemies_near(sim, fighter, fighter.tile, fighter.attack_range, 4, false):
			sim.receive_attack(enemy, fighter.attack / 2, fighter)
			if enemy.is_unit():
				sim.push_in_air(enemy, fighter, 2)
		return false
	if in_special(fighter, 1):
		if _draggies < MAX_DRAGGIES:
			throw_egg(sim, fighter, LIGHTNING_DRAGGY, func(draggy: BattleFighter) -> void:
				_draggies += 1
				sim.died.connect(func(item: BattleFighter, _killer: BattleFighter) -> void:
					if item == draggy:
						_draggies -= 1))
		return false
	if in_special(fighter, 2):
		if fighter.target != null and not fighter.target.dead:
			sim.particle(fighter, fighter.target.tile, MagicParticles.LIGHTNING_HUGE, fighter.attack * 2, 0)
		return false
	var target := fighter.target
	sim.after(shot_delay, func() -> void:
		if not fighter.dead and fighter.target == target and not target.dead and target.is_unit():
			sim.electrocute(target, fighter, 0, 10, 3))
	return true
