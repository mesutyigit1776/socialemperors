class_name BigUnitsAbility
extends BattleAbility
## Big units whose delegates of the client change the normal attack.
##
## - cyclops_ii (CyclopsDelegate): next to the target it slaps (frame 5: the
##   target flies 2 tiles and takes the attack); each eighth such attack it
##   grabs the nearest enemy unit in range whose item has at most 350 life and
##   that can act, and eats it (it dies at frame 16). In its range it fires
##   its eye laser 8 frames after the attack (a beam of 0.7 seconds).
## - atlas (AtlasTitanDelegate): a fireball 15 frames after the attack. Near
##   the target (2 tiles or less) attack 5 of each 10 makes the planet explode
##   (special attack 2, frames 55 to 80): the 10 nearest enemy units within 8
##   tiles take the attack and fly 5 tiles. Farther away attack 5 of each 10
##   throws the planet (special attack 1, frame 31): where it lands, the 5
##   nearest enemy units within 2 tiles take 1.5 times the attack and fly 8
##   tiles. 69 frames after the titan dies, the planet explodes again.
## - kong (KongDelegate): near the target (2 tiles or less) it hits for 1.5
##   times the attack; in its range it throws a banana (10 frames). Every 105
##   frames of fight it makes a special attack, by turns: it eats the 2
##   nearest enemy units within its range - 1 whose items have at most 350
##   life (both or none; they die at frame 104 of special attack 3), or it
##   heals itself by 100 (special attack 2).
## - mammoth (MamutDelegate): near the target (2 tiles or less) its attack
##   pushes a target unit 5 tiles at frame 10 and does no damage. Attack 3 of
##   each 5 is a spin (special attack 1, frame 20): on each tile within 2
##   tiles one enemy takes 1.5 times the attack, and a unit flies 4 tiles.
##   Attack 5 of each 5 is a charge: it runs 5 tiles ahead at twice its speed
##   and back; on each tile, the enemy unit within 1 tile takes 1.5 times the
##   attack and flies 5 tiles. The charge ends after 5 seconds at the latest.
## - godzilla (NuclearGodzillaDelegate): within 3 tiles of the target attack 3
##   of each 12 is a smash (special attack 1, frame 22) and attack 6 a
##   radiation (special attack 2, frame 30); the other attacks hit. On each
##   tile within 2 tiles one enemy takes 1.25 (smash) or 1.5 (radiation) times
##   the attack, and a unit flies 4 tiles. When it dies, a radiation pushes 6
##   tiles. It does not walk while a special attack plays.
## - sphinx (EsfingeDelegate): near the target (2 tiles or less) it hits;
##   attack 4 of each 9 (special attack 2, frame 18): the target takes the
##   attack and a unit flies 3 tiles; attack 8 (special attack 1, frame 21):
##   the target takes the attack and a unit is poisoned (half the attack a
##   second for 5 seconds).

const UNITS := {
	792: "cyclops_ii",
	2114: "atlas",
	741: "kong",
	770: "mammoth",
	776: "godzilla",
	861: "sphinx",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SP3 := SP1 + 2
const SMALL_LIFE := 350
const KONG_SPECIAL_FRAMES := 105
const MAMMOTH_CHARGE_TILES := 5
const MAMMOTH_CHARGE_SECONDS := 5

var _kind := ""
var _count := 0
var _second_count := 0
var _kong_special := 0
var _kong_frames := -KONG_SPECIAL_FRAMES
var _charging := false
var _charge_back := Vector2i.ZERO


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["godzilla", "sphinx"]
	if _kind == "cyclops_ii":
		shot_graphic = "p.laser"
		beam = true
		beam_frames = 21
	elif _kind == "kong":
		shot_graphic = "p.banana"
		shot_delay = 10
	if _kind == "atlas":
		_count = 1
		_second_count = 1


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var distance := sim.distance(fighter, target)
	match _kind:
		"cyclops_ii":
			_count += 1
			if distance <= 1:
				if _count < 8:
					play(sim, fighter, UnitSprite.Action.ATTACKING, 10, {5: func() -> void:
						var slapped := fighter.target
						if slapped != null and not slapped.dead and slapped.is_unit():
							sim.push_in_air(slapped, fighter, 2)
							sim.receive_attack(slapped, fighter.attack, fighter)})
				else:
					_count = 0
					_cyclops_grab(sim, fighter)
			else:
				play(sim, fighter, SP2, 30, {8: func() -> void:
					if fighter.target != null and not fighter.target.dead:
						sim.shoot(fighter, fighter.target, shot_graphic, fighter.attack)})
			return false
		"atlas":
			if distance <= 2:
				if _second_count == 5:
					var events := {}
					for frame in [55, 60, 65, 70, 75, 80]:
						events[frame] = func() -> void: _atlas_explosion(sim, fighter)
					play(sim, fighter, SP2, 85, events, Callable(), true)
				else:
					_fireball(sim, fighter, target)
				_second_count = _second_count + 1 if _second_count < 10 else 1
			else:
				if _count == 5:
					play(sim, fighter, SP1, 40, {31: func() -> void: _atlas_throw(sim, fighter)}, Callable(), true)
				else:
					_fireball(sim, fighter, target)
				_count = _count + 1 if _count < 10 else 1
			return false
		"kong":
			if _kong_frames >= 0:
				return false
			if distance <= 2:
				sim.receive_attack(target, int(fighter.attack * 1.5), fighter)
				return false
			return distance <= fighter.attack_range
		"mammoth":
			if _charging or distance > 2:
				return false
			if _count > 4:
				_count = 0
			if _count == 2:
				_count += 1
				play(sim, fighter, SP1, 30, {20: func() -> void: _ring_blow(sim, fighter, 1.5, 4)}, Callable(), true)
			elif _count == 4:
				_count += 1
				_mammoth_charge(sim, fighter)
			else:
				_count += 1
				sim.after(10, func() -> void:
					if not fighter.dead and fighter.target != null and fighter.target.is_unit() and not fighter.target.dead:
						sim.push_in_air(fighter.target, fighter, 5))
			return false
		"godzilla":
			if distance <= 3:
				_count += 1
				if _count > 12:
					_count = 0
				if _count == 3:
					play(sim, fighter, SP1, 30, {22: func() -> void: _ring_blow(sim, fighter, 1.25, 4)}, Callable(), true)
				elif _count == 6:
					play(sim, fighter, SP2, 40, {30: func() -> void: _ring_blow(sim, fighter, 1.5, 4)}, Callable(), true)
				else:
					sim.receive_attack(target, fighter.attack, fighter)
			return false
		"sphinx":
			if distance > 2:
				return false
			if _count == 4:
				play(sim, fighter, SP2, 30, {18: func() -> void:
					var hit := fighter.target
					if hit != null and not hit.dead:
						sim.receive_attack(hit, fighter.attack, fighter)
						if hit.is_unit() and not hit.dead:
							sim.push_in_air(hit, fighter, 3)}, Callable(), true)
			elif _count == 8:
				play(sim, fighter, SP1, 30, {21: func() -> void:
					var hit := fighter.target
					if hit != null and not hit.dead:
						sim.receive_attack(hit, fighter.attack, fighter)
						if hit.is_unit() and not hit.dead:
							sim.poison(hit, fighter.attack / 2, 5, 0, fighter)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 8 else 0
			return false
	return true


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _kind != "kong" or fighter.target == null or fighter.target.dead:
		return
	_kong_frames += 1
	if _kong_frames != 0:
		return
	_kong_special += 1
	if _kong_special % 2 == 1:
		_kong_grab(sim, fighter)
	else:
		sim.heal(fighter, 100, fighter)
		play(sim, fighter, SP2, 75, {}, func() -> void: _kong_frames = -KONG_SPECIAL_FRAMES, true)


func on_enter_tile(sim: BattleSim, fighter: BattleFighter) -> void:
	if not _charging:
		return
	var found := sim.items_near(fighter.tile, 1, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return not item.dead and item.is_valid_target())
	if not found.is_empty() and found[0].is_unit():
		sim.receive_attack(found[0], int(fighter.attack * 1.5), fighter)
		if not found[0].dead:
			sim.push_in_air(found[0], fighter, 5)


func on_died(sim: BattleSim, fighter: BattleFighter) -> void:
	match _kind:
		"atlas":
			sim.after(69, func() -> void: _atlas_explosion(sim, fighter))
		"godzilla":
			sim.after(30, func() -> void: _ring_blow(sim, fighter, 1.5, 6))


## On each tile within 2 tiles one enemy takes the attack times factor, and
## a unit flies push tiles.
static func _ring_blow(sim: BattleSim, fighter: BattleFighter, factor: float, push: int) -> void:
	var attacker := fighter if fighter in sim.fighters else null
	for y in range(-2, 3):
		for x in range(-2, 3):
			var found := sim.items_near(fighter.tile + Vector2i(x, y), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return not item.dead and item.is_valid_target())
			if found.is_empty():
				continue
			sim.receive_attack(found[0], int(fighter.attack * factor), attacker)
			if found[0].is_unit() and not found[0].dead:
				sim.push_in_air(found[0], fighter, push)


static func _fireball(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	sim.after(15, func() -> void:
		if fighter.dead or target.dead:
			return
		var tile := target.tile
		sim.shoot(fighter, target, "p.catapultFireball", fighter.attack, func(_shot: BattleProjectile) -> void: sim.effect("b.earthFire", tile)))


static func _atlas_explosion(sim: BattleSim, fighter: BattleFighter) -> void:
	var attacker := fighter if fighter in sim.fighters else null
	for enemy in sim.items_near(fighter.tile, 8, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, fighter.attack, attacker)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, 5)


static func _atlas_throw(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if fighter.dead or target == null or target.dead:
		return
	var tile := target.tile
	sim.shoot(fighter, target, "p.fireAtlas", fighter.attack, func(_shot: BattleProjectile) -> void:
		sim.effect("b.atlasExplosion", tile)
		for enemy in sim.items_near(tile, 2, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
			sim.receive_attack(enemy, int(fighter.attack * 1.5), fighter if fighter in sim.fighters else null)
			if not enemy.dead:
				sim.push_in_air(enemy, fighter, 8))


## The units that the Cyclops II and Kong can eat.
static func _edible(item: BattleFighter) -> bool:
	return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= SMALL_LIFE \
			and item.def.subcat_functional != BattleSim.SUBCAT_BOSS


static func _hold(sim: BattleSim, prey: BattleFighter) -> void:
	prey.incapacitated = true
	prey.swallowed = true
	sim.state_changed.emit(prey)


static func _cyclops_grab(sim: BattleSim, fighter: BattleFighter) -> void:
	var held: Array[BattleFighter] = []
	play(sim, fighter, SP1, 30, {
		5: func() -> void:
			var prey := sim.items_near(fighter.tile, fighter.attack_range, 1, enemy_side(fighter), true, _edible)
			if prey.is_empty():
				sim.stop_special(fighter)
				return
			held.append(prey[0])
			_hold(sim, prey[0]),
		16: func() -> void:
			for prey in held:
				if not prey.dead:
					sim.kill(prey, fighter)
			held.clear(),
	}, Callable(), true)


func _kong_grab(sim: BattleSim, fighter: BattleFighter) -> void:
	var prey := sim.items_near(fighter.tile, fighter.attack_range - 1, 2, enemy_side(fighter), true, _edible)
	if prey.size() < 2:
		_kong_frames = -KONG_SPECIAL_FRAMES
		return
	for unit in prey:
		_hold(sim, unit)
	play(sim, fighter, SP3, 105, {104: func() -> void:
		for unit in prey:
			if not unit.dead:
				sim.kill(unit, fighter)}, func() -> void: _kong_frames = -KONG_SPECIAL_FRAMES, true)


func _mammoth_charge(sim: BattleSim, fighter: BattleFighter) -> void:
	var step: Vector2i = DIRECTION_STEPS[direction(fighter)]
	if direction(fighter) == 3:
		step = Vector2i(1, -1)  # The client charges up-right when it looks right.
	var start := fighter.tile
	var goal := (start + step * MAMMOTH_CHARGE_TILES).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
	_charging = true
	SpecialUnit.fly_to(sim, fighter, goal, fighter.speed * 2, func() -> void: pass, func() -> void:
		if not _charging or fighter.dead:
			return
		SpecialUnit.fly_to(sim, fighter, start, fighter.speed * 2, func() -> void: pass, func() -> void: _charging = false))
	sim.after(MAMMOTH_CHARGE_SECONDS * BattleSim.FRAMES_PER_SECOND, func() -> void: _charging = false)
