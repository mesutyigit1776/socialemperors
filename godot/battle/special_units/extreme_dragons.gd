class_name ExtremeDragons
extends SpecialUnit
## The extreme dragons and their riders (the second id). The client writes
## most of these attacks in the unit classes themselves.

const UNITS := {
	2180: "bull", 2182: "bull",
	2171: "electric", 2173: "electric",
	2177: "fire", 2179: "fire",
	2186: "forest", 2188: "forest",
	2183: "frost", 2185: "frost",
	2174: "golden", 2176: "golden",
	2193: "soul", 2195: "soul",
	2190: "wind", 2192: "wind",
	2333: "rock", 2335: "rock",
	2318: "wraith", 2320: "wraith",
}
## Kind -> [the picture names with %d for the button number, the rider id].
const NAMES := {
	"bull": ["2180_special_%d", 2182],
	"electric": ["2171_electricExtremeDragon_button%d", 2173],
	"fire": ["2177_%d", 2179],
	"forest": ["2186_forestExtremeDragon_button_%d", 2188],
	"frost": ["2183_special_%d", 2185],
	"golden": ["2174_goldenExtremeDragon_button%d", 2176],
	"soul": ["2193_soulExtremeDragon_%d", 2195],
	"wind": ["2190_windExtremeDragon_%d", 2192],
	"rock": ["2333_rockExtremeDragonUnit_button_%d", 2335],
	"wraith": ["2318_wraithExtremeDragonUnit_button_%d", 2320],
}
const NO_TARGET_TEXT := "No target within range"
const PLANTS := 18
const BUGS := 15
const BUG_ID := 2189
const BUG_SECONDS := 15
const MINI_WHIRLWIND_ID := 2147
const MINI_WHIRLWIND_SECONDS := 11
const PLANT_EAT_FRAMES := 30  ## The plant holds the unit this long before it dies.


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var names: Array = NAMES[kind]
	var pic := func(number: int) -> String: return names[0] % number
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	var rider: bool = unit.def.id == names[1]
	var freeze := func() -> UnitDamage: return Damages.Freeze.new(sim, unit, 125, 5, 5)
	match kind:
		"bull":
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [25, 30, 35], func() -> void:
				_shoot_then(sim, unit, "p.dualWhite", int(atk / 2), freeze.call()), 5), has_target(), NO_TARGET_TEXT)
			# The client also makes the dragon invisible: enemies do not choose it.
			# The attack object must live outside the button action: the frame
			# events of the animation do not keep it.
			var invisible := SpecialAttacks.Frames.new(sim, unit, SP2, [32, 37, 43], func() -> void:
				_shoot_then(sim, unit, "p.dualWhite", int(atk / 2), null), 3)
			add(ability, 1, "Ultra Fireball", pic.call(2), func(_s: BattleSim, _f: BattleFighter) -> void:
				var factor := unit.damage_factor
				unit.damage_factor = 0.0
				invisible.execute()
				sim.after(4 * BattleSim.FRAMES_PER_SECOND, func() -> void: unit.damage_factor = factor), has_target(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), _whirlwind(sim, unit, atk / 2, freeze.call(), 1500))
			_minions(sim, unit, ability, pic.call(4), 2181, true)
			if rider:
				limit_smash(ability, SP4, [29], 2, 6, 6)
		"electric":
			var shock := func() -> UnitDamage: return Damages.Electrocute.new(sim, unit, 25, 5, 1000, true)
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [30], func() -> void:
				var damage := Damages.Sequenced.new(sim, unit).add(Damages.Simple.new(sim, unit, atk / 3, 0, 1, false)).add(shock.call())
				for hit in directional_hits(sim, unit, 6, 6, 4):
					if damage.can_apply(hit):
						damage.apply(hit), 4), has_target(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [60],
					_push_then(sim, unit, atk / 2, 10, shock.call()), 8, 10), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), _whirlwind(sim, unit, atk, null, 1000))
			_minions(sim, unit, ability, pic.call(4), 2172, true)
			if rider:
				limit_lightning(ability, beams(SP4, [14], 50, LIMIT_RED_BEAM))
		"fire":
			add(ability, 0, "Mega Slash", pic.call(1), _directional_push(sim, unit, atk / 2), has_target(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 4, 2, SP2, MagicParticles.MAGMA_BALL_RAIN, null)
					.with_multiplier(2).with_frames([59]), has_target(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), _whirlwind(sim, unit, atk / 2, null, 1500))
			_minions(sim, unit, ability, pic.call(4), 2178, true)
			if rider:
				limit_lightning(ability, beams(SP4, [14], 50, LIMIT_RED_BEAM))
		"forest":
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [24], func() -> void: _plant_beam(sim, unit)),
					has_target(), NO_TARGET)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Frames.new(sim, unit, SP2, [23], func() -> void: _plants(sim, unit)),
					has_target(), NO_TARGET_TEXT)
			var whirl := _whirlwind(sim, unit, atk / 2, null, 1000)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), func(_s: BattleSim, _f: BattleFighter) -> void:
				whirl.execute()
				_bugs(sim, unit))
			_minions(sim, unit, ability, pic.call(4), 2187, false)
			if rider:
				limit_healing(ability, LimitAttacks.Beams.new(SP3, [14], 100, 100, LIMIT_GREEN_BEAM, 0.4, false, 2))
		"frost":
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [26], func() -> void:
				for i in 2:
					_frost_tornado(sim, unit, freeze)), func(_s: BattleSim, fighter: BattleFighter) -> bool:
						return fighter.target != null and not fighter.target.dead and fighter.target.is_unit(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [36],
					_push_then(sim, unit, atk / 2, 5, freeze.call()), 9, 10), has_target(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), _whirlwind(sim, unit, atk / 2, freeze.call(), 1500))
			_minions(sim, unit, ability, pic.call(4), 2184, false)
			if rider:
				limit_smash(ability, SP4, [29], 2, 9, 6)
		"golden":
			add(ability, 0, "Mega Slash", pic.call(1), _directional_push(sim, unit, atk / 2), has_target(), NO_TARGET_TEXT)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [48],
					Damages.PushInAir.new(sim, unit, atk, 10), 8, 15), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), _whirlwind(sim, unit, atk, null, 1000))
			_minions(sim, unit, ability, pic.call(4), 2175, true)
			if rider:
				limit_healing(ability, beams(SP3, [14], 50, LIMIT_GREEN_BEAM))
		"soul":
			add(ability, 0, "Soul Skulls", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [24], func() -> void:
				_shoot_then(sim, unit, "p.dragonSkull", unit.attack, Damages.Simple.new(sim, unit, 700, 0, 1, false))), has_target(), NO_TARGET)
			add(ability, 1, "Ultra Smash", pic.call(2), SpecialAttacks.Area.new(sim, unit, SP2, [48],
					Damages.PushInAir.new(sim, unit, atk, 10), 8, 15), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Super Whirlwind", pic.call(3), _whirlwind(sim, unit, atk / 2, null, 1500))
			_minions(sim, unit, ability, pic.call(4), 2194, false)
			if rider:
				limit_lightning(ability, beams(SP4, [14], 50, LIMIT_RED_BEAM))
		"wind":
			add(ability, 0, "Mega Slash", pic.call(1), SpecialAttacks.Frames.new(sim, unit, SP1, [14], func() -> void: _mini_whirlwinds(sim, unit)),
					Callable(), NO_TARGET)
			add(ability, 1, "Ultra Fireball", pic.call(2), SpecialAttacks.Rain.new(sim, unit, 7, 3, SP2, MagicParticles.THUNDERBOLT, null)
					.with_multiplier(1.25).with_frames([28]), Callable(), NO_TARGET_TEXT)
			add(ability, 2, "Hyper Whirlwind", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, WindHit.new(sim, unit, atk / 2), 5, 5)
					.with_interval(1000))
			_minions(sim, unit, ability, pic.call(4), 2191, false)
			if rider:
				limit_smash(ability, SP4, [29], 2, 8, 8)
		"rock":
			add(ability, 0, "ROCK PUNCH!", pic.call(1), SpecialAttacks.ShootProjectiles.new(sim, unit, SP1, [64],
					Damages.PushInAir.new(sim, unit, atk * 3.41, 4).with_shared(true), "p.bigRock", 1, 1, true), has_target(), NO_TARGET)
			add(ability, 1, "ROCK RAIN!", pic.call(2), SpecialAttacks.Rain.new(sim, unit, rng, 1, SP2, MagicParticles.ROCKS,
					Damages.PushInAir.new(sim, unit, atk * 0.75, 4).with_shared(true)).with_shared(true), has_target(), NO_TARGET)
			# The first unit with at most 500 life falls into a crevice and
			# dies; the others are dizzy.
			var hit := [0]
			var crevices := Damages.ChosenByFilter.new(sim, unit) \
					.add(Damages.DieAnimation.new(sim, unit), func(target: BattleFighter) -> bool:
						if hit[0] > 0 or target.max_life() > 500:
							return false
						hit[0] += 1
						return true) \
					.add(Damages.Dizzy.new(sim, unit, 10, 3, 2), func(_target: BattleFighter) -> bool: return true)
			add(ability, 2, "CREVICES OF DEATH", pic.call(3), SpecialAttacks.Area.new(sim, unit, SP3, [33], crevices, rng, 10)
					.with_end_action(func() -> void: hit[0] = 0), has_target(), NO_TARGET)
			add_minions(ability, 3, "ROCK EXTREME DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2334, 1))
			if rider:
				limit_smash(ability, SP4, [28], 2, 8, 8)
		"wraith":
			add(ability, 0, "MAGIC STAMP", pic.call(1), SpecialAttacks.Area.new(sim, unit, SP1, [28],
					Damages.PushInAir.new(sim, unit, atk * 3.62, 4).with_shared(true), rng, 8), has_target(), NO_TARGET)
			add(ability, 1, "GOBBLE UP", pic.call(2), SpecialAttacks.Eat.new(sim, unit, SP2, [21], [63], Damages.DirectKill.new(sim, unit, 500),
					["sub2"], rng), has_target_life(0, 500), NO_TARGET)
			add(ability, 2, "BONE HURRICANE", pic.call(3), SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 43,
					Damages.PushInAir.new(sim, unit, atk, 4).with_shared(true), rng, 5), has_target(), NO_TARGET)
			add_minions(ability, 3, "WRAITH EXTREME DRAGGY", pic.call(4), SpecialAttacks.SpawnMinion.new(sim, unit, 2319, 1))
			if rider:
				limit_healing(ability, beams(SP4, [16], 50, LIMIT_GREEN_BEAM))


## A push of amount over tiles, then then_damage when the unit lands.
static func _push_then(sim: BattleSim, unit: BattleFighter, amount: float, tiles: int, then_damage: UnitDamage) -> UnitDamage:
	var damage := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, amount, tiles))
	return damage.add(then_damage) if then_damage != null else damage


## The whirlwind of the extreme dragons: for 8 seconds, every interval_ms
## after 17 frames, the 5 nearest enemy units within 5 tiles take amount and
## fly 5 tiles, then after_push acts on them.
static func _whirlwind(sim: BattleSim, unit: BattleFighter, amount: float, after_push: UnitDamage, interval_ms: int) -> SpecialAttacks.Whirlwind:
	return SpecialAttacks.Whirlwind.new(sim, unit, SP3, 8, 17, _push_then(sim, unit, amount, 5, after_push), 5, 5).with_interval(interval_ms)


## For 4 seconds, at frame 30 of each loop, the units of the directional
## attack (6 tiles, radius 6, at most 5 hits) take amount and fly 3 tiles.
static func _directional_push(sim: BattleSim, unit: BattleFighter, amount: float) -> SpecialAttacks.Frames:
	return SpecialAttacks.Frames.new(sim, unit, SP1, [30], func() -> void:
		for hit in directional_hits(sim, unit, 6, 6, 4):
			if not hit.dead:
				sim.receive_attack(hit, int(amount), unit)
				if not hit.dead and (hit.ability == null or not hit.ability.immune_to_push):
					sim.push_in_air(hit, unit, 3), 4)


## The minion button: 2 minions. The first extreme dragons allow it while at
## most 2 are alive (two_at_once), the others while fewer than 4 are alive.
static func _minions(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, picture: String, minion_id: int, two_at_once: bool) -> void:
	var can_use := func(_s: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive + 2 <= 4
	add(ability, 3, "God Minions", picture, func(_s: BattleSim, _f: BattleFighter) -> void: unit.ability.spawn_minions(sim, unit, minion_id, 2),
			can_use if two_at_once else below_minions(4), "4 " + MINIONS_MAX)


## A shot of graphic at the target of the unit with damage points; then
## on_hit acts on the target when it is a unit that is still alive.
static func _shoot_then(sim: BattleSim, unit: BattleFighter, graphic: String, damage: int, on_hit: UnitDamage) -> void:
	var target := unit.target
	if unit.dead or target == null or target.dead:
		return
	sim.shoot(unit, target, graphic, damage, func(_shot: BattleProjectile) -> void:
		if on_hit != null and target.is_unit() and on_hit.can_apply(target):
			on_hit.apply(target))


## The plant beam of the Extreme Forest Dragon: a unit with at most 500 life
## is held by strangling plants and frozen for 4 seconds (200 points); a
## stronger unit flies 3 tiles and is frozen for 4 seconds (400 points).
static func _plant_beam(sim: BattleSim, unit: BattleFighter) -> void:
	var target := unit.target
	if target == null or target.dead:
		return
	sim.shoot(unit, target, "p.plantsBeam", unit.attack, func(_shot: BattleProjectile) -> void:
		if target.dead or not target.is_unit():
			return
		if target.max_life() <= 500:
			sim.particle(unit, target.tile, MagicParticles.STRANGLING_PLANTS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
			Damages.Freeze.new(sim, unit, 200, 4, 4).apply(target)
		else:
			_push_then(sim, unit, 0, 3, Damages.Freeze.new(sim, unit, 400, 4, 4)).apply(target))


## Carnivorous plants of the Extreme Forest Dragon: 18 plants. Each second
## plant grows under one of the 18 nearest enemy units within 8 tiles and eats
## it; the plant takes only units with at most 500 life, except one time in
## eleven. The other plants grow on random tiles in range and eat nothing.
static func _plants(sim: BattleSim, unit: BattleFighter) -> void:
	var enemies := sim.items_near(unit.tile, 8, PLANTS, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead)
	for i in range(1, PLANTS + 1):
		var prey: BattleFighter = null
		if i - 1 < enemies.size():
			prey = enemies[i - 1]
			if prey.dead or (sim.rng.randi_range(0, 10) != 10 and prey.max_life() > 500):
				prey = null
		if i % 2 == 0 and prey != null:
			var eaten := prey
			sim.particle(unit, eaten.tile, MagicParticles.CARNIVOROUS_PLANT, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void:
				if eaten.dead:
					return
				eaten.incapacitated = true
				eaten.swallowed = true
				sim.state_changed.emit(eaten)
				sim.after(PLANT_EAT_FRAMES, func() -> void:
					if not eaten.dead:
						sim.kill(eaten, unit if not unit.dead else null)), true)
		else:
			var reach := unit.attack_range
			var tile := (unit.tile + Vector2i(sim.rng.randi_range(-reach, reach), sim.rng.randi_range(-reach, reach))) \
					.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
			sim.after(roundi(sim.rng.randf() * BattleSim.FRAMES_PER_SECOND), func() -> void:
				sim.particle(unit, tile, MagicParticles.CARNIVOROUS_PLANT, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true))


## 15 bugs fly from the Extreme Forest Dragon, one every 180 ms after 500 ms;
## each lives 15 seconds.
static func _bugs(sim: BattleSim, unit: BattleFighter) -> void:
	for i in BUGS:
		sim.after(15 + roundi(0.18 * BattleSim.FRAMES_PER_SECOND * i), func() -> void:
			if unit.dead:
				return
			var bug := sim.spawn(sim.config_item(BUG_ID), unit.tile, unit.team)
			if bug == null:
				return
			sim.push_in_air(bug, unit, 3)
			sim.after(BUG_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
				if not bug.dead:
					sim.kill(bug, null)))


## A tornado shot of the Extreme Frost Dragon at its target with 3 times its
## attack; where it hits, the 5 nearest enemy units within 5 tiles take half
## the attack, fly 3 tiles and freeze, and the target freezes.
static func _frost_tornado(sim: BattleSim, unit: BattleFighter, freeze: Callable) -> void:
	var target := unit.target
	if unit.dead or target == null or target.dead:
		return
	sim.shoot(unit, target, "p.iceWhirlwind", unit.attack * 3, func(_shot: BattleProjectile) -> void:
		if not target.is_unit():
			return
		var near := sim.items_near(target.tile, 5, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead)
		var push := _push_then(sim, unit, unit.def.attack / 2.0, 3, freeze.call())
		for item in near:
			if push.can_apply(item):
				push.apply(item)
		sim.particle(unit, target.tile, MagicParticles.CRYSTAL_EXPLOSION, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
		var frozen: UnitDamage = freeze.call()
		if frozen.can_apply(target):
			frozen.apply(target))


## Two small whirlwinds (item 2147) with half their attack come next to the
## Extreme Wind Dragon for 11 seconds.
static func _mini_whirlwinds(sim: BattleSim, unit: BattleFighter) -> void:
	for i in 2:
		var whirl := sim.spawn(sim.config_item(MINI_WHIRLWIND_ID), unit.tile + Vector2i(i, i), unit.team)
		if whirl == null:
			continue
		whirl.attack /= 2
		sim.after(MINI_WHIRLWIND_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
			if not whirl.dead and whirl in sim.fighters:
				sim.remove_item(whirl))


## The whirlwind hit of the Extreme Wind Dragon: after each 5 units that take
## half the attack and fly 5 tiles, the next unit is pulled in, flies 30
## tiles and dies when it lands (absorbAndPush).
class WindHit extends UnitDamage:
	var amount: float
	var _count := 0

	func _init(battle: BattleSim, from: BattleFighter, damage: float) -> void:
		super(battle, from)
		amount = damage

	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (target.ability == null or not target.ability.immune_to_push)

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		if _count >= 5:
			_count = 0
			sim.absorb_and_push(target, attacker, 30)
			sim.after(2 * BattleSim.FRAMES_PER_SECOND, func() -> void:
				if not target.dead:
					sim.kill(target, _source()))
			return
		_count += 1
		sim.receive_attack(target, int(amount), _source())
		if not target.dead:
			sim.push_in_air(target, attacker, 5)
