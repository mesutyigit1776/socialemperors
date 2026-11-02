class_name Dragons
extends SpecialUnit
## Dragons of single kinds that use the newer button builder of the client
## (SpecialUnitAttackCreator), with their riders.

const UNITS := {
	2232: "blue_fire_djinn", 2234: "blue_fire_djinn",
	2226: "red_djinn", 2228: "red_djinn",
	2272: "demon", 2274: "demon",
	2267: "easter", 2268: "easter",
	2269: "forge", 2271: "forge",
	2363: "night_forge", 2365: "night_forge",
	2339: "thunder_forge", 2341: "thunder_forge",
	2324: "ivory_dynasty", 2326: "ivory_dynasty",
	2330: "night_enel", 2332: "night_enel",
	2287: "saint_george",
	2275: "spawn", 2277: "spawn",
}
## Kind -> [the first item id, the picture name, the rider id].
const NAMES := {
	"blue_fire_djinn": [2232, "blueFireDjinnDragon", 2234],
	"red_djinn": [2226, "redDjinnDragon", 2228],
	"demon": [2272, "demonDragonUnit", 2274],
	"easter": [2267, "easterDragonUnit", 2268],
	"forge": [2269, "forgeDragonUnit", 2271],
	# The client checks the id of the Platinum Armor Dragon rider (2359)
	# here, so the Night Forge Dragon rider has no limit button.
	"night_forge": [2363, "nightForgeDragonUnit", 2359],
	"thunder_forge": [2339, "thunderForgeDragonUnit", 2341],
	"ivory_dynasty": [2324, "ivoryDinastyDragonUnit", 2326],
	"night_enel": [2330, "nightEnelDragonUnit", 2332],
	"saint_george": [2287, "saintGeorgeDragonUnit", 2287],  # Only the rider exists.
	"spawn": [2275, "spawnDragonUnit", 2277],
}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return thumb(names[0], names[1], number)
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[2]
	match kind:
		"blue_fire_djinn":
			var burn := func(amount: float, tiles: int) -> UnitDamage:
				var fire := Damages.Incinerate.new(sim, unit, 20, 10, 1000).with_incapacitate(true)
				return Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, amount, tiles)).add(fire)
			add(ability, 0, "Fire Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [31], 6, "p.elfKnight", burn.call(atk * 0.5, 3))
					.with_shot_damage(false).with_directional(true).with_impact_particle(MagicParticles.MEGA_EXPLOSION), Callable(), NO_TARGET)
			add(ability, 1, "Fire boomerang", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [25, 30, 35, 40, 45, 50, 55, 60],
					burn.call(atk * 0.5, 5), 10, 5))
			add(ability, 2, "Tongues of fire", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [35, 45, 55], burn.call(atk, 5), 10, 6))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2233, 2))
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"red_djinn":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [31], 2, "p.largeFireball", Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk * 0.5, 3)).add(Damages.Incinerate.new(sim, unit, atk * 0.5, 3, 500)))
					.with_impact_particle(MagicParticles.FIRE_EXPLOSION), has_target(), NO_TARGET)
			var pit := Damages.Sequenced.new(sim, unit).add(Damages.Levitate.new(sim, unit, 2.4, 30, 3).with_up_time(0.6)) \
					.add(Damages.Incinerate.new(sim, unit, atk * 0.5, 4, 500))
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.ParticleAttack.new(sim, unit, SP2, [25], 12, 5, MagicParticles.FIRE_PIT, pit).with_shared(true))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [26], Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, 20, 1)).add(Damages.Incinerate.new(sim, unit, atk, 5, 250)), 12, 8).with_shared(true))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2227, 2))
			if rider:
				limit_lightning(ability, beams(SP3, [14], 50, LIMIT_RED_BEAM, 100, 0.5))
		"demon":
			var lava := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 4, 4).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 10, 4, 100).with_shared(true)).with_shared(true)
			add(ability, 0, "", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [39], lava, "p.lavaBall", 1, 1, true)
					.with_count(10).with_range(rng), has_target(), NO_TARGET)
			add(ability, 1, "", pic.call(2), SpecialAttacks.Eat.new(sim, unit, SP2, [18], [90], Damages.DirectKill.new(sim, unit, 500), ["proyectilePoint"], rng)
					.with_incapacitate(true).with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500),
					AncientDragons._target_max_life(0, 500), NO_TARGET)
			var claws := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 5.2 / 3, 4).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 5, 5, 500).with_shared(true)).with_shared(true)
			add(ability, 2, "", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [25, 38, 51], claws, rng, 15), has_target())
			add_minions(ability, 3, "Demon Minion", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2076, 2))
			if rider:
				limit_lightning(ability, beams(SP5, [35], 50, LIMIT_RED_BEAM))
		"easter":
			add(ability, 0, "Eggs Burst", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 15, 20], 3, "p.easterEgg",
					Damages.PushInAir.new(sim, unit, atk * 1.4, 4).with_shared(true)).with_shared(true), has_target(), NO_TARGET)
			var bubble := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 1.8, rng + 1).with_shared(true)) \
					.add(Damages.Dizzy.new(sim, unit, 0, 10, 1000).with_shared(true)).with_shared(true)
			add(ability, 1, "Easter Bubble", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [30, 60, 90], bubble, 5, 5))
			add(ability, 2, "Colorful Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17,
					Damages.PushInAir.new(sim, unit, atk, 5).with_shared(true), 5, 5).with_shared(true))
			# Three eggs hatch a golden, an electric and a red-hot epic draggy.
			var eggs := SpecialAttacks.EasterEggs.new(sim, unit, SP4, 1, [15, 30, 44], ["p.yellowEgg", "p.blueEgg", "p.redEgg"], [2197, 2203, 2209])
			add(ability, 3, "Triple Easter Eggs", pic.call(4), eggs, below_minions(3), "3 " + MINIONS_MAX)
			if rider:
				limit_smash(ability, SP5, [28], 2, 8, 8)
		"forge":
			var fire := func(damage: UnitDamage, ticks: int, tick_ms: int) -> UnitDamage:
				return Damages.Sequenced.new(sim, unit).add(damage.with_shared(true)) \
						.add(Damages.Incinerate.new(sim, unit, 5, ticks, tick_ms).with_shared(true)).with_shared(true)
			add(ability, 0, "Attack 1", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [21],
					fire.call(Damages.PushInAir.new(sim, unit, atk * 4, 3), 10, 1000), rng, 5), has_target(), NO_TARGET)
			add(ability, 1, "Attack 2", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [21, 22, 23, 25, 27, 29, 31, 33],
					fire.call(Damages.PushInAir.new(sim, unit, atk * 3.7 / 8, 3), 10, 1000), rng, 5), has_target())
			add(ability, 2, "Attack 3", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [18],
					fire.call(Damages.Simple.new(sim, unit, atk * 3.7, 0.1, 1), 5, 500), 5, 5), has_target())
			# The fourth button is an attack too; the client checks the minions anyway.
			add(ability, 3, "Draggy", pic.call(4), SpecialAttacks.Area.new(sim, unit, SP4, [35],
					fire.call(Damages.PushInAir.new(sim, unit, atk * 3.7, 2), 5, 500), 5, 5), below_minions(3), "3 " + MINIONS_MAX)
			if rider:
				limit_smash(ability, SP5, [35], 2, 8, 8)
		"night_forge":
			add(ability, 0, "PURE FIRE", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [19, 23, 29, 33],
					Damages.Simple.new(sim, unit, atk, 0, 1).with_shared(true), rng, 10), has_target(), NO_TARGET)
			add(ability, 1, "PERFECT STORM", pic.call(2), SpecialAttacks.Rain.new(sim, unit, rng * 2, 1, SP2, MagicParticles.PURPLE_RAY, Damages.Sequenced.new(sim, unit)
					.add(Damages.Simple.new(sim, unit, atk / 2, 1, 1)).add(Damages.Electrocute.new(sim, unit, 5, 5, 10, true))).with_frames([20, 30, 40]),
					has_target(), NO_TARGET)
			add(ability, 2, "METEORIC CRASH", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [36, 46, 56, 66, 76],
					Damages.PushInAir.new(sim, unit, atk * 4 / 5, 4).with_shared(true), int(rng * 1.3), 15), has_target(), NO_TARGET)
			add_minions(ability, 3, "NIGHT FORGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2364, 1))
			if rider:
				limit_smash(ability, SP5, [38, 48, 55], 2, 8, 8)
		"thunder_forge":
			add(ability, 0, "BARRAGE FIRE!", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [19, 24, 29, 34, 39],
					Damages.Simple.new(sim, unit, atk * 4.1 / 5, 1, 1).with_shared(true), rng * 2, 15), has_target_in_range(rng * 3), NO_TARGET)
			add(ability, 1, "FLAMING TAIL", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [27],
					Damages.PushInAir.new(sim, unit, atk * 4.3, 4).with_shared(true), rng, 15), has_target(), NO_TARGET)
			add(ability, 2, "PERFECT STORM", pic.call(3), SpecialAttacks.Rain.new(sim, unit, rng * 2, 1, SP3, MagicParticles.THUNDER_L, Damages.Sequenced.new(sim, unit)
					.add(Damages.Simple.new(sim, unit, atk, 1, 1)).add(Damages.Electrocute.new(sim, unit, 5, 5, 10, true))).with_frames([20, 30, 40]),
					has_target(), NO_TARGET)
			add_minions(ability, 3, "THUNDER FORGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2340, 1))
			if rider:
				limit_smash(ability, SP4, [50], 2, 8, 8)
		"ivory_dynasty":
			add(ability, 0, "PURE FIREBALL", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [36],
					Damages.PushInAir.new(sim, unit, atk * 3.5, 6).with_shared(true), rng, 12).with_shared(true), has_target(), NO_TARGET)
			# The beams are the own beams of the dragon; it takes no damage meanwhile.
			add(ability, 1, "INVISIBILITY", pic.call(2), SpecialAttacks.ShootProjectiles.new(sim, unit, SP2, [45, 60, 75, 90],
					Damages.Simple.new(sim, unit, atk * 0.88, 1, 1).with_shared(true), "", 1, 1, true).with_invulnerable(true), has_target(), NO_TARGET)
			var hit := [0]
			var teeth := Damages.ChosenByFilter.new(sim, unit) \
					.add(Damages.DieAnimation.new(sim, unit), func(target: BattleFighter) -> bool:
						if hit[0] >= 1 or target.max_life() > 500:
							return false
						hit[0] += 1
						return true) \
					.add(Damages.PushInAir.new(sim, unit, atk * 0.2, 3).with_shared(true), func(_target: BattleFighter) -> bool:
						hit[0] += 1
						return true)
			add(ability, 2, "TEETH AND HORNS", pic.call(3), SpecialAttacks.ShootProjectiles.new(sim, unit, SP3, [16], teeth, "", 1, 1, true)
					.with_instant().with_end_action(func() -> void: hit[0] = 0).with_shared(true), has_target(), NO_TARGET)
			add_minions(ability, 3, "IVORY DYNASTY DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2325, 1))
			if rider:
				limit_healing(ability, beams(SP4, [20], 50, LIMIT_GREEN_BEAM))
		"night_enel":
			add(ability, 0, "MOON SEAL", pic.call(1), SpecialAttacks.SealArea.new(sim, unit, SP1, [24], int(rng * 1.5), 8, MagicParticles.MOON_SEAL,
					Damages.PushInAir.new(sim, unit, atk * 3.44, 4).with_shared(true), true, 400).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "HEALING SPELL", pic.call(2), SpecialAttacks.HealthArea.new(sim, unit, SP2, [12, 22], rng, 10, MagicParticles.SEAL_HEALTH,
					Damages.Health.new(sim, unit, atk * 1.73).with_shared(true)).with_shared(true), Callable(), NO_TARGET)
			add(ability, 2, "BLINDING CLAP", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [19],
					Damages.Dizzy.new(sim, unit, atk * 2.5).with_shared(true), int(rng * 1.5), 15).with_shared(true), has_target(), NO_TARGET)
			add_minions(ability, 3, "NIGHT ENEL DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2331, 1))
			if rider:
				limit_smash(ability, SP4, [31], 2, 6, 6)
		"saint_george":
			add(ability, 0, "FIREBALL RAIN", pic.call(1), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP1, MagicParticles.FIREBALL_RAIN,
					Damages.PushInAir.new(sim, unit, atk * 0.36, 3).with_shared(true), 3).with_delay(0.2).with_frames([10, 22, 34]).with_shared(true),
					has_target(), NO_TARGET)
			var blaze := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 3.5, 6).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 0, 5, 750)).with_shared(true)
			add(ability, 1, "LEGENDARY BLAZE", pic.call(2), SpecialAttacks.ShootProjectiles.new(sim, unit, SP2, [18], blaze, "p.fireball_01", 1, 1, true)
					.with_range(rng), has_target(), NO_TARGET)
			var flare := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 0, 5, 750)).with_shared(true)
			add(ability, 2, "FLARE WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, flare, 5, 5), has_target(), NO_TARGET)
			add_minions(ability, 3, "SAINT GEORGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2288, 1))
			limit_lightning(ability, beams(SP4, [10], 50, LIMIT_RED_BEAM))
		"spawn":
			add(ability, 0, "GHOST BITE", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [23],
					Damages.Simple.new(sim, unit, atk * 3.78, 0.1, 1).with_shared(true), rng, 5).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "CRYSTAL FIRE-WAVE", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [46],
					Damages.PushInAir.new(sim, unit, atk * 4.05, 3).with_shared(true), rng, 10), has_target())
			add(ability, 2, "LETHAL STAB", pic.call(3), SpecialAttacks.ShootProjectiles.new(sim, unit, SP3, [43],
					Damages.PushInAir.new(sim, unit, atk * 3.914, 3).with_shared(true), "", 1, 1, true).with_blast("b.cristalStab").with_count(10)
					.with_shared(true), has_target())
			# 10 to 20 draggies; the button works while fewer than 4 are alive,
			# the maximum that the attack gives to the unit.
			add(ability, 3, "SPAWN DRAGGIES SWARM", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2276, 2).with_random_count(10, 20),
					below_minions(4), "4 " + MINIONS_MAX)
			if rider:
				limit_healing(ability, beams(SP5, [10], 50, LIMIT_GREEN_BEAM))
