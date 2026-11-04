class_name WarriorUnitsAbility
extends BattleAbility
## Warriors whose delegates of the client change the normal attack. Most count
## their attacks and make a special attack at some counts; the other attacks
## hit at once.
##
## - double_sword (DoubleSwordDelegate): 2 tiles or more from the target it
##   throws a sword at frame 5 of special attack 1; nearer it hits.
## - punisher (PunisherKnightDelegate): near the target (2 tiles or less) it
##   hits; attack 5 of each 11 (special attack 1, frame 8): one enemy on each
##   of the 3 x 3 tiles in front takes 1.5 times the attack and a unit is
##   stunned; attack 10 (special attack 2, frame 40): one enemy on each tile
##   within 2 tiles takes the attack and a unit flies 4 tiles.
## - cobra_rider (CobraRiderDelegate): attack 5 of each 9 eats a target unit
##   whose item has at most 500 life and that can act (special attack 1, frame
##   10; it dies at the end); attack 9 is a spin for 3 seconds (special attack
##   2, frames 4, 8 and 12 of each loop): the 10 nearest enemies within 2
##   tiles take half the attack, and units fly 4 tiles and are poisoned (5
##   points a second for 5 seconds).
## - turkish_axe (TurkishAxeDelegate): attack 4 of each 8 (special attack 1,
##   frame 19): the target takes 1.5 times the attack and a unit flies 4
##   tiles; attack 8 (special attack 2, frames 25 to 45): the 10 nearest enemies
##   within 2 tiles, not on its tile, take half the attack, and units fly 4
##   tiles and burn (5 points a second for 5 seconds).
## - turkish_sword (TurkishSwordDelegate): the target takes the attack at
##   frame 5. Attack 5 of each 11 is a rain of swords (special attack 1, frame
##   59); 600 ms later the 5 nearest enemies within 7 tiles take the attack.
##   Attack 9 heals it by 500 (special attack 2, frame 23).
## - burning_tiger (BurningTigerDelegate): a hit that pushes a unit 1 tile.
##   Attack 5 of each 10 throws fireballs for 5 seconds (special attack 1,
##   frame 23 of each loop) that burn the unit they hit; attack 10 (special
##   attack 2, frames 40 and 45): the 10 nearest enemy units within 3 tiles,
##   not on its tile, that can act take half the attack, burn and fly 4 tiles.
## - sword_lion (SwordLionDelegate): a hit; attack 6 of each 12 (special
##   attack 1, frames 27, 47, 68 and 88): the 3 nearest enemy units within 3
##   tiles take twice the attack and fly 5 tiles; attack 12 (special attack 2,
##   frame 20): a storm of thunderbolts on a target in range.
## - ice_golem (IceGolemDelegate): a hit; attack 5 of each 11 (special attack
##   1, frame 12): each unit of a directional attack of 3 tiles (radius 3)
##   freezes (20 points a second for 5 seconds); attack 10 (special attack 2,
##   frame 45): the 3 nearest enemy units within 6 tiles with at most 500 life
##   change sides for 15 seconds.
## - black_lizard (BlackLizardDelegate): an acid spit 15 frames after the
##   attack. Far from the target each fifth attack shoots its tongue at a unit
##   in range with at most 500 life (special attack 2): the unit dies at the
##   end. Near the target each fifth attack (special attack 1, frame 35): the 5
##   nearest enemy units within 5 tiles take the attack and fly 5 tiles.
## - demolisher (DemolisherDelegate): a hit; attack 8 of each 16 (special
##   attack 1, frame 49): each unit of a directional attack of 8 tiles takes
##   1.2 times the attack, flies 5 tiles and is stunned; attack 16 (special
##   attack 2): for 2.8 seconds from frame 7, every 500 ms, the 6 nearest enemy
##   units within 8 tiles take 1.4 times the attack and fly 5 tiles.
## - dragon_rider (DragonRiderDelegate): each fifth attack (special attack 1)
##   the enemies within 2 tiles, not on its tile, take half the attack and
##   units fly 3 tiles; without a target it takes the first of them.
## - ramses (RamsesDelegate): a hit; attack 4 of each 8 (special attack 1,
##   frame 9): the target takes twice the attack; attack 8 (special attack 2,
##   frame 11): the 10 nearest enemies within 3 tiles, not on its tile, take
##   the attack and units fly 2 tiles.
## - anubis (AnubisDelegate): a golden ball 12 frames after the attack. With
##   the target within 5 tiles, attack 4 of each 8 is a jump (special attack 1,
##   frame 19): the 10 nearest enemy units within 5 tiles take half the attack
##   and fly 3 tiles. Attack 8, while fewer than 4 of its minions live, is an
##   energy bubble (special attack 2, frame 22, for 3 seconds): 16 frames
##   later, enemy units within 5 tiles with at most 350 life become Mini
##   Anubis (item 878) of its side, up to 4 minions. A new minion cannot act
##   for 1.5 seconds and is poisoned (the attack of Anubis every 3 seconds).
##   The port does not draw the red bubble.

const UNITS := {
	825: "double_sword",
	829: "punisher",
	871: "cobra_rider",
	881: "turkish_axe",
	880: "turkish_sword",
	2035: "burning_tiger",
	2059: "sword_lion",
	2145: "ice_golem",
	2138: "black_lizard",
	2108: "demolisher",
	822: "dragon_rider", 823: "dragon_rider", 824: "dragon_rider",
	860: "ramses",
	879: "anubis",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SMALL_LIFE := 500
const PUSH_LAND_FRAMES := BattleSim.FRAMES_PER_SECOND
const ICE_SECONDS := 15
const MINI_ANUBIS := 878
const ANUBIS_MINIONS := 4
const ANUBIS_RANGE := 5
const ANUBIS_CONVERT_LIFE := 350
const ANUBIS_POISON_TICKS := 1000
const ANUBIS_APPEAR_FRAMES := 45  ## 1.5 seconds.

var _kind := ""
var _count := 0
var _second_count := 0
var _rain: SpecialAttacks.Rain  # Kept here: the rain lives longer than the call.
var _anubis_minions: Array[BattleFighter] = []


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	match _kind:
		"cobra_rider", "turkish_axe", "burning_tiger", "sword_lion", "demolisher":
			_count = 1
		"black_lizard":
			_count = 1
			_second_count = 1
	ranged_melee = _kind in ["punisher", "cobra_rider", "turkish_axe", "turkish_sword", "burning_tiger", "sword_lion", "ice_golem", "demolisher", "ramses"]
	if _kind == "anubis":
		shot_graphic = "p.goldenDragon"
		shot_delay = 12


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var distance := sim.distance(fighter, target)
	match _kind:
		"dragon_rider":
			if _count < 4:
				_count += 1
				return true
			_count = 0
			sim.play_special(fighter, SP1, sim.animation_frames(fighter, SP1, 30))
			for enemy in sim.items_near(fighter.tile, 2, 20, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
					return not item.dead and item.is_valid_target()):
				if enemy.is_unit():
					sim.push_in_air(enemy, fighter, 3)
				sim.receive_attack(enemy, fighter.attack / 2, fighter)
				if fighter.target == null and not enemy.dead:
					sim.set_target(fighter, enemy)
			return false
		"ramses":
			_count += 1
			if _count % 8 == 0:
				play(sim, fighter, SP2, 20, {11: func() -> void:
					for enemy in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
							return not item.dead and item.is_valid_target()):
						sim.receive_attack(enemy, fighter.attack, fighter)
						if enemy.is_unit() and not enemy.dead:
							sim.push_in_air(enemy, fighter, 2)})
				return false
			if _count % 4 == 0:
				play(sim, fighter, SP1, 20, {9: func() -> void:
					if fighter.target != null and not fighter.target.dead:
						sim.receive_attack(fighter.target, fighter.attack * 2, fighter)})
				return false
			return true
		"anubis":
			_count += 1
			_anubis_minions = _anubis_minions.filter(func(unit: BattleFighter) -> bool: return not unit.dead)
			if _count % 8 == 0 and _anubis_minions.size() < ANUBIS_MINIONS and distance <= ANUBIS_RANGE:
				sim.play_special(fighter, SP2, 22 + 3 * BattleSim.FRAMES_PER_SECOND, {22 + 16: func() -> void: _anubis_convert(sim, fighter)}, Callable(), true)
				return false
			if _count % 4 == 0 and distance <= ANUBIS_RANGE:
				play(sim, fighter, SP1, 30, {19: func() -> void:
					_push_near(sim, fighter, fighter.tile, ANUBIS_RANGE, 10, fighter.attack / 2, 3)})
				return false
			return true
		"double_sword":
			if distance < 2:
				return true
			play(sim, fighter, SP1, 20, {5: func() -> void:
				if fighter.target != null and not fighter.target.dead:
					sim.shoot(fighter, fighter.target, "p.necroDoubleSword", fighter.attack)})
			return false
		"punisher":
			if distance > 2:
				return false
			if _count == 5:
				play(sim, fighter, SP1, 30, {8: func() -> void: _front_blow(sim, fighter)}, Callable(), true)
			elif _count == 10:
				play(sim, fighter, SP2, 50, {40: func() -> void: _ring_blow(sim, fighter, 1.0, 4)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 10 else 0
			return false
		"cobra_rider":
			if _count == 5 and _edible(target):
				var prey := target
				play(sim, fighter, SP1, 30, {10: func() -> void:
					if _edible(prey):
						_hold(sim, prey)}, func() -> void:
					if prey.swallowed and not prey.dead:
						sim.kill(prey, fighter), true)
			elif _count == 9:
				var loop := maxi(sim.animation_frames(fighter, SP2, 16), 12)
				var events := {}
				var start := 0
				while start < 3 * BattleSim.FRAMES_PER_SECOND:
					for frame in [4, 8, 12]:
						events[start + frame] = func() -> void: _cobra_spin(sim, fighter)
					start += loop
				sim.play_special(fighter, SP2, 3 * BattleSim.FRAMES_PER_SECOND, events)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 9 else 1
			return false
		"turkish_axe":
			if _count == 4:
				play(sim, fighter, SP1, 30, {19: func() -> void:
					var hit := fighter.target
					if hit == null or hit.dead:
						return
					sim.receive_attack(hit, int(fighter.attack * 1.5), fighter)
					if hit.is_unit() and not hit.dead:
						sim.push_in_air(hit, fighter, 4)}, Callable(), true)
			elif _count == 8:
				var events := {}
				for frame in [25, 30, 35, 40, 45]:
					events[frame] = func() -> void:
						for enemy in sim.items_near(fighter.tile, 2, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return not item.dead):
							sim.receive_attack(enemy, fighter.attack / 2, fighter)
							if enemy.is_unit() and not enemy.dead:
								sim.push_in_air(enemy, fighter, 4)
								sim.incinerate(enemy, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND)
				play(sim, fighter, SP2, 50, events, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 8 else 1
			return false
		"turkish_sword":
			if _count == 9:
				play(sim, fighter, SP2, 30, {23: func() -> void: sim.heal(fighter, 500, fighter)}, Callable(), true)
			elif _count == 5:
				play(sim, fighter, SP1, 60, {59: func() -> void:
					arrow_storm(sim, fighter, MagicParticles.SWORDS_RAIN, 20, 5, 0, 0, 30)
					sim.after(18, func() -> void:
						if fighter.dead:
							return
						for enemy in sim.items_near(fighter.tile, 7, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
							sim.receive_attack(enemy, fighter.attack, fighter))})
			else:
				sim.after(5, func() -> void:
					if not fighter.dead and fighter.target != null and not fighter.target.dead:
						sim.receive_attack(fighter.target, fighter.attack, fighter))
			_count = _count + 1 if _count < 10 else 0
			return false
		"burning_tiger":
			if _count == 5:
				var loop := maxi(sim.animation_frames(fighter, SP1, 30), 24)
				var events := {}
				var start := 0
				while start + 23 <= 5 * BattleSim.FRAMES_PER_SECOND:
					events[start + 23] = func() -> void: _tiger_fireball(sim, fighter)
					start += loop
				sim.play_special(fighter, SP1, 5 * BattleSim.FRAMES_PER_SECOND, events, Callable(), true)
			elif _count == 10:
				var events := {}
				for frame in [40, 45]:
					events[frame] = func() -> void:
						for enemy in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
								return item.is_unit() and not item.dead and not item.incapacitated):
							sim.receive_attack(enemy, fighter.attack / 2, fighter)
							if not enemy.dead:
								sim.incinerate(enemy, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND)
								sim.push_in_air(enemy, fighter, 4)
				play(sim, fighter, SP2, 50, events, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
				if target.is_unit() and not target.dead:
					sim.push_in_air(target, fighter, 1)
			_count = _count + 1 if _count < 10 else 1
			return false
		"sword_lion":
			if _count == 6:
				var events := {}
				for frame in [27, 47, 68, 88]:
					events[frame] = func() -> void: _push_near(sim, fighter, fighter.tile, 3, 3, fighter.attack * 2, 5)
				play(sim, fighter, SP1, 90, events, Callable(), true)
			elif _count == 12:
				play(sim, fighter, SP2, 30, {20: func() -> void:
					if fighter.target != null and sim.distance(fighter, fighter.target) > fighter.attack_range:
						return
					_rain = SpecialAttacks.Rain.new(sim, fighter, 3, 2, SP2, MagicParticles.THUNDERBOLT, null).with_multiplier(0.5)
					_rain.start()}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 12 else 1
			return false
		"ice_golem":
			if _count == 5:
				play(sim, fighter, SP1, 30, {12: func() -> void:
					for enemy in SpecialUnit.directional_hits(sim, fighter, 3, 3):
						if not enemy.dead and (enemy.ability == null or not enemy.ability.immune_to_freeze):
							sim.freeze_with_damage(enemy, fighter, 20, 5, BattleSim.FRAMES_PER_SECOND)
							SpecialUnit.show_particle(sim, fighter, enemy.tile, MagicParticles.ICE_BLOCK)}, Callable(), true)
			elif _count == 10:
				play(sim, fighter, SP2, 50, {45: func() -> void: _ice_convert(sim, fighter)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 10 else 0
			return false
		"black_lizard":
			if distance > 2:
				if _second_count == 5 and target.is_unit() and target.max_life() <= SMALL_LIFE and distance <= fighter.attack_range:
					var prey := target
					play(sim, fighter, SP2, 40, {10: func() -> void:
						if prey.dead or sim.distance(fighter, prey) > fighter.attack_range:
							return
						sim.shoot_beam(fighter, prey, prey.tile, "p.tongue", 22, -1)
						sim.after(14, func() -> void:
							if not prey.dead:
								_hold(sim, prey))}, func() -> void:
						if prey.swallowed and not prey.dead:
							sim.kill(prey, fighter), true)
				else:
					_spit(sim, fighter, target)
				_second_count = _second_count + 1 if _second_count < 5 else 1
			else:
				if _count == 5:
					play(sim, fighter, SP1, 40, {35: func() -> void: _push_near(sim, fighter, fighter.tile, 5, 5, fighter.attack, 5)}, Callable(), true)
				else:
					_spit(sim, fighter, target)
				_count = _count + 1 if _count < 5 else 1
			return false
		"demolisher":
			if _count == 8:
				play(sim, fighter, SP1, 55, {49: func() -> void:
					for enemy in SpecialUnit.directional_hits(sim, fighter, 8):
						if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
							continue
						sim.receive_attack(enemy, int(fighter.attack * 1.2), fighter)
						if not enemy.dead:
							sim.push_in_air(enemy, fighter, 5)
							var landed := enemy
							sim.after(PUSH_LAND_FRAMES, func() -> void: sim.stun(landed))}, Callable(), true)
			elif _count == 16:
				var events := {}
				for i in range(1, 6):
					events[7 + i * 15] = func() -> void: _push_near(sim, fighter, fighter.tile, 8, 6, int(fighter.attack * 1.4), 5)
				sim.play_special(fighter, SP2, 7 + 84 + 1, events, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 16 else 1
			return false
	return true


func _anubis_convert(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.dead:
		return
	var victims := sim.items_near(fighter.tile, ANUBIS_RANGE, ANUBIS_MINIONS - _anubis_minions.size(), enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= ANUBIS_CONVERT_LIFE \
				and item.def.subcat_functional != BattleSim.SUBCAT_BOSS and (item.ability == null or not item.ability.immune_to_conversion))
	for victim in victims:
		var tile := victim.tile
		sim.kill(victim, fighter)
		sim.remove_item(victim)
		var minion := sim.spawn(sim.config_item(MINI_ANUBIS), tile, fighter.team)
		if minion == null:
			continue
		_anubis_minions.append(minion)
		minion.converted = true
		minion.incapacitated = true
		sim.poison(minion, fighter.attack, ANUBIS_POISON_TICKS, 0, fighter)
		sim.after(ANUBIS_APPEAR_FRAMES, func() -> void:
			if not minion.dead:
				minion.incapacitated = minion.frozen or minion.stunned or minion.in_air)


static func _edible(unit: BattleFighter) -> bool:
	return unit != null and unit.is_unit() and not unit.dead and not unit.incapacitated and unit.def.life <= SMALL_LIFE


static func _hold(sim: BattleSim, prey: BattleFighter) -> void:
	prey.incapacitated = true
	prey.swallowed = true
	sim.state_changed.emit(prey)


static func _push_near(sim: BattleSim, fighter: BattleFighter, tile: Vector2i, range_tiles: int, count: int, damage: int, push: int) -> void:
	for enemy in sim.items_near(tile, range_tiles, count, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, damage, fighter)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, push)


## One enemy on each tile within 2 tiles takes the attack times factor; a unit flies push tiles.
static func _ring_blow(sim: BattleSim, fighter: BattleFighter, factor: float, push: int) -> void:
	for y in range(-2, 3):
		for x in range(-2, 3):
			var found := sim.items_near(fighter.tile + Vector2i(x, y), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return not item.dead and item.is_valid_target())
			if found.is_empty():
				continue
			sim.receive_attack(found[0], int(fighter.attack * factor), fighter)
			if found[0].is_unit() and not found[0].dead:
				sim.push_in_air(found[0], fighter, push)


## Punisher: the 3 x 3 tiles in front take 1.5 times the attack; units are stunned.
static func _front_blow(sim: BattleSim, fighter: BattleFighter) -> void:
	var front: Vector2i = fighter.tile + TILE_STEPS[direction(fighter)]
	for y in range(-1, 2):
		for x in range(-1, 2):
			var found := sim.items_near(front + Vector2i(x, y), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return not item.dead and item.is_valid_target())
			if found.is_empty():
				continue
			sim.receive_attack(found[0], int(fighter.attack * 1.5), fighter)
			if found[0].is_unit() and not found[0].dead:
				sim.stun(found[0])


static func _cobra_spin(sim: BattleSim, fighter: BattleFighter) -> void:
	for enemy in sim.items_near(fighter.tile, 2, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
		sim.receive_attack(enemy, fighter.attack / 2, fighter)
		if enemy.is_unit() and not enemy.dead:
			sim.push_in_air(enemy, fighter, 4)
			sim.poison(enemy, 5, 5, 0, fighter)


static func _tiger_fireball(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead:
		return
	var tile := target.tile
	sim.shoot(fighter, target, "p.catapultFireball", fighter.attack, func(_shot: BattleProjectile) -> void:
		sim.effect("b.earthFire", tile)
		if target.is_unit() and not target.dead:
			sim.incinerate(target, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND))


static func _spit(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	sim.after(15, func() -> void:
		if not fighter.dead and not target.dead:
			sim.shoot(fighter, target, "p.acidGreen", fighter.attack))


## Ice Golem: up to 3 enemy units with at most 500 life change sides for 15 seconds.
static func _ice_convert(sim: BattleSim, fighter: BattleFighter) -> void:
	var converted: Array[BattleFighter] = []
	for enemy in sim.items_near(fighter.tile, 6, 3, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
		if enemy.max_life() > SMALL_LIFE or (enemy.ability != null and enemy.ability.immune_to_conversion):
			continue
		sim.convert(enemy, fighter.team)
		converted.append(enemy)
	sim.after(ICE_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void:
		for unit in converted:
			if not unit.dead and unit in sim.fighters:
				sim.convert(unit, BattleFighter.Team.PLAYER if unit.team == BattleFighter.Team.ENEMY else BattleFighter.Team.ENEMY))
