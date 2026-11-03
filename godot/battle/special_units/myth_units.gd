class_name MythUnits
extends SpecialUnit
## The first special units of the client: the old gods and the creatures of
## myth. Their buttons have a cooldown of 25 seconds and no limit.

const UNITS := {
	711: "arcangel",
	788: "ares",
}
const COOLDOWN_OLD := 25
const ARCHANGEL_AURA_FRAMES := 220
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
			# The 3 x 3 tiles in front of Ares: one enemy on each takes twice
			# the attack, and a unit is stunned.
			add(ability, 0, "ares_sword", "ares_sword", SpecialAttacks.Frames.new(sim, unit, SP2, [12], func() -> void:
				var front: Vector2i = unit.tile + BattleAbility.TILE_STEPS[BattleAbility.direction(unit)]
				for y in range(-1, 2):
					for x in range(-1, 2):
						var target := tile_target(sim, unit, front + Vector2i(x, y))
						if target == null:
							continue
						sim.receive_attack(target, unit.attack * 2, unit)
						if target.is_unit() and not target.dead:
							sim.stun(target)), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "ares_pincer", "ares_pincer", SpecialAttacks.Frames.new(sim, unit, SP4, [10], func() -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= 3:
					sim.receive_attack(target, 350, unit)), Callable(), "", COOLDOWN_OLD)
			# Once a second, 9 times: on each tile within 2 tiles that is not
			# on the row or the column of Ares, one enemy takes half the
			# attack, and a unit flies 2 tiles.
			var spin := {}
			for second in range(1, 10):
				spin[second * BattleSim.FRAMES_PER_SECOND] = func() -> void: _ares_whirlwind(sim, unit)
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


static func _ares_whirlwind(sim: BattleSim, unit: BattleFighter) -> void:
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
