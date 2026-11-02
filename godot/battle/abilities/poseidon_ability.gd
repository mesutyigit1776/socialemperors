class_name PoseidonAbility
extends BattleAbility
## Poseidon (GodPoseidonDelegate of the client). It hits its target only when
## the target is 2 tiles away or nearer; farther away it does not attack. Its
## graphic is 0.8 times as big.

func _init() -> void:
	scale = 0.8


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) <= 2:
		sim.receive_attack(fighter.target, fighter.attack, fighter)
	return false
