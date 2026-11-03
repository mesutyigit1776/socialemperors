class_name NecroSoldiersAbility
extends NecroAbility
## Necro units whose delegates change the normal attack. The units they kill
## can rise as skeletons (NecroAbility).
##
## - archer (NecroArcherDelegate): near the target (2 tiles or less) a normal
##   attack; in range an arrow at frame 6.
## - paladin (NecroPaladinDelegate): attack 8 of each 8 is a whirlwind (special
##   attack 2): 12 times, at frame 18 of each loop, the 4 nearest enemies in
##   range take the attack and units fly 3 tiles; attack 4 heals it by 150.
## - gryphon_knight (NecroGryphonKnightDelegate): attack 12 of each 12 is a
##   magic explosion (special attack 2, frame 17; it cannot act for 3 seconds):
##   the 10 nearest enemies within 2 tiles, not on its tile, take 1.5 times
##   the attack and units fly 4 tiles; attack 4 of each 4 shoots 4 energy
##   balls (special attack 1, frame 27 of each loop).
## - horseman (NecroHorseManDelegate): next to the target it hits at frame 13;
##   farther away it throws its weapon at frame 8. Its graphic is 1.15 times
##   as big.
## - fork_soldier (NecroForkSoldierDelegate): near the target (2 tiles or
##   less) a normal attack; farther away it throws a fork at frame 5.
## - big_sword (NecroBigSwordDelegate): in range, at random: a normal attack
##   (1 in 2), a blow at frame 9 that pushes the target 3 tiles and does the
##   attack (1 in 4), or a whirlwind at frame 11 (1 in 4).
## - harvester (NecroHarvesterDelegate): attack 8 of each 8 is a green ray at
##   the target, or at the nearest enemy within 8 tiles (special attack 2,
##   frame 11): the beam does the attack, and a unit changes sides for 10
##   seconds; attack 4 (special attack 1, frame 7): twice the attack and the
##   target flies 2 tiles.
## - ghost (NecroGhostDelegate): an electric beam (9 frames) that holds the
##   target; attack 6 of each 6 takes souls (special attack 1, frame 7): the
##   20 nearest enemies within 5 tiles, not on its tile, take half the attack,
##   and the ones that live are stunned.
## - priest (NecroPriestDelegate): attack 8 of each 8 heals (special attack
##   2): at frame 19 and then each second, 3 times in all, the own units within
##   3 tiles get 100 life. Next to the target it hits at frame 8; farther away
##   it fires a beam at frame 22 (special attack 1).
## - scorpion (NecroScorpionDelegate): near the target (2 tiles or less) it
##   hits; attack 3 of each 7 (special attack 1, frame 10): the target takes
##   the attack, is poisoned (half the attack a second for 5 seconds) and a
##   unit flies 2 tiles; attack 6 spins for 8 seconds (special attack 2, frame
##   15 of each loop): one enemy on each tile within 2 tiles takes the attack
##   and a unit flies 4 tiles.
## - dragon_king (DragonKingDelegate): a beam (13 frames, 1 second); attack 3
##   of each 4 throws 7 fireballs (special attack 2, frames 16 to 40).

const UNITS := {
	809: "archer",
	794: "paladin",
	812: "gryphon_knight",
	799: "horseman",
	802: "fork_soldier",
	815: "big_sword",
	801: "harvester",
	821: "ghost",
	810: "priest",
	827: "scorpion",
	830: "dragon_king",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const CONVERT_SECONDS := 10

var _kind := ""
var _count := 0


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["paladin", "gryphon_knight", "fork_soldier", "harvester"]
	match _kind:
		"horseman":
			scale = 1.15
		"ghost":
			shot_graphic = "p.electricityBeam"
			shot_delay = 9
			beam = true
		"dragon_king":
			shot_graphic = "p.necroBeam"
			shot_delay = 13
			beam = true
			beam_frames = BattleSim.FRAMES_PER_SECOND


func on_added(_sim: BattleSim, fighter: BattleFighter) -> void:
	if _kind == "ghost":
		beam_frames = maxi(roundi(fighter.attack_interval * 0.4), 1)


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var distance := sim.distance(fighter, target)
	match _kind:
		"archer":
			if distance <= 2:
				return true
			if distance <= fighter.attack_range:
				play(sim, fighter, UnitSprite.Action.ATTACKING, 10, {6: func() -> void: _shot(sim, fighter, "p.arrow")})
			return false
		"paladin":
			_count += 1
			if _count % 8 == 0:
				var loop := maxi(sim.animation_frames(fighter, SP2, 20), 18)
				var events := {}
				for i in 12:
					events[i * loop + 18] = func() -> void:
						for enemy in sim.items_near(fighter.tile, fighter.attack_range, 4, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
							sim.receive_attack(enemy, fighter.attack, fighter)
							if enemy.is_unit() and not enemy.dead:
								sim.push_in_air(enemy, fighter, 3)
				sim.play_special(fighter, SP2, 11 * loop + 19, events)
				return false
			if _count % 8 == 4:
				play(sim, fighter, SP1, 30)
				sim.heal(fighter, 150, fighter)
				return false
			return true
		"gryphon_knight":
			_count += 1
			if _count % 12 == 0:
				sim.play_special(fighter, SP2, 3 * BattleSim.FRAMES_PER_SECOND, {17: func() -> void:
					show_explosion(sim, fighter)
					for enemy in sim.items_near(fighter.tile, 2, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return not item.dead):
						sim.receive_attack(enemy, int(fighter.attack * 1.5), fighter)
						if enemy.is_unit() and not enemy.dead:
							sim.push_in_air(enemy, fighter, 4)}, Callable(), true)
				return false
			if _count % 4 == 0:
				var loop := maxi(sim.animation_frames(fighter, SP1, 30), 28)
				var events := {}
				for i in 4:
					events[i * loop + 27] = func() -> void: _shot(sim, fighter, "p.energyBall")
				sim.play_special(fighter, SP1, 3 * loop + 28, events, Callable(), true)
				return false
			return true
		"horseman":
			if distance <= 1:
				play(sim, fighter, UnitSprite.Action.ATTACKING, 20, {13: func() -> void: _hit(sim, fighter, 1.0)})
			else:
				play(sim, fighter, SP1, 20, {8: func() -> void: _shot(sim, fighter, "p.necroHorseman")})
			return false
		"fork_soldier":
			if distance <= 2:
				return true
			play(sim, fighter, SP1, 20, {5: func() -> void: _shot(sim, fighter, "p.necroFork")})
			return false
		"big_sword":
			if distance > fighter.attack_range:
				return false
			var roll := sim.rng.randf()
			if roll < 0.5:
				return true
			if roll <= 0.75:
				play(sim, fighter, SP1, 20, {9: func() -> void:
					var hit := fighter.target
					if hit == null or hit.dead:
						return
					if hit.is_unit():
						sim.push_in_air(hit, fighter, 3)
					sim.receive_attack(hit, fighter.attack, fighter)})
			else:
				play(sim, fighter, SP2, 20, {11: func() -> void: sim.whirlwind(fighter, 0.45, 3, fighter.attack_range)})
			return false
		"harvester":
			_count += 1
			if _count % 8 == 0:
				play(sim, fighter, SP2, 40, {11: func() -> void: _green_ray(sim, fighter)}, Callable(), true)
				return false
			if _count % 4 != 0:
				return true
			play(sim, fighter, SP1, 20, {7: func() -> void:
				var hit := fighter.target
				if hit == null or hit.dead:
					return
				sim.receive_attack(hit, fighter.attack * 2, fighter)
				if hit.is_unit() and not hit.dead:
					sim.push_in_air(hit, fighter, 2)})
			return false
		"ghost":
			_count += 1
			if _count % 6 == 0:
				play(sim, fighter, SP1, 20, {7: func() -> void:
					for enemy in sim.items_near(fighter.tile, 5, 20, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
						sim.receive_attack(enemy, fighter.attack / 2, fighter)
						if enemy.dead:
							SpecialUnit.show_particle(sim, fighter, enemy.tile, MagicParticles.SOUL)
						else:
							sim.stun(enemy)})
				return false
			sim.after(shot_delay, func() -> void:
				if not fighter.dead and not target.dead and target.is_unit():
					sim.electrocute(target, fighter, 0, 1, roundi(beam_frames * 1.2)))
			return true
		"priest":
			_count += 1
			if _count % 8 == 0:
				var events := {}
				for i in 3:
					events[19 + i * BattleSim.FRAMES_PER_SECOND] = func() -> void:
						for ally in sim.items_near(fighter.tile, 3, 20, fighter.team, true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
							sim.heal(ally, 100, fighter)
							SpecialUnit.show_particle(sim, fighter, ally.tile, MagicParticles.STARS)
				sim.play_special(fighter, SP2, 19 + 2 * BattleSim.FRAMES_PER_SECOND + 1, events)
			elif distance <= 1:
				play(sim, fighter, UnitSprite.Action.ATTACKING, 15, {8: func() -> void: _hit(sim, fighter, 1.0)})
			else:
				play(sim, fighter, SP1, 40, {22: func() -> void:
					var shot := fighter.target
					if shot != null and not shot.dead:
						sim.shoot_beam(fighter, shot, shot.tile, "p.necroBeam", BattleSim.FRAMES_PER_SECOND, fighter.attack)})
			return false
		"scorpion":
			if distance > 2:
				return false
			if _count == 3:
				play(sim, fighter, SP1, 20, {10: func() -> void:
					var hit := fighter.target
					if hit == null or hit.dead:
						return
					sim.receive_attack(hit, fighter.attack, fighter)
					if hit.is_unit() and not hit.dead:
						sim.poison(hit, fighter.attack / 2, 5, 0, hit)
						sim.push_in_air(hit, fighter, 2)}, Callable(), true)
			elif _count == 6:
				var loop := maxi(sim.animation_frames(fighter, SP2, 20), 16)
				var events := {}
				var start := 0
				while start + 15 <= 8 * BattleSim.FRAMES_PER_SECOND:
					events[start + 15] = func() -> void: _ring_blow(sim, fighter)
					start += loop
				sim.play_special(fighter, SP2, 9 * BattleSim.FRAMES_PER_SECOND, events)
			elif target.is_unit():
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 6 else 0
			return false
		"dragon_king":
			_count = _count + 1 if _count < 3 else 0
			if _count != 3:
				return true
			var events := {}
			for frame in [16, 20, 24, 28, 32, 36, 40]:
				events[frame] = func() -> void: _shot(sim, fighter, "p.necroFireball")
			play(sim, fighter, SP2, 45, events, Callable(), true)
			return false
	return true


static func _shot(sim: BattleSim, fighter: BattleFighter, graphic: String) -> void:
	if fighter.target != null and not fighter.target.dead:
		sim.shoot(fighter, fighter.target, graphic, fighter.attack)


static func _hit(sim: BattleSim, fighter: BattleFighter, factor: float) -> void:
	if fighter.target != null and not fighter.target.dead:
		sim.receive_attack(fighter.target, int(fighter.attack * factor), fighter)


static func show_explosion(sim: BattleSim, fighter: BattleFighter) -> void:
	SpecialUnit.show_particle(sim, fighter, fighter.tile + Vector2i(2, 2), MagicParticles.MEGA_EXPLOSION)


## One enemy on each tile within 2 tiles takes the attack; a unit flies 4 tiles.
static func _ring_blow(sim: BattleSim, fighter: BattleFighter) -> void:
	for y in range(-2, 3):
		for x in range(-2, 3):
			var found := sim.items_near(fighter.tile + Vector2i(x, y), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return not item.dead and item.is_valid_target())
			if found.is_empty():
				continue
			sim.receive_attack(found[0], fighter.attack, fighter)
			if found[0].is_unit() and not found[0].dead:
				sim.push_in_air(found[0], fighter, 4)


## Harvester: the beam does the attack; a unit changes sides for 10 seconds.
static func _green_ray(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead:
		target = sim.nearest_enemy(fighter, fighter.tile, 8)
	if target == null:
		sim.stop_special(fighter)
		return
	sim.shoot_beam(fighter, target, target.tile, "p.necroBeam", BattleSim.FRAMES_PER_SECOND, fighter.attack)
	if not target.is_unit() or (target.ability != null and target.ability.immune_to_conversion) or target.converted:
		return
	var own_team := target.team
	sim.convert(target, fighter.team)
	sim.after(CONVERT_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
		if not target.dead and target in sim.fighters:
			sim.convert(target, own_team))
