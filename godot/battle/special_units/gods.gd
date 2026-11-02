class_name Gods
extends SpecialUnit
## The gods and goddesses. The elemental goddesses fly with their limit
## button and have a combo with the colossus and the god of their element.

const UNITS := {
	2369: "fire_goddess",
	2350: "light_goddess",
	2167: "genesis_ice",
	2169: "genesis_iron",
	2160: "genesis_shadow",
	2156: "genesis_wind",
}
const NO_TARGET_TEXT := "No target within range"
const GOD_MINIONS := "God Minions"


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	match kind:
		"fire_goddess":
			var pic := func(number: int) -> String: return thumb(2369, "elementalFireGoddessUnit", number)
			add(ability, 0, "SWALLOWED BY HELL", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [11],
					Damages.DirectKill.new(sim, unit, 1000), "", 1, 1, true).with_blast("b.openEarthFire").with_count(1), has_target(), NO_TARGET)
			add(ability, 1, "DEMON CONVERSION", pic.call(2), SpecialAttacks.PowerDown.new(sim, unit, SP1, [20], rng, 12,
					Damages.Simple.new(sim, unit, 0, 12, 5, false)).with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 1000),
					has_target(), NO_TARGET)
			var magma := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 4, 4)) \
					.add(Damages.Incinerate.new(sim, unit, 10, 10, 500)).with_shared(true)
			add(ability, 2, "MAGMA BALL", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [35], magma, rng, 10), has_target(), NO_TARGET)
			add_minions(ability, 3, "ELEMENTAL FIRE MINIONS", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2076, 3, 3))
			limit_flying(ability)
			combo(sim, unit, [2077, 2075])
		"light_goddess":
			var pic := func(number: int) -> String: return thumb(2350, "elementalLightGoddessUnit", number)
			add(ability, 0, "HEALING AURA", pic.call(1), SpecialAttacks.HealthArea.new(sim, unit, SP1, [15, 45, 75, 105, 135, 165], rng, 10,
					MagicParticles.NONE, Damages.Health.new(sim, unit, 1010 / 5.0).with_shared(true)).with_shared(true))
			add(ability, 1, "PARALYZING GAZE", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [31],
					Damages.Dizzy.new(sim, unit, atk * 4.2, 9, 1).with_shared(true), 10, 20), has_target(), NO_TARGET)
			add(ability, 2, "DIVINE LIGHT", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [35, 45, 55, 67],
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), rng, 20), has_target(), NO_TARGET)
			add_minions(ability, 3, "ELEMENTAL LIGHT MINIONS", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2092, 3))
			limit_flying(ability)
			combo(sim, unit, [2094, 2093])
		"genesis_ice":
			var pic := func(number: int) -> String: return "2167_%d" % number
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [24], func() -> void: _god_slash(sim, unit)),
					has_target(), NO_TARGET_TEXT)
			var freeze := Damages.Freeze.new(sim, unit, 125, 5, 5)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 3, 3, SP2, MagicParticles.FROZEN_RAIN, freeze)
					.with_multiplier(0.75).with_frames([16]), _target_in_range(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 10, 22,
					Damages.PushInAir.new(sim, unit, atk, 5), 5, 5).with_interval(1000))
			_god_minions(sim, unit, ability, pic.call(4), 2168)
			limit_special(ability, SP5, [35, 40, 45, 50, 55, 60, 65, 70], func(battle: BattleSim, god: BattleFighter) -> void:
				var push := Damages.Sequenced.new(battle, god).add(Damages.PushInAir.new(battle, god, god.attack, 4)) \
						.add(Damages.Freeze.new(battle, god, 125, 5, 5))
				for enemy in _pushable(battle, god, god.tile, 10, 15):
					push.apply(enemy))
		"genesis_iron":
			var pic := func(number: int) -> String: return "2169_genesisIronGod_button%d" % number
			# Two axes, 200 ms apart; each takes 500 points and pushes 6 tiles.
			var axe := func() -> void:
				var target := unit.target
				if target != null and not target.dead:
					sim.shoot(unit, target, "p.godAxe", 0, func(_shot: BattleProjectile) -> void:
						if target.is_unit() and not target.dead:
							sim.receive_attack(target, 500, unit)
							sim.push_in_air(target, unit, 6))
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [59], func() -> void:
				axe.call()
				sim.after(6, axe)), has_target(), NO_TARGET_TEXT)
			# Eight swords at the 8 nearest enemy units in range, then at random ones.
			add(ability, 1, "Ultra Fireball", pic.call(4), SpecialAttacks.Frames.new(sim, unit, SP2, [69], func() -> void:
				var enemies := sim.items_near(unit.tile, rng, 8, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
					return item.is_unit() and not item.dead)
				if enemies.is_empty():
					return
				for i in 8:
					var target: BattleFighter = enemies[i] if i < enemies.size() else enemies[sim.rng.randi_range(0, enemies.size() - 1)]
					sim.shoot(unit, target, "p.godSword", unit.attack)), has_target(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 22,
					Damages.PushInAir.new(sim, unit, atk, 5), 5, 5).with_interval(1000))
			_god_minions(sim, unit, ability, pic.call(2), 2170)
			# A rain of swords; where one hits a unit, the unit flies 3 tiles and
			# the 3 nearest units within 3 tiles take half the attack and fly 2.
			var sword_rain := SpecialAttacks.Rain.new(sim, unit, 8, 4, SP5, MagicParticles.SWORD_RAIN, _SwordHit.new(sim, unit)).with_multiplier(2).with_delay(0.075)
			limit_special(ability, SP5, [115], func(_battle: BattleSim, _god: BattleFighter) -> void: sword_rain.start())
		"genesis_shadow":
			var pic := func(number: int) -> String: return "2160_%d" % number
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [37], func() -> void: _god_slash(sim, unit)),
					has_target(), NO_TARGET_TEXT)
			# Up to 5 units with at most 500 life float for 3.75 seconds and take
			# 5 points every 500 ms; then they fall and take the attack.
			add(ability, 1, "Ultra Fireball", pic.call(2), func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP2, roundi(3.75 * BattleSim.FRAMES_PER_SECOND), {30: func() -> void:
					var floating := _pushable(sim, unit, unit.tile, 8, 15).filter(func(item: BattleFighter) -> bool: return item.max_life() <= 500).slice(0, 5)
					for target: BattleFighter in floating:
						Damages.Levitate.new(sim, unit, 2.25, 5 * 5, 5).with_up_time(0.75).apply(target)
					sim.after(roundi(3.75 * BattleSim.FRAMES_PER_SECOND) - 30, func() -> void:
						for target: BattleFighter in floating:
							if not target.dead:
								sim.receive_attack(target, unit.attack, unit))}, Callable(), true), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 22,
					Damages.PushInAir.new(sim, unit, atk, 5), 5, 5).with_interval(1000))
			_god_minions(sim, unit, ability, pic.call(4), 2161)
			var frames: Array[int] = []
			for frame in range(35, 156, 5):
				frames.append(frame)
			# At each frame, the 5 nearest units within 5 tiles of a random tile
			# within 10 tiles take 0.75 times the attack and fly 1 tile.
			limit_special(ability, SP5, frames, func(battle: BattleSim, god: BattleFighter) -> void:
				var tile := (god.tile + Vector2i(battle.rng.randi_range(-10, 10), battle.rng.randi_range(-10, 10))) \
						.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
				for enemy in _pushable(battle, god, tile, 5, 5):
					battle.receive_attack(enemy, int(god.attack * 0.75), god)
					if not enemy.dead:
						battle.push_in_air(enemy, god, 1))
		"genesis_wind":
			var pic := func(number: int) -> String: return "2156_%d" % number
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [31], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				sim.shoot(unit, target, "p.fireWindArrow", 0, func(shot: BattleProjectile) -> void:
					for enemy in _pushable(sim, unit, IsoGrid.map_to_tile(shot.end), 3, 3):
						sim.receive_attack(enemy, int(atk / 2), unit)
						if not enemy.dead:
							sim.push_in_air(enemy, unit, 3)
					if target.is_unit() and not target.dead:
						sim.receive_attack(target, int(atk * 2), unit)
						if not target.dead:
							sim.push_in_air(target, unit, 8))), has_target(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 3, 3, SP2, MagicParticles.WIND_ARROWS, null)
					.with_multiplier(1.5).with_frames([45]), _target_in_range(), NO_TARGET_TEXT)
			# The units of the directional attack take the attack and slide away:
			# 12 tiles (life below 300), 6 (below 500), 4 (below 1500) or 2, give
			# or take 2.
			add(ability, 2, "Hyper Whirlwind", pic.call(3), SpecialAttacks.Frames.new(sim, unit, SP3, [22], func() -> void:
				for enemy in directional_hits(sim, unit, 10, 8, 8):
					if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
						continue
					var life := enemy.max_life()
					var tiles := 12 if life < 300 else 6 if life < 500 else 4 if life < 1500 else 2
					sim.receive_attack(enemy, unit.attack, unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, sim.rng.randi_range(tiles - 2, tiles + 1)), 2))
			_god_minions(sim, unit, ability, pic.call(4), 2159)
			# The count of pulled units lasts for the whole limit attack, which
			# pulls 8 times.
			var pulled := [0, -1000]
			limit_special(ability, SP5, [35, 40, 45, 50, 55, 60, 65, 70], func(battle: BattleSim, god: BattleFighter) -> void:
				if battle.frame - pulled[1] > 40:
					pulled[0] = 0
				pulled[1] = battle.frame
				_wind_limit(battle, god, pulled))


## The target of the unit is within its range (hasStormTarget).
static func _target_in_range() -> Callable:
	return func(sim: BattleSim, fighter: BattleFighter) -> bool:
		return fighter.target != null and sim.distance(fighter, fighter.target) <= fighter.attack_range


## The enemy units within range_tiles of tile, at most count, that can fly.
static func _pushable(sim: BattleSim, unit: BattleFighter, tile: Vector2i, range_tiles: int, count: int) -> Array[BattleFighter]:
	return sim.items_near(tile, range_tiles, count, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push))


## The weapon of the genesis gods: the directional attack (10 tiles, radius
## 4, at most 6 hits). The first unit takes 500 points; the others take half
## the attack and fly 4 tiles.
static func _god_slash(sim: BattleSim, unit: BattleFighter) -> void:
	var first := true
	for enemy in directional_hits(sim, unit, 10, 4, 5):
		if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
			continue
		if first:
			sim.receive_attack(enemy, 500, unit)
			first = false
		else:
			sim.receive_attack(enemy, unit.attack / 2, unit)
			if not enemy.dead:
				sim.push_in_air(enemy, unit, 4)


## The minion button of the genesis gods: 3 minions while at most 3 are alive.
static func _god_minions(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, picture: String, minion_id: int) -> void:
	add(ability, 3, GOD_MINIONS, picture, SpecialAttacks.Frames.new(sim, unit, SP4, [23], func() -> void:
		unit.ability.spawn_minions(sim, unit, minion_id, 3)),
		func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 3 <= 6, "6 " + MINIONS_MAX)


## One pull of the limit of the God of Wind: each enemy unit in range that
## can fly (at most 15) is pulled to the god. Of the units with at most 500
## life, the first 3 of the attack go into the whirlwind and die; the others
## fly 6 to 12 tiles and take the attack. Stronger units come 1 to 3 tiles
## nearer, take the attack and fly 3 tiles. pulled[0] counts the units.
static func _wind_limit(sim: BattleSim, god: BattleFighter, pulled: Array) -> void:
	for enemy in _pushable(sim, god, god.tile, god.attack_range, 15):
		pulled[0] += 1
		var target := enemy
		if target.incapacitated:
			continue
		if target.max_life() <= 500:
			if pulled[0] > 3:
				sim.absorb_and_push(target, god, sim.rng.randi_range(6, 11))
				sim.after(2 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					if not target.dead:
						sim.receive_attack(target, god.attack, god))
			else:
				target.incapacitated = true
				target.swallowed = true
				sim.state_changed.emit(target)
				sim.after(3 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					if not target.dead:
						sim.kill(target, god))
		else:
			var life := target.max_life()
			sim.push_in_air(target, god, -(3 if life < 1000 else 2 if life < 3000 else 1))
			sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
				if not target.dead:
					sim.receive_attack(target, god.attack, god)
					sim.push_in_air(target, god, 3))


## A sword of the rain of the God of Iron hits a unit: the unit flies 3
## tiles, and the 3 nearest units within 3 tiles take half the attack and
## fly 2 tiles.
class _SwordHit extends UnitDamage:
	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		sim.push_in_air(target, attacker, 3)
		for enemy in Gods._pushable(sim, attacker, target.tile, 3, 3):
			sim.receive_attack(enemy, attacker.attack / 2, _source())
			if not enemy.dead:
				sim.push_in_air(enemy, attacker, 2)
