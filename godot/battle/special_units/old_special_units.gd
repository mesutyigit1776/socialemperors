class_name OldSpecialUnits
extends SpecialUnit
## The first special units of the client: old gods, creatures of myth and
## heroes. Their buttons have a cooldown of 25 seconds and no limit.

const UNITS := {
	711: "arcangel",
	788: "ares",
	787: "chimera",
	661: "conan",
	635: "ent",
	773: "poseidon",
}
const COOLDOWN_OLD := 25
const ARCHANGEL_AURA_FRAMES := 220
const CHIMERA_BEAMS := 3
const SACRED_RAIN := 5
const HAIL := 3
const ENT_SPIRIT := 636
const ENT_SPIRITS := 16
const ENT_GIANT_SECONDS := 20
const ENT_GIANT_SCALE := 1.8
const POSEIDON_SHOTS := 5
const POSEIDON_SHOT_RANGE := 11
const OCTOPUS := 624
const OCTOPUSES := 4
const OCTOPUS_SECONDS := 8
const CHIMERA_BEAM_FRAMES := 30
const CHIMERA_BEAM_PAUSE := 8  ## 250 ms.
## The steps of the thrust of the Archangel (doThrust of the client).
const THRUST_STEPS := {1: Vector2i(-1, 0), 2: Vector2i(0, -1), 3: Vector2i(0, -1), 4: Vector2i(1, 0), 5: Vector2i(1, 0), 6: Vector2i(-1, 0), 7: Vector2i(0, 1), 8: Vector2i(0, 1)}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	match kind:
		"arcangel":
			# The beam of the chest hits the tiles in front of the unit and burns
			# the units; the unit stands 30 frames after it.
			add(ability, 0, "Laser Pectoral", "botonLaserPectoral", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 13 + 30, {13: func() -> void: _arcangel_line(sim, unit, true)}, Callable(), true),
				Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Ataque Súbito", "botonAtaqueSubito", SpecialAttacks.Frames.new(sim, unit, SP2, [6], func() -> void:
				_arcangel_line(sim, unit, false)), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Subidón de Moral", "botonSubidonDeMoral", SpecialAttacks.Frames.new(sim, unit, SP3, [1], func() -> void:
				show_particle(sim, unit, unit.tile, MagicParticles.AURA_ARCHANGEL)
				HeroAbility.wallace_aura(sim, unit, ARCHANGEL_AURA_FRAMES)), Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Lluvia Laser", "botonLluviaLaser", SpecialAttacks.Frames.new(sim, unit, SP4, [1], func() -> void:
				BattleAbility.arrow_storm(sim, unit, MagicParticles.ARCHANGEL_BEAM, 40, 2, 1.6, 10, 120)), Callable(), "", COOLDOWN_OLD)
		"ares":
			ability.ranged_melee = true  # AresDelegate
			add(ability, 0, "ares_sword", "ares_sword", SpecialAttacks.Frames.new(sim, unit, SP2, [12], func() -> void: front_sword(sim, unit)),
					Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "ares_pincer", "ares_pincer", SpecialAttacks.Frames.new(sim, unit, SP4, [10], func() -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= 3:
					sim.receive_attack(target, 350, unit)), Callable(), "", COOLDOWN_OLD)
			# Once a second, 9 times.
			var spin := {}
			for second in range(1, 10):
				spin[second * BattleSim.FRAMES_PER_SECOND] = func() -> void: spin_blow(sim, unit)
			add(ability, 2, "ares_whirlwind", "ares_whirlwind", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 10 * BattleSim.FRAMES_PER_SECOND, spin, Callable(), true), Callable(), "", COOLDOWN_OLD)
			# A magma bubble: the units within 5 tiles that can act burn, 8
			# points a second for 10 seconds. The bubble goes after 4 seconds.
			add(ability, 3, "ares_bubble", "ares_bubble", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP3, 10 + 4 * BattleSim.FRAMES_PER_SECOND, {10: func() -> void:
					show_particle(sim, unit, unit.tile + Vector2i(2, 2), MagicParticles.MAGMA)
					for enemy in sim.items_near(unit.tile, 5, 100, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead and not item.incapacitated and item.def.subcat_functional != BattleSim.SUBCAT_BOSS):
						sim.incinerate(enemy, unit, 8, 10, BattleSim.FRAMES_PER_SECOND)}, Callable(), true), Callable(), "", COOLDOWN_OLD)
		"chimera":
			ability.ranged_melee = true  # ChimeraDelegate
			add(ability, 0, "chimera_lion", "botonChimeraLion", SpecialAttacks.Frames.new(sim, unit, SP2, [12], func() -> void: front_sword(sim, unit)),
					Callable(), "", COOLDOWN_OLD)
			# Electric beams at the 3 nearest enemy units within 5 tiles, one
			# after the other: each beam freezes its unit for 2 seconds and
			# does twice the attack when it ends.
			add(ability, 1, "chimera_dragon", "botonChimeraDragon", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 16 + CHIMERA_BEAMS * (CHIMERA_BEAM_FRAMES + CHIMERA_BEAM_PAUSE), {16: func() -> void:
					var targets := sim.items_near(unit.tile, 5, CHIMERA_BEAMS, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead)
					_chimera_beam(sim, unit, targets)}, Callable(), true), Callable(), "", COOLDOWN_OLD)
			# The target within 3 tiles takes the attack and is poisoned: the
			# attack each second, 2 times.
			add(ability, 2, "chimera_snake", "botonChimeraSnake", SpecialAttacks.Frames.new(sim, unit, SP3, [15], func() -> void:
				var target := unit.target
				if target == null or target.dead or sim.distance(unit, target) > 3:
					return
				sim.receive_attack(target, unit.attack, unit)
				if target.is_unit() and not target.dead:
					sim.poison(target, unit.attack, 2, 0, unit)), Callable(), "", COOLDOWN_OLD)
		"conan":
			add(ability, 0, "Power Sword", "botonFeelThePowerOfThySword", SpecialAttacks.Frames.new(sim, unit, SP1, [9], func() -> void:
				front_sword(sim, unit)), Callable(), "", COOLDOWN_OLD)
			# At the end of the animation Conan gets a quarter of his life back.
			add(ability, 1, "Heroic Endurance", "botonEndurance", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP2, sim.animation_frames(unit, SP2, 30), {}, func() -> void:
					if unit.dead:
						return
					sim.heal(unit, unit.max_life() / 4, unit)
					show_particle(sim, unit, unit.tile, MagicParticles.STARS)), Callable(), "", COOLDOWN_OLD)
			# The items within 2 tiles take 1.5 times the attack; units fly 2 tiles.
			add(ability, 2, "Sword Jump", "botonSwordJump", SpecialAttacks.Frames.new(sim, unit, SP3, [32], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 100, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool: return not item.dead):
					sim.receive_attack(enemy, int(unit.attack * 1.5), unit)
					if enemy.is_unit() and not enemy.dead:
						sim.push_in_air(enemy, unit, 2)), Callable(), "", COOLDOWN_OLD)
			# Once a second, 4 times.
			var spin := {}
			for second in range(1, 5):
				spin[second * BattleSim.FRAMES_PER_SECOND] = func() -> void: spin_blow(sim, unit)
			add(ability, 3, "Spinning Blow", "botonSpinningBlow", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP4, 5 * BattleSim.FRAMES_PER_SECOND, spin), Callable(), "", COOLDOWN_OLD)
		"ent":
			add(ability, 0, "Earth calls", "botonCuracion", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.cast_unit_spell(SACRED_RAIN, _ent_spell_tile(sim, unit)), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Stone Rain", "botonStoneRain", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.cast_unit_spell(HAIL, _ent_spell_tile(sim, unit)), Callable(), "", COOLDOWN_OLD)
			add(ability, 2, "Protecting roots", "botonRaices", func(_s: BattleSim, _f: BattleFighter) -> void: _roots_wave(sim, unit),
					Callable(), "", COOLDOWN_OLD)
			# The Ent grows for 20 seconds and 16 spirits of the woods (item
			# 636) come near it. Growing does not change the
			# battle.
			add(ability, 3, "Giant Ent", "botonGiantEnt", func(_s: BattleSim, _f: BattleFighter) -> void:
				var spirits: Array[BattleFighter] = []
				for i in ENT_SPIRITS:
					var spirit := sim.spawn(sim.config_item(ENT_SPIRIT), unit.tile, unit.team)
					if spirit == null:
						continue
					if spirit.ability != null:
						spirit.ability.scale = 0.6
					var target := unit.target if unit.target != null and not unit.target.dead else sim.nearest_enemy(spirit, unit.tile, 10)
					if target != null:
						sim.set_target(spirit, target)
					spirits.append(spirit)
				unit.ability.scale = ENT_GIANT_SCALE
				sim.after(ENT_GIANT_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
					unit.ability.scale = 1.0
					for spirit in spirits:
						if spirit in sim.fighters:
							sim.remove_item(spirit)), Callable(), "", COOLDOWN_OLD)
		"poseidon":
			add(ability, 0, "Shoot Beam", "boton_tridente", func(_s: BattleSim, _f: BattleFighter) -> void: _poseidon_shot(sim, unit, POSEIDON_SHOTS),
					Callable(), "", COOLDOWN_OLD)
			# One enemy on each tile within 2 tiles takes 1.5 times the attack;
			# a unit flies 4 tiles. Poseidon waits 250 ms after the animation.
			add(ability, 1, "Smash Attack", "boton_tentaculos", func(_s: BattleSim, _f: BattleFighter) -> void:
				var length := maxi(sim.animation_frames(unit, SP3, 31), 31) + 8
				sim.play_special(unit, SP3, length, {31: func() -> void:
					for y in range(-2, 3):
						for x in range(-2, 3):
							var target := tile_target(sim, unit, unit.tile + Vector2i(x, y))
							if target == null:
								continue
							sim.receive_attack(target, int(unit.attack * 1.5), unit)
							if target.is_unit() and not target.dead:
								sim.push_in_air(target, unit, 4)}, Callable(), true), Callable(), "", COOLDOWN_OLD)
			# 4 octopuses (item 624) come near Poseidon for 8 seconds and attack
			# its target. Poseidon waits 1 second after the animation.
			add(ability, 2, "Spawn Octospuss", "boton_pulpos", func(_s: BattleSim, _f: BattleFighter) -> void:
				var length := maxi(sim.animation_frames(unit, SP2, 18), 18) + BattleSim.FRAMES_PER_SECOND
				sim.play_special(unit, SP2, length, {18: func() -> void:
					var octopuses: Array[BattleFighter] = []
					for i in OCTOPUSES:
						var octopus := sim.spawn(sim.config_item(OCTOPUS), unit.tile, unit.team)
						if octopus == null:
							continue
						if unit.target != null and not unit.target.dead:
							sim.set_target(octopus, unit.target)
						octopuses.append(octopus)
					sim.after(OCTOPUS_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
						for octopus in octopuses:
							if octopus in sim.fighters:
								sim.remove_item(octopus))}, Callable(), true), Callable(), "", COOLDOWN_OLD)


## One enemy item on tile, or null (getNearestTarget with a range of 0).
static func tile_target(sim: BattleSim, unit: BattleFighter, tile: Vector2i) -> BattleFighter:
	var found := sim.items_near(tile, 0, 1, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return not item.dead and item.is_valid_target())
	return found[0] if not found.is_empty() else null


## The Archangel hits the tile of the unit, the two tiles beside the next
## tile and 7 tiles in a line: one enemy on each tile takes twice the attack,
## and a unit flies 1 to 5 tiles. With burn, the units also burn (half the
## attack a second for 5 seconds) and the line starts on the tile of the
## unit, so that tile is hit two times. Without burn, the client turns the
## directions: down hits down-right, left hits down-left, and so on.
static func _arcangel_line(sim: BattleSim, unit: BattleFighter, burn: bool) -> void:
	var direction := BattleAbility.direction(unit)
	var step: Vector2i = BattleAbility.TILE_STEPS[direction] if burn else THRUST_STEPS[direction]
	var tiles: Array[Vector2i] = [unit.tile]
	if step.x != 0:
		tiles.append(unit.tile + Vector2i(step.x, 1))
		tiles.append(unit.tile + Vector2i(step.x, -1))
	if step.y != 0:
		tiles.append(unit.tile + Vector2i(1, step.y))
		tiles.append(unit.tile + Vector2i(-1, step.y))
	for i in range(0 if burn else 1, 8):
		tiles.append(unit.tile + step * i)
	for tile in tiles:
		var target := tile_target(sim, unit, tile)
		if target == null:
			continue
		sim.receive_attack(target, unit.attack * 2, unit)
		if target.is_unit() and not target.dead:
			sim.push_in_air(target, unit, sim.rng.randi_range(1, 5))
			if burn:
				sim.incinerate(target, unit, unit.attack / 2, 5, BattleSim.FRAMES_PER_SECOND)


## The Ent casts its spells on the corner tile half the area of its Sacred
## Rain right and down from it; the Hail uses the area of the Sacred Rain too.
static func _ent_spell_tile(sim: BattleSim, unit: BattleFighter) -> Vector2i:
	var def := sim.config.get_spell(SACRED_RAIN) if sim.config != null else null
	var area: int = def.areas[sim.config.spell_level(sim.spell_uses.get(SACRED_RAIN, 0)) - 1] if def != null else 0
	var half := roundi(area / 2.0)
	return unit.tile + Vector2i(half, half)


## Roots grow every 500 ms on each tile of a square around the Ent that gets
## one tile larger each time, 6 times (the first square is empty). The enemy
## unit on a tile takes the attack of the Ent and flies 1 tile.
static func _roots_wave(sim: BattleSim, unit: BattleFighter) -> void:
	for dist in 6:
		sim.after(dist * BattleSim.FRAMES_PER_SECOND / 2 + 15, func() -> void:
			for y in range(-dist, dist + 1):
				for x in range(-dist, dist + 1):
					if x == 0 and y == 0:
						continue
					sim.particle(unit, unit.tile + Vector2i(x, y), MagicParticles.ROOT, 0, 0, func(_a: BattleFighter, target: BattleFighter, _v: int) -> void:
						if target == null or not target.is_unit() or target.dead:
							return
						sim.push_in_air(target, unit, 1)
						sim.receive_attack(target, unit.def.attack, unit if unit in sim.fighters else null)))


## Poseidon throws napalm at the nearest enemy within 11 tiles at frame 22,
## then plays the animation again until it has thrown shots times.
static func _poseidon_shot(sim: BattleSim, unit: BattleFighter, shots: int) -> void:
	if shots <= 0 or unit.dead:
		return
	sim.play_special(unit, SP1, maxi(sim.animation_frames(unit, SP1, 30), 22), {22: func() -> void:
		var target := sim.nearest_enemy(unit, unit.tile, POSEIDON_SHOT_RANGE)
		if target != null:
			sim.shoot(unit, target, "p.napalm", unit.attack)}, func() -> void: _poseidon_shot(sim, unit, shots - 1), true)


## The 3 x 3 tiles in front of the unit: one enemy on each takes twice the
## attack, and a unit is stunned.
static func front_sword(sim: BattleSim, unit: BattleFighter) -> void:
	var front: Vector2i = unit.tile + BattleAbility.TILE_STEPS[BattleAbility.direction(unit)]
	for y in range(-1, 2):
		for x in range(-1, 2):
			var target := tile_target(sim, unit, front + Vector2i(x, y))
			if target == null:
				continue
			sim.receive_attack(target, unit.attack * 2, unit)
			if target.is_unit() and not target.dead:
				sim.stun(target)


## On each tile within 2 tiles that is not on the row or the column of the
## unit, one enemy takes half the attack, and a unit flies 2 tiles.
static func spin_blow(sim: BattleSim, unit: BattleFighter) -> void:
	for y in range(-2, 3):
		for x in range(-2, 3):
			if x == 0 or y == 0:
				continue
			var target := tile_target(sim, unit, unit.tile + Vector2i(x, y))
			if target == null:
				continue
			sim.receive_attack(target, unit.attack / 2, unit)
			if target.is_unit() and not target.dead:
				sim.push_in_air(target, unit, 2)


static func _chimera_beam(sim: BattleSim, unit: BattleFighter, targets: Array[BattleFighter]) -> void:
	if targets.is_empty() or unit.dead:
		return
	var target: BattleFighter = targets.pop_front()
	if target.dead:
		_chimera_beam(sim, unit, targets)
		return
	sim.freeze_with_damage(target, unit, 0, 1, 2 * BattleSim.FRAMES_PER_SECOND)
	sim.shoot_beam(unit, target, target.tile, "p.electricityBeam", CHIMERA_BEAM_FRAMES, unit.attack * 2, func(_shot: BattleProjectile) -> void:
		sim.after(CHIMERA_BEAM_PAUSE, func() -> void: _chimera_beam(sim, unit, targets)))
