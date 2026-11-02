class_name ElfCrossbowAbility
extends BattleAbility
## The Elven Crossbow (ElfCrossbowDelegate of the client). At frame 10 of its
## attack it shoots three arrows, 100 ms apart, each at an enemy within its
## range that the other arrows did not choose. Every sixth attack is a super
## arrow (special attack 1, it cannot act meanwhile) at frame 10, which hurts
## with 4 times its attack.

const ARROW := "p.elfCrossbowArrow"
const SUPER_ARROW := "p.elfCrossbowSuperArrow"
const SPECIAL_EVERY := 6

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _counter == SPECIAL_EVERY:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {10: func() -> void:
			if fighter.target != null and not fighter.target.dead:
				sim.shoot(fighter, fighter.target, SUPER_ARROW, fighter.attack * 4)}, Callable(), true)
	else:
		var chosen: Array[BattleFighter] = []
		for i in 3:
			sim.after(10 + i * 3, func() -> void: _shoot(sim, fighter, chosen))
	_counter += 1
	if _counter > SPECIAL_EVERY:
		_counter = 1
	return false


func _shoot(sim: BattleSim, fighter: BattleFighter, chosen: Array[BattleFighter]) -> void:
	if fighter.dead:
		return
	for enemy in sim.items_near(fighter.tile, fighter.attack_range, 20, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return not item.dead):
		if enemy in chosen:
			sim.set_target(fighter, chosen.back())
			continue
		sim.set_target(fighter, enemy)
		chosen.append(enemy)
		break
	if fighter.target != null and not fighter.target.dead:
		sim.shoot(fighter, fighter.target, ARROW, fighter.attack)
