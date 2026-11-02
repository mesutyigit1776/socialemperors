class_name GoldenSlayerAbility
extends BattleAbility
## The Medieval Golden Slayer (MedievalGoldenSlayerDelegate of the client). Each
## attack plays the attack animation and hits the target with its attack at
## frame 12. Its other attacks (sword, beams, whirlwind, drones) start only from
## the buttons of the player, see roadmap step 3.2.

func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	play(sim, fighter, UnitSprite.Action.ATTACKING, 20, {12: func() -> void:
		if fighter.target != null and not fighter.target.dead:
			sim.receive_attack(fighter.target, fighter.attack, fighter)})
	return false
