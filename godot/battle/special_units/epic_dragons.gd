class_name EpicDragons
extends SpecialUnit
## The epic dragons and their riders (the second id). Each has four buttons;
## the rider also has the limit button.

const UNITS := {
	2292: "black_demon", 2294: "black_demon",
	2199: "black", 2201: "black",
	2278: "dark_shogun", 2280: "dark_shogun",
	2202: "electric", 2204: "electric",
	2223: "enel", 2225: "enel",
	2327: "ghost", 2329: "ghost",
	2196: "golden", 2198: "golden",
	2205: "jewel", 2207: "jewel",
	2253: "laser", 2255: "laser",
	2229: "nebula", 2231: "nebula",
	2211: "neon", 2213: "neon",
	2208: "red_hot", 2210: "red_hot",
	2217: "shogun", 2219: "shogun",
	2214: "skull", 2216: "skull",
	2220: "taiji", 2222: "taiji",
	2238: "thunder", 2240: "thunder",
	2321: "waterborn", 2323: "waterborn",
}
## Kind -> [the first item id, the picture name, the rider id].
const NAMES := {
	"black_demon": [2292, "blackDemonEpicDragonUnit", 2294],
	"black": [2199, "blackEpicDragon", 2201],
	"dark_shogun": [2278, "darkShogunEpicDragonUnit", 2280],
	"electric": [2202, "electricEpicDragon", 2204],
	"enel": [2223, "enelEpicDragon", 2225],
	"ghost": [2327, "ghostEpicDragonUnit", 2329],
	"golden": [2196, "goldenEpicDragon", 2198],
	"jewel": [2205, "jewelEpicDragon", 2207],
	"laser": [2253, "laserEpicDragonUnit", 2255],
	"nebula": [2229, "nebulaEpicDragon", 2231],
	"neon": [2211, "neonEpicDragon", 2213],
	# The client checks the id of the Skull Epic Dragon rider (2216) here, so
	# the Red Hot Epic Dragon rider has no limit button.
	"red_hot": [2208, "redHotEpicDragon", 2216],
	"shogun": [2217, "shogunEpicDragon", 2219],
	"skull": [2214, "skullEpicDragon", 2216],
	"taiji": [2220, "taijiEpicDragon", 2222],
	"thunder": [2238, "thunderEpicDragonUnit", 2240],
	"waterborn": [2321, "waterbornEpicDragonUnit", 2323],
}
const NO_TARGET_TEXT := "No target within range"
const SEAL_DROP_FRAME := 88  ## The frame of the golden seal at which the units fall.


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return thumb(names[0], names[1], number)
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[2]
	match kind:
		"black_demon":
			add(ability, 0, "COAL FIREBALLS", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 18, 27, 36], 1, "p.violetFlameBall",
					Damages.PushInAir.new(sim, unit, atk * 1.28, 4).with_shared(true)).with_directional(true, 300), has_target(), NO_TARGET)
			var shadow := Damages.Sequenced.new(sim, unit).add(Damages.Freeze.new(sim, unit, atk * 4.3, 6, 5)) \
					.add(Damages.Simple.new(sim, unit, atk, 6, 5).with_shared(true)).with_shared(true)
			add(ability, 1, "SHADOW PROJECTION", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2,
					[17, 35, 45, 55, 65, 75, 85, 95, 105, 115, 125, 135, 145, 155], shadow, rng, 10), has_target(), NO_TARGET)
			add(ability, 2, "DARK FIRE WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 12,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), rng, 5), has_target(), NO_TARGET)
			add_minions(ability, 3, "BLACK DEMON EPIC DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2293, 1))
			if rider:
				limit_smash(ability, SP4, [26], 2, 8, 8)
		"black":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 14, 18], 5, "p.violetFlameBall"),
					has_target(), NO_TARGET)
			add(ability, 1, "Balls Rain", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 7, 3, SP2, MagicParticles.FROZEN_RAIN, null)
					.with_multiplier(1.25).with_delay(0.1), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Black Whirlwind", pic.call(3), _old_whirlwind(sim, unit, atk / 2, Damages.Freeze.new(sim, unit, 25, 5, 5)))
			_old_minions(sim, unit, ability, "Black Minions", pic.call(4), 2200)
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"dark_shogun":
			add(ability, 0, "MAHOU CROWN", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [16, 18, 21, 23, 26, 28], 4, "p.ballTitanHydros",
					Damages.Simple.new(sim, unit, atk * 0.68, 1, 1).with_shared(true), rng, 10).with_shared(true), has_target(), NO_TARGET)
			var sphere := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 4.3, 5).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 10, 10, 1000).with_shared(true)).with_shared(true)
			add(ability, 1, "SPHERE SUMMONING", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [23], sphere, int(rng * 1.3), 10), has_target(), NO_TARGET)
			var katana := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5).with_shared(true)) \
					.add(Damages.Dizzy.new(sim, unit, 50, 3, 6).with_shared(true)).with_shared(true)
			add(ability, 2, "KATANA INVOCATION", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 43, katana, 10, 5))
			add_minions(ability, 3, "DARK SHOGUN EPIC DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2279, 1))
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"electric":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 14, 18], 5, "p.crystalBall"),
					has_target(), NO_TARGET)
			var shock := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, 0, 5)) \
					.add(Damages.Electrocute.new(sim, unit, 10, 5, 1000))
			add(ability, 1, "Ray Storm", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 7, 3, SP2, MagicParticles.RAY, shock)
					.with_multiplier(1.25).with_delay(0.4), Callable(), NO_TARGET_TEXT)
			var whirl := _old_whirlwind(sim, unit, atk * 0.7, Damages.Electrocute.new(sim, unit, 10, 5, 1000))
			add(ability, 2, "Electric Whirlwind", pic.call(3), func(_s: BattleSim, _f: BattleFighter) -> void:
				whirl.execute()
				_random_beams(sim, unit, 15, 14, "p.electricityBeam", int(atk * 0.2)))
			_old_minions(sim, unit, ability, "Electric Minions", pic.call(4), 2203)
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"enel":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [10, 10, 10, 19, 19, 19], 4, "p.fireEnel",
					Damages.PushInAir.new(sim, unit, atk * 3, 2), 6, 4).with_shot_damage(false).with_directional(true, 300), has_target(), NO_TARGET)
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.Stealth.new(sim, unit, SP2, [26], 6, 10, 15), has_target(), NO_TARGET)
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Poison.new(sim, unit, 50, 3, 6)), 5, 5))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2224, 2))
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"ghost":
			add(ability, 0, "Dummy Attack", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 14, 18], 3, "p.necroFireball",
					Damages.PushInAir.new(sim, unit, atk * 1.16, 4).with_shared(true)).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "Dummy Attack", pic.call(2), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP2, MagicParticles.LIGHTING_NECRO,
					Damages.PushInAir.new(sim, unit, atk * 0.8, 4).with_shared(true)).with_frames([25]).with_shared(true), has_target(), NO_TARGET)
			var souls := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true)) \
					.add(Damages.Poison.new(sim, unit, 10)).with_shared(true)
			add(ability, 2, "Dummy Attack", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, souls, 5, 5).with_shared(true), has_target(), NO_TARGET)
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2328, 2))
			if rider:
				limit_healing(ability, beams(SP4, [16], 50, LIMIT_GREEN_BEAM))
		"golden":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 14, 18], 5, "p.lightBall"),
					has_target(), NO_TARGET)
			add(ability, 1, "Sky Sword", pic.call(2), func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP2, maxi(sim.animation_frames(unit, SP2, 40), 30), {30: func() -> void: _sky_sword(sim, unit)}, Callable(), true),
					Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Golden Whirlwind", pic.call(3), _old_whirlwind(sim, unit, atk / 2, Damages.Freeze.new(sim, unit, 25, 5, 5)))
			_old_minions(sim, unit, ability, "Gold Minions", pic.call(4), 2197)
			if rider:
				# The client uses the green beams of healing for this lightning attack.
				limit_lightning(ability, beams(SP3, [14], 50, LIMIT_GREEN_BEAM))
		"jewel":
			add(ability, 0, "Ruby Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [9, 14, 18], 5, "p.fireBall_02"),
					has_target(), NO_TARGET)
			add(ability, 1, "Emerald Storm", pic.call(2), SpecialAttacks.MultiBeam.new(sim, unit, SP2, [45], "p.lavaBeam", 5, 5, atk * 3.6, 1.8, true),
					Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Diamond Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, atk * 0.4)), 5, 5))
			add_minions(ability, 3, "Electric Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2206, 2))
			if rider:
				limit_lightning(ability, beams(SP3, [14], 50, LIMIT_RED_BEAM))
		"laser":
			add(ability, 0, "POINTER OF DEATH", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [45],
					Damages.PushInAir.new(sim, unit, atk * 4, 7).with_shared(true), 6, 20), has_target(), NO_TARGET)
			add(ability, 1, "HAND OF DESTRUCTION", pic.call(2), SpecialAttacks.EnergyBalls.new(sim, unit, SP2, [16, 23, 29], 3, "p.redLaser",
					_push_then_burn(sim, unit, atk * 1.15), rng, 5), has_target())
			add(ability, 2, "BEAM WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, _push_then_burn(sim, unit, atk * 2), 5, 5))
			add_minions(ability, 3, "LASER EPIC DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2254, 1))
			if rider:
				limit_lightning(ability, beams(SP4, [5], 50, LIMIT_RED_BEAM))
		"nebula":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [10], 3, "p.crystalBall"), has_target(), NO_TARGET)
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [77], Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Incinerate.new(sim, unit, 18, 10, 1000)), 10, 5))
			# Units with at most 500 life: death or a push with dizziness, half
			# and half; the other units: a push with dizziness.
			var weak := Damages.RandomizedFactor.new(sim, unit).add(Damages.DirectKill.new(sim, unit), 50) \
					.add(Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 30, 3, 3)), 50)
			var hole := Damages.ChosenByFilter.new(sim, unit) \
					.add(weak, func(target: BattleFighter) -> bool: return target.max_life() <= 500) \
					.add(Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 50, 4, 3)),
						func(_target: BattleFighter) -> bool: return true)
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.WhirlHole.new(sim, unit, SP3, [10], hole, 10, 10))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2230, 2))
			if rider:
				limit_healing(ability, beams(SP4, [14], 50, LIMIT_GREEN_BEAM))
		"neon":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [10, 15, 25, 35, 45, 55, 65],
					Damages.PushInAir.new(sim, unit, 220, 5), 13, 5), Callable(), NO_TARGET)
			add(ability, 1, "Autohealing", pic.call(2), SpecialAttacks.SelfHealing.new(sim, unit, SP2, [80], 1000))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 75, 5, 5)), 5, 5))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2212, 2))
			if rider:
				limit_healing(ability, beams(SP3, [14], 50, LIMIT_GREEN_BEAM))
		"red_hot":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [10, 10, 10, 19, 19, 19, 28, 28, 28], 4,
					"p.largeFireball").with_directional(true, 300), Callable(), NO_TARGET)
			var ghost_damage := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 0.5, 3)) \
					.add(Damages.Incinerate.new(sim, unit, 20, 10, 1000))
			add(ability, 1, "Ghost Attack", pic.call(2), SpecialAttacks.Ghosts.new(sim, unit, 2208, 4, 8, 5,
					func(battle: BattleSim, ghost: BattleFighter) -> SpecialAttacks.Attack:
						return SpecialAttacks.Area.new(battle, ghost, SP2, [35], ghost_damage, 5, 5)), Callable(), NO_TARGET)
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Incinerate.new(sim, unit, 5, 5, 500)), 5, 5))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2209, 2))
			if rider:
				limit_lightning(ability, beams(SP3, [14], 50, LIMIT_RED_BEAM))
		"shogun":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [16, 18, 21, 23, 26, 28], 4, "p.ballTitanHydros")
					.with_directional(true), has_target(), NO_TARGET)
			var waypoints := SpecialAttacks.Area.new(sim, unit, SP2, [20, 30, 40, 50, 60, 70, 75], Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 200, 3, 6)), 13, 5)
			waypoints.points = 2
			add(ability, 1, "Attack", pic.call(2), waypoints.with_shared(true))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 43, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 50, 3, 6)), 10, 5))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2218, 2))
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"skull":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [10, 19, 28, 37], 4, "p.fireBall_02"),
					has_target(), NO_TARGET)
			# While they float, 30% of the units die (a skull explodes on them)
			# and the others take 700 points.
			var float_damage := Damages.RandomizedFactor.new(sim, unit) \
					.add(Damages.Sequenced.new(sim, unit).add(Damages.AnimationDummy.new(sim, unit, "skullExplosion", 3)).add(Damages.DirectKill.new(sim, unit, 500)), 30) \
					.add(Damages.Simple.new(sim, unit, 700, 3, 5), 70)
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.SealArea.new(sim, unit, SP2, [25], 20, 10, MagicParticles.SKULL_SEAL,
					Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, 300, 3)), true, 300, float_damage).with_shared(true), has_target(), NO_TARGET)
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, 700, 5)).add(Damages.Simple.new(sim, unit, 300, 5, 5)), 5, 5).with_shared(true))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2215, 2))
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"taiji":
			add(ability, 0, "Rain Balls", pic.call(1), SpecialAttacks.Rain.new(sim, unit, 7, 3, SP1, MagicParticles.BALL_HEALTH, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Dizzy.new(sim, unit, 50, 3, 6))), Callable(), NO_TARGET)
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.HealthArea.new(sim, unit, SP2, [25], 10, 10, MagicParticles.SEAL_HEALTH,
					Damages.Health.new(sim, unit, 100)).with_shared(true))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.Attract.new(sim, unit, 900, 5, 0.5, 2.5)).add(Damages.PushInAir.new(sim, unit, 900, 5)), 10, 5)
					.with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2221, 2))
			if rider:
				limit_lightning(ability, beams(SP3, [14], 50, LIMIT_RED_BEAM, 100, 0.5))
		"thunder":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [11], 4, "p.cloudBall",
					Damages.Freeze.new(sim, unit, atk * 0.5, 3, 3), 5, 1), has_target(), NO_TARGET)
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [26], Damages.Dizzy.new(sim, unit, atk, 6, 5), 7, 15))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 6, 10, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Electrocute.new(sim, unit, 7, 20, 750, true)), 5, 5))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2239, 2))
			if rider:
				limit_lightning(ability, beams(SP4, [14], 50, LIMIT_RED_BEAM, 100, 0.5))
		"waterborn":
			add(ability, 0, "TSUNAMI!", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [23],
					Damages.PushInAir.new(sim, unit, atk * 2.92, 5).with_shared(true), int(rng * 1.5), 8).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "STEAM CLOUD", pic.call(2), SpecialAttacks.ShootProjectiles.new(sim, unit, SP2, [66],
					Damages.PushInAir.new(sim, unit, atk * 2.918, 4).with_shared(true), "p.steamRay", 1, 1, true).with_range(rng * 2), has_target(), NO_TARGET)
			var storm := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 0.6, 1).with_shared(true)) \
					.add(Damages.Dizzy.new(sim, unit, 0, 1, 1)).with_shared(true)
			add(ability, 2, "ICE STORM", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [23, 33, 43, 53, 63], storm, int(rng * 1.5), 10)
					.with_shared(true), has_target(), NO_TARGET)
			add_minions(ability, 3, "WATERBORN EPIC DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2322, 1))
			if rider:
				limit_lightning(ability, beams(SP4, [10], 50, LIMIT_RED_BEAM))


## A push of amount, then a fire of 5 points in 5 ticks of 500 ms.
static func _push_then_burn(sim: BattleSim, unit: BattleFighter, amount: float) -> UnitDamage:
	return Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, amount, 5).with_shared(true)) \
			.add(Damages.Incinerate.new(sim, unit, 5, 5, 500).with_shared(true)).with_shared(true)


## The whirlwind of the first epic dragons: for 8 seconds, every 1.5 seconds
## after 17 frames, the 5 nearest enemy units within 5 tiles take amount and
## fly 5 tiles; then after_push acts on them.
static func _old_whirlwind(sim: BattleSim, unit: BattleFighter, amount: float, after_push: UnitDamage) -> SpecialAttacks.Whirlwind:
	var damage := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, amount, 5)).add(after_push)
	return SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, damage, 5, 5)


## The minion button of the first epic dragons: 2 minions, at most 4 alive.
static func _old_minions(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, name: String, picture: String, minion_id: int) -> void:
	add(ability, 3, name, picture, func(_s: BattleSim, _f: BattleFighter) -> void: unit.ability.spawn_minions(sim, unit, minion_id, 2),
			below_minions(4), "4 " + MINIONS_MAX)


## count beams, one every interval frames, to random tiles within the attack
## range of the unit; each hurts the enemy item on its tile by damage.
static func _random_beams(sim: BattleSim, unit: BattleFighter, count: int, interval: int, graphic: String, damage: int) -> void:
	for i in count:
		sim.after(interval * (i + 1), func() -> void:
			if unit.dead:
				return
			var reach := unit.attack_range
			var offset := Vector2i(sim.rng.randi_range(-reach, reach), sim.rng.randi_range(-reach, reach))
			if offset.x == 0:
				offset.x = 1 if sim.rng.randf() < 0.5 else -1
			if offset.y == 0:
				offset.y = 1 if sim.rng.randf() < 0.5 else -1
			var tile := (unit.tile + offset).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
			var hit := sim.items_near(tile, 0, 1, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool: return not item.dead)
			sim.shoot_beam(unit, hit[0] if hit.size() > 0 else null, tile, graphic, 8, damage))


## Sky Sword of the Golden Epic Dragon: up to 5 enemy units with at most 500
## life near the centre of such units within 8 tiles float under a golden
## seal; they take 10 points every 500 ms, and at frame 88 of the seal they
## fall, take 0.75 times the attack and fly 5 tiles.
static func _sky_sword(sim: BattleSim, unit: BattleFighter) -> void:
	var weak := func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and item.max_life() <= 500 and (item.ability == null or not item.ability.immune_to_push)
	var side := BattleAbility.enemy_side(unit)
	var near := sim.items_near(unit.tile, 8, 15, side, true, weak)
	if near.is_empty():
		return
	var sum := Vector2.ZERO
	for item in near:
		sum += Vector2(item.tile)
	var centre := Vector2i(sum / near.size())
	var floating := sim.items_near(centre, 8, 5, side, true, weak)
	for target in floating:
		target.incapacitated = true
		target.levitating = true
		sim.state_changed.emit(target)
	sim.particle(unit, centre, MagicParticles.GOLDEN_SEAL, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
	for tick in range(15, SEAL_DROP_FRAME, 15):
		sim.after(tick, func() -> void:
			for target in floating:
				if not target.dead:
					sim.receive_attack(target, 10, unit if not unit.dead else null))
	sim.after(SEAL_DROP_FRAME, func() -> void:
		for target in floating:
			target.levitating = false
			target.incapacitated = target.frozen or target.stunned or target.in_air
			sim.state_changed.emit(target)
			if not target.dead:
				sim.receive_attack(target, int(unit.def.attack * 0.75), unit if not unit.dead else null)
				if not target.dead:
					sim.push_in_air(target, unit, 5))
