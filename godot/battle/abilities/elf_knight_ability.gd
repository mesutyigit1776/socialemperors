class_name ElfKnightAbility
extends BattleAbility
## The Imperial Elf Knight (ElfKnightDelegate of the client). It shoots its
## lance at frame 10 of each attack. Next to its target, the fourth attack is
## a charge (special attack 1, it cannot act): at frame 17 a target unit with
## 350 life or less dies, a stronger one takes 350, and it flies 4 tiles away.
## The eighth attack is an energy ball (special attack 2): at frame 20 the
## enemy units in its range that can act fly 1 tile away.

const LANCE := "p.elfKnight"
const CHARGE_DAMAGE := 350

var _counter := 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) > 2:
		_shoot(sim, fighter)
		return false
	if _counter == 4:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {17: func() -> void: _charge(sim, fighter)}, Callable(), true)
	elif _counter == 8:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, {20: func() -> void:
			for unit in sim.items_near(fighter.tile, fighter.attack_range, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead and not item.incapacitated):
				sim.push_in_air(unit, fighter, 1)}, Callable(), true)
	else:
		_shoot(sim, fighter)
	_counter += 1
	if _counter > 8:
		_counter = 1
	return false


func _shoot(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(10, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, LANCE, fighter.attack))


func _charge(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or not target.is_unit() or target.dead:
		return
	if target.health <= CHARGE_DAMAGE:
		sim.kill(target)
	else:
		sim.receive_attack(target, CHARGE_DAMAGE, fighter)
	sim.push_in_air(target, fighter, 4)
