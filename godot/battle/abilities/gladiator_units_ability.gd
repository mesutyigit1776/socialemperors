class_name GladiatorUnitsAbility
extends BattleAbility
## The gladiators of the client whose delegates change the normal attack.
## Most count their attacks and make a special attack at some counts; the
## other attacks are direct hits or shots. The buttons of the gladiators that
## are special units are in special_units/gladiators.gd.
##
## - chariot (ChariotGladiatorDelegate): it does not look for enemies (passive).
##   While it moves, each enemy unit within 3 tiles (the 3 nearest) that can
##   fly takes its attack; each third such hit also pushes the unit, by 6, 3
##   or 1 tiles for units with up to 500, 1000 or more life. A hit unit is safe
##   for 2, 4 or 6 seconds. When enemies stay within 3 tiles of the standing
##   chariot for 3 seconds, it smashes (special attack 1, frame 30): the 5
##   nearest enemy units within 5 tiles take 1.25 times the attack and fly 6
##   tiles.
## - priest (PriestGladiatorDelegate): a beam that does the attack at frame 8;
##   each seventh attack a rain falls on the target for 3 seconds (special
##   attack 2, frame 17).
## - priest_minion (PriestGladiatorMinionDelegate): the target takes the attack
##   at frame 11.
## - sword (SwordGladiatorDelegate): a hit; each eighth attack (special attack
##   1, frame 23) the 3 nearest enemy units within 3 tiles take 1.2 times the
##   attack and fly 5 tiles.
## - spear (SpearGladiatorDelegate): a spear 16 frames after the attack. Near
##   the target (2 tiles or less), each fifth attack at a unit is a whirlwind
##   (special attack 1) for 3 seconds after 20 frames: every 500 ms the 5
##   nearest enemy units within 4 tiles take half the attack and fly 5 tiles.
## - rider (RiderGladiatorDelegate): a hit; attack 8 (special attack 1, frame
##   27): the 6 nearest enemies within 8 tiles take 1.2 times the attack;
##   attack 16 (special attack 2, frame 3): they take 1.4 times the attack
##   and fly 5 tiles.
## - big_warrior (BigWarriorGladiatorDelegate): a hit; attack 8 (special
##   attack 1, frame 31): each unit of a directional attack of 4 tiles takes
##   1.2 times the attack; attack 16 (special attack 2): for 3 seconds, every
##   500 ms, the 6 nearest enemy units within 8 tiles take 1.4 times the
##   attack and fly 5 tiles.
## - bull (BullGladiatorDelegate): a trident 1 second after the attack (it
##   cannot act meanwhile). Far from the target, each sixth attack is a charge
##   (special attack 1) when it has room: the first unit of a directional attack
##   along its range with less than 500 life flies 12 tiles and dies, others
##   take 500 points or the attack and fly 5 tiles. Near the target, each sixth
##   attack is a whirlwind (special attack 2) for 4 seconds after 30 frames:
##   every 500 ms the 10 nearest enemy units within 5 tiles take the attack and
##   fly 5 tiles.
## - blade (BladeGladiatorDelegate): a hit; attack 5 (special attack 1, frame
##   45): each unit of a directional attack of 3 tiles (radius 2) takes 1.5
##   times the attack and flies 5 tiles; attack 10 (special attack 2, frame
##   25): a target unit with at most 500 life flies 12 tiles and dies, others
##   take 1.5 times the attack and fly 5 tiles.
## - devil (DevilGladiatorDelegate): a hit; attack 6 (special attack 1, frame
##   13): of a directional attack of 4 tiles (radius 4, at most 4 units) the
##   first unit with less than 500 life flies 8 tiles and dies, the others
##   take 1.2 times the attack; attack 12 (special attack 2): for 3 seconds,
##   every 750 ms, the 5 nearest enemy units within 5 tiles take the attack
##   and fly 5 tiles.
## - mace (GladiatorMaceDelegate): a mace 12 frames after the attack; near
##   the target each fifth attack (special attack 1, frame 35): the 10 nearest
##   enemy units within 6 tiles take 1.2 times the attack and fly 5 tiles.
## - centaur (GladiatorCentaur): a trident 15 frames after the attack. Far from
##   the target, attack 5 throws a net at a unit with less than 500 life
##   (special attack 2, frame 32): it cannot act for 5 seconds; attack 10
##   throws a fast trident (special attack 1, frame 35): the unit flies 6 tiles
##   and then takes 1.5 times the attack. Near the target, each fifth attack
##   (special attack 3, frame 62): the 5 nearest enemy units within 8 tiles
##   take the attack and fly 5 tiles.
## - four_weapons (FourWeaponGladiatorDelegate): a hit; attack 5 (special
##   attack 1, frame 37): a target unit with at most 500 life flies 10 tiles
##   and dies when it lands, others take 2 times the attack and fly 2 tiles;
##   attack 10 (special attack 2, frame 91): the 10 nearest enemy units within
##   6 tiles that can fly take the attack and fly 10 tiles.

const UNITS := {
	2151: "chariot",
	2117: "priest",
	2118: "priest_minion",
	2105: "sword",
	2106: "spear",
	2107: "rider",
	2125: "big_warrior",
	2126: "bull",
	2143: "blade",
	2150: "devil",
	2116: "mace",
	2136: "centaur",
	2135: "four_weapons",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SP3 := SP1 + 2
const SMALL_LIFE := 500
const PUSH_LAND_FRAMES := BattleSim.FRAMES_PER_SECOND
## Chariot: [the most life, push tiles, safe seconds] by the life of a unit.
const CHARIOT_PUSHES := [[500, 6, 2], [1000, 3, 4], [2147483647, 1, 6]]

var _kind := ""
var _count := 0
var _second_count := 0
var _safe := {}  # Chariot: unit -> the frame from which it can be hit again.
var _hits := 0  # Chariot: hits since the last push.
var _defence := 0  # Chariot: seconds with enemies near the standing chariot.


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["chariot", "priest_minion", "sword", "rider", "big_warrior", "blade", "devil", "four_weapons"]
	match _kind:
		"sword", "rider", "big_warrior", "four_weapons":
			_count = 1
		"blade", "mace", "centaur":
			_count = 1
			_second_count = 1


func on_added(sim: BattleSim, fighter: BattleFighter) -> void:
	if _kind == "chariot":
		if fighter.ai != null:
			fighter.ai.condition = BattleAI.Condition.PASSIVE
		sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void: _chariot_second(sim, fighter))


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _kind != "chariot" or not fighter.moving:
		return
	for enemy in sim.items_near(fighter.tile, 3, 3, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		if _safe.get(enemy, 0) > sim.frame:
			continue
		var data: Array = CHARIOT_PUSHES[0]
		for row: Array in CHARIOT_PUSHES:
			data = row
			if enemy.max_life() < row[0]:
				break
		sim.receive_attack(enemy, fighter.attack, fighter)
		if _hits == 3:
			sim.push_in_air(enemy, fighter, data[1])
			_hits = 0
		_hits += 1
		_safe[enemy] = sim.frame + data[2] * BattleSim.FRAMES_PER_SECOND


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var near := sim.distance(fighter, target) <= 2
	match _kind:
		"chariot":
			return true
		"priest":
			_count += 1
			if _count % 7 == 0:
				sim.play_special(fighter, SP2, 17 + 3 * BattleSim.FRAMES_PER_SECOND, {17: func() -> void:
					if fighter.target == null or fighter.target.dead:
						var other := sim.nearest_enemy(fighter, fighter.tile, fighter.attack_range)
						if other != null:
							sim.set_target(fighter, other)
					BattleAbility.storm_symmetric(sim, fighter, MagicParticles.RAIN_PRIEST_GLADIATOR, 2, 0.5, 10, 35)}, Callable(), true)
			else:
				sim.after(8, func() -> void:
					if not fighter.dead and not target.dead:
						sim.shoot_beam(fighter, target, target.tile, "p.priestGladiator", 15, fighter.attack))
			return false
		"priest_minion":
			sim.after(11, func() -> void:
				if not fighter.dead and fighter.target != null and not fighter.target.dead:
					sim.receive_attack(fighter.target, fighter.attack, fighter))
			return false
		"sword":
			if _count == 8:
				play(sim, fighter, SP1, 30, {23: func() -> void: _push_near(sim, fighter, fighter.tile, 3, 3, int(fighter.attack * 1.2), 5)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 8 else 1
			return false
		"spear":
			if near:
				if _count == 5 and target.is_unit():
					_timed(sim, fighter, SP1, 3, 20, 15, func() -> void: _push_near(sim, fighter, fighter.tile, 4, 5, fighter.attack / 2, 5))
				else:
					_shot_after(sim, fighter, target, 16, "p.gladiatorSpear")
				_count = _count + 1 if _count < 5 else 1
			else:
				_shot_after(sim, fighter, target, 16, "p.gladiatorSpear")
			return false
		"rider":
			if _count == 8:
				play(sim, fighter, SP1, 30, {27: func() -> void:
					for enemy in sim.items_near(fighter.tile, 8, 6, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
						sim.receive_attack(enemy, int(fighter.attack * 1.2), fighter)}, Callable(), true)
			elif _count == 16:
				play(sim, fighter, SP2, 30, {3: func() -> void: _push_near(sim, fighter, fighter.tile, 8, 6, int(fighter.attack * 1.4), 5)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 16 else 1
			return false
		"big_warrior":
			if _count == 8:
				play(sim, fighter, SP1, 40, {31: func() -> void:
					for enemy in SpecialUnit.directional_hits(sim, fighter, 4):
						if not enemy.dead:
							sim.receive_attack(enemy, int(fighter.attack * 1.2), fighter)}, Callable(), true)
			elif _count == 16:
				_timed(sim, fighter, SP2, 3, 1, 15, func() -> void: _push_near(sim, fighter, fighter.tile, 8, 6, int(fighter.attack * 1.4), 5))
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 16 else 1
			return false
		"bull":
			if busy:
				return false
			if not near:
				if _count == 6:
					_bull_charge(sim, fighter)
				else:
					_trident(sim, fighter, target)
				_count = _count + 1 if _count < 6 else 0
			else:
				if _second_count == 6:
					_timed(sim, fighter, SP2, 4, 30, 15, func() -> void: _push_near(sim, fighter, fighter.tile, 5, 10, fighter.attack, 5))
				else:
					_trident(sim, fighter, target)
				_second_count = _second_count + 1 if _second_count < 6 else 0
			return false
		"blade":
			if _count == 5:
				play(sim, fighter, SP1, 50, {45: func() -> void:
					for enemy in SpecialUnit.directional_hits(sim, fighter, 3, 2):
						if not enemy.dead and (enemy.ability == null or not enemy.ability.immune_to_push):
							sim.receive_attack(enemy, int(fighter.attack * 1.5), fighter)
							sim.push_in_air(enemy, fighter, 5)}, Callable(), true)
			elif _count == 10:
				play(sim, fighter, SP2, 30, {25: func() -> void:
					var cut := fighter.target
					if cut == null or cut.dead or not cut.is_unit() or (cut.ability != null and cut.ability.immune_to_push):
						return
					if cut.max_life() <= SMALL_LIFE:
						_fly_and_die(sim, fighter, cut, 12)
					else:
						sim.receive_attack(cut, int(fighter.attack * 1.5), fighter)
						sim.push_in_air(cut, fighter, 5)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 10 else 1
			return false
		"four_weapons":
			if _count == 5:
				play(sim, fighter, SP1, 40, {37: func() -> void: _four_weapons_smash(sim, fighter)}, Callable(), true)
			elif _count == 10:
				play(sim, fighter, SP2, 95, {91: func() -> void: _push_near(sim, fighter, fighter.tile, 6, 10, fighter.attack, 10)}, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 10 else 1
			return false
		"devil":
			if _count == 6:
				play(sim, fighter, SP1, 30, {13: func() -> void:
					var killed := false
					for enemy in SpecialUnit.directional_hits(sim, fighter, 4, 4, 3):
						if enemy.dead:
							continue
						if enemy.max_life() < SMALL_LIFE and not killed:
							killed = true
							_fly_and_die(sim, fighter, enemy, 8)
						else:
							sim.receive_attack(enemy, int(fighter.attack * 1.2), fighter)})
			elif _count == 12:
				_timed(sim, fighter, SP2, 3, 1, 22, func() -> void: _push_near(sim, fighter, fighter.tile, 5, 5, fighter.attack, 5))
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 12 else 0
			return false
		"mace":
			if near:
				if _count == 5:
					play(sim, fighter, SP1, 40, {35: func() -> void: _push_near(sim, fighter, fighter.tile, 6, 10, int(fighter.attack * 1.2), 5)}, Callable(), true)
				else:
					_shot_after(sim, fighter, target, 12, "p.gladiatorMace")
				_count = _count + 1 if _count < 5 else 1
			else:
				_shot_after(sim, fighter, target, 12, "p.gladiatorMace")
			return false
		"centaur":
			if not near:
				if _second_count == 5 and target.is_unit() and target.max_life() < SMALL_LIFE:
					play(sim, fighter, SP2, 40, {32: func() -> void: _centaur_net(sim, fighter)}, Callable(), true)
				elif _second_count == 10:
					play(sim, fighter, SP1, 40, {35: func() -> void: _centaur_super_spear(sim, fighter)}, Callable(), true)
				else:
					_shot_after(sim, fighter, target, 15, "p.centaurTrident")
				_second_count = _second_count + 1 if _second_count < 10 else 1
			else:
				if _count == 5:
					play(sim, fighter, SP3, 70, {62: func() -> void: _push_near(sim, fighter, fighter.tile, 8, 5, fighter.attack, 5)}, Callable(), true)
				else:
					_shot_after(sim, fighter, target, 15, "p.centaurTrident")
				_count = _count + 1 if _count < 5 else 1
			return false
	return true


## Chariot: called each second (the timer of the client).
func _chariot_second(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.dead or not fighter in sim.fighters:
		return
	if _defence >= 3:
		_defence = 0
		play(sim, fighter, SP1, 40, {30: func() -> void: _push_near(sim, fighter, fighter.tile, 5, 5, int(fighter.attack * 1.25), 6)}, Callable(), true)
	elif not fighter.moving and not sim.items_near(fighter.tile, 3, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead).is_empty():
		_defence += 1
	else:
		_defence = 0
	sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void: _chariot_second(sim, fighter))


## A special animation for seconds in which action runs every interval frames,
## the first time after delay frames (startTimedAttack of the client).
static func _timed(sim: BattleSim, fighter: BattleFighter, animation: int, seconds: int, delay: int, interval: int, action: Callable) -> void:
	var events := {}
	var times := seconds * BattleSim.FRAMES_PER_SECOND / interval
	for i in range(1, times + 1):
		events[delay + i * interval] = action
	sim.play_special(fighter, animation, delay + times * interval + 1, events)


static func _shot_after(sim: BattleSim, fighter: BattleFighter, target: BattleFighter, delay: int, graphic: String) -> void:
	sim.after(delay, func() -> void:
		if not fighter.dead and not target.dead:
			sim.shoot(fighter, target, graphic, fighter.attack))


static func _push_near(sim: BattleSim, fighter: BattleFighter, tile: Vector2i, range_tiles: int, count: int, damage: int, push: int) -> void:
	for enemy in sim.items_near(tile, range_tiles, count, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, damage, fighter)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, push)


## The unit flies tiles and dies when it lands.
static func _fly_and_die(sim: BattleSim, fighter: BattleFighter, unit: BattleFighter, tiles: int) -> void:
	sim.push_in_air(unit, fighter, tiles)
	sim.after(PUSH_LAND_FRAMES, func() -> void:
		if not unit.dead:
			sim.kill(unit, fighter if fighter in sim.fighters else null))


## 4-Weapons Gladiator: in the client, a small unit that cannot fly does not
## die, because the kill waits for the end of the flight.
static func _four_weapons_smash(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead or not target.is_unit():
		return
	if target.max_life() > SMALL_LIFE:
		sim.receive_attack(target, fighter.attack * 2, fighter)
		if not target.dead:
			sim.push_in_air(target, fighter, 2)
		return
	sim.push_in_air(target, fighter, 10)
	if target.in_air:
		sim.after(PUSH_LAND_FRAMES, func() -> void:
			if not target.dead:
				sim.kill(target, fighter if fighter in sim.fighters else null))


## Bull: the trident leaves after 1 second; the gladiator cannot act meanwhile.
func _trident(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	busy = true
	fighter.incapacitated = true
	sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
		busy = false
		if fighter.dead:
			return
		fighter.incapacitated = fighter.frozen or fighter.stunned or fighter.in_air
		if not target.dead:
			sim.shoot(fighter, target, "p.trident", fighter.attack))


## Bull: the charge needs a tile on its line: a free tile farther than half
## its range, or a unit; the line stops at the map edge or a building. The
## client looks up, right or down (the down line repeats the next tile).
## Without such a tile nothing happens.
static func _bull_charge(sim: BattleSim, fighter: BattleFighter) -> void:
	var step := Vector2i(0, 1)
	var repeat := false
	match direction(fighter):
		1, 2: step = Vector2i(0, -1)
		3, 4, 5: step = Vector2i(1, 0)
		6: step = Vector2i(-1, 0)
		_: repeat = true
	var found := false
	for i in range(1, fighter.attack_range + 1):
		var tile := fighter.tile + (step if repeat else step * i)
		if tile.x <= 0 or tile.y <= 0 or tile.x >= IsoGrid.MAP_TILES or tile.y >= IsoGrid.MAP_TILES:
			break
		var item := sim.fighter_at(tile)
		if item == null:
			if sim.is_free(tile) and i > fighter.attack_range / 2.0:
				found = true
			continue
		if not item.is_unit():
			break
		found = true
	if not found:
		return
	var killed := false
	for enemy in SpecialUnit.directional_hits(sim, fighter, fighter.attack_range, 5):
		if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
			continue
		if not killed:
			if enemy.max_life() < SMALL_LIFE:
				killed = true
				_fly_and_die(sim, fighter, enemy, 12)
			else:
				sim.receive_attack(enemy, SMALL_LIFE, fighter)
				sim.push_in_air(enemy, fighter, 5)
		else:
			sim.receive_attack(enemy, fighter.attack, fighter)
			sim.push_in_air(enemy, fighter, 5)
	sim.play_special(fighter, SP1, BattleSim.FRAMES_PER_SECOND, {}, Callable(), true)


static func _centaur_net(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead or not target.is_unit():
		return
	sim.shoot(fighter, target, "p.centaurNet", -1, func(_shot: BattleProjectile) -> void:
		if target.dead or target.max_life() > SMALL_LIFE:
			return
		SpecialUnit.show_particle(sim, fighter, target.tile, MagicParticles.GLADIATOR_NET)
		sim.stun(target)
		Damages.Simple.new(sim, fighter, 0, 5, 1).apply(target))


static func _centaur_super_spear(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead:
		return
	sim.shoot(fighter, target, "p.centaurTrident", -1, func(_shot: BattleProjectile) -> void:
		if target.dead or not target.is_unit():
			return
		sim.push_in_air(target, fighter, 6)
		sim.after(PUSH_LAND_FRAMES, func() -> void:
			if not target.dead:
				sim.receive_attack(target, int(fighter.attack * 1.5), fighter if fighter in sim.fighters else null)))
