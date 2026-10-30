class_name HealerAbility
extends BattleAbility
## Healers heal their target, a unit of their own side, during their special
## animation. Their normal attack does nothing.


func _init() -> void:
	special_intervals = [0]
	special_durations = [60]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if fighter.animation == BattleFighter.Pose.SPECIAL and fighter.target != null and fighter.target.is_unit() and fighter.target.team == fighter.team:
		sim.heal(fighter.target, fighter.attack)
	return fighter.animation == BattleFighter.Pose.ATTACKING
