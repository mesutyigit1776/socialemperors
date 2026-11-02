class_name TitanStratosAbility
extends BattleAbility
## Titan Stratos (TitanStratosDelegate of the client), a ranged unit that hits
## like a melee unit. It counts its attacks from 1.
##
## - Next to its target (2 tiles or less), each twelfth attack swallows up to 2
##   enemy units in its range (special attack 1); the other attacks hit at once.
## - Farther away in its range, each fourth attack makes a tornado near it for
##   10 seconds (special attack 2, frame 11), when it has no tornado; the other
##   attacks swallow. The client puts the tornado on the side of the player,
##   also when the titan is an enemy; the port does the same.
## - Swallowed units cannot act and die at frame 35. Bosses, units that cannot
##   act and units that cannot be swallowed stay.
## - When it dies, its tornado goes away.

const TORNADO := 617  ## ID_UNIT_TORNADO
const TORNADO_FRAME := 11
const TORNADO_LIFE_FRAMES := 300  ## 10 seconds.
const SWALLOW_FRAME := 35
const SWALLOW_COUNT := 2

var _attacks := 0
var _in_special := false
var _tornados: Array[BattleFighter] = []
var _swallowed: Array[BattleFighter] = []


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var target := fighter.target
	var distance := sim.distance(fighter, target)
	_attacks += 1
	if distance <= 2:
		var prey := _prey(sim, fighter) if _attacks % 12 == 0 else ([] as Array[BattleFighter])
		if prey.is_empty():
			sim.receive_attack(target, fighter.attack, fighter)
		else:
			_swallow(sim, fighter, prey)
		return false
	if distance <= fighter.attack_range:
		if _attacks % 4 == 0 and _tornados.is_empty():
			_in_special = true
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, {TORNADO_FRAME: func() -> void: _spawn_tornado(sim, fighter)}, _end)
		else:
			_swallow(sim, fighter, _prey(sim, fighter))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_in_special = false
		sim.stop_special(fighter)
		_release()


func on_died(sim: BattleSim, _fighter: BattleFighter) -> void:
	_release()
	_remove_tornados(sim)


func _end() -> void:
	_in_special = false


func _prey(sim: BattleSim, fighter: BattleFighter) -> Array[BattleFighter]:
	return sim.items_near(fighter.tile, fighter.attack_range, SWALLOW_COUNT, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and not item.incapacitated and item.can_be_swallowed() \
				and (item.ability == null or not item.ability.immune_to_swallow) and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)


func _swallow(sim: BattleSim, fighter: BattleFighter, prey: Array[BattleFighter]) -> void:
	_in_special = true
	_swallowed = prey
	for unit in prey:
		unit.incapacitated = true
	play(sim, fighter, UnitSprite.Action.SPECIAL, 50, {SWALLOW_FRAME: func() -> void:
		_release()
		for unit in prey:
			if not unit.dead:
				sim.kill(unit, fighter)}, _end)


## The swallowed units can act again.
func _release() -> void:
	for unit in _swallowed:
		unit.incapacitated = unit.frozen or unit.stunned or unit.in_air
	_swallowed = []


func _spawn_tornado(sim: BattleSim, fighter: BattleFighter) -> void:
	var unit := sim.spawn(sim.config_item(TORNADO), fighter.tile, BattleFighter.Team.PLAYER)
	if unit == null:
		return
	_tornados.append(unit)
	sim.after(TORNADO_LIFE_FRAMES, func() -> void: _remove_tornados(sim))


func _remove_tornados(sim: BattleSim) -> void:
	for unit in _tornados:
		if not unit.dead:
			sim.remove_item(unit)
	_tornados.clear()
