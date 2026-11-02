class_name ArmorDragons
extends SpecialUnit
## The armor dragons and their riders (the second id).

const UNITS := {
	2360: "bull", 2362: "bull",
	2351: "golden", 2353: "golden",
	2357: "platinum", 2359: "platinum",
	2347: "red", 2349: "red",
}
## Kind -> [the first item id, the picture name, the rider id].
const NAMES := {
	"bull": [2360, "bullArmorDragonUnit", 2362],
	"golden": [2351, "goldenArmorDragonUnit", 2353],
	"platinum": [2357, "platinumArmorDragonUnit", 2359],
	"red": [2347, "redArmorDragonUnit", 2349],
}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return thumb(names[0], names[1], number)
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[2]
	match kind:
		"bull":
			add(ability, 0, "DOME SHIELD", pic.call(1), SpecialAttacks.Shield.new(sim, unit, 0, 0.3, 10, "shield_bull"))
			add(ability, 1, "DRAGON CHARGE", pic.call(2), SpecialAttacks.Charge.new(sim, unit, SP2, [15],
					Damages.PushInAir.new(sim, unit, atk / 2, 4).with_shared(true), rng, 10), has_target(), NO_TARGET)
			add(ability, 2, "WAVE OF DOOM", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [50],
					Damages.PushInAir.new(sim, unit, atk * 4.1, 4).with_shared(true), rng, 20), has_target(), NO_TARGET)
			add_minions(ability, 3, "BULL ARMOR DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2361, 1))
			if rider:
				limit_lightning(ability, beams(SP5, [15], 50, LIMIT_RED_BEAM))
		"golden":
			add(ability, 0, "SPIRIT BOMB", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [61],
					Damages.PushInAir.new(sim, unit, atk * 4, 4).with_shared(true), "p.goldenBall", 1, 1, true), has_target(), NO_TARGET)
			add(ability, 1, "SHINING CHEST", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [31],
					Damages.Dizzy.new(sim, unit, atk * 4.2, 9, 1).with_shared(true), 10, 20), has_target(), NO_TARGET)
			# The client gives 5.5 seconds; the whirlwind hits 3 times either way.
			add(ability, 2, "MIDAS WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 5, 10,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), 3, 10)
					.with_end_damage(Damages.Dizzy.new(sim, unit, atk, 9, 1).with_shared(true)), has_target(), NO_TARGET)
			add_minions(ability, 3, "GOLDEN ARMOR DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2352, 1))
			if rider:
				limit_lightning(ability, beams(SP5, [10], 50, LIMIT_RED_BEAM))
		"platinum":
			add(ability, 0, "SHARP RAIN", pic.call(1), SpecialAttacks.Rain.new(sim, unit, rng, 1, SP1, MagicParticles.PLATINUM_SWORD,
					Damages.PushInAir.new(sim, unit, atk * 0.75, 4).with_shared(true), 2).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "CUTTER WHIRLWIND", pic.call(2), SpecialAttacks.Whirlwind.new(sim, unit, SP2, 6, 10,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), 5, 5), has_target(), NO_TARGET)
			add(ability, 2, "TRIPLE DEATH", pic.call(3), SpecialAttacks.Eat.new(sim, unit, SP3, [33], [55], Damages.DirectKill.new(sim, unit, 500),
					["sub0", "sub1", "sub2"], rng), has_target_life(0, 500, 2), NO_TARGET)
			add_minions(ability, 3, "PLATINUM ARMOR DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2358, 1))
			if rider:
				limit_smash(ability, SP5, [38, 48, 55], 2, 8, 8)
		"red":
			add(ability, 0, "ENERGY SPHERES", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [23, 28, 33, 38, 43, 48, 53, 58, 63], 3.2,
					"p.redArmor", Damages.Simple.new(sim, unit, atk * 4), 10, 1).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "TRAP SUMMONING", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [67],
					Damages.Dizzy.new(sim, unit, atk * 4.21, 5, 1).with_shared(true), rng, 20), has_target(), NO_TARGET)
			add(ability, 2, "BLADE WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 12, 10,
					Damages.PushInAir.new(sim, unit, atk / 3, 4).with_shared(true), 3, 10), has_target(), NO_TARGET)
			add_minions(ability, 3, "RED ARMOR DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2348, 1))
			if rider:
				limit_healing(ability, beams(SP5, [16], 50, LIMIT_GREEN_BEAM))
