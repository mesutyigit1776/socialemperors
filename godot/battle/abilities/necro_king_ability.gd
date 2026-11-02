class_name NecroKingAbility
extends NecroAbility
## The Necro King (NecroKingDelegate of the client). For each attack it draws
## a random number:
## - 0.75 or more, with its target 1 or 2 tiles away: a lightning rain (special
##   attack 2) at frame 11: 30 lightnings within 3 tiles of the target, each
##   with half its attack, after 7 to 47 frames; the animation then waits 1.8
##   seconds.
## - 0.5 to 0.74: a blow (special attack 1) at frame 22: the target flies 3
##   tiles away and takes its attack.
## - else a normal hit at frame 8.

const RAIN_WAIT := 54  ## 1.8 seconds.


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var roll := sim.rng.randf()
	var distance := sim.distance(fighter, fighter.target)
	if distance > 0 and distance < 3 and roll >= 0.75:
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, sim.animation_frames(fighter, UnitSprite.Action.SPECIAL + 1, 30) + RAIN_WAIT, {11: func() -> void:
			arrow_storm(sim, fighter, MagicParticles.LIGHTING_NECRO, 30, 3, 0.5, 7, 40)})
		return false
	if roll >= 0.5 and roll <= 0.74:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {22: func() -> void:
			var target := fighter.target
			if target != null and not target.dead:
				if target.is_unit():
					sim.push_in_air(target, fighter, 3)
				sim.receive_attack(target, fighter.attack, fighter)})
	else:
		play(sim, fighter, UnitSprite.Action.ATTACKING, 15, {8: func() -> void:
			if fighter.target != null and not fighter.target.dead:
				sim.receive_attack(fighter.target, fighter.attack, fighter)})
	return false
