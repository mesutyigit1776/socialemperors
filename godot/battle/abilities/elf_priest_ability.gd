class_name ElfPriestAbility
extends BattleAbility
## The Elf Priest (ElfPriestDelegate of the client). It shoots a fireball at
## frame 10 of each attack. Next to its target (2 tiles or less):
##
## - The fourth attack is an energy bubble (special attack 1, it cannot act):
##   at frame 20 up to 3 enemy units within 5 tiles, with MAX_LIFE_TO_CONVERT
##   life or less, that can act and can be converted, change to its side as
##   summoned units for TRANSFORM_FRAMES. The client counts them as dead on
##   their old side. Then they come back as enemy units (the client puts them
##   on the enemy side also when the priest is an enemy).
## - The eighth attack heals the units of its side in its range by 150 (special
##   attack 2), when there are any; else it shoots.

const FIREBALL := "p.fireBall_02"
const ENERGY_RANGE := 5
const MAX_MINIONS := 3
const MAX_LIFE_TO_CONVERT := 350
const LIFE_TO_HEAL := 150
const TRANSFORM_FRAMES := 450  ## 15 seconds.

var _counter := 0
var _minions: Array[BattleFighter] = []
var _transforming := false


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if sim.distance(fighter, fighter.target) > 2:
		_shoot(sim, fighter)
		return false
	if _counter == 4:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 40, {20: func() -> void: _bubble(sim, fighter)}, Callable(), true)
	elif _counter == 8:
		var friends := sim.items_near(fighter.tile, fighter.attack_range, 5, fighter.team, false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead)
		if not friends.is_empty():
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 40, {20: func() -> void:
				for unit in friends:
					if not unit.dead:
						sim.heal(unit, LIFE_TO_HEAL, fighter)}, Callable(), true)
		else:
			_shoot(sim, fighter)
	else:
		_shoot(sim, fighter)
	_counter += 1
	if _counter > 8:
		_counter = 0
	return false


func _shoot(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(10, func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, FIREBALL, fighter.attack))


func _bubble(sim: BattleSim, fighter: BattleFighter) -> void:
	_minions = _minions.filter(func(unit: BattleFighter) -> bool: return not unit.dead)
	var room := MAX_MINIONS - _minions.size()
	if room <= 0:
		return
	for unit in sim.items_near(fighter.tile, ENERGY_RANGE, room, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= MAX_LIFE_TO_CONVERT and item.def.life < MonkAbility.CONVERSION_MAX_LIFE and item.def.subcat_functional != BattleSim.SUBCAT_BOSS and not (item.ability != null and item.ability.immune_to_conversion)):
		sim.convert(unit, fighter.team)
		unit.summoned = true
		_minions.append(unit)
	if not _transforming and not _minions.is_empty():
		_transforming = true
		sim.after(TRANSFORM_FRAMES, func() -> void:
			_transforming = false
			for unit in _minions:
				if not unit.dead:
					sim.convert(unit, BattleFighter.Team.ENEMY)
					unit.summoned = false
					unit.converted = true
			_minions.clear())
