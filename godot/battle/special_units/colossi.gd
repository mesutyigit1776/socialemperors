class_name Colossi
extends SpecialUnit
## The colossi and the Antimatter Golem. They have no limit button.

const UNITS := {
	2235: "genesis_ice",
	2237: "genesis_iron",
	2236: "genesis_shadow",
	2162: "genesis_wind",
	2152: "genesis_earth",
	2098: "antimatter_golem", 2111: "antimatter_golem",
}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	match kind:
		"genesis_ice":
			var pic := func(number: int) -> String: return "2235_genesisIceColossus_button_%d" % number
			add(ability, 0, "Ice Blow", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85],
					Damages.Freeze.new(sim, unit, atk * 1.5, 4, 4), 7, 5), has_target(), NO_TARGET)
			add(ability, 1, "Freezing Whirlwind", pic.call(2), SpecialAttacks.Whirlwind.new(sim, unit, SP2, 6, 10, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk * 1.5, 5)).add(Damages.Freeze.new(sim, unit, atk * 1.5, 6, 5)), 5, 5))
			add_minions(ability, 2, "Minions", pic.call(3), SpecialAttacks.SpawnMinion.new(sim, unit, 2168, 1))
		"genesis_iron":
			var pic := func(number: int) -> String: return thumb(2237, "genesisIronColossusUnit", number)
			add(ability, 0, "SPIKY SUMMONING", pic.call(1), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP1, MagicParticles.SPIKES_RAIN,
					Damages.PushInAir.new(sim, unit, 250, 3)).with_delay(0.2).with_frames([59]), has_target(), NO_TARGET)
			add(ability, 1, "WHIRLWIND OF FISTS", pic.call(2), SpecialAttacks.Whirlwind.new(sim, unit, SP2, 8, 17, Damages.PushInAir.new(sim, unit, atk, 5), rng, 5))
			add_minions(ability, 2, "GENESIS IRON MINION", pic.call(3), SpecialAttacks.SpawnMinion.new(sim, unit, 2170, 2))
		"genesis_shadow":
			var pic := func(number: int) -> String: return thumb(2236, "genesisShadowColossusUnit", number)
			var kick := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, 700, 10)) \
					.add(Damages.DirectKill.new(sim, unit).with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500)).with_shared(true)
			add(ability, 0, "DEADLY KICK", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [17], kick, 5, 2), has_target(), NO_TARGET)
			add(ability, 1, "SMASHING FISTS", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [42], Damages.PushInAir.new(sim, unit, 850, 5).with_shared(true), 5, 9))
			add_minions(ability, 2, "GENESIS SHADOW MINION", pic.call(3), SpecialAttacks.SpawnMinion.new(sim, unit, 2161, 1))
		"genesis_wind":
			var pic := func(number: int) -> String: return thumb(2162, "genesisWindColossusUnit", number)
			add(ability, 0, "Sudden Death", pic.call(1), SpecialAttacks.Eat.new(sim, unit, SP1, [16], [55], Damages.DirectKill.new(sim, unit), ["sub"], 5)
					.with_incapacitate(true).with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500),
					AncientDragons._target_max_life(0, 500), NO_TARGET)
			add(ability, 1, "Meteor Crash", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [26],
					Damages.PushInAir.new(sim, unit, atk * 6, 5).with_shared(true), 7, 16).with_shared(true))
			add_minions(ability, 2, "Genesis Wind Minion", pic.call(3), SpecialAttacks.SpawnMinion.new(sim, unit, 2159, 1))
		"genesis_earth":
			# The 10 nearest enemies within 8 tiles take the attack and fly 5
			# tiles; those with at most 2000 life turn to stone (freeze) then.
			add(ability, 0, "Mega Slash", "2152_1", SpecialAttacks.Frames.new(sim, unit, SP1, [41], func() -> void:
				var stone := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5)) \
						.add(Damages.Freeze.new(sim, unit, 75, 3, 3).with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 2000))
				for enemy in sim.items_near(unit.tile, 8, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if stone.can_apply(enemy):
						stone.apply(enemy)))
			add(ability, 1, "Ultra Fireball", "2152_2", func(_s: BattleSim, _f: BattleFighter) -> void: unit.ability.spawn_minions(sim, unit, 2149, 3),
					below_minions(6), "6 " + MINIONS_MAX)
		"antimatter_golem":
			add(ability, 0, "Mega Slash", "2098_ataque_golpe", SpecialAttacks.Frames.new(sim, unit, SP1, [22], func() -> void:
				for enemy in directional_hits(sim, unit, 8):
					if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
						continue
					sim.receive_attack(enemy, int(atk), unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, 7)), has_target(), "No target within range")
			add(ability, 1, "Ultra Fireball", "2098_cabeza_humo", SpecialAttacks.Frames.new(sim, unit, SP2, [15, 25, 35, 45], func() -> void:
				for enemy in sim.items_near(unit.tile, 3, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_poison)):
					sim.receive_attack(enemy, int(atk), unit)
					sim.poison(enemy, 5, 5, 0, unit)), Callable(), "No target within range")
