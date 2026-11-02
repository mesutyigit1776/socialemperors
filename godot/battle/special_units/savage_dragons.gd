class_name SavageDragons
extends SpecialUnit
## The savage dragons and their riders (the second id).

const UNITS := {
	2256: "diamonds", 2258: "diamonds",
	2250: "rock", 2252: "rock",
	2241: "savage", 2243: "savage",
	2244: "scorch", 2246: "scorch",
	2247: "shock", 2249: "shock",
	2259: "space", 2261: "space",
}
## Kind -> [the first item id, the picture name, the rider id].
const NAMES := {
	"diamonds": [2256, "diamondsSavageDragonUnit", 2258],
	"rock": [2250, "rockSavageDragonUnit", 2252],
	"savage": [2241, "savageDragon", 2243],
	"scorch": [2244, "scorchSavageDragonUnit", 2246],
	"shock": [2247, "shockSavageDragonUnit", 2249],
	"space": [2259, "spaceSavageDragonUnit", 2261],
}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return thumb(names[0], names[1], number)
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[2]
	match kind:
		"diamonds":
			var block := Damages.Delayed.new(sim, unit, Damages.PushInAir.new(sim, unit, atk, 5).with_shared(true), 1300).with_shared(true)
			add(ability, 0, "DIAMOND BLOCK", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [5], block, "", 1, 1, true)
					.with_blast("b.diamondGrowFromGround").with_count(10).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "CRYSTAL RAIN", pic.call(2), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP2, MagicParticles.DIAMONDS_RAIN,
					Damages.PushInAir.new(sim, unit, atk, 3).with_shared(true), 3).with_delay(0.1).with_frames([10, 20, 30, 40]).with_shared(true))
			add(ability, 2, "BOOMERANG METAMORPHOSIS", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [17, 20, 25, 30, 35, 40, 45, 50],
					Damages.PushInAir.new(sim, unit, atk * 1.6, 3).with_shared(true), 10, 20))
			add_minions(ability, 3, "DIAMONDS SAVAGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2257, 1))
			if rider:
				limit_healing(ability, beams(SP4, [10], 50, LIMIT_GREEN_BEAM))
		"rock":
			add(ability, 0, "PEBBLE RAIN", pic.call(1), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP1, MagicParticles.ROCKS_RAIN,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true)).with_frames([25]).with_shared(true), has_target(), NO_TARGET)
			add(ability, 1, "METEOR EARTHQUAKE", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [29],
					Damages.PushInAir.new(sim, unit, atk * 5, 3).with_shared(true), 6, 10))
			add(ability, 2, "ROLLING BOULDER", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17,
					Damages.PushInAir.new(sim, unit, atk, 5).with_shared(true), 5, 5))
			add_minions(ability, 3, "ROCK SAVAGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2251, 1))
			if rider:
				limit_healing(ability, beams(SP4, [5], 50, LIMIT_GREEN_BEAM))
		"savage":
			# The pictures of this dragon have other names.
			pic = func(number: int) -> String: return "2241_savageDragon_SpecialAttack%d" % number
			add(ability, 0, "Sky Fall", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [29], Damages.PushInAir.new(sim, unit, atk * 4, 4), 5, 8)
					.with_shared(true))
			var snack := Damages.Sequenced.new(sim, unit).add(Damages.HealthSelf.new(sim, unit, atk)).add(Damages.DirectKill.new(sim, unit))
			add(ability, 1, "Healing Snack", pic.call(2), SpecialAttacks.Eat.new(sim, unit, SP2, [11], [65], snack, ["sub2"], 5).with_incapacitate(true)
					.with_filter(func(target: BattleFighter) -> bool: return target.max_life() <= 500), has_target(), NO_TARGET)
			add(ability, 2, "Fireball Ring", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [41, 57, 73], _push_then_burn(sim, unit, atk), 6, 8))
			add_minions(ability, 3, "Savage Draggy", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2242, 1))
			if rider:
				limit_healing(ability, beams(SP4, [9], 50, LIMIT_GREEN_BEAM))
		"scorch":
			add(ability, 0, "Flamethrower", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [41, 57, 73], _push_then_burn(sim, unit, atk), 6, 8),
					has_target(), NO_TARGET)
			add(ability, 1, "Tornado of death", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [25], Damages.DirectKill.new(sim, unit, 500), 10, 1),
					has_target_life(0, 500), NO_TARGET)
			var twister := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 5)) \
					.add(Damages.Incinerate.new(sim, unit, 20, 10, 1000)).with_shared(true)
			add(ability, 2, "Flame Twister", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 12, twister, 5, 5))
			add_minions(ability, 3, "Sorch Savage Draggy", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2245, 1))
			if rider:
				limit_smash(ability, SP4, [31, 38, 45, 52, 62], 2, 8, 8)
		"shock":
			add(ability, 0, "LIGHTNING INVOCATION", pic.call(1), SpecialAttacks.Rain.new(sim, unit, rng, 1.5, SP1, MagicParticles.LIGHTNING_HUGE,
					Damages.PushInAir.new(sim, unit, atk * 0.36, 3).with_shared(true), 3).with_delay(0.2).with_frames([10, 22, 34]).with_shared(true),
					has_target(), NO_TARGET)
			add(ability, 1, "SUDDEN RAY-DEATH", pic.call(2), SpecialAttacks.EnergyBalls.new(sim, unit, SP2, [18], 0, "p.crystalBall",
					Damages.DirectKill.new(sim, unit, 500), 5, 1), has_target_life(0, 500), NO_TARGET)
			add(ability, 2, "VOLTAIC WHIRLWIND", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, Damages.Sequenced.new(sim, unit)
					.add(Damages.PushInAir.new(sim, unit, atk, 5)).add(Damages.Electrocute.new(sim, unit, 5, 5, 750)), 5, 5))
			add_minions(ability, 3, "SHOCK SAVAGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2248, 1))
			if rider:
				limit_lightning(ability, beams(SP4, [10], 50, LIMIT_RED_BEAM))
		"space":
			add(ability, 0, "SHOOTING STARS", pic.call(1), SpecialAttacks.EnergyBalls.new(sim, unit, SP1, [14, 18, 22, 26, 30, 34, 38, 42, 46, 49], 1.6,
					"p.purpleBall", Damages.PushInAir.new(sim, unit, atk * 0.5, 4).with_shared(true), rng, 10), has_target(), NO_TARGET)
			add(ability, 1, "SUPERNOVA", pic.call(2), SpecialAttacks.ShootProjectiles.new(sim, unit, SP2, [25],
					Damages.PushInAir.new(sim, unit, atk * 3.75, 6).with_shared(true), "", 1, 1, true).with_blast("b.spaceSupernova").with_count(10)
					.with_shared(true), has_target())
			add(ability, 2, "MULTIVERSAL RAY", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [15, 30, 45],
					Damages.PushInAir.new(sim, unit, atk * 1.35, 5).with_shared(true), rng, 10), has_target())
			add_minions(ability, 3, "SPACE SAVAGE DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2260, 1))
			if rider:
				limit_smash(ability, SP4, [31], 2, 8, 8)


## A push of a quarter of the attack, then a fire of a quarter of the attack
## in 3 ticks of 500 ms.
static func _push_then_burn(sim: BattleSim, unit: BattleFighter, atk: float) -> UnitDamage:
	return Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk / 4, 5)).add(Damages.Incinerate.new(sim, unit, atk / 4, 3, 500))
