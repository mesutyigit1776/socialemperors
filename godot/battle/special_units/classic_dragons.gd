class_name ClassicDragons
extends SpecialUnit
## The first special dragons, whose attacks the client writes in the unit
## classes. Most have a cooldown of 25 seconds; the riders (the second id) have the
## limit button.

const UNITS := {
	2037: "rainbow", 2038: "rainbow",
	847: "vulcano", 851: "vulcano",
	2048: "galaxy", 2050: "galaxy",
	2063: "star", 2065: "star",
	2039: "sun", 2041: "sun",
	2013: "snake", 2015: "snake",
	2016: "snake_electric", 2018: "snake_electric",
	2057: "three_headed", 2058: "three_headed",
	2043: "dual_gods", 2045: "dual_gods",
	2132: "three_head_elemental", 2134: "three_head_elemental",
	2069: "golden_dynasty", 2071: "golden_dynasty",
	736: "double_head_2", 838: "double_head_2",
	888: "egyptian", 889: "egyptian",
	2140: "four_wing", 2142: "four_wing",
	2129: "hell", 2131: "hell",
	826: "necro", 845: "necro",
	2023: "frost_fire", 2026: "frost_fire",
	777: "crystal", 841: "crystal",
	798: "rubies", 844: "rubies",
	785: "furious_bull", 842: "furious_bull",
	708: "golden", 835: "golden",
	695: "light", 834: "light",
	723: "black", 837: "black",
}
const RIDERS: Array[int] = [2038, 851, 2050, 2065, 2041, 2015, 2018, 2058, 2045, 2134, 2071, 838, 889, 2142, 2131, 845, 2026, 841, 844, 842, 835, 834, 837]
const GOLD_PER_STATUE := 10
const MAX_STATUES := 10
const COOLDOWN_OLD := 25


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rider := unit.def.id in RIDERS
	match kind:
		"rainbow":
			# The dragon becomes another dragon for 20 seconds; it teleports
			# when it walks.
			var forms := [[777, "Crystal Dragon", "2037_botones_ataques_sw1"], [847, "Vulcano Dragon", "2037_botones_ataques_sw2"],
					[826, "Death Dragon", "2037_botones_ataques_sw"], [862, "Electric Bahamut", "2037_botones_ataques_sw4"]]
			for i in forms.size():
				var form: Array = forms[i]
				add(ability, i, form[1], form[2], SpecialAttacks.Frames.new(sim, unit, SP1, [8], func() -> void:
					transform(sim, unit, form[0], 20, SP2)), Callable(), "", COOLDOWN_OLD)
			ability.teleports = true
			if rider:
				limit_lightning(ability, beams(SP3, [16], 50, LIMIT_RED_BEAM))
		"vulcano":
			add(ability, 0, "Shoot Fireballs", "botonbolas_847", SpecialAttacks.Frames.new(sim, unit, SP2, [16, 20, 24, 28, 32, 36], func() -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range:
					sim.shoot(unit, target, "p.lavaBall_01", unit.attack), 5), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Fireball Rain", "botonlluvia_847", SpecialAttacks.Frames.new(sim, unit, SP3, [25], func() -> void:
				BattleAbility.storm_symmetric(sim, unit, MagicParticles.FIRE_METEOR, 3, 1, 7, 20)), Callable(), "", COOLDOWN_OLD)
			var whirl := SpecialAttacks.Frames.new(sim, unit, SP1, [18, 24], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.incinerate(enemy, unit, int(atk / 3), 5, BattleSim.FRAMES_PER_SECOND)
					sim.push_in_air(enemy, unit, 2), 10)
			whirl.incapacitate = false
			add(ability, 2, "Whirlwind Attack", "botongiro_847", whirl, Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Draggies", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 849),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(SP1, [17], 50, LIMIT_RED_BEAM))
		"galaxy", "star", "sun":
			var data: Dictionary = {
				"galaxy": ["2048_botones_ataques_sw3", "2048_botones_ataques_sw1", "2048_botones_ataques_sw4", "botonGreenDraggis", "p.crystalBall", 2049],
				"star": ["btn1_2063", "btn2_2063", "btn3_2063", "btn4_2063", "p.star", 2064],
				"sun": ["2039botones_ataques_sw10", "2039botones_ataques_sw7", "2039botones_ataques_sw9", "2039botones_ataques_sw8", "p.catapultFireball", 2040],
			}
			var pics: Array = data[kind]
			var target_check := has_target() if kind == "star" else Callable()
			add(ability, 0, "Shoot Balls", pics[0], SpecialAttacks.Frames.new(sim, unit, SP2, [23, 29], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				if kind == "sun":
					# Where the fireball lands, the 3 nearest enemies within 2 tiles burn.
					sim.shoot(unit, target, pics[4], unit.attack, func(shot: BattleProjectile) -> void:
						var tile := IsoGrid.map_to_tile(shot.end)
						sim.particle(unit, tile, MagicParticles.FIRE_EXPLOSION_SMALL, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
						for enemy in sim.items_near(tile, 2, 3, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
								return item.is_unit() and not item.dead):
							sim.incinerate(enemy, unit, 5, 5, BattleSim.FRAMES_PER_SECOND))
				else:
					sim.shoot(unit, target, pics[4], unit.attack), 6), target_check, "No targets in range" if kind == "star" else "")
			if kind == "star":
				# A rain of falling stars; each hit takes half the attack and makes
				# the unit dizzy for 5 seconds.
				add(ability, 1, "Falling Stars Rain", pics[1], SpecialAttacks.Rain.new(sim, unit, 4, 2, SP3, MagicParticles.FALLING_STAR,
						_StarHit.new(sim, unit)).with_multiplier(0).with_frames([12]), target_check, "No targets in range")
			else:
				add(ability, 1, "Galaxy Explossion" if kind == "galaxy" else "Sun Explossion", pics[1], SpecialAttacks.Frames.new(sim, unit, SP3,
						[53 if kind == "galaxy" else 60], func() -> void: circular_push(sim, unit, 5, 10, int(atk * 2), 8)))
			var whirl_frames := [20, 25, 30, 35] if kind == "galaxy" else [25, 30, 35]
			add(ability, 2, "Whirlwind", pics[2], SpecialAttacks.Frames.new(sim, unit, SP1, whirl_frames, func() -> void:
				var reach := 2 if kind == "sun" else 3
				for enemy in sim.items_near(unit.tile, reach, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					if kind == "galaxy":
						sim.absorb_and_push(enemy, unit, 4)
					else:
						sim.push_in_air(enemy, unit, 2 if kind == "star" else 4), 10))
			add(ability, 3, "Spawn Minions", pics[3], func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, pics[5]),
					below_minions(3), "3 draggies max")
			if rider:
				if kind == "sun":
					limit_smash(ability, SP4, [29], 2, 6, 5)
				else:
					limit_healing(ability, beams(SP4, [25], 50, LIMIT_GREEN_BEAM))
		"snake":
			var rays := SpecialAttacks.Frames.new(sim, unit, SP3, [15, 20, 25, 30, 35, 40], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.goldenDragon", unit.attack)
					sim.shoot(unit, target, "p.goldenDragon", -1), 5)
			rays.incapacitate = false
			add(ability, 0, "Red Rays", "btn_rayo_ojos_2013", rays, has_target(), "No targets in range")
			add(ability, 1, "Deadly Rain", "btn_lluvia_dragon_2013", SpecialAttacks.Frames.new(sim, unit, SP4, [22], func() -> void:
				BattleAbility.storm_symmetric(sim, unit, MagicParticles.FIRE_RAIN, 2, 0.5, 10, 35)
				sim.after(45, func() -> void:
					if not unit.dead:
						for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
								return item.is_unit() and not item.dead):
							sim.poison(enemy, 5, 5, 0, unit))))
			var whirl := SpecialAttacks.Frames.new(sim, unit, SP5, [17, 27], func() -> void:
				circular_push(sim, unit, 3, 10, int(atk / 2), 2), 8)
			whirl.incapacitate = false
			add(ability, 2, "Whirlwind", "btn_resplandor_2013", whirl)
			add(ability, 3, "Spawn Draggies", "btn_draggie_2013", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2014),
					below_minions(3), "3 draggies max")
			ability.teleports = true
			if rider:
				limit_lightning(ability, beams(SP5, [16], 50, LIMIT_RED_BEAM))

		"snake_electric":
			add(ability, 0, "Blue Rays", "btn_bluerays_2016", SpecialAttacks.Frames.new(sim, unit, SP3, [11], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.crystalBall", int(atk / 4)), 6), has_target(), "No targets in range")
			# The target takes 350 points, or dies with at most 350 life, and flies 3 tiles.
			add(ability, 1, "Deadly Rain", "btn_smash_2016", SpecialAttacks.Frames.new(sim, unit, SP4, [20], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				if target.is_unit():
					sim.push_in_air(target, unit, 3)
					if target.health <= 350:
						sim.kill(target, unit)
						return
				sim.receive_attack(target, 350, unit)), func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.target != null,
					"No targets in range")
			var whirl := SpecialAttacks.Frames.new(sim, unit, SP5, [17, 27], func() -> void:
				for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.electrocute(enemy, unit, 5, 5, BattleSim.FRAMES_PER_SECOND)
					sim.push_in_air(enemy, unit, 2), 8)
			whirl.incapacitate = false
			add(ability, 2, "Whirlwind", "btn_whirlwind_2016", whirl)
			add(ability, 3, "Spawn Draggies", "btn_draggy_2016", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2017),
					below_minions(3), "3 draggies max")
			ability.teleports = true
			if rider:
				limit_lightning(ability, beams(SP5, [16], 50, LIMIT_RED_BEAM))
		"three_headed":
			var in_range := func(_s: BattleSim, fighter: BattleFighter) -> bool:
				return fighter.target != null and not fighter.target.dead and sim.distance(fighter, fighter.target) <= fighter.attack_range
			add(ability, 0, "Energy balls", "2057_energyballs", SpecialAttacks.Frames.new(sim, unit, SP5, [24, 32], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.lightBall", unit.attack), 6), in_range, "No target", COOLDOWN_OLD)
			# Three light beams; the target takes 3 times the attack.
			add(ability, 1, "Ultra ray", "2057_ultraray", SpecialAttacks.Frames.new(sim, unit, SP4, [22], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				for i in 3:
					sim.shoot_beam(unit, target, target.tile, "p.lightBeam", BattleSim.FRAMES_PER_SECOND, -1)
				sim.receive_attack(target, int(atk * 3), unit)), in_range, "No target", COOLDOWN_OLD)
			add(ability, 2, "Poison cloud", "2057_poison", SpecialAttacks.Frames.new(sim, unit, SP6, [53], func() -> void:
				for enemy in sim.items_near(unit.tile, 5, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.poison(enemy, int(atk / 10), 10, 0, unit)), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Whirlwind", "2057_whirlwind", SpecialAttacks.Frames.new(sim, unit, SP7, [31, 36], func() -> void:
				for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.absorb_and_push(enemy, unit, 4), 10), Callable(), "", COOLDOWN_OLD)
			if rider:
				limit_smash(ability, SP8, [29], 2, 6, 5)
		"dual_gods":
			# A purple ball at frame 22, a white ball at frame 30.
			var next_purple := [true]
			add(ability, 0, "Shoot Balls", "2043_energy_balls", SpecialAttacks.Frames.new(sim, unit, SP5, [22, 30], func() -> void:
				var target := unit.target
				var purple: bool = next_purple[0]
				next_purple[0] = not purple
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.dualPurple" if purple else "p.dualWhite", unit.attack), 6), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Auto Heal", "2043_heal", SpecialAttacks.Frames.new(sim, unit, SP6, [35], func() -> void: sim.heal(unit, 500, unit)),
					Callable(), "", COOLDOWN_OLD)
			# Enemies within 2 tiles take half the attack and fly 4 tiles; own
			# units with at most 500 life within 2 tiles get 25 life.
			add(ability, 2, "Whirlwind", "2043_whirlwind", SpecialAttacks.Frames.new(sim, unit, SP4, [25, 30, 35], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.push_in_air(enemy, unit, 4)
				for ally in sim.items_near(unit.tile, 2, 10, unit.team, false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and item.attack > 0 and item.max_life() <= 500):
					sim.heal(ally, 25, unit), 10), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Minions", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2044),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(SP7, [23], 50, LIMIT_RED_BEAM))
		"three_head_elemental":
			add(ability, 0, "Mega Slash", "2132_1", SpecialAttacks.Frames.new(sim, unit, SP6, [53, 59], func() -> void:
				circular_push(sim, unit, 8, 10, int(atk * 1.5), 8)), Callable(), "No target within range")
			# A rain of heavy rocks: a unit that a rock hits falls into a hole
			# and dies (one hole for each tile); a building takes the attack.
			add(ability, 1, "Ultra Fireball", "2132_2", SpecialAttacks.Rain.new(sim, unit, 4, 2.5, SP5, MagicParticles.HEAVY_ROCK_RAIN,
					_HoleHit.new(sim, unit)).with_multiplier(0.5).with_frames([25]), Callable(), "No target within range")
			# The 5 nearest enemies within 5 tiles with less than 500 life turn
			# around the dragon for 3 seconds and die.
			add(ability, 2, "Hyper Whirlwind", "2132_3", SpecialAttacks.Frames.new(sim, unit, SP4, [30, 35, 40, 45], func() -> void:
				for enemy in sim.items_near(unit.tile, 5, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and not item.swallowed and item.max_life() < 500 \
								and (item.ability == null or not item.ability.immune_to_push)):
					var target := enemy
					target.incapacitated = true
					target.swallowed = true
					sim.state_changed.emit(target)
					sim.after(3 * BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not target.dead:
							sim.kill(target, unit))))
			add(ability, 3, "God Minions", "2132_4", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2133),
					below_minions(3), "3 " + MINIONS_MAX)
			if rider:
				limit_healing(ability, beams(SP7, [22], 50, LIMIT_GREEN_BEAM))
		"golden_dynasty":
			add(ability, 0, "Shoot Balls", "bolas_dragon_2069", SpecialAttacks.Frames.new(sim, unit, SP3, [11], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.lightBall", int(atk / 2)), 6), has_target(), "No targets in range")
			add(ability, 1, "Horn Attack", "dale_cabeza_2069", SpecialAttacks.Frames.new(sim, unit, SP4, [11], func() -> void:
				var target := unit.target
				if target == null or target.dead or not target.is_unit():
					return
				if target.max_life() <= 500:
					sim.kill(target, unit)
				else:
					sim.receive_attack(target, int(atk * 3), unit)
					sim.push_in_air(target, unit, 4)), has_target(), "No targets in range")
			# Up to 10 enemies with less than 500 life become gold statues for
			# 10 seconds; each statue gives the player 10 gold. The others are
			# pulled in, fly 4 tiles and take half the attack.
			var statues := [0]
			var whirl := SpecialAttacks.Frames.new(sim, unit, SP5, [17, 27], func() -> void:
				for enemy in sim.items_near(unit.tile, 6, 5, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					var target := enemy
					if statues[0] < MAX_STATUES and target.max_life() < 500:
						if target.frozen:
							continue
						statues[0] += 1
						sim.push_in_air(target, unit, -maxi(sim.distance(target, unit) / 2, 1))
						sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
							if not target.dead:
								Damages.Freeze.new(sim, unit, 25, 5, 5).apply(target)
								sim.gold_earned.emit(GOLD_PER_STATUE))
						sim.after(10 * BattleSim.FRAMES_PER_SECOND, func() -> void: statues[0] = maxi(statues[0] - 1, 0))
					else:
						sim.absorb_and_push(target, unit, 4)
						sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
							if not target.dead:
								sim.receive_attack(target, int(atk / 2), unit)), 10)
			whirl.incapacitate = false
			add(ability, 2, "Whirlwind", "whirwind_2069", whirl)
			add(ability, 3, "Spawn Minions", "draggie_dinasty_2069", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2070),
					below_minions(3), "3 draggies max")
			ability.teleports = true
			if rider:
				limit_lightning(ability, beams(SP5, [16], 50, LIMIT_RED_BEAM))
		"double_head_2":
			ability.giant = true
			add(ability, 0, "Culazo digo... culetazo", "botonCuletazo", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP4, 42, {18: func() -> void:
					for enemy in sim.items_near(unit.tile, 2, 20, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead):
						sim.push_in_air(enemy, unit, 3)
						sim.receive_attack(enemy, int(atk / 2.2), unit)
						if unit.target == null and not enemy.dead:
							sim.set_target(unit, enemy)}, Callable(), true), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Torbelliiiino murtal", "botonTorbellino", func(_s: BattleSim, _f: BattleFighter) -> void: _torning(sim, unit, 12),
					Callable(), "", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(SP5, [17], 50, LIMIT_RED_BEAM))
		"egyptian":
			add(ability, 0, "Shoot Balls", "btn_bolas", SpecialAttacks.Frames.new(sim, unit, SP2, [22, 26, 30, 34], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.egyptianBall", unit.attack), 6), Callable(), "", COOLDOWN_OLD)
			# When the target has at most 500 life, the 2 nearest enemy units in
			# range die.
			add(ability, 1, "Breath From Hell", "btn_tufillo_chungo", SpecialAttacks.Frames.new(sim, unit, SP3, [18], func() -> void:
				for enemy in sim.items_near(unit.tile, unit.attack_range, 2, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.particle(unit, enemy.tile, MagicParticles.SOUL, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
					sim.kill(enemy, unit)), func(_s: BattleSim, fighter: BattleFighter) -> bool:
						var target := fighter.target
						return target != null and not target.dead and target.is_unit() and target.def.life <= 500 and sim.distance(fighter, target) <= fighter.attack_range,
					"No targets in range", COOLDOWN_OLD)
			add(ability, 2, "Whirlwind", "btn_giro", SpecialAttacks.Frames.new(sim, unit, SP1, [22, 26, 30, 34], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and not item.incapacitated and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.push_in_air(enemy, unit, 2), 10), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Minions", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 890),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(SP1, [16], 50, LIMIT_RED_BEAM))
		"four_wing":
			# The dragon flies at 3 times its speed to the tile in front of it
			# and back; on each tile a green flame burns the units within 3
			# tiles (once each): they take the attack, burn and fly 2 tiles.
			add(ability, 0, "", "2140_1", func(_s: BattleSim, _f: BattleFighter) -> void:
				var origin := unit.tile
				var goal: Variant = directional_tile(sim, unit, unit.attack_range * 2)
				if goal == null:
					return
				var burnt: Array[BattleFighter] = []
				var flame := func() -> void:
					sim.particle(unit, unit.tile, MagicParticles.GREEN_FLAME, 5, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
					for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead and not item in burnt):
						burnt.append(enemy)
						sim.receive_attack(enemy, unit.attack, unit)
						if not enemy.dead:
							sim.incinerate(enemy, unit, 25, 5, BattleSim.FRAMES_PER_SECOND)
							sim.push_in_air(enemy, unit, 2)
				sim.play_special(unit, SP1, 10 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
				fly_to(sim, unit, goal, unit.speed * 3, flame, func() -> void:
					fly_to(sim, unit, origin, unit.speed * 3, flame, func() -> void: sim.stop_special(unit))),
					func(_s: BattleSim, _f: BattleFighter) -> bool: return directional_tile(sim, unit, unit.attack_range * 2) != null,
					"You are too close to a building, wall or tree")
			add(ability, 1, "", "2140_2", SpecialAttacks.Frames.new(sim, unit, SP2, [40], func() -> void:
				var whirl := sim.spawn(sim.config_item(2147), unit.tile, unit.team)
				if whirl != null:
					sim.after(11 * BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not whirl.dead and whirl in sim.fighters:
							sim.remove_item(whirl))))
			add(ability, 2, "", "2140_3", SpecialAttacks.Rain.new(sim, unit, 6, 3, SP3, MagicParticles.ACID_RAIN, _AcidHit.new(sim, unit))
					.with_multiplier(0).with_frames([25]))
			add(ability, 3, "", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void:
				egg_minion(sim, unit, 2141)
				sim.after(6, func() -> void: egg_minion(sim, unit, 2141)),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 2 <= 4, "4 " + MINIONS_MAX)
			if rider:
				var frames: Array[int] = []
				for frame in range(35, 116, 5):
					frames.append(frame)
				limit_special(ability, SP5, frames, func(battle: BattleSim, dragon: BattleFighter) -> void:
					circular_push(battle, dragon, 7, 10, int(dragon.attack * 1.5), 12))
		"hell":
			add(ability, 0, "Energy Balls", "2129_1", SpecialAttacks.Frames.new(sim, unit, SP1, [30, 35, 40], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.largeFireball", unit.attack), 5), has_target(), "No target within range")
			add(ability, 1, "Hell Invocation", "2129_2", SpecialAttacks.Frames.new(sim, unit, SP2, [65], func() -> void: _hell_cracks(sim, unit)),
					has_target(), "No target within range")
			add(ability, 2, "Hell Whirlwind", "2129_3", SpecialAttacks.Frames.new(sim, unit, SP3, [45, 50], func() -> void:
				var burn := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk / 2, 5)).add(Damages.Incinerate.new(sim, unit, 20, 5, 1000))
				for enemy in sim.items_near(unit.tile, 5, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if burn.can_apply(enemy):
						burn.apply(enemy), 10))
			add(ability, 3, "Minions", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2130),
					below_minions(3), "3 " + MINIONS_MAX)
			if rider:
				limit_lightning(ability, beams(SP4, [16], 50, LIMIT_RED_BEAM))
		"necro":
			# The target must be nearer than the attack range (canAttack).
			var near := func(_s: BattleSim, fighter: BattleFighter) -> bool:
				return fighter.target != null and sim.distance(fighter, fighter.target) < fighter.attack_range
			var shoot := func(graphic: String) -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range + 2:
					sim.shoot(unit, target, graphic, unit.attack)
			add(ability, 0, "Shoot Beam", "boton_necro_bola", SpecialAttacks.Frames.new(sim, unit, SP2, [16, 20, 24, 28, 32, 36], func() -> void:
				shoot.call("p.necroFireball"), 6), near, "No target", COOLDOWN_OLD)
			add(ability, 1, "Smash Attack", "boton_necro_tornado", SpecialAttacks.Frames.new(sim, unit, SP3, [16, 24, 32], func() -> void:
				shoot.call("p.necroTornado"), 6), near, "No target", COOLDOWN_OLD)
			# For 10 seconds, each second, the units within 3 tiles take 1.5
			# times the attack and fly 4 tiles.
			add(ability, 2, "Spawn Octospuss", "boton_necro_giro", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 10 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
				for second in range(1, 10):
					sim.after(second * BattleSim.FRAMES_PER_SECOND, func() -> void: circular_push(sim, unit, 3, 20, int(atk * 1.5), 4)),
					Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Octospuss", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 820),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 5)
		"frost_fire":
			add(ability, 0, "Red Rays", "2023_bolafuego", SpecialAttacks.Frames.new(sim, unit, SP5, [23, 28], func() -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range:
					sim.shoot(unit, target, "p.catapultFireball", unit.attack), 6))
			# A frozen rain; after 1.5 seconds the units within 3 tiles of its
			# centre freeze for 6 seconds.
			var frozen_rain := SpecialAttacks.Rain.new(sim, unit, 3, 2.75, SP6, MagicParticles.FROZEN_RAIN, null).with_multiplier(0.5)
			add(ability, 1, "Red Rays", "2023_lluvia", SpecialAttacks.Frames.new(sim, unit, SP6, [24], func() -> void:
				var centre := unit.target.tile if unit.target != null and not unit.target.dead else unit.tile
				frozen_rain.start()
				sim.after(45, func() -> void:
					for enemy in sim.items_near(centre, 3, 15, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead):
						Damages.Freeze.new(sim, unit, 0, 6, 6).apply(enemy))))
			# Units within 3 tiles take half the attack; every second one
			# freezes, the others burn; then they fly 2 tiles.
			add(ability, 2, "Red Rays", "2023_whirlwind", SpecialAttacks.Frames.new(sim, unit, SP4, [25, 30, 35], func() -> void:
				var index := 1
				for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.receive_attack(enemy, int(atk / 2), unit)
					if index % 2 == 0:
						if not enemy.frozen:
							Damages.Freeze.new(sim, unit, 0, 6, 6).apply(enemy)
					elif not enemy.incapacitated:
						sim.incinerate(enemy, unit, 5, 5, BattleSim.FRAMES_PER_SECOND)
					index += 1
					sim.push_in_air(enemy, unit, 2), 10))
			add(ability, 3, "Spawn Draggies", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 2024),
					below_minions(3), "3 draggies max")
			if rider:
				limit_healing(ability, beams(SP7, [30], 50, LIMIT_GREEN_BEAM))
		"crystal":
			ability.giant = true
			var free_unit := func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead and not item.incapacitated and item.def.subcat_functional != BattleSim.SUBCAT_BOSS
			add(ability, 0, "Crystal Light Balls", "boton_crystal_energy_ball", SpecialAttacks.Frames.new(sim, unit, SP1, [16, 20, 24, 28, 32, 36, 40], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.crystalBall", unit.attack), 6), Callable(), "", COOLDOWN_OLD)
			# A crystal laser at the target in range; a unit freezes for 4 seconds.
			add(ability, 1, "Crystalizer Ray", "boton_crystal_eye_beam", SpecialAttacks.Frames.new(sim, unit, SP2, [13], func() -> void:
				var target := unit.target
				if target == null or target.dead or sim.distance(unit, target) > unit.attack_range:
					return
				sim.shoot_beam(unit, target, target.tile, "p.crystalLaser", BattleSim.FRAMES_PER_SECOND, unit.attack)
				if target.is_unit():
					sim.particle(unit, target.tile, MagicParticles.FREEZE_UNITS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
					sim.freeze(target, 120)), Callable(), "", COOLDOWN_OLD)
			# A crystal rain; after 1.5 seconds the 20 nearest enemies within 7
			# tiles take the attack.
			add(ability, 2, "Crystal Rain", "boton_crystal_rain", SpecialAttacks.Frames.new(sim, unit, SP3, [11], func() -> void:
				BattleAbility.arrow_storm(sim, unit, MagicParticles.CRYSTAL_RAIN, 20, 5, 0, 0, 30)
				sim.after(45, func() -> void:
					if not unit.dead:
						for enemy in sim.items_near(unit.tile, 7, 20, BattleAbility.enemy_side(unit), true, free_unit):
							sim.receive_attack(enemy, unit.attack, unit))), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Sorrounding Multi-Ray", "boton_crystal_rainbow", SpecialAttacks.Frames.new(sim, unit, SP4, [17], func() -> void:
				for enemy in sim.items_near(unit.tile, 4, 2, BattleAbility.enemy_side(unit), true, free_unit):
					sim.receive_attack(enemy, unit.attack, unit)
					sim.push_in_air(enemy, unit, 3), 7), Callable(), "", COOLDOWN_OLD)
			if rider:
				limit_healing(ability, beams(SP2, [16], 50, LIMIT_GREEN_BEAM))
		"rubies":
			ability.giant = true
			add(ability, 0, "Crystal Light Balls", "boton_rubies_balls", SpecialAttacks.Frames.new(sim, unit, SP1, [16, 20, 24, 28, 32, 36, 40], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.fireBall_02", unit.attack)), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Crystalizer Ray", "boton_rubies_laser", SpecialAttacks.Frames.new(sim, unit, SP2, [13], func() -> void:
				var target := unit.target
				if target == null or target.dead or sim.distance(unit, target) > unit.attack_range:
					sim.stop_special(unit)
					return
				sim.shoot_beam(unit, target, target.tile, "p.rubiesLaser", BattleSim.FRAMES_PER_SECOND, int(atk * 2))
				if target.is_unit():
					sim.particle(unit, target.tile, MagicParticles.FREEZE_UNITS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
					sim.freeze(target, 120)), Callable(), "", COOLDOWN_OLD)
			# 50 loops: the 2 nearest enemies within 4 tiles take half the
			# attack and fly 3 tiles.
			add(ability, 2, "Surrounding Multi-Ray", "boton_rubies_beam", SpecialAttacks.Frames.new(sim, unit, SP4, [18], func() -> void:
				circular_push(sim, unit, 4, 2, int(atk * 0.5), 3), 50.0 * sim.animation_frames(unit, SP4, 30) / BattleSim.FRAMES_PER_SECOND),
					Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Draggies", "botonGreenDraggis", SpecialAttacks.Frames.new(sim, unit, SP3, [14], func() -> void: egg_minion(sim, unit, 813)),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, LimitAttacks.Beams.new(SP3, [15], 100, 50, LIMIT_RED_BEAM, 0.25, true))
		"furious_bull":
			# For 6 seconds, energy balls at the nearest enemy within 11 tiles.
			add(ability, 0, "Fire Balls", "botonbolas_785", SpecialAttacks.Frames.new(sim, unit, SP2, [15, 22], func() -> void:
				var near := sim.items_near(unit.tile, 11, 1, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool: return not item.dead)
				if not near.is_empty():
					sim.shoot(unit, near[0], "p.energyBallBullDragon", unit.attack), 6), Callable(), "", COOLDOWN_OLD)
			# The enemies in range take 1.5 times the attack, fly 4 tiles and
			# are electrocuted.
			add(ability, 1, "Electricity", "botonrayos_785", SpecialAttacks.Frames.new(sim, unit, SP1, [25], func() -> void:
				for enemy in sim.items_near(unit.tile, unit.def.attack_range, 20, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.receive_attack(enemy, int(atk * 1.5), unit)
					sim.push_in_air(enemy, unit, 4)
					sim.electrocute(enemy, unit, 0, 5, 45), 4), Callable(), "", COOLDOWN_OLD)
			# For 10 seconds, each second, the units within 3 tiles take 1.5
			# times the attack and fly 4 tiles.
			add(ability, 2, "Spin Attack", "botonremolino_785", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP3, 10 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
				for second in range(1, 10):
					sim.after(second * BattleSim.FRAMES_PER_SECOND, func() -> void: circular_push(sim, unit, 3, 20, int(atk * 1.5), 4)),
					Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Minions", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 784),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 5)
		"golden":
			add(ability, 0, "Dragoncito Aliado", "botonGreenDraggis", SpecialAttacks.Frames.new(sim, unit, SP1, [16], func() -> void: egg_minion(sim, unit, 710)),
					below_minions(3), "", COOLDOWN_OLD)
			add(ability, 1, "Ataque Giratorio", "botonGoldenDragonTorn", func(_s: BattleSim, _f: BattleFighter) -> void: _torning(sim, unit, 8),
					Callable(), "", COOLDOWN_OLD)
			# For 13 seconds the dragon is twice as big and fast, a giant, and
			# has 15 more attack.
			add(ability, 2, "Dragon Colosal", "botonGoldenDragonGiant", SpecialAttacks.Frames.new(sim, unit, SP2, [1], func() -> void:
				var own := unit.ability
				own.scale = 2.0
				own.giant = true
				unit.speed = unit.def.velocity * 2
				unit.attack = unit.def.attack + 15
				sim.state_changed.emit(unit)
				sim.after(13 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					own.scale = 1.0
					own.giant = false
					unit.speed = unit.def.velocity
					unit.attack = unit.def.attack
					sim.state_changed.emit(unit))), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Carga Aerea", "botonGoldenDragonAssQuake", SpecialAttacks.Frames.new(sim, unit, SP5, [15], func() -> void:
				for enemy in sim.items_near(unit.tile, 1, 4, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool: return not item.dead):
					sim.receive_attack(enemy, int(atk * 1.5), unit)
					if enemy.is_unit() and not enemy.dead:
						sim.push_in_air(enemy, unit, 2)), Callable(), "", COOLDOWN_OLD)
			if rider:
				limit_healing(ability, beams(SP3, [23], 50, LIMIT_GREEN_BEAM))
		"light":
			add(ability, 0, "Light Storm", "botonLightStorm", _light_storm(sim, unit, SP3, "p.lightBall"), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Ground Quake", "botonAssQuake", SpecialAttacks.Frames.new(sim, unit, SP2, [15], func() -> void:
				for enemy in sim.items_near(unit.tile, unit.attack_range, 4, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool: return not item.dead):
					sim.receive_attack(enemy, int(atk / 2), unit)
					if enemy.is_unit() and not enemy.dead:
						sim.push_in_air(enemy, unit, 2)), Callable(), "", COOLDOWN_OLD)
			# 6 times every 500 ms, a sixth of a quarter of its life.
			add(ability, 2, "Draconic Healing", "botonDraconicHealing", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP4, 6 * 15, {}, Callable(), true)
				for i in 6:
					sim.after(15 * (i + 1), func() -> void:
						if not unit.dead:
							sim.heal(unit, int(unit.def.life * 0.25 / 6), unit)), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Green Draggy's", "botonGreenDraggis", SpecialAttacks.Frames.new(sim, unit, SP5, [13], func() -> void: egg_minion(sim, unit, 698)),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_smash(ability, SP6, [29], 2, 6, 5)
		"black":
			add(ability, 0, "Light Storm", "boton_ball_fire_multiple", _light_storm(sim, unit, SP2, "p.fireBall_02"), Callable(), "", COOLDOWN_OLD)
			# A red explosion near the dragon hits 5 times, every 16 frames,
			# the items on the 5 x 5 tiles around the dragon: 1.5 times the
			# attack; units burn and fly 4 tiles. The client shows the graphic
			# of the Force Shield spell in red; the port shows a mega explosion.
			add(ability, 1, "Ground Quake", "boton_fire_explosion", SpecialAttacks.Frames.new(sim, unit, SP3, [16], func() -> void:
				sim.particle(unit, unit.tile + Vector2i(2, 2), MagicParticles.MEGA_EXPLOSION, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
				for time in 5:
					sim.after(16 * time, func() -> void:
						if unit.dead:
							return
						for item in sim.items_near(unit.tile, 2, 25, BattleAbility.enemy_side(unit), true, func(other: BattleFighter) -> bool: return not other.dead):
							sim.receive_attack(item, int(atk * 1.5), unit)
							if item.is_unit() and not item.dead:
								sim.incinerate(item, unit, int(atk * 0.2), 5, BattleSim.FRAMES_PER_SECOND)
								sim.push_in_air(item, unit, 4))), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Green Draggy's", "botonGreenDraggis", SpecialAttacks.Frames.new(sim, unit, SP1, [13], func() -> void: egg_minion(sim, unit, 725)),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(UnitSprite.Action.ATTACKING, [13], 50, LIMIT_RED_BEAM))

## A falling star of the Star Dragon hits a unit: half the attack, and 5
## seconds of dizziness when the unit is not dizzy yet.
class _StarHit extends UnitDamage:
	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		sim.receive_attack(target, attacker.def.attack / 2, _source())
		if not target.dead and not target.dizzy:
			Damages.Dizzy.new(sim, attacker, 0, 5, 1).apply(target)


## A heavy rock of the Three-Headed Elemental Dragon: a unit falls into a
## hole and dies, once for each tile; a building takes the attack.
class _HoleHit extends UnitDamage:
	var _holes: Array[Vector2i] = []

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		if not target.is_unit():
			sim.receive_attack(target, attacker.def.attack, _source())
			return
		if target.tile in _holes or target.swallowed:
			return
		_holes.append(target.tile)
		target.incapacitated = true
		sim.particle(attacker, target.tile, MagicParticles.ROCK_HOLE, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void:
			target.swallowed = true
			sim.state_changed.emit(target)
			sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
				if not target.dead:
					sim.kill(target, _source())), true)

	func can_apply(target: BattleFighter) -> bool:
		return target != null and not target.dead


## An acid drop of the Four-Wing Dragon: 1.2 times the attack and poison.
class _AcidHit extends UnitDamage:
	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (target.ability == null or not target.ability.immune_to_poison)

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		sim.receive_attack(target, int(attacker.def.attack * 1.2), _source())
		sim.poison(target, 25, 5, 0, attacker)


## Hell cracks of the Hell Dragon: one under the target, then of its 5
## nearest units in range every second one gets a crack, and the other
## cracks open on random tiles within 1 second. Each crack (at its frame 11)
## hits the 5 nearest enemies within 5 tiles: the attack, a push of 5 tiles,
## then fire.
static func _hell_cracks(sim: BattleSim, unit: BattleFighter) -> void:
	var target := unit.target
	var centre := unit.tile
	var crack := func(tile: Vector2i) -> void: _crack(sim, unit, tile)
	if target != null and not target.dead and target.is_unit():
		centre = target.tile
		crack.call(centre)
	var enemies := sim.items_near(centre, unit.attack_range, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead)
	for i in range(1, 6):
		var enemy: BattleFighter = enemies[i - 1] if i - 1 < enemies.size() else null
		if i % 2 == 0 and enemy != null:
			crack.call(enemy.tile)
		else:
			var reach := unit.attack_range
			var tile := (centre + Vector2i(sim.rng.randi_range(-reach, reach), sim.rng.randi_range(-reach, reach))).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
			sim.after(roundi(sim.rng.randf() * BattleSim.FRAMES_PER_SECOND), func() -> void: crack.call(tile))


static func _crack(sim: BattleSim, unit: BattleFighter, tile: Vector2i) -> void:
	sim.particle(unit, tile, MagicParticles.HELL_INVOCATION, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void:
		if unit.dead:
			return
		var burn := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, unit.attack, 5)).add(Damages.Incinerate.new(sim, unit, 20, 5, 1000))
		for enemy in sim.items_near(tile, 5, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead):
			if burn.can_apply(enemy):
				burn.apply(enemy), true)


## The turning attack of the Golden Dragon and the Epic 2-Head Dragon: for
## ticks seconds the dragon turns and walks slowly with a range of 1; each
## second the items on the 5 x 5 tiles around it take half the attack, and
## units fly 2 tiles.
static func _torning(sim: BattleSim, unit: BattleFighter, ticks: int) -> void:
	unit.speed = 15
	unit.attack_range = 1
	for second in range(1, ticks + 1):
		sim.after(second * BattleSim.FRAMES_PER_SECOND, func() -> void:
			if unit.dead:
				return
			if second == ticks:
				unit.speed = unit.def.velocity
				unit.attack_range = unit.def.attack_range
				return
			for item in sim.items_near(unit.tile, 2, 25, BattleAbility.enemy_side(unit), true, func(other: BattleFighter) -> bool: return not other.dead):
				sim.receive_attack(item, unit.attack / 2, unit)
				if item.is_unit() and not item.dead:
					sim.push_in_air(item, unit, 2))


## The light storm of the Light and Black dragons: for 10 seconds, balls of
## graphic at the target in range, with an explosion where they hit.
static func _light_storm(sim: BattleSim, unit: BattleFighter, animation: int, graphic: String) -> SpecialAttacks.Frames:
	return SpecialAttacks.Frames.new(sim, unit, animation, [12, 16, 20, 24, 28], func() -> void:
		var target := unit.target
		if target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range:
			sim.shoot(unit, target, graphic, unit.attack, func(_shot: BattleProjectile) -> void:
				sim.particle(unit, target.tile, MagicParticles.BALL_EXPLOSION, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)), 10)
