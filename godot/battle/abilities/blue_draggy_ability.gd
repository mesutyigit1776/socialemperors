class_name BlueDraggyAbility
extends BattleAbility
## The Lightning Draggy (BlueDraggyDelegate of the client). It shoots
## lightning; in its special attack a huge lightning strikes the tile of the
## target with twice its attack.

func _init() -> void:
	special_intervals = [90]
	special_durations = [30]
	shot_graphic = "p.lightning"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0) and fighter.target != null and not fighter.target.dead:
		sim.particle(fighter, fighter.target.tile, MagicParticles.LIGHTNING_HUGE, fighter.attack * 2, 0)
	return fighter.animation == BattleFighter.Pose.ATTACKING
