class_name PhoenixAbility
extends BattleAbility
## The Phoenix, the Blue Phoenix and the Green Phoenix (PhoenixDelegate,
## PhoenixBlueDelegate and PhoenixGreenDelegate of the client). Their graphic
## is 1.5 times bigger. They shoot fire 8 frames after an attack (13 in a
## special attack); a unit hit by the fire of the Phoenix or the Blue Phoenix
## burns with a third of the attack every second, 5 times.
##
## - Phoenix: every fifth attack shoots at the best enemy unit in its range,
##   at frame 13 and then every 400 ms, 10 times, with half its attack. Every
##   eleventh attack heals it by 50 at frame 4 and then every second, 5 times
##   or until its life is full.
## - Blue Phoenix: every eighth attack shoots at up to 5 enemy units in its
##   range at frame 5 and then every 400 ms, 10 times, with a third of its
##   attack. When it dies, an egg comes on its tile (PhoenixEggAbility), from
##   which it comes back once.
## - Green Phoenix: every eleventh attack it spins: the items of the other side
##   on the 5 x 5 tiles around it take its attack / 1.4 and units fly 3 tiles
##   away, at once and then every 400 ms, 5 times. When it dies, at frame 35 of
##   its death, the same tiles take twice its attack and units fly 6 tiles away.
## When a phoenix walks, its special attack stops.

const PHOENIX := 744
const BLUE := 775
const GREEN := 856
const BLUE_EGG := 1282
const REPEAT_FRAMES := 12  ## 400 ms.
const HEALTH_BOOST := 50
const DEATH_FRAME := 35

var _kind := PHOENIX
var _attacks := 0
var _in_special := false
var _special := 0  # Counts the special attacks, so that a stopped one does nothing.
var _saved_attack := 0
var resurrect := true  ## The Blue Phoenix comes back from its egg only once.


func configure(item_id: int) -> void:
	_kind = item_id
	scale = 1.5
	shot_graphic = {PHOENIX: "p.phoenix", BLUE: "p.bluePhoenix", GREEN: "p.greenPhoenix"}[item_id]
	shot_delay = 8


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	_attacks += 1
	_special += 1
	var id := _special
	match _kind:
		PHOENIX:
			if _attacks % 5 == 0:
				_start(sim, fighter, 2)
				_repeat(sim, fighter, id, 13, 10, func() -> void:
					var enemy := sim.nearest_target(fighter, fighter.tile, fighter.attack_range, func(item: BattleFighter) -> bool: return item.is_unit(), false)
					if enemy == null:
						return
					sim.shoot(fighter, enemy, shot_graphic, fighter.attack))
				return false
			if _attacks % 11 == 0:
				_in_special = true
				sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, 1 << 20)
				for i in 5:
					sim.after(4 + i * BattleSim.FRAMES_PER_SECOND, func() -> void:
						if id == _special and not fighter.dead and fighter.health < fighter.max_life():
							sim.heal(fighter, HEALTH_BOOST, fighter))
				sim.after(4 + 5 * BattleSim.FRAMES_PER_SECOND, func() -> void: _end(sim, fighter, id))
				return false
		BLUE:
			if _attacks % 8 == 0:
				_start(sim, fighter, 3)
				_repeat(sim, fighter, id, 5, 10, func() -> void:
					for enemy in enemy_units_near(sim, fighter, fighter.tile, fighter.attack_range, 5):
						sim.shoot(fighter, enemy, shot_graphic, fighter.attack)
						GodzillaAbility._take_target(sim, fighter, enemy))
				return false
		GREEN:
			if _attacks % 11 == 0:
				_in_special = true
				sim.play_special(fighter, UnitSprite.Action.SPECIAL, 1 << 20)
				_repeat(sim, fighter, id, 0, 5, func() -> void: _blast(sim, fighter, fighter.attack / 1.4, 3))
				return false
	return true


func on_shot_landed(sim: BattleSim, fighter: BattleFighter, shot: BattleProjectile) -> void:
	if _kind != GREEN and shot.target != null and shot.target.is_unit() and not shot.target.dead:
		sim.incinerate(shot.target, fighter, fighter.attack / 3, 5, BattleSim.FRAMES_PER_SECOND)


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_end(sim, fighter, _special)


func on_died(sim: BattleSim, fighter: BattleFighter) -> void:
	_special += 1
	if _saved_attack > 0:
		fighter.attack = _saved_attack
	match _kind:
		GREEN:
			sim.after(DEATH_FRAME, func() -> void: _blast(sim, fighter, fighter.attack * 2, 6))
		BLUE:
			if resurrect:
				var tile := fighter.tile
				var team := fighter.team
				sim.after(DEATH_FRAME, func() -> void:
					sim.remove_item(fighter)
					sim.spawn(sim.config_item(BLUE_EGG), tile, team, false))


## The special attack 1 with the attack divided by divisor.
func _start(sim: BattleSim, fighter: BattleFighter, divisor: int) -> void:
	_in_special = true
	shot_delay = 13
	_saved_attack = fighter.attack
	fighter.attack = fighter.attack / divisor
	sim.play_special(fighter, UnitSprite.Action.SPECIAL, 1 << 20)


func _repeat(sim: BattleSim, fighter: BattleFighter, id: int, first: int, times: int, action: Callable) -> void:
	for i in times:
		sim.after(first + i * REPEAT_FRAMES, func() -> void:
			if id == _special and not fighter.dead:
				action.call())
	sim.after(first + times * REPEAT_FRAMES, func() -> void: _end(sim, fighter, id))


func _end(sim: BattleSim, fighter: BattleFighter, id: int) -> void:
	if id != _special:
		return
	_special += 1
	_in_special = false
	shot_delay = 8
	if _saved_attack > 0:
		fighter.attack = _saved_attack
		_saved_attack = 0
	sim.stop_special(fighter)


func _blast(sim: BattleSim, fighter: BattleFighter, damage: float, push: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			for target in sim.items_near(fighter.tile + Vector2i(dx, dy), 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead and item.is_valid_target()):
				sim.receive_attack(target, int(damage), fighter)
				if target.is_unit():
					sim.push_in_air(target, fighter, push)
				GodzillaAbility._take_target(sim, fighter, target)
