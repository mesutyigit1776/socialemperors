class_name TitanLythosAbility
extends BattleAbility
## Titan Lythos (TitanLythosDelegate of the client), a ranged unit that hits
## like a melee unit and shoots boulders. At each attack it takes a random
## number from 0 to 9:
## 1. Stone rain (special attack 1): at frame 20, 25 falling boulders within 3
##    tiles of the target, each with 10 times its attack.
## 2. Whirlwind (special attack 2): every second, 4 times, the enemy units
##    within 2 tiles fly 3 tiles away and take its attack / 2.2.
## 3. Minions (special attack 3): at frame 42, 3 minions come 2 tiles beside it
##    for 5 seconds, when it has none. The client puts them on the side of the
##    player, also when the titan is an enemy; the port does the same. They
##    are drawn at 0.3 of their size.
## Other numbers: a normal attack.

const MINION := 763  ## ID_UNIT_TITAN_LITHOS_MINION
const MINIONS := 3
const MINION_LIFE_FRAMES := 150  ## 5 seconds.
const MINION_SCALE := 0.3

var _doing_attack := false
var _minions: Array[BattleFighter] = []


func _init() -> void:
	ranged_melee = true
	shot_graphic = "p.boulder"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _doing_attack:
		return true
	match roundi(sim.rng.randf() * 9):
		1:
			_doing_attack = true
			play(sim, fighter, UnitSprite.Action.SPECIAL, 40, {20: func() -> void:
				arrow_storm(sim, fighter, MagicParticles.FALLING_BOULDER, 25, 3, 10, 20, 3)
				_doing_attack = false})
			return false
		2:
			_doing_attack = true
			sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, 4 * BattleSim.FRAMES_PER_SECOND, {}, func() -> void: _doing_attack = false)
			for i in 4:
				sim.after((i + 1) * BattleSim.FRAMES_PER_SECOND, func() -> void: _whirlwind(sim, fighter))
			return false
		3:
			_doing_attack = true
			play(sim, fighter, UnitSprite.Action.SPECIAL + 2, 50, {42: func() -> void: _spawn_minions(sim, fighter)})
			return false
	return true


func _whirlwind(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.dead:
		return
	for unit in enemy_units_near(sim, fighter, fighter.tile, 2, 20):
		sim.push_in_air(unit, fighter, 3)
		sim.receive_attack(unit, int(fighter.attack / 2.2), fighter)


func _spawn_minions(sim: BattleSim, fighter: BattleFighter) -> void:
	_doing_attack = false
	_minions = _minions.filter(func(unit: BattleFighter) -> bool: return not unit.dead)
	if not _minions.is_empty():
		return
	var side := -2 if direction(fighter) > 6 else 2
	for i in MINIONS:
		var unit := sim.spawn(sim.config_item(MINION), fighter.tile + Vector2i(side, 0), BattleFighter.Team.PLAYER)
		if unit == null:
			continue
		unit.draw_scale = MINION_SCALE
		if fighter.target != null and fighter.target.team != unit.team:
			sim.set_target(unit, fighter.target)
		_minions.append(unit)
	var minions := _minions.duplicate()
	sim.after(MINION_LIFE_FRAMES, func() -> void:
		for unit: BattleFighter in minions:
			if not unit.dead:
				sim.remove_item(unit)
		_minions.clear())
