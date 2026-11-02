class_name TRexAbility
extends BattleAbility
## The Fire T-Rex (FireTRexDelegate of the client), a ranged unit that hits
## like a melee unit. Its cycle has three special attacks; the T-Rex
## (TRexDelegate) has only the second and the third:
## 1. It sets its target on fire: its attack every 800 ms, 5 times. It does
##    not attack until frame 45 of the animation.
## 2. It eats the best enemy within 4 tiles, a unit with 350 life or less: the
##    unit cannot act and dies at frame 69.
## 3. It turns its tail once around, 1/16 of a turn in each frame: the items
##    of the other side on the tiles of the tail (3 tiles from its tile) take
##    its attack, and units fly 2 to 4 tiles away.

const MAX_LIFE_TO_EAT := 350
const MOUTH_DISTANCE := 4
const TAIL_LENGTH := 3
const BURN_END_FRAME := 45
const EAT_END_FRAME := 69
const TURN_FRAMES := 16
const TREX := 713

## The special attacks of the cycle, in order.
var _specials: Array[String] = ["burn", "eat", "tail"]
var _burning := false
var _eating := false
var _turning := false


func _init() -> void:
	special_intervals = [105, 105, 105]
	special_durations = [45, 70, 39]
	ranged_melee = true


func configure(item_id: int) -> void:
	if item_id == TREX:
		_specials = ["eat", "tail"]
		special_intervals = [105, 105]
		special_durations = [70, 38]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var special := _special(fighter)
	if special == "burn" and not _burning:
		_burning = true
		if fighter.target.is_unit():
			sim.incinerate(fighter.target, fighter, fighter.attack, 5, 24)
		sim.after(BURN_END_FRAME, func() -> void: _burning = false)
	elif special == "eat" and not _eating:
		var prey := sim.nearest_enemy(fighter, fighter.tile, MOUTH_DISTANCE)
		if prey != null and prey.is_unit() and prey.def.life <= MAX_LIFE_TO_EAT and prey.def.subcat_functional != BattleSim.SUBCAT_BOSS:
			_eating = true
			prey.incapacitated = true
			sim.after(EAT_END_FRAME, func() -> void:
				_eating = false
				if not prey.dead:
					prey.incapacitated = false
					sim.kill(prey, fighter))
	elif special == "tail" and not _turning:
		_turning = true
		var start := Vector2(DIRECTION_STEPS[direction(fighter)]).angle()
		for step in range(1, TURN_FRAMES + 2):
			sim.after(step, func() -> void: _tail(sim, fighter, start + step * PI / 8, step == TURN_FRAMES + 1))
	return not (_burning or _eating or _turning)


func _special(fighter: BattleFighter) -> String:
	for i in _specials.size():
		if in_special(fighter, i):
			return _specials[i]
	return ""


func _tail(sim: BattleSim, fighter: BattleFighter, angle: float, last: bool) -> void:
	if last:
		_turning = false
	if fighter.dead:
		return
	for k in TAIL_LENGTH:
		var tile := fighter.tile + Vector2i(int(cos(angle) * k), int(sin(angle) * k))
		for target in sim.items_near(tile, 0, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
			sim.receive_attack(target, fighter.attack, fighter)
			if target.is_unit() and not target.incapacitated:
				sim.push_in_air(target, fighter, sim.rng.randi_range(2, 4))
