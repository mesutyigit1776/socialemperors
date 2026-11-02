class_name WerewolfAlbinoAbility
extends BattleAbility
## The Albino Werewolf (WerewolfAlbinoDelegate of the client), a ranged unit
## that hits like a melee unit. It counts its attacks from 1.
##
## - Each tenth attack (special attack 1): at frame 8 its target, a unit that
##   is not a boss and that can be converted, dies and becomes an Albino
##   Werewolf on the side of the attacker, with 300 life. The new werewolf is
##   poisoned until it dies (half the attack of the attacker every 3 seconds)
##   and cannot act for 1.5 seconds while it appears.
## - Each tenth attack plus 5 (special attack 2): at frames 10, 12, ... 26, the
##   nearest enemy unit in its range takes its attack and flies 4 tiles away.

const NEW_LIFE := 300
const APPEAR_FRAMES := 45
const WHIRL_FRAMES: Array[int] = [10, 12, 14, 16, 18, 20, 22, 24, 26]

var _attacks := 0


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if busy:
		return false
	_attacks += 1
	if _attacks % 10 == 0:
		play(sim, fighter, UnitSprite.Action.SPECIAL, 20, {8: func() -> void: _transform(sim, fighter)})
		return false
	if _attacks % 10 == 5:
		var events := {}
		for frame in WHIRL_FRAMES:
			events[frame] = func() -> void: _whirl(sim, fighter)
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, events)
		return false
	return true


func _transform(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead or not target.is_unit() or target.def.subcat_functional == BattleSim.SUBCAT_BOSS:
		return
	if target.ability != null and target.ability.immune_to_conversion:
		return
	var tile := target.tile
	sim.kill(target, fighter)
	sim.remove_item(target)
	var unit := sim.spawn(fighter.def, tile, fighter.team)
	if unit == null:
		return
	unit.health = NEW_LIFE
	unit.converted = true
	unit.incapacitated = true
	sim.poison(unit, fighter.attack / 2, 0, 0, fighter)
	sim.after(APPEAR_FRAMES, func() -> void:
		if not unit.dead:
			unit.incapacitated = unit.frozen or unit.stunned or unit.in_air)


func _whirl(sim: BattleSim, fighter: BattleFighter) -> void:
	var units := enemy_units_near(sim, fighter, fighter.tile, fighter.attack_range, 1)
	if units.is_empty():
		return
	sim.receive_attack(units[0], fighter.attack, fighter)
	sim.push_in_air(units[0], fighter, 4)
