class_name PunkAbility
extends BattleAbility
## The Heavy Dragon (PunkDelegate of the client), a ranged unit that hits like
## a melee unit. Each attack fires a beam 13 frames later, which holds the
## target with electricity for 1 second when it starts. Its other attacks
## (egg, energy balls, roll, smash) start only from the buttons of the player,
## see roadmap step 3.2.

const BEAM := "p.punkBeam_02"


func _init() -> void:
	ranged_melee = true
	shot_graphic = BEAM
	beam = true
	beam_frames = 30


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	sim.after(13, func() -> void:
		if fighter.dead or target.dead or fighter.target != target:
			return
		if target.is_unit():
			sim.electrocute(target, fighter, 0, 10, 3)
		sim.shoot(fighter, target, BEAM, fighter.attack))
	return false
