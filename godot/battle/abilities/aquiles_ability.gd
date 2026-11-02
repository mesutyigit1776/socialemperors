class_name AquilesAbility
extends BattleAbility
## Achilles (AquilesDelegate of the client). Near the target (2 tiles or less)
## he hits it at once. Farther away he throws spears: special attack 1, with a
## spear SPEAR_DELAY frames after each attack, while he keeps the target. His
## graphic is 1.2 times bigger.

const SPEAR := "p.spear"
const SPEAR_DELAY := 8


func _init() -> void:
	scale = 1.2


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if sim.distance(fighter, target) <= 2:
		sim.stop_special(fighter)
		sim.receive_attack(target, fighter.attack, fighter)
		return false
	fighter.forced_action = UnitSprite.Action.SPECIAL
	fighter.forced_frames = 1 << 20
	sim.after(SPEAR_DELAY, func() -> void:
		if not fighter.dead and fighter.target == target and not target.dead:
			sim.shoot(fighter, target, SPEAR, fighter.attack))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.forced_action >= 0 and (fighter.target == null or fighter.moving):
		sim.stop_special(fighter)
