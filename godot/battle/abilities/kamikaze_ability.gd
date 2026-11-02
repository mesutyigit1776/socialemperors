class_name KamikazeAbility
extends BattleAbility
## The Kamikaze and the Infernal Kamikaze (the attack of the client for the
## kamikaze, and HellKamikazeDelegate): the attack is an explosion, see
## BattleSim.explode().

func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	sim.explode(fighter)
	return false
