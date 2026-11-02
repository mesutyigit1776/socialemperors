class_name ElfAxeAbility
extends BattleAbility
## The Imperial Elf Axe (ElfAxeDelegate of the client). It hits like a melee
## unit; every eighth attack is a whirlwind (special attack 1): each time the
## animation reaches frame SPIN_FRAME, up to 4 units of the other side within
## 3 tiles take its attack and fly 3 tiles away, SPINS times.

const SPIN_FRAME := 10
const SPINS := 12

var _attacks := 0


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	_attacks += 1
	if _attacks % 8 != 0:
		return true
	var length := sim.animation_frames(fighter, UnitSprite.Action.SPECIAL, 20)
	var events := {}
	# The client checks the frame of the looping animation, so the spin comes once in each loop.
	for spin in SPINS:
		events[spin * length + SPIN_FRAME] = func() -> void: _spin(sim, fighter)
	sim.play_special(fighter, UnitSprite.Action.SPECIAL, (SPINS - 1) * length + SPIN_FRAME, events)
	return false


func _spin(sim: BattleSim, fighter: BattleFighter) -> void:
	for enemy in sim.items_near(fighter.tile, 3, 4, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
		sim.receive_attack(enemy, fighter.attack, fighter)
		if enemy.is_unit():
			sim.push_in_air(enemy, fighter, 3)
