class_name KongAbility
extends BattleAbility
## King Kong (KongDelegate of the client). From its first attack, a counter
## runs in each frame while it has a target; every SPECIAL_INTERVAL frames it
## stops (it cannot act) for a special attack, by turns:
## - It grabs two enemy units within its range - 1 with 350 life or less, when
##   there are two (special attack 3); they die at frame 104.
## - It heals itself by HEALTH_BOOST (special attack 2) until frame 75.
## Between them, next to its target it hits with 1.5 times its attack, and
## farther away it throws bananas.

const BANANA := "p.banana"
const SPECIAL_INTERVAL := 105
const MAX_LIFE_TO_EAT := 350
const HEALTH_BOOST := 100

var _counter := -SPECIAL_INTERVAL
var _ticking := false
var _special := 0


func _init() -> void:
	shot_graphic = BANANA
	shot_delay = 10


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	_ticking = true
	if _counter >= 0:
		return false
	var distance := sim.distance(fighter, fighter.target)
	if distance <= 2:
		sim.receive_attack(fighter.target, int(fighter.attack * 1.5), fighter)
		return false
	return distance <= fighter.attack_range


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if not _ticking:
		return
	if fighter.target == null:
		_ticking = false
		return
	_counter += 1
	if _counter != 0:
		return
	var which := _special % 2
	_special += 1
	if which == 0:
		var eaten := sim.items_near(fighter.tile, fighter.attack_range - 1, 2, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS)
		if eaten.size() < 2:
			_counter = -SPECIAL_INTERVAL
			return
		for unit in eaten:
			unit.incapacitated = true
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 2, 104, {104: func() -> void:
			for unit in eaten:
				if not unit.dead:
					unit.incapacitated = false
					sim.kill(unit, fighter)}, func() -> void: _counter = -SPECIAL_INTERVAL, true)
	else:
		sim.heal(fighter, HEALTH_BOOST, fighter)
		sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, 75, {}, func() -> void: _counter = -SPECIAL_INTERVAL, true)
