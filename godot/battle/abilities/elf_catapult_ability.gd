class_name ElfCatapultAbility
extends BattleAbility
## The Imperial Elf Catapult (ElfCatapultDelegate of the client). At frame 5 of
## its attack it throws a fireball. Where it lands, up to 3 units of the other
## side within 2 tiles, not on the tile itself, burn: 5 damage every second, 5
## times.

const FIREBALL := "p.catapultFireball"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	sim.after(5, func() -> void:
		var target := fighter.target
		if fighter.dead or target == null or target.dead:
			return
		sim.shoot(fighter, target, FIREBALL, fighter.attack, func(shot: BattleProjectile) -> void:
			var tile := IsoGrid.nearest_tile(shot.end)
			sim.particle(fighter, tile, MagicParticles.NONE, 0, 0)
			for unit in sim.items_near(tile, 2, 3, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
				sim.incinerate(unit, fighter, 5, 5, 30)))
	return false
