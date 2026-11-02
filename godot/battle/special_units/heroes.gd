class_name Heroes
extends SpecialUnit
## Special units with few buttons that their delegates of the client make:
## hunters, healers, the Big Lure, the Chameleon, the Fire Soul Eater, the
## Mother Monster, the Celestial Dragon and the dragons that have only a
## limit button.

const UNITS := {
	886: "angelical_healer",
	2087: "big_lure",
	896: "chameleon",
	872: "dragon_hunter",
	873: "dragon_hunter_2",
	894: "monster_hunter",
	2081: "fire_soul_eater",
	2127: "mother_monster",
	793: "celestial", 843: "celestial",
	836: "double_head_rider",
	832: "furious_red_rider",
	839: "infernal_rider",
	833: "lightning_rider",
	2090: "infraworld_colossus",
	2099: "golden_slayer",
	897: "scarab_rider",
}
const COOLDOWN_OLD := 25
const HUNTER_TILES := 5
const HUNTER_UNITS := 5
const CHAMELEON_SECONDS := 30
const LURE_RANGE := 17
const LURE_SECONDS := 15


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	match kind:
		"angelical_healer":
			# The limit fills with healing; the 5 nearest own units within 7
			# tiles get 500 life.
			limit_special(ability, SP1, [40], func(battle: BattleSim, healer: BattleFighter) -> void:
				battle.particle(healer, healer.tile, MagicParticles.STARS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
				for ally in battle.items_near(healer.tile, 7, 5, healer.team, false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
					battle.heal(ally, 500, healer))
			ability.limit_type = BattleAbility.LimitType.HEALTH
		"big_lure":
			# The enemy units within 17 tiles (at most 10) attack the lure.
			add(ability, 0, "Mega Slash", "biglure_button", SpecialAttacks.Frames.new(sim, unit, SP2, [33], func() -> void:
				for enemy in sim.items_near(unit.tile, LURE_RANGE, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.set_target(enemy, unit)), func(_s: BattleSim, _f: BattleFighter) -> bool:
						return not sim.items_near(unit.tile, LURE_RANGE, 1, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead).is_empty(), "No target within range")
		"chameleon":
			add(ability, 0, "Absorbe Powers", "btn_chamaleon", func(_s: BattleSim, _f: BattleFighter) -> void: _absorb_powers(sim, unit),
					func(_s: BattleSim, fighter: BattleFighter) -> bool:
						return fighter.target != null and fighter.target.is_unit() and not fighter.target.dead and sim.distance(fighter, fighter.target) <= fighter.attack_range + 1,
					"No targets in range", COOLDOWN_OLD)
		"dragon_hunter", "dragon_hunter_2", "monster_hunter":
			var damage := 1500 if kind == "dragon_hunter_2" else 900
			if kind == "monster_hunter":
				add(ability, 0, "Rays Attack", "3_hunter", SpecialAttacks.Frames.new(sim, unit, SP1, [13, 15, 45], func() -> void:
					for enemy in sim.items_near(unit.tile, 3, 4, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool: return not item.dead):
						Damages.Freeze.new(sim, unit, atk / 8 * 4, 2.4, 4).apply(enemy)), Callable(), "", COOLDOWN_OLD)
				add(ability, 1, "Sword Jump", "2_hunter", SpecialAttacks.Frames.new(sim, unit, SP2, [20], func() -> void:
					circular_push(sim, unit, 3, 5, unit.attack, 3)), Callable(), "", COOLDOWN_OLD)
			else:
				var second := kind == "dragon_hunter_2"
				add(ability, 0, "Whirlwind", "btn_axe_spin" if second else "btn_dragon_hunter_whirlwind", func(_s: BattleSim, _f: BattleFighter) -> void:
					# 5 hits, one each second, on the units within 2 tiles.
					sim.play_special(unit, SP1, 5 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
					for i in 5:
						sim.after(i * BattleSim.FRAMES_PER_SECOND, func() -> void:
							if not unit.dead:
								for enemy in sim.items_near(unit.tile, 2, 20, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
										return item.is_unit() and not item.dead):
									sim.push_in_air(enemy, unit, 3)
									sim.receive_attack(enemy, int(atk * 1.2), unit)), Callable(), "", COOLDOWN_OLD)
				add(ability, 1, "Healing", "btn_autoheal" if second else "btn_dragon_hunter_heal", func(_s: BattleSim, _f: BattleFighter) -> void:
					sim.play_special(unit, SP2, BattleSim.FRAMES_PER_SECOND, {}, Callable(), true)
					sim.heal(unit, 500, unit), Callable(), "", COOLDOWN_OLD)
				if second:
					# For 10 seconds the hunter takes half the damage.
					add(ability, 2, "ForceField", "btn_forcefield", func(_s: BattleSim, _f: BattleFighter) -> void:
						unit.damage_factor = 0.5
						sim.after(10 * BattleSim.FRAMES_PER_SECOND, func() -> void: unit.damage_factor = 1.0), Callable(), "", COOLDOWN_OLD)
			# The limit (a quarter of the usual bar) hits the nearest dragon
			# within 5 tiles, or for the Monster Hunter the nearest other unit
			# with at least 900 life: it takes the damage and flies 3 tiles.
			ability.limit_max = BattleAbility.LIMIT_MAX / 4
			var prey := func(battle: BattleSim, hunter: BattleFighter) -> BattleFighter:
				var found := battle.items_near(hunter.tile, HUNTER_TILES, HUNTER_UNITS, BattleAbility.enemy_side(hunter), true, func(item: BattleFighter) -> bool:
					if not item.is_unit() or item.dead:
						return false
					return item.health >= damage and item.def.groups != "dragon" if kind == "monster_hunter" else item.def.groups == "dragon")
				return found[0] if not found.is_empty() else null
			limit_special(ability, SP3, [33], func(battle: BattleSim, hunter: BattleFighter) -> void:
				var target: BattleFighter = prey.call(battle, hunter)
				if target != null:
					battle.push_in_air(target, hunter, 3)
					battle.receive_attack(target, damage, hunter), func(battle: BattleSim, hunter: BattleFighter) -> bool:
						var target: BattleFighter = prey.call(battle, hunter)
						if target != null:
							battle.set_target(hunter, target)
						return target != null,
					"MONSTER_HUNTER_NO_UNITS_IN_RANGE" if kind == "monster_hunter" else "DRAGON_HUNTER_NO_DRAGONS_IN_RANGE")
		"fire_soul_eater":
			var eater := unit.ability as SoulEaterAbility
			add(ability, 0, "Fire Rays", "2081_fire_soul_eater_sw1", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP2, BattleSim.FRAMES_PER_SECOND, {20: func() -> void: eater.soul_beam(sim, unit)}, Callable(), true),
					Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Smash", "2081_fire_soul_eater_sw2", SpecialAttacks.Frames.new(sim, unit, SP1, [31], func() -> void: eater.soul_smash(sim, unit)),
					Callable(), "", COOLDOWN_OLD)
		"mother_monster":
			add(ability, 0, "Minions", "botonGreenDraggis", SpecialAttacks.Frames.new(sim, unit, SP2, [33], func() -> void: egg_minion(sim, unit, 2128)),
					below_minions(3), "3 " + MINIONS_MAX)
		"celestial":
			var damaging := [true]
			add(ability, 0, "Energy Balls", "boton_bolas_793", SpecialAttacks.Frames.new(sim, unit, SP2, [20, 24, 28, 32, 36, 40], func() -> void:
				# Every second ball does no damage.
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.energyBall", unit.attack if damaging[0] else -1)
				damaging[0] = not damaging[0]), func(_s: BattleSim, fighter: BattleFighter) -> bool:
					return fighter.target != null and sim.distance(fighter, fighter.target) <= fighter.attack_range and not fighter.ability.in_limit_attack,
					"", COOLDOWN_OLD)
			# For 5.2 seconds, every 300 ms, 10 laser lightnings around the target.
			add(ability, 1, "Electricity", "boton_rayos_793", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP3, 15 + roundi(5.2 * BattleSim.FRAMES_PER_SECOND), {}, Callable(), true)
				for tick in range(15 + 9, 15 + roundi(5.2 * BattleSim.FRAMES_PER_SECOND), 9):
					sim.after(tick, func() -> void:
						if not unit.dead:
							BattleAbility.arrow_storm(sim, unit, MagicParticles.LIGHTING_LASER, 10, 3, 0.65, 5, 5)), _not_in_limit(), "", COOLDOWN_OLD)
			# 20 loops of a whirlwind.
			add(ability, 2, "Whirlwind Attack", "boton_remolino_793", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 20 + 8 * 20, {}, Callable(), false)
				for i in 21:
					sim.after(20 + 8 * i, func() -> void:
						if not unit.dead:
							sim.whirlwind(unit, 0.65, 2)), _not_in_limit(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Draggies", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 814),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return not fighter.ability.in_limit_attack and fighter.ability.minions_alive < 3,
					"", COOLDOWN_OLD)
			if unit.def.id == 843:
				limit_healing(ability, beams(SP1, [17], 50, LIMIT_GREEN_BEAM))
		"double_head_rider", "lightning_rider":
			limit_smash(ability, SP4, [29], 2, 6, 5)
		"furious_red_rider":
			limit_lightning(ability, beams(SP3, [15], 50, LIMIT_RED_BEAM))
		"infernal_rider":
			# The beams come from the normal attack animation, which stops meanwhile.
			limit_lightning(ability, LimitAttacks.Beams.new(UnitSprite.Action.ATTACKING, [15], 100, 50, LIMIT_RED_BEAM, 0.25, true))

		"infraworld_colossus":
			var cant := "No targets in sight"
			var in_range := func(_s: BattleSim, fighter: BattleFighter) -> bool: return not _near(sim, fighter, fighter.attack_range, 20).is_empty()
			# For 4 seconds: a beam at the first enemy in range; while it lives,
			# the next hits take 1.5 times the attack.
			var hit := [null]
			add(ability, 0, "Rays!", "2090_infra_colossus_1", SpecialAttacks.Frames.new(sim, unit, SP1, [10], func() -> void:
				var enemies := _near(sim, unit, unit.attack_range, 20)
				if enemies.is_empty():
					return
				if enemies[0] != hit[0]:
					hit[0] = enemies[0]
					sim.shoot(unit, enemies[0], "p.dualBeamPurple", unit.attack)
				else:
					sim.receive_attack(enemies[0], int(atk * 1.5), unit), 4), in_range, cant)
			# The smash of the limit settings of the client, as a button.
			add(ability, 1, "Jump!", "2090_infra_colossus_2", func(battle: BattleSim, fighter: BattleFighter) -> void:
				LimitAttacks.smash(battle, fighter, SP3, [33], 2, 4, 6), in_range, cant)
			add(ability, 2, "Deadly Breath!", "2090_infra_colossus_3", SpecialAttacks.Frames.new(sim, unit, SP2, [21], func() -> void:
				for enemy in _near(sim, unit, unit.attack_range, 20):
					Damages.Freeze.new(sim, unit, sim.rng.randi_range(15, 20) * 3, 3, 3).apply(enemy)
					sim.receive_attack(enemy, int(atk * 0.75), unit)), in_range, cant)
			# A soul whirlwind that cannot die comes next to the colossus.
			add(ability, 3, "Souls Attack!", "2090_infra_colossus_4", SpecialAttacks.Frames.new(sim, unit, SP4, [50], func() -> void:
				var soul := sim.spawn(sim.config_item(2110), unit.tile + Vector2i(2, 2), unit.team)
				if soul != null:
					soul.cannot_die = true
				unit.ability.add_limit(sim, unit, int(atk * 3), false)), Callable(), cant)
			# The deadly hole (the limit button, with a cooldown of 24 seconds):
			# up to 20 enemy units within 7 tiles that attack and have at most
			# 500 life fall into it and die.
			ability.has_limit = true
			var eatable := func(fighter: BattleFighter) -> Array[BattleFighter]:
				return sim.items_near(fighter.tile, 7, 20, BattleAbility.enemy_side(fighter), false, func(item: BattleFighter) -> bool:
					return item.is_unit() and not item.dead and item.attack > 0 and item.health <= 500)
			add(ability, BattleAbility.LIMIT_BUTTON, "Deadly Hole!", "", SpecialAttacks.Frames.new(sim, unit, SP5, [22], func() -> void:
				var prey: Array[BattleFighter] = eatable.call(unit)
				for i in prey.size():
					var target := prey[i]
					target.incapacitated = true
					target.swallowed = true
					sim.state_changed.emit(target)
					sim.after(2 * (i / ceili(prey.size() / 10.0)) + 15, func() -> void:
						if not target.dead:
							sim.kill(target, unit))), func(_s: BattleSim, fighter: BattleFighter) -> bool: return not eatable.call(fighter).is_empty(), cant)
		"golden_slayer":
			var cant := "No targets in sight"
			add(ability, 0, "Sword!", "2099_medieval_slayer_btn1", SpecialAttacks.Frames.new(sim, unit, SP1, [28], func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					if target.is_unit():
						sim.push_in_air(target, unit, 3)
					sim.receive_attack(target, int(atk * 5), unit)), func(_s: BattleSim, fighter: BattleFighter) -> bool:
						return fighter.target != null and sim.distance(fighter, fighter.target) <= 3, cant)
			# 3 loops of 11 beams at the enemies within 8 tiles; each enemy takes
			# at most 500 / the number of enemies from them.
			add(ability, 1, "Beams!", "2099_medieval_slayer_btn2", func(_s: BattleSim, _f: BattleFighter) -> void: _slayer_beams(sim, unit),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return not _near(sim, fighter, 8, 10).is_empty(), cant)
			# 30 loops; every third loop, the 8 nearest enemies within 3 tiles
			# take half the attack and fly 3 tiles.
			add(ability, 2, "Whirlwind!", "2099_medieval_slayer_btn3", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP3, 30 * 8 + 5, {}, Callable(), false)
				for loop in range(0, 30, 3):
					sim.after(5 + loop * 8, func() -> void:
						if not unit.dead:
							circular_push(sim, unit, 3, 8, unit.attack / 2, 3)))
			# A drone comes within 4 tiles; at most 3.
			add(ability, 3, "Drone!", "2099_medieval_slayer_btn4", func(_s: BattleSim, _f: BattleFighter) -> void:
				var tile := unit.tile + Vector2i(sim.rng.randi_range(-4, 4), sim.rng.randi_range(-4, 4))
				var drone := sim.spawn(sim.config_item(2103), tile.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1)), unit.team)
				if drone != null:
					unit.ability.add_minion(sim, drone)
					if unit.target != null:
						sim.set_target(drone, unit.target), below_minions(3), "Max 3 drones")
		"scarab_rider":
			var busy := func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.forced_action < 0
			add(ability, 0, "Fly attack", "897_scarab_rider_button1", func(_s: BattleSim, _f: BattleFighter) -> void: _scarab_fly(sim, unit),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return _scarab_prey(sim, fighter) != null, "No small units in range")
			# 15 loops; every third loop a whirlwind.
			add(ability, 1, "Whirlwind", "897_scarab_rider_button2", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 14 + 15 * 8, {}, Callable(), true)
				for loop in range(0, 15, 3):
					sim.after(14 + loop * 8, func() -> void:
						if not unit.dead:
							sim.whirlwind(unit, 0.45, 2)), busy)
			# 5 scarabs come within 4 tiles; each lives 15 seconds.
			add(ability, 2, "Spawn Minions", "897_scarab_rider_button3", func(_s: BattleSim, _f: BattleFighter) -> void:
				for i in 5:
					var tile := (unit.tile + Vector2i(sim.rng.randi_range(-4, 4), sim.rng.randi_range(-4, 4))).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
					var scarab := sim.spawn(sim.config_item(898), tile, unit.team)
					if scarab == null:
						continue
					if unit.target != null:
						sim.set_target(scarab, unit.target)
					sim.after(15 * BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not scarab.dead:
							sim.kill(scarab, null)), busy)

static func _not_in_limit() -> Callable:
	return func(_s: BattleSim, fighter: BattleFighter) -> bool: return not fighter.ability.in_limit_attack


## The Chameleon takes the life part, the attack, the range, the speed, the
## shots and the look of its target for 30 seconds; its own button is gone
## meanwhile, as the client empties the buttons.
static func _absorb_powers(sim: BattleSim, unit: BattleFighter) -> void:
	var target := unit.target
	if target == null or target.dead or not target.is_unit() or target.incapacitated:
		return
	var own_ability := unit.ability
	var part := float(unit.health) / unit.max_health
	_copy_stats(unit, target.def, part)
	var copied := AbilityTable.create(target.def.id)
	unit.ability = copied if copied != null else BattleAbility.new()
	unit.ability.limit_max = own_ability.limit_max
	sim.particle(unit, target.tile, MagicParticles.STARS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
	sim.change_look(unit, target.def)
	sim.after(CHAMELEON_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
		if unit.dead:
			return
		_copy_stats(unit, unit.def, float(unit.health) / unit.max_health)
		unit.ability = own_ability
		sim.change_look(unit, null))


static func _copy_stats(unit: BattleFighter, source: GameConfig.ItemDef, life_part: float) -> void:
	unit.max_health = source.life
	unit.health = maxi(int(source.life * life_part), 1)
	unit.attack = source.attack
	unit.attack_range = source.attack_range
	unit.attack_interval = source.attack_interval
	unit.speed = source.velocity


## The enemy units within range_tiles of the unit, at most count.
static func _near(sim: BattleSim, unit: BattleFighter, range_tiles: int, count: int) -> Array[BattleFighter]:
	return sim.items_near(unit.tile, range_tiles, count, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead)


static func _slayer_beams(sim: BattleSim, unit: BattleFighter) -> void:
	var enemies := _near(sim, unit, 8, 10)
	if enemies.is_empty():
		return
	var limit := ceili(500.0 / enemies.size())
	var dealt := {}
	var frames := [20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 59]
	var events := {}
	for loop in 3:
		for frame: int in frames:
			events[loop * 59 + frame] = func() -> void:
				var target: BattleFighter = null
				for enemy in enemies:
					if not enemy.dead and dealt.get(enemy, 0) < limit:
						target = enemy
						break
				if target == null or unit.dead:
					return
				var amount := int(unit.attack * 0.5)
				var done: int = dealt.get(target, 0)
				if done > limit - 1:
					amount = 5
				elif done + amount > limit - 10:
					amount = limit - 10 - done
				sim.shoot_beam(unit, target, target.tile, "p.yellowLightning", 5, -1)
				sim.receive_attack(target, maxi(amount, 0), unit)
				dealt[target] = done + amount
	sim.play_special(unit, SP2, 3 * 59 + 5, events, Callable(), true)


## The nearest enemy unit within 6 tiles with at most 350 life that is not a
## boss, for the Scarab Rider.
static func _scarab_prey(sim: BattleSim, unit: BattleFighter) -> BattleFighter:
	var found := sim.items_near(unit.tile, 6, 1, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and item.def.life <= 350 and item.def.subcat_functional != BattleSim.SUBCAT_BOSS and not item.incapacitated)
	return found[0] if not found.is_empty() else null


## The Scarab Rider flies fast next to its prey, grabs it and eats it.
static func _scarab_fly(sim: BattleSim, unit: BattleFighter) -> void:
	var prey := _scarab_prey(sim, unit)
	if prey == null:
		return
	prey.incapacitated = true
	var speed := unit.speed
	unit.speed = 114
	sim.order_walk(unit, prey.tile)
	var watch := func(again: Callable) -> void:
		if unit.dead:
			return
		if unit.moving and sim.distance(unit, prey) > 1:
			sim.after(1, again.bind(again))
			return
		unit.speed = speed
		sim.play_special(unit, SP2, 40, {7: func() -> void:
			prey.swallowed = true
			sim.state_changed.emit(prey), 35: func() -> void:
				if not prey.dead:
					sim.kill(prey, unit)}, Callable(), true)
	sim.after(1, watch.bind(watch))
