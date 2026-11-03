class_name AttackAdderAbility
extends BattleAbility
## The Attack Adder (AttackAdderDelegate of the client). It shoots lightning 5
## frames after each attack. Once a second, the 10 nearest own units within
## 10 tiles, other Attack Adders not included, get its aura: their attacks do
## 1.5 times the damage (see BattleFighter.attack_adder_buff). The client never
## takes the aura away again.

const RANGE := 10
const COUNT := 10
const SHOT := "p.lightning"
const SHOT_DELAY := 5


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	sim.after(SHOT_DELAY, func() -> void:
		if not fighter.dead and target != null and not target.dead:
			sim.shoot(fighter, target, SHOT, fighter.attack))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if (sim.frame + fighter.get_instance_id()) % BattleSim.FRAMES_PER_SECOND != 0:
		return
	for ally in sim.items_near(fighter.tile, RANGE, COUNT, fighter.team, true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and item.def.id != fighter.def.id):
		ally.attack_adder_buff = true
