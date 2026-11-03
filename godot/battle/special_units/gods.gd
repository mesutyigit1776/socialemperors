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
	2075: "red",
	2085: "water",
	2079: "forest",
	2148: "earth",
	2113: "evil",
	2089: "soul",
	2093: "heaven",
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

		"red":
			# The 10 nearest enemies within 8 tiles jump, take the attack and burn.
			add(ability, 0, "Mega Slash", "red3_2075", SpecialAttacks.Frames.new(sim, unit, SP1, [45], func() -> void:
				for enemy in sim.items_near(unit.tile, 8, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_burn)):
					sim.receive_attack(enemy, int(atk), unit)
					sim.incinerate(enemy, unit, 5, 8, BattleSim.FRAMES_PER_SECOND)), has_target(), NO_TARGET_TEXT)
			# A giant fireball: the target takes 3 times the attack; the 10
			# nearest enemies within 5 tiles of it take the attack and fly 8 tiles.
			add(ability, 1, "Ultra Fireball", "red2_2075", SpecialAttacks.Frames.new(sim, unit, SP2, [61], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				sim.shoot(unit, target, "p.giantFireball", int(atk * 3), func(shot: BattleProjectile) -> void:
					for enemy in _pushable(sim, unit, IsoGrid.map_to_tile(shot.end), 5, 10):
						sim.receive_attack(enemy, int(atk), unit)
						if not enemy.dead:
							sim.push_in_air(enemy, unit, 8))), has_target(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", "red4_2075", SpecialAttacks.Frames.new(sim, unit, SP3, [12, 17], func() -> void:
				circular_push(sim, unit, 8, 5, int(atk), 5), 10))
			_god_minions_on(sim, unit, ability, "red1_2075", SP4, 52, 2076)
			var frames: Array[int] = []
			for frame in range(35, 116, 5):
				frames.append(frame)
			limit_special(ability, SP5, frames, func(battle: BattleSim, god: BattleFighter) -> void:
				for enemy in battle.items_near(god.tile, 7, 10, BattleAbility.enemy_side(god), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_burn)):
					battle.receive_attack(enemy, god.attack, god)
					battle.incinerate(enemy, god, 5, 8, BattleSim.FRAMES_PER_SECOND))
			combo(sim, unit, [2369, 2077])
		"water":
			add(ability, 0, "Mega Slash", "2085_1", SpecialAttacks.Frames.new(sim, unit, SP2, [23], func() -> void: _directional_smash(sim, unit)),
					has_target(), NO_TARGET_TEXT)
			_poke_button(sim, unit, ability, 1, "2085_2", SP3)
			add(ability, 2, "Hyper Whirlwind", "2085_3", SpecialAttacks.Frames.new(sim, unit, SP1, [16], func() -> void:
				circular_push(sim, unit, unit.attack_range, 10, int(atk / 2), 6), 12))
			_god_minions_on(sim, unit, ability, "2085_4", SP5, 30, 2084)
			var frames: Array[int] = []
			for frame in range(35, 131, 5):
				frames.append(frame)
			limit_special(ability, SP4, frames, func(battle: BattleSim, god: BattleFighter) -> void:
				circular_push(battle, god, 7, 10, int(god.attack * 1.5), 8))
		"forest":
			add(ability, 0, "Mega Slash", "1_2079", SpecialAttacks.Frames.new(sim, unit, SP1, [35], func() -> void: _directional_smash(sim, unit)),
					has_target(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", "2_2079", SpecialAttacks.Frames.new(sim, unit, SP2, [15], func() -> void:
				ExtremeDragons.carnivorous_plants(sim, unit)), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", "3_2079", SpecialAttacks.Frames.new(sim, unit, SP3, [20], func() -> void:
				circular_push(sim, unit, unit.attack_range, 5, int(atk / 4), 6), 12))
			_god_minions_on(sim, unit, ability, "4_2079", SP4, 35, 2078)
			limit_healing(ability, beams(SP5, [25], 50, LIMIT_GREEN_BEAM))
		"earth":
			_poke_button(sim, unit, ability, 0, "2148_1", SP4)
			add(ability, 1, "Ultra Fireball", "2148_2", SpecialAttacks.Rain.new(sim, unit, 6, 3, SP2, MagicParticles.HEAVY_ROCKS, null)
					.with_multiplier(1.2).with_frames([20]), Callable(), NO_TARGET_TEXT)
			# A whirlwind (item 2154) for 12 seconds.
			add(ability, 2, "Hyper Whirlwind", "2148_3", SpecialAttacks.Frames.new(sim, unit, SP3, [25], func() -> void:
				MinionWhirlwindAbility.summon(sim, unit, 2154, unit.tile, 12)))
			_god_minions_on(sim, unit, ability, "2148_4", SP1, 30, 2149)
			# Of the 10 nearest enemies within 8 tiles, every second one falls
			# into a hole and dies when it has at most 500 life (at most 6),
			# else it takes 500 points and flies 10 tiles. The other holes
			# open on random tiles.
			limit_special(ability, SP5, [60], func(battle: BattleSim, god: BattleFighter) -> void:
				var holes: Array[Vector2i] = []
				var swallowed := 0
				var enemies := battle.items_near(god.tile, 8, 10, BattleAbility.enemy_side(god), true, func(item: BattleFighter) -> bool:
					return item.is_unit() and not item.dead)
				for i in enemies.size():
					var enemy: BattleFighter = enemies[i]
					if i % 2 == 0:
						if enemy.tile in holes or swallowed > 5:
							continue
						if enemy.max_life() <= 500:
							swallowed += 1
							holes.append(enemy.tile)
							ClassicDragons.HoleHit.new(battle, god).apply(enemy)
						else:
							battle.receive_attack(enemy, 500, god)
							battle.push_in_air(enemy, god, 10)
					else:
						var reach := god.attack_range
						var tile := (god.tile + Vector2i(battle.rng.randi_range(-reach, reach), battle.rng.randi_range(-reach, reach))).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
						if not tile in holes:
							holes.append(tile)
							battle.particle(god, tile, MagicParticles.ROCK_HOLE, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true))
		"evil":
			# The first unit of the directional attack flies 18 tiles and dies
			# when it has at most 1000 life, else it flies 15 tiles and takes
			# 1000 points; the others take half the attack and fly 5 tiles.
			add(ability, 0, "Mega Slash", "evil_god_1", SpecialAttacks.Frames.new(sim, unit, SP1, [36], func() -> void:
				var first := true
				for enemy in directional_hits(sim, unit, 12, 5):
					if enemy.dead or enemy.in_air:
						continue
					var target := enemy
					if first:
						first = false
						var weak := target.max_life() <= 1000
						sim.push_in_air(target, unit, 18 if weak else 15)
						sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
							if not target.dead:
								if weak:
									sim.kill(target, unit)
								else:
									sim.receive_attack(target, 1000, unit))
					else:
						sim.receive_attack(target, int(atk / 2), unit)
						if not target.dead:
							sim.push_in_air(target, unit, 5)), has_target_in_range(5), NO_TARGET_TEXT, COOLDOWN + 1)
			add(ability, 1, "Ultra Fireball", "evil_god_2", SpecialAttacks.Frames.new(sim, unit, SP2, [37], func() -> void:
				for enemy in sim.items_near(unit.tile, 8, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_poison)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.poison(enemy, 25, 5, 0, unit)), Callable(), NO_TARGET_TEXT, COOLDOWN + 1)
			add(ability, 2, "Hyper Whirlwind", "evil_god_3", SpecialAttacks.Frames.new(sim, unit, SP3, [12], func() -> void:
				circular_push(sim, unit, 6, 15, int(atk / 2), 5), 10), Callable(), "", COOLDOWN + 1)
			_god_minions_on(sim, unit, ability, "evil_god_4", SP4, 17, 2115)
			ability.buttons[3].cooldown_seconds = COOLDOWN + 1
			# The 10 nearest enemies within 7 tiles take the attack, fly 8
			# tiles and are dizzy for 6 seconds, 8 times.
			limit_special(ability, SP5, [25, 30, 35, 40, 45, 50, 55, 60], func(battle: BattleSim, god: BattleFighter) -> void:
				var hit := Damages.Sequenced.new(battle, god).add(Damages.PushInAir.new(battle, god, god.attack, 8)).add(Damages.Dizzy.new(battle, god, 0, 6, 1))
				for enemy in battle.items_near(god.tile, 7, 10, BattleAbility.enemy_side(god), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if hit.can_apply(enemy):
						hit.apply(enemy))
		"soul":
			# A sonic boom at a target within 12 tiles: the 5 nearest enemies
			# within 5 tiles of it take a quarter of the attack and fly 5
			# tiles; a target with at most 500 life flies 12 tiles and dies,
			# another takes twice the attack (more against a weaker element)
			# and flies 10 tiles.
			add(ability, 0, "Mega Slash", "2089_1", SpecialAttacks.Frames.new(sim, unit, SP1, [41], func() -> void:
				var target := unit.target
				if target == null or target.dead or sim.distance(unit, target) > 12:
					return
				sim.shoot(unit, target, "p.deathSonicBoom", -1, func(_shot: BattleProjectile) -> void:
					if target.dead:
						return
					for enemy in _pushable(sim, unit, target.tile, 5, 5):
						sim.receive_attack(enemy, int(atk / 4), unit)
						if not enemy.dead:
							sim.push_in_air(enemy, unit, 5)
					if not target.is_unit() or target.dead:
						return
					if target.max_life() <= 500:
						sim.push_in_air(target, unit, 12)
						sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
							if not target.dead:
								sim.kill(target, unit))
					else:
						var damage := atk * 2
						if BattleSim.ELEMENT_BEATS.get(unit.def.subcat_functional) == target.def.subcat_functional:
							damage *= BattleSim.ELEMENT_MULTIPLIER
						sim.receive_attack(target, int(damage), unit)
						if not target.dead:
							sim.push_in_air(target, unit, 10))), has_target_in_range(12), NO_TARGET_TEXT)
			# Up to 7 enemies within 7 tiles take half the attack, freeze for
			# 5 seconds and then fight for the player for 15 seconds.
			var converted: Array[BattleFighter] = []
			add(ability, 1, "Ultra Fireball", "2089_2", SpecialAttacks.Frames.new(sim, unit, SP2, [25], func() -> void:
				converted.assign(converted.filter(func(item: BattleFighter) -> bool: return not item.dead and item.team == unit.team))
				var free := 7 - converted.size()
				if free <= 0:
					return
				for enemy in sim.items_near(unit.tile, 7, free, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and not item.incapacitated and item.def.subcat_functional != BattleSim.SUBCAT_BOSS \
								and (item.ability == null or not item.ability.immune_to_conversion)):
					var target := enemy
					sim.receive_attack(target, int(atk / 2), unit)
					if target.dead:
						return
					Damages.Freeze.new(sim, unit, 0, 5, 5).apply(target)
					sim.after(5 * BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not target.dead:
							converted.append(target)
							Damages.ConvertToAlly.new(sim, unit, 15).apply(target))), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", "2089_3", SpecialAttacks.Frames.new(sim, unit, SP3, [12], func() -> void:
				circular_push(sim, unit, 8, 10, int(atk / 2), 6), 10))
			_god_minions_on(sim, unit, ability, "2089_4", SP4, 9, 2091)
			limit_special(ability, SP5, [65], func(battle: BattleSim, god: BattleFighter) -> void:
				circular_push(battle, god, 10, 20, god.attack * 3, 15))
		"heaven":
			add(ability, 0, "Autoheal Invocation", "4god", SpecialAttacks.Frames.new(sim, unit, SP1, [20], func() -> void: sim.heal(unit, 800, unit)),
					Callable(), "", COOLDOWN + 1)
			add(ability, 1, "Energy Explosion", "2god", SpecialAttacks.Frames.new(sim, unit, SP2, [82], func() -> void:
				circular_push(sim, unit, 6, 15, int(atk * 1.5), 10)), Callable(), "", COOLDOWN + 1)
			# A lightning whirlwind (item 2298) for 15 seconds, one at a time.
			var whirls: Array[BattleFighter] = []
			add(ability, 2, "Lightning Whilrwind", "1god", SpecialAttacks.Frames.new(sim, unit, SP3, [20], func() -> void:
				var whirl := sim.spawn(sim.config_item(2298), unit.tile, unit.team)
				if whirl == null:
					return
				whirls.append(whirl)
				sim.after(15 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					whirls.erase(whirl)
					if not whirl.dead and whirl in sim.fighters:
						sim.remove_item(whirl))),
					func(_s: BattleSim, _f: BattleFighter) -> bool: return whirls.filter(func(item: BattleFighter) -> bool: return not item.dead).is_empty(),
					"1 whirlwind max", COOLDOWN + 1)
			add(ability, 3, "Unleash Miniors", "3god", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP4, sim.animation_frames(unit, SP4, 30), {}, func() -> void:
					unit.ability.spawn_minions(sim, unit, 2092, 3), true),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 3 <= 6, "6 minions max", COOLDOWN + 1)
			# A rain of rays; each hit takes twice the attack and flies 4 tiles.
			var rays := SpecialAttacks.Rain.new(sim, unit, 4, 2.5, SP5, MagicParticles.RAY, Damages.PushInAir.new(sim, unit, atk * 2, 4)).with_multiplier(0.5)
			limit_special(ability, SP5, [22], func(_battle: BattleSim, _god: BattleFighter) -> void: rays.start())
			combo(sim, unit, [2350, 2094])

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


## The directional smash of the elemental gods (12 tiles, radius 6): each
## hit takes the attack and flies 7 tiles.
static func _directional_smash(sim: BattleSim, unit: BattleFighter) -> void:
	for enemy in directional_hits(sim, unit, 12, 6):
		if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
			continue
		sim.receive_attack(enemy, unit.attack, unit)
		if not enemy.dead:
			sim.push_in_air(enemy, unit, 7)


## The minion button of the elemental gods: at frame of animation, 3 minions
## while at most 3 are alive.
static func _god_minions_on(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, picture: String, animation: int, frame: int, minion_id: int) -> void:
	add(ability, 3, GOD_MINIONS, picture, SpecialAttacks.Frames.new(sim, unit, animation, [frame], func() -> void:
		unit.ability.spawn_minions(sim, unit, minion_id, 3)),
		func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 3 <= 6, "6 " + MINIONS_MAX)


## The trident of the water and earth gods: up to 3 enemies with at most
## 500 life within 2 tiles are poked at frames 24, 32 and 40 and die at the
## end of the animation.
static func _poke_button(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, id: int, picture: String, animation: int) -> void:
	var targets := func() -> Array[BattleFighter]:
		var found: Array[BattleFighter] = []
		for item in sim.items_near(unit.tile, 2, 15, BattleAbility.enemy_side(unit), true, func(other: BattleFighter) -> bool:
				return other.is_unit() and not other.dead and other.max_life() <= 500):
			if found.size() < 3:
				found.append(item)
		return found
	add(ability, id, "Ultra Fireball", picture, func(_s: BattleSim, _f: BattleFighter) -> void:
		var prey: Array[BattleFighter] = targets.call()
		var events := {}
		for i in prey.size():
			var target: BattleFighter = prey[i]
			events[24 + 8 * i] = func() -> void:
				if not target.dead:
					target.incapacitated = true
					target.swallowed = true
					sim.state_changed.emit(target)
		sim.play_special(unit, animation, maxi(sim.animation_frames(unit, animation, 40), 41), events, func() -> void:
			for target in prey:
				if not target.dead:
					sim.kill(target, unit), true),
		func(_s: BattleSim, _f: BattleFighter) -> bool: return not targets.call().is_empty(), NO_TARGET_TEXT)
