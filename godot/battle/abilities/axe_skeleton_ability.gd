class_name AxeSkeletonAbility
extends BattleAbility
## The Axe Skeleton (AxeSkeletonDelegate of the client). Near the target (2
## tiles or less) it hits like a melee unit. Farther away it plays special
## attack 1 and throws an axe at frame AXE_FRAME.

const AXE := "p.axeSkeleton"
const AXE_FRAME := 5


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if sim.distance(fighter, target) <= 2:
		sim.stop_special(fighter)
		return true
	play(sim, fighter, UnitSprite.Action.SPECIAL, 15, {AXE_FRAME: func() -> void:
		if fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, AXE, fighter.attack)})
	return false


func on_leave_fight(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.stop_special(fighter)
