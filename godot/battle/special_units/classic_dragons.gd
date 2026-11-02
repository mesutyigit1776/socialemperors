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
}
const RIDERS: Array[int] = [2038, 851, 2050, 2065, 2041, 2015, 2018, 2058, 2045]
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

## A falling star of the Star Dragon hits a unit: half the attack, and 5
## seconds of dizziness when the unit is not dizzy yet.
class _StarHit extends UnitDamage:
	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		sim.receive_attack(target, attacker.def.attack / 2, _source())
		if not target.dead and not target.dizzy:
			Damages.Dizzy.new(sim, attacker, 0, 5, 1).apply(target)
