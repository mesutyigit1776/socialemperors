class_name ElfSwordAbility
extends BattleAbility
## The Imperial Elf Sword and the Silver Paladin (ElfSwordDelegate and
## ElfSilverPaladinDelegate of the client). The sword hits 333 ms (10 frames)
## after each attack; the paladin is a ranged unit that hits like a melee unit.

const HIT_DELAY := 10
const SWORD := 2005

var _delayed := false


func configure(item_id: int) -> void:
	_delayed = item_id == SWORD
	ranged_melee = not _delayed


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if not _delayed:
		return true
	sim.after(HIT_DELAY, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.receive_attack(fighter.target, fighter.attack, fighter))
	return false
