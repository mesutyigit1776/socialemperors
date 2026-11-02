class_name BahamutDragons
extends SpecialUnit
## The bahamut dragons and their riders. The client writes most of these
## attacks in the unit classes themselves; the first bahamuts have a cooldown
## of 25 seconds.

const UNITS := {
	2000: "paladin", 2002: "paladin",
	2003: "supreme",
	891: "black", 893: "black",
	862: "electric", 864: "electric",
	2315: "fireborn", 2317: "fireborn",
	875: "golden", 877: "golden",
	846: "green", 852: "green",
	853: "red", 855: "red",
	2121: "sky", 2123: "sky",
}
const RIDERS: Array[int] = [2002, 893, 864, 2317, 877, 852, 855, 2123]
const COOLDOWN_OLD := 25
const DRAGGIES := "botonGreenDraggis"
const DRAGGIES_MAX := "3 draggies max"


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider := unit.def.id in RIDERS
	var draggies := func(minion_id: int, maximum := 3) -> void:
		add(ability, 3, "Spawn Draggies", DRAGGIES, func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, minion_id),
				below_minions(maximum), DRAGGIES_MAX if maximum == 3 else "%d draggies max" % maximum, COOLDOWN_OLD if kind in ["black", "electric", "golden", "green", "red"] else COOLDOWN)
	match kind:
		"paladin":
			add(ability, 0, "Red Rays", "btn_red_rays_2000", SpecialAttacks.Frames.new(sim, unit, SP2, [21, 30], func() -> void:
				for i in 2:
					_shoot_target(sim, unit, "p.goldenDragon", unit.attack), 5))
			# The sword kills a target unit with at most 350 life, or takes 350
			# points; the units within 5 tiles of it take a quarter of the attack.
			add(ability, 1, "Sword Smash", "btn_sword_smash_2000", SpecialAttacks.Frames.new(sim, unit, SP3, [40, 45, 50], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				if target.is_unit() and target.health <= 350:
					sim.kill(target, unit)
				else:
					sim.receive_attack(target, 350, unit)
				for enemy in _units_near(sim, unit, target.tile, 5, 10):
					sim.receive_attack(enemy, int(atk / 4), unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, 3)))
			add(ability, 2, "Whirlwind", "btn_whirlwind_2000", _whirl_frames(sim, unit, SP1, [17, 22], 10, func(enemy: BattleFighter) -> void:
				sim.receive_attack(enemy, int(atk / 4), unit)
				if not enemy.dead:
					sim.push_in_air(enemy, unit, 3)))
			draggies.call(2001)
			if rider:
				limit_lightning(ability, beams(SP1, [16], 50, LIMIT_RED_BEAM))
		"supreme":
			ability.giant = true
			add(ability, 0, "Energy Balls", "btn_energyballs_2003", SpecialAttacks.Frames.new(sim, unit, SP3, [25, 30, 35, 40, 45], func() -> void:
				for i in 2:
					_shoot_target(sim, unit, "p.multicolredEnergyBall", unit.attack), 8))
			add(ability, 1, "Energy Rain", "btn_energy_rain_2003", SpecialAttacks.Frames.new(sim, unit, SP1, [15], func() -> void:
				BattleAbility.arrow_storm(sim, unit, MagicParticles.MULTICOLOR_RAIN, 45, 5, 0.65, 5, 60)))
			# At most 5 units are poisoned at a time.
			var poisoned: Array[BattleFighter] = []
			add(ability, 2, "Energy Whirlwind", "btn_whirlwind_2003", _whirl_frames(sim, unit, SP2, [24, 28, 32, 36], 12, func(enemy: BattleFighter) -> void:
				sim.receive_attack(enemy, int(atk), unit)
				poisoned.assign(poisoned.filter(func(item: BattleFighter) -> bool: return not item.dead))
				if not enemy.dead and poisoned.size() < 5 and not enemy in poisoned:
					sim.poison(enemy, 5, 1000, 0, unit)
					poisoned.append(enemy)
				sim.absorb_and_push(enemy, unit, 2), true))
			add(ability, 3, "Spawn Draggies", DRAGGIES, func(_s: BattleSim, _f: BattleFighter) -> void:
				egg_minion(sim, unit, 2004)
				sim.after(8, func() -> void: egg_minion(sim, unit, 2004)), below_minions(6), "6 draggies max")
		"black":
			ability.giant = true
			add(ability, 0, "Lightnings", "black_bahamut_rayos", func(_s: BattleSim, _f: BattleFighter) -> void:
				SpecialAttacks.Frames.new(sim, unit, SP2, [20, 24, 28], func() -> void:
					var target := unit.target
					if target != null and not target.dead and sim.distance(unit, target) <= rng:
						for i in 2:
							sim.shoot_beam(unit, target, target.tile, LIMIT_RED_BEAM, 6, 0), 4).execute()
				# The target in range takes 0.7 times the attack every 500 ms for 4 seconds.
				for tick in range(15, 4 * BattleSim.FRAMES_PER_SECOND + 16, 15):
					sim.after(tick, func() -> void:
						var target := unit.target
						if not unit.dead and target != null and not target.dead and sim.distance(unit, target) <= rng:
							sim.receive_attack(target, int(atk * 0.7), unit)), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Smash", "black_bahamut_salto", SpecialAttacks.Frames.new(sim, unit, SP3, [38], func() -> void:
				circular_push(sim, unit, 5, 10, int(atk))), Callable(), "", COOLDOWN_OLD)
			# The whirlwind pulls in and kills up to 3 units with at most 350 life.
			var absorbed := [0]
			add(ability, 2, "Whirlwind", "black_bahamut_whirlwind", func(_s: BattleSim, _f: BattleFighter) -> void:
				absorbed[0] = 0
				_whirl_frames(sim, unit, SP1, [20, 24], 3, func(enemy: BattleFighter) -> void:
					if absorbed[0] < 3 and enemy.def.life <= 350:
						absorbed[0] += 1
						_absorb_and_kill(sim, unit, enemy)
					else:
						sim.receive_attack(enemy, int(atk / 3), unit)
						sim.absorb_and_push(enemy, unit, 2)).execute(), Callable(), "", COOLDOWN_OLD)
			draggies.call(892)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 5)
		"electric":
			add(ability, 0, "Shoot Balls", "btn-bolas-azules", SpecialAttacks.Frames.new(sim, unit, SP2, [22, 26, 30, 34], func() -> void:
				_shoot_target(sim, unit, "p.crystalBall", unit.attack), 5), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Electric Whirlwind", "btn-magia-huracan-electrico", _whirl_frames(sim, unit, SP1, [24, 30, 36], 10, func(item: BattleFighter) -> void:
				sim.receive_attack(item, int(atk / 2), unit)
				if not item.dead:
					sim.push_in_air(item, unit, 2)
					sim.electrocute(item, unit, 0, 10, 3)), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Auto-Heal", "btn-magia-curar", SpecialAttacks.Frames.new(sim, unit, SP3, [15], func() -> void: sim.heal(unit, 300, unit)),
					Callable(), "", COOLDOWN_OLD)
			draggies.call(868)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 5)
		"fireborn":
			add(ability, 0, "INFERNO BEAM", thumb(2315, "firebornBahamutDragonUnit", 1), SpecialAttacks.MultiBeam.new(sim, unit, SP1, [18],
					"p.fireBeam01", rng * 2, 1, atk * 3.61, 2.8, true).with_hold_enemies(true), has_target(), NO_TARGET)
			var hit := [0]
			var whip := Damages.ChosenByFilter.new(sim, unit) \
					.add(Damages.DirectKill.new(sim, unit, 500), func(target: BattleFighter) -> bool:
						if hit[0] >= 1 or target.max_life() > 500:
							return false
						hit[0] += 1
						return true) \
					.add(Damages.PushInAir.new(sim, unit, 50, 4), func(_target: BattleFighter) -> bool:
						hit[0] += 1
						return true)
			add(ability, 1, "FLAMING WHIP", thumb(2315, "firebornBahamutDragonUnit", 2), SpecialAttacks.Area.new(sim, unit, SP2, [30], whip,
					int(rng * 1.3), 5).with_end_action(func() -> void: hit[0] = 0), has_target(), NO_TARGET)
			var clap := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 3.59, 4).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 10, 6, 10)).with_shared(true)
			add(ability, 2, "RADIAL FIRE-CLAP", thumb(2315, "firebornBahamutDragonUnit", 3), SpecialAttacks.Area.new(sim, unit, SP3, [21], clap, rng, 8),
					has_target(), NO_TARGET)
			add_minions(ability, 3, "FIREBORN BAHAMUT DRAGGY", thumb(2315, "firebornBahamutDragonUnit", 4), SpecialAttacks.SpawnMinion.new(sim, unit, 2316, 1))
			if rider:
				limit_lightning(ability, beams(SP4, [15], 50, LIMIT_RED_BEAM))
		"golden":
			ability.giant = true
			# The enemy units within 6 tiles (at most 8) turn to gold statues
			# for 8 seconds: they cannot act.
			add(ability, 0, "Circular Shine", "botonGoldenBahamutShine", SpecialAttacks.Frames.new(sim, unit, SP4, [25], func() -> void:
				for enemy in _units_near(sim, unit, unit.tile, 6, 8):
					Damages.Simple.new(sim, unit, 0, 8, 1).apply(enemy)), Callable(), "", COOLDOWN_OLD)
			var eatable := func(item: BattleFighter) -> bool:
				return item.def.life <= 350 and not item.incapacitated and item.def.subcat_functional != BattleSim.SUBCAT_BOSS
			add(ability, 1, "Grab Enemies", "botonGoldenBahamutGrab", SpecialAttacks.Eat.new(sim, unit, SP2, [1], [81],
					Damages.DirectKill.new(sim, unit), ["sub", "sub2"], 2).with_filter(eatable),
					func(_s: BattleSim, _f: BattleFighter) -> bool: return not _units_near(sim, unit, unit.tile, 2, 2, eatable).is_empty(),
					"No enemies", COOLDOWN_OLD)
			add(ability, 2, "Whirlwind", "botonGoldenBahamutWhirl", SpecialAttacks.Frames.new(sim, unit, SP1, [25], func() -> void:
				for enemy in _units_near(sim, unit, unit.tile, 4, 4):
					sim.receive_attack(enemy, int(atk * 0.5), unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, 3), 4), Callable(), "", COOLDOWN_OLD)
			draggies.call(876)
			if rider:
				limit_healing(ability, beams(SP3, [14], 50, LIMIT_GREEN_BEAM))
		"green":
			add(ability, 0, "Shoot Beam", "bolas_846", SpecialAttacks.Frames.new(sim, unit, SP2, [16, 20, 24, 28, 32, 36], func() -> void:
				_shoot_target(sim, unit, "p.lavaBall_01", unit.attack), 5), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Smash Attack", "pisoton_846", _whirl_frames(sim, unit, SP3, [38, 42, 46], 0, func(enemy: BattleFighter) -> void:
				sim.receive_attack(enemy, int(atk * 1.5), unit)
				if not enemy.dead:
					sim.push_in_air(enemy, unit, 4)), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Spawn Octospuss", "huracan_846", _whirl_frames(sim, unit, SP1, [15, 19], 10, func(enemy: BattleFighter) -> void:
				sim.receive_attack(enemy, int(atk), unit)
				sim.absorb_and_push(enemy, unit, 2)), Callable(), "", COOLDOWN_OLD)
			# Two draggies, one egg after the other.
			add(ability, 3, "Spawn Octospuss", DRAGGIES, func(_s: BattleSim, _f: BattleFighter) -> void:
				egg_minion(sim, unit, 850)
				sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void: egg_minion(sim, unit, 850)), below_minions(3), DRAGGIES_MAX, COOLDOWN_OLD)
			if rider:
				limit_healing(ability, beams(SP1, [17], 50, LIMIT_GREEN_BEAM))
		"red":
			add(ability, 0, "Flies", "redbaha_fuego", func(_s: BattleSim, _f: BattleFighter) -> void: _fly(sim, unit),
					func(_s: BattleSim, _f: BattleFighter) -> bool: return _fly_tile(sim, unit) != null,
					"You are too close to a building, wall or tree", COOLDOWN_OLD)
			add(ability, 1, "Wing attack", "redbaha_bola", SpecialAttacks.Frames.new(sim, unit, SP3, [28], func() -> void:
				var target := unit.target
				if target == null or target.dead or sim.distance(unit, target) > rng + 1:
					return
				sim.shoot(unit, target, "p.fireballBahamut", -1, func(shot: BattleProjectile) -> void:
					for enemy in _units_near(sim, unit, IsoGrid.map_to_tile(shot.end), 3, 10):
						sim.receive_attack(enemy, int(atk * 2), unit)
						if not enemy.dead:
							sim.push_in_air(enemy, unit, 2))), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Whirl", "redbaha_whirl", _whirl_frames(sim, unit, SP1, [24, 31], 10, func(enemy: BattleFighter) -> void:
				sim.receive_attack(enemy, int(atk), unit)
				sim.absorb_and_push(enemy, unit, 2)), Callable(), "", COOLDOWN_OLD)
			draggies.call(854)
			if rider:
				limit_lightning(ability, beams(SP1, [23], 50, LIMIT_RED_BEAM))
		"sky":
			add(ability, 0, "Shoot Balls", "btn_sky_balls", SpecialAttacks.Frames.new(sim, unit, SP1, [30, 40], func() -> void:
				_shoot_target(sim, unit, "p.crystalBall", unit.attack), 6), has_target(), "No targets in range")
			add(ability, 1, "Ultra Fireball", "btn_sky_feathers", SpecialAttacks.Frames.new(sim, unit, SP2, [44], func() -> void:
				circular_push(sim, unit, 8, 10, int(atk * 1.25), 10)), has_target(), "No target within range")
			# For 10 seconds, every 500 ms after 20 frames, the 10 nearest units
			# within 6 tiles take the attack and fly 5 tiles.
			add(ability, 2, "Hyper Whirlwind", "btn_sky_whirlwind", SpecialAttacks.Whirlwind.new(sim, unit, SP3, 10, 20,
					Damages.PushInAir.new(sim, unit, atk, 5), 6, 10).with_interval(500))
			draggies.call(2122)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 5)


## A shot of graphic at the target of the unit within its range.
static func _shoot_target(sim: BattleSim, unit: BattleFighter, graphic: String, damage: int) -> void:
	var target := unit.target
	if not unit.dead and target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range:
		sim.shoot(unit, target, graphic, damage)


## The enemy units within range_tiles of tile, at most count, that can fly.
static func _units_near(sim: BattleSim, unit: BattleFighter, tile: Vector2i, range_tiles: int, count: int, extra := Callable()) -> Array[BattleFighter]:
	return sim.items_near(tile, range_tiles, count, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push) and (not extra.is_valid() or extra.call(item)))


## An animation of the bahamut whirlwinds: at frames (in a loop for seconds,
## or once when seconds is 0), hit acts on each of the 10 nearest units
## within 2 tiles of the dragon that can fly. The unit can still be hurt
## and does not stop (the client does not incapacitate it) unless stop.
static func _whirl_frames(sim: BattleSim, unit: BattleFighter, animation: int, frames: Array, seconds: float, hit: Callable, stop := false) -> SpecialAttacks.Frames:
	var attack := SpecialAttacks.Frames.new(sim, unit, animation, frames, func() -> void:
		if unit.dead:
			return
		for item in sim.items_near(unit.tile, 2, 10, BattleAbility.enemy_side(unit), false, func(other: BattleFighter) -> bool:
				return other.is_unit() and not other.dead and other != unit and (other.ability == null or not other.ability.immune_to_push)):
			hit.call(item), seconds)
	attack.incapacitate = stop
	return attack


## The unit flies half the way to the dragon and dies when it lands (absorbAndKill).
static func _absorb_and_kill(sim: BattleSim, unit: BattleFighter, enemy: BattleFighter) -> void:
	if enemy.incapacitated or enemy.def.subcat_functional == BattleSim.SUBCAT_BOSS or (enemy.ability != null and enemy.ability.giant):
		return
	sim.push_in_air(enemy, unit, -maxi(sim.distance(enemy, unit) / 2, 1))
	sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
		if not enemy.dead:
			sim.kill(enemy, unit))


## The tile at twice the attack range in front of the Red Bahamut, in the
## four directions of the client, or the last free tile before an obstacle;
## null when the next tile is not free (getDirectionalTile).
static func _fly_tile(sim: BattleSim, unit: BattleFighter) -> Variant:
	var step := Vector2i(0, 1)
	match BattleAbility.direction(unit):
		1, 2: step = Vector2i(0, -1)
		3, 4, 5: step = Vector2i(1, 0)
		6: step = Vector2i(-1, 0)
	var last: Variant = null
	for i in range(1, unit.attack_range * 2 + 1):
		var tile := unit.tile + step * i
		if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile) or not sim.is_free(tile):
			break
		last = tile
	return last


## The Red Bahamut flies fast to the tile in front of it. On each tile, a fire
## comes up and the units within 3 tiles take its attack, burn and fly 2 tiles.
static func _fly(sim: BattleSim, unit: BattleFighter) -> void:
	var goal: Variant = _fly_tile(sim, unit)
	if goal == null:
		return
	var speed := unit.speed
	unit.speed = 114
	sim.play_special(unit, SP2, 10 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
	sim.order_walk(unit, goal)
	var last := [unit.tile]
	var watch := func(again: Callable) -> void:
		if unit.dead:
			return
		if unit.tile != last[0]:
			last[0] = unit.tile
			sim.particle(unit, unit.tile, MagicParticles.FIRE_RED, 5, 0)
			for enemy in sim.items_near(unit.tile, 3, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
					return item.is_unit() and not item.dead):
				sim.receive_attack(enemy, unit.attack, unit)
				if not enemy.dead:
					sim.incinerate(enemy, unit, 5, 3, 1)
					sim.push_in_air(enemy, unit, 2)
		if unit.tile == goal or not unit.moving:
			unit.speed = speed
			sim.stop_special(unit)
			return
		sim.after(1, again.bind(again))
	sim.after(1, watch.bind(watch))
