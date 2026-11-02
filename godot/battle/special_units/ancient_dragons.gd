class_name AncientDragons
extends SpecialUnit
## The ancient dragons and their riders. Each has four buttons; only the
## rider (the second id) has the limit button.

const UNITS := {
	2354: "abyss", 2356: "abyss",
	2281: "ancient", 2283: "ancient",
	2336: "cerberus", 2338: "cerberus",
	2299: "core", 2301: "core",
	2295: "corpse", 2297: "corpse",
	2370: "dark_horror", 2375: "dark_horror",
	2366: "devil", 2368: "devil",
	2305: "ent", 2307: "ent",
	2302: "hellborn", 2304: "hellborn",
	2308: "horror", 2313: "horror",
	2289: "rune", 2291: "rune",
	2284: "shaman", 2286: "shaman",
	2344: "wolf", 2346: "wolf",
}
## Kind -> [the first item id, the picture name, the rider id].
const NAMES := {
	"abyss": [2354, "abyssAncientDragonUnit", 2356],
	"ancient": [2281, "ancientDragonUnit", 2283],
	"cerberus": [2336, "cerberusAncientDragonUnit", 2338],
	"core": [2299, "coreAncientDragonUnit", 2301],
	"corpse": [2295, "corpseAncientDragonUnit", 2297],
	"dark_horror": [2370, "darkHorrorAncientDragonUnit", 2375],
	"devil": [2366, "devilAncientDragonUnit", 2368],
	"ent": [2305, "entAncientDragonUnit", 2307],
	"hellborn": [2302, "hellbornAncientDragonUnit", 2304],
	"horror": [2308, "horrorAncientDragonUnit", 2313],
	"rune": [2289, "runeAncientDragonUnit", 2291],
	"shaman": [2284, "shamanAncientDragonUnit", 2286],
	"wolf": [2344, "wolfAncientDragonUnit", 2346],
}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return thumb(names[0], names[1], number)
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[2]
	match kind:
		"abyss":
			add(ability, 0, "TSUNAMI WAVE", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [38, 41, 44, 54],
					Damages.PushInAir.new(sim, unit, atk * 2.92, 5).with_shared(true), int(rng * 1.5), 8).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "ICE RAINFALL", pic.call(2), SpecialAttacks.Rain.new(sim, unit, rng, 1, SP2, MagicParticles.ICE_SHARD,
					Damages.PushInAir.new(sim, unit, atk * 0.75, 4).with_shared(true)).with_shared(true), has_target(), NO_TARGET)
			add(ability, 2, "ACQUA STREAM", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [35, 50, 65, 80, 95, 110],
					Damages.PushInAir.new(sim, unit, atk * 4 / 6, 10).with_shared(true), rng, 10), has_target(), NO_TARGET)
			add_minions(ability, 3, "ABYSS ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2355, 1))
			if rider:
				limit_smash(ability, SP5, [38, 48, 60], 2, 8, 8)
		"ancient":
			add(ability, 0, "CLAWS OF DESTRUCTION", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [16, 26, 36, 46, 56, 66],
					_push_then_burn(sim, unit, atk), int(rng * 1.5), 10), has_target(), NO_TARGET)
			add(ability, 1, "SOUL DEVOURER", pic.call(2), SpecialAttacks.Eat.new(sim, unit, SP2, [14], [99],
					Damages.DirectKill.new(sim, unit, 500), ["eatPoint"], rng), _target_max_life(0, 500), NO_TARGET)
			add(ability, 2, "FLAMING ROAR", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [47],
					_push_then_burn(sim, unit, atk * 4.03), int(rng * 1.5), 10), has_target())
			add_minions(ability, 3, "ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2282, 1))
			if rider:
				limit_lightning(ability, beams(SP4, [15], 50, LIMIT_RED_BEAM))
		"cerberus":
			add(ability, 0, "ARMAGEDDON RAIN", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [82, 87, 91, 94, 97, 100, 103, 106, 109, 112, 115],
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), int(rng * 1.4), 15), has_target(), NO_TARGET)
			add(ability, 1, "LETHAL VENOM", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [75],
					Damages.Incinerate.new(sim, unit, 30, 4, 1000).with_incapacitate(true), rng * 2, 20), has_target_in_range(rng * 3), NO_TARGET)
			add(ability, 2, "THREE-HEADED RAY", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [95, 107, 120],
					Damages.PushInAir.new(sim, unit, atk * 4.6 / 2, 4).with_shared(true), int(rng * 1.4), 15), has_target(), NO_TARGET)
			# One minion of each kind: fire, poison and bones.
			var spawn := SpecialAttacks.SpawnMultiple.new(sim, unit, [2337, 2342, 2343], [1, 1, 1])
			add(ability, 3, "CERBERUS ANCIENT DRAGGIES", pic.call(4), spawn, below_minions(3), "3 " + MINIONS_MAX)
			if rider:
				limit_lightning(ability, beams(SP4, [35], 50, LIMIT_RED_BEAM))
		"core":
			add(ability, 0, "BLAZE STOMP!", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [35],
					Damages.PushInAir.new(sim, unit, atk * 3.2, 4).with_shared(true), rng, 10), has_target(), NO_TARGET)
			add(ability, 1, "BERSERK FLAMES", pic.call(2), SpecialAttacks.MultiBeam.new(sim, unit, SP2, [21], "p.firebeamBahamut",
					rng * 3, 1, atk * 0.4, 0.5).with_timeout(5).with_shared(true), has_target(), NO_TARGET)
			add(ability, 2, "IGNITION ROCK", pic.call(3), SpecialAttacks.ShootProjectiles.new(sim, unit, SP3, [44],
					Damages.PushInAir.new(sim, unit, atk * 3.18, 4).with_shared(true), "p.flamingRock", 1, 1, true), has_target(), NO_TARGET)
			var blast := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 3.18, 4).with_shared(true)) \
					.add(Damages.Incinerate.new(sim, unit, 10, 5, 100)).with_shared(true)
			add(ability, 3, "MAGMA BLAST", pic.call(4), SpecialAttacks.Area.new(sim, unit, SP4, [64], blast, rng, 10), has_target(), NO_TARGET)
			if rider:
				limit_smash(ability, SP5, [33], 1.5, 8, 8)
		"corpse":
			add(ability, 0, "LETHAL SKULL", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [15],
					Damages.DirectKill.new(sim, unit, 500), "p.violetSkull", 1, 1, true), has_target_life(0, 500), NO_TARGET)
			var poison := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 5.13, 4).with_shared(true)) \
					.add(Damages.Poison.new(sim, unit, 10)).with_shared(true)
			add(ability, 1, "POISONOUS SPIRITS", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [35], poison, rng, 10), has_target(), NO_TARGET)
			add(ability, 2, "SOULS WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 6, 17,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), 5, 5), Callable(), NO_TARGET)
			add_minions(ability, 3, "CORPSE ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2296, 1))
			if rider:
				limit_lightning(ability, beams(SP5, [2], 50, LIMIT_RED_BEAM))
		"dark_horror":
			_four_minions(sim, unit, ability, pic, ["DEVOURER", "SPIDER", "BLOW-BUG", "ABOMINATION"], [2371, 2372, 2373, 2374], [10, 3, 2, 1])
			if rider:
				limit_smash(ability, SP4, [30], 2, 8, 8)
		"devil":
			add(ability, 0, "CATAPULT TAIL", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [32],
					Damages.PushInAir.new(sim, unit, atk * 4, 4).with_shared(true), "p.fireBallDevil", 1, 1, true).with_count(15), has_target(), NO_TARGET)
			# The client also shows the soul of each unit that this attack kills.
			add(ability, 1, "SKULL BREATH", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [23, 28, 33, 37],
					Damages.Simple.new(sim, unit, atk, 0, 1).with_shared(true), rng, 2), has_target(), NO_TARGET)
			add(ability, 2, "DANCE OF DEATH", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [41, 43, 47, 51, 53, 56, 60, 62, 70, 73, 77],
					Damages.PushInAir.new(sim, unit, atk / 4, 4).with_shared(true), rng, 3), has_target(), NO_TARGET)
			add_minions(ability, 3, "DEVIL ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2367, 1))
			if rider:
				limit_lightning(ability, beams(SP5, [20], 50, LIMIT_RED_BEAM))
		"ent":
			add(ability, 0, "ROOT TSUNAMI", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [32],
					Damages.PushInAir.new(sim, unit, atk * 3.69, 4).with_shared(true), int(rng * 1.5), 10), has_target(), NO_TARGET)
			add(ability, 1, "LEAF HURRICANE", pic.call(2), SpecialAttacks.SpawnMinion.new(sim, unit, 2314, 1, 1))
			add(ability, 2, "DEADLY TONGUE", pic.call(3), SpecialAttacks.Tongue.new(sim, unit, SP3, 6, 14, "p.woodTongue"),
					has_target_life(0, 500, rng + 1), NO_TARGET)
			add_minions(ability, 3, "ENT ANCIENT DRAGGIES", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2306, 6, 6))
			if rider:
				limit_healing(ability, beams(SP4, [10], 50, LIMIT_GREEN_BEAM))
		"hellborn":
			# The first unit with at most 500 life dies; the others are poisoned.
			var hit := [0]
			var roulette := Damages.ChosenByFilter.new(sim, unit) \
					.add(Damages.DirectKill.new(sim, unit, 500), func(target: BattleFighter) -> bool:
						if hit[0] >= 1 or target.max_life() > 500:
							return false
						hit[0] += 1
						return true) \
					.add(Damages.Poison.new(sim, unit, 15, 10, 10), func(_target: BattleFighter) -> bool: return true)
			add(ability, 0, "POISON ROULETTE", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [21], roulette, rng, 10)
					.with_end_action(func() -> void: hit[0] = 0), has_target(), NO_TARGET)
			add(ability, 1, "CONVERSION SEAL", pic.call(2), SpecialAttacks.SealArea.new(sim, unit, SP2, [21], rng, 5,
					MagicParticles.SKULL_SEAL, Damages.ConvertToAlly.new(sim, unit, 10), true, 150), has_target(), NO_TARGET)
			var venom := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 3.7, 4).with_shared(true)) \
					.add(Damages.Poison.new(sim, unit, 10)).with_shared(true)
			add(ability, 2, "VENOM EXPLOSION", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [35], venom, rng, 12), has_target(), NO_TARGET)
			add_minions(ability, 3, "HELLBORN ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2303, 1))
			if rider:
				# The client uses the green beams of healing for this lightning attack.
				limit_lightning(ability, beams(SP4, [35], 50, LIMIT_GREEN_BEAM))
		"horror":
			_four_minions(sim, unit, ability, pic, ["DEVOURER", "ATROCITY", "BLOW-BUG", "IMPALER"], [2309, 2310, 2311, 2312], [10, 1, 2, 3])
			if rider:
				limit_smash(ability, SP4, [30], 2, 8, 8)
		"rune":
			add(ability, 0, "STONE PROJECTILES", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [19, 23, 27, 31, 35, 39, 43, 47, 51, 55, 59],
					1, "p.runeRock", Damages.PushInAir.new(sim, unit, atk, 4), rng), has_target(), NO_TARGET)
			var bubble := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk * 2, 5).with_shared(true)) \
					.add(Damages.Dizzy.new(sim, unit, 10, 5, 10).with_shared(true)).with_shared(true)
			add(ability, 1, "RUNE MYSTIC BUBBLE", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [15, 25, 35, 45, 55, 65, 75], bubble,
					int(rng * 1.3), 5).with_shared(true), Callable(), NO_TARGET)
			add(ability, 2, "DEADLY FISSURES", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [33], Damages.DieAnimation.new(sim, unit), rng, 1)
					.with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500), has_target_life(0, 500), NO_TARGET)
			add_minions(ability, 3, "RUNE ANCIENT DRAGON", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2290, 1))
			if rider:
				limit_smash(ability, SP5, [31], 1, 8, 8)
		"shaman":
			add(ability, 0, "Energy Balls", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [47],
					Damages.DirectKill.new(sim, unit, 500), "p.tribalSymbol", 1, 1, true), has_target_life(0, 500), "No valid target within range")
			add(ability, 1, "Attack", pic.call(2), SpecialAttacks.MultiBeam.new(sim, unit, SP2, [20], "p.lightBeam", rng, 1, atk, 1.0, true)
					.with_invulnerable(true))
			add(ability, 2, "Whirlwind", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [60],
					Damages.PushInAir.new(sim, unit, atk * 4.2, 5).with_shared(true), rng, 10).with_shared(true))
			add_minions(ability, 3, "Minions", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2285, 1))
			if rider:
				limit_healing(ability, beams(SP5, [10], 50, LIMIT_GREEN_BEAM))
		"wolf":
			add(ability, 0, "BERSERK SEAL", pic.call(1), SpecialAttacks.PowerUp.new(sim, unit, SP1, [20], rng, 12), Callable(), NO_TARGET)
			add(ability, 1, "X SCRATCH", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [39, 43, 46, 48, 51],
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), int(rng * 1.2), 15), has_target(), NO_TARGET)
			add(ability, 2, "LUNATIC EXPLOSION", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [89],
					Damages.PushInAir.new(sim, unit, atk * 4, 4).with_shared(true), rng, 15), has_target(), NO_TARGET)
			add_minions(ability, 3, "WOLF ANCIENT DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2345, 1))
			if rider:
				limit_smash(ability, SP4, [28], 2, 8, 8)


## A push of amount, then a fire of 10 points in 10 ticks of 100 ms.
static func _push_then_burn(sim: BattleSim, unit: BattleFighter, amount: float) -> UnitDamage:
	return Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, amount, 4).with_shared(true)) \
			.add(Damages.Incinerate.new(sim, unit, 10, 10, 100).with_shared(true)).with_shared(true)


## The target is a unit in range with a maximum life from low to high; the
## Ancient Dragon checks the range with <= (hasTargetWithMaxLife).
static func _target_max_life(low: int, high: int) -> Callable:
	return func(sim: BattleSim, fighter: BattleFighter) -> bool:
		var target := fighter.target
		return target != null and not target.dead and target.is_unit() and sim.distance(fighter, target) <= fighter.attack_range \
				and target.max_life() >= low and target.max_life() <= high


## Four buttons that each summon one kind of minion up to its number.
static func _four_minions(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, pic: Callable, names: Array, ids: Array, counts: Array) -> void:
	for i in 4:
		add_minions(ability, i, names[i], pic.call(i + 1), SpecialAttacks.SpawnMinion.new(sim, unit, ids[i], counts[i], counts[i]))
