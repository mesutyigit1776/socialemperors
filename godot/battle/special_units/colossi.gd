class_name Colossi
extends SpecialUnit
## The colossi and the Antimatter Golem. The elemental colossi have a limit
## button and some a combo with the god and the goddess of their element.

const UNITS := {
	2235: "genesis_ice",
	2237: "genesis_iron",
	2236: "genesis_shadow",
	2162: "genesis_wind",
	2152: "genesis_earth",
	2098: "antimatter_golem", 2111: "antimatter_golem",
	2094: "heaven",
	2077: "fire",
	2086: "water",
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
		"heaven":
			add(ability, 0, "Mega Slash", "2094_1", SpecialAttacks.Frames.new(sim, unit, SP1, [15], func() -> void: sim.heal(unit, 500, unit)),
					Callable(), "No target within range")
			# The units of the directional attack take the attack, fly 7 tiles
			# and freeze for 5 seconds.
			add(ability, 1, "Ultra Fireball", "2094_2", SpecialAttacks.Frames.new(sim, unit, SP2, [31], func() -> void:
				var hit := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 7)).add(Damages.Freeze.new(sim, unit, 0, 5, 5))
				for enemy in directional_hits(sim, unit, 12, 6):
					if hit.can_apply(enemy):
						hit.apply(enemy)), has_target(), "No target within range")
			add(ability, 2, "Hyper Whirlwind", "2094_3", SpecialAttacks.Frames.new(sim, unit, SP4, [10, 15, 20, 25, 30, 34, 40], func() -> void:
				circular_push(sim, unit, 5, 10, int(atk / 2), 6), 12))
			_colossus_minions(sim, unit, ability, "2094_4", SP3, 33, 2092)
			limit_special(ability, SP5, [72], func(battle: BattleSim, colossus: BattleFighter) -> void:
				circular_push(battle, colossus, 8, 15, int(colossus.attack * 1.5), 12))
			combo(sim, unit, [2350, 2093])

		"fire":
			add(ability, 0, "Mega Slash", "2077_2", SpecialAttacks.Frames.new(sim, unit, SP1, [26], func() -> void:
				_directional_push(sim, unit, 12, 4, int(atk), 6)), has_target(), "No target within range")
			# Flames: at each frame, each unit of the directional attack takes
			# the attack once and burns.
			var flame_frames: Array[int] = []
			for frame in range(18, 63, 4):
				flame_frames.append(frame)
			add(ability, 1, "Ultra Fireball", "2077_1", SpecialAttacks.Frames.new(sim, unit, SP2, flame_frames, func() -> void:
				var burnt: Array[BattleFighter] = []
				for enemy in directional_hits(sim, unit, 12, 6):
					if enemy.dead or enemy in burnt:
						continue
					burnt.append(enemy)
					sim.receive_attack(enemy, int(atk), unit)
					sim.incinerate(enemy, unit, 25, 5, BattleSim.FRAMES_PER_SECOND)), has_target(), "No target within range")
			var smash_frames: Array[int] = []
			for frame in range(40, 116, 5):
				smash_frames.append(frame)
			add(ability, 2, "Hyper Whirlwind", "2077_3", SpecialAttacks.Frames.new(sim, unit, SP3, smash_frames, func() -> void:
				var burn := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk / 2, 6)).add(Damages.Incinerate.new(sim, unit, 5, 5, 1000))
				for enemy in sim.items_near(unit.tile, 8, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if burn.can_apply(enemy):
						burn.apply(enemy)))
			_colossus_minions(sim, unit, ability, "2077_4", SP4, 12, 2076)
			var magma := SpecialAttacks.Rain.new(sim, unit, 4, 2, SP5, MagicParticles.MAGMA_BALL_RAIN, _BurnHit.new(sim, unit)).with_delay(0.075)
			limit_special(ability, SP5, [65], func(_battle: BattleSim, _colossus: BattleFighter) -> void: magma.start())
			combo(sim, unit, [2369, 2075])
		"water":
			add(ability, 0, "Anchor Shot", "2086_water_colossus_sw3", SpecialAttacks.Frames.new(sim, unit, SP1, [60], func() -> void:
				_directional_push(sim, unit, 12, 6, int(atk), 7)))
			add(ability, 1, "Black Smash", "2086_water_colossus_sw2", SpecialAttacks.Frames.new(sim, unit, SP2, [22], func() -> void:
				for enemy in sim.items_near(unit.tile, 5, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.push_in_air(enemy, unit, 5)))
			add(ability, 2, "Whirlwind", "2086_water_colossus_sw1", SpecialAttacks.Frames.new(sim, unit, SP3, [15], func() -> void:
				circular_push(sim, unit, 7, 5, int(atk / 4), 6), 10))
			_colossus_minions(sim, unit, ability, "2086_water_colossus_sw4", SP4, 15, 2096)
			ability.buttons[3].name = "Colossus Minions"
			# For 6 seconds, at each frame, the enemies within 7 tiles turn
			# around the colossus: units with more than 1000 life take 150
			# points; units with at most 500 life vanish; others vanish one
			# time in five, else they take 150 points and fly 7 tiles.
			var swirling: Array[BattleFighter] = []
			ability.has_limit = true
			add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(battle: BattleSim, colossus: BattleFighter) -> void:
				var events := {}
				for frame in range(60, 96, 5):
					events[frame] = func() -> void: _water_swap(battle, colossus, swirling)
				battle.play_special(colossus, SP5, 6 * BattleSim.FRAMES_PER_SECOND, events, Callable(), true), Callable(), "", 0)


## Each enemy of the directional attack takes damage and flies tiles.
static func _directional_push(sim: BattleSim, unit: BattleFighter, length: int, radius: int, damage: int, tiles: int) -> void:
	for enemy in directional_hits(sim, unit, length, radius):
		if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
			continue
		sim.receive_attack(enemy, damage, unit)
		if not enemy.dead:
			sim.push_in_air(enemy, unit, tiles)


static func _water_swap(sim: BattleSim, unit: BattleFighter, swirling: Array[BattleFighter]) -> void:
	for enemy in sim.items_near(unit.tile, 7, 20, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and not item in swirling):
		var life := enemy.max_life()
		if life > 1000:
			sim.receive_attack(enemy, 150, unit)
			continue
		var vanish := life <= 500 or sim.rng.randf() <= 0.2
		var target := enemy
		swirling.append(target)
		target.incapacitated = true
		target.swallowed = true
		sim.state_changed.emit(target)
		sim.after(3 * BattleSim.FRAMES_PER_SECOND, func() -> void:
			swirling.erase(target)
			if target.dead:
				return
			if vanish:
				sim.remove_item(target)
				return
			target.swallowed = false
			target.incapacitated = target.frozen or target.stunned or target.in_air
			sim.state_changed.emit(target)
			sim.receive_attack(target, 150, unit)
			if not target.dead:
				sim.push_in_air(target, unit, 7))


## A magma ball of the Fire Colossus limit: the attack, then fire.
class _BurnHit extends UnitDamage:
	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (target.ability == null or not target.ability.immune_to_burn)

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		sim.receive_attack(target, attacker.attack, _source())
		sim.incinerate(target, attacker, 5, 5, BattleSim.FRAMES_PER_SECOND)

## The minion button of the elemental colossi: 3 minions at frame of
## animation while at most 3 are alive.
static func _colossus_minions(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, picture: String, animation: int, frame: int, minion_id: int) -> void:
	add(ability, 3, "God Minions", picture, SpecialAttacks.Frames.new(sim, unit, animation, [frame], func() -> void:
		unit.ability.spawn_minions(sim, unit, minion_id, 3)),
		func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 3 <= 6, "6 " + MINIONS_MAX)
