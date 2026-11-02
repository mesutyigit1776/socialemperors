class_name IsisHealerAbility
extends BattleAbility
## The Isis Healer (IsisHealerDelegate of the client). Each attack heals its
## target by its attack; in its special animation by twice its attack.

func _init() -> void:
	special_intervals = [240]
	special_durations = [120]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target != null and target.is_unit():
		sim.heal(target, fighter.attack * (2 if in_special(fighter, 0) else 1), fighter)
		sim.particle(fighter, target.tile, MagicParticles.STARS, 0, 0)
	return false
