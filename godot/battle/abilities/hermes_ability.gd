class_name HermesAbility
extends BattleAbility
## Hermes (HermesDelegate of the client): in its range it fires a laser beam
## 11 frames after each attack and stays in the attack for 700 ms.

const LASER := "p.laser"
const LASER_FRAMES := 21


func _init() -> void:
	shot_graphic = LASER
	beam = true
	beam_frames = LASER_FRAMES


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	sim.play_special(fighter, UnitSprite.Action.ATTACKING, LASER_FRAMES)
	sim.after(11, func() -> void:
		if not fighter.dead and fighter.target == target and not target.dead:
			sim.shoot(fighter, target, LASER, fighter.attack))
	return false
