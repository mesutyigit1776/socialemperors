class_name MedusaAbility
extends BattleAbility
## Medusa (MedusaDelegate of the client).
##
## - Next to its target, in 40 of 100 attacks it hits with its tail (special
##   attack 3): a whirlwind at frame 16. The other attacks hit at once.
## - Farther away in its range, in half of the attacks it turns its target to
##   stone (special attack 1): a stone beam after 11 frames holds the target
##   for 3 seconds. A target that is stone already gets the other attack: a
##   snake (special attack 2) after 16 frames, then 700 ms in the attack.
## - Out of range it walks to the target. When it walks, the attack stops.

const STONE_BEAM := "p.medusaStoneBeam"
const SNAKE := "p.snake"
const STONE_FRAMES := 90

## Units that a Medusa turned to stone, for all Medusas, as in the client.
static var _stoned := {}

var _in_special := false
var _attack_id := 0


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	_attack_id += 1
	var id := _attack_id
	var target := fighter.target
	var distance := sim.distance(fighter, target)
	var roll := sim.rng.randf()
	var done := func() -> void: if id == _attack_id: _in_special = false
	if distance <= 1:
		if roll > 0.6:
			_in_special = true
			play(sim, fighter, UnitSprite.Action.SPECIAL + 2, 30, {16: func() -> void: sim.whirlwind(fighter)}, done)
		else:
			sim.receive_attack(target, fighter.attack, fighter)
	elif distance <= fighter.attack_range:
		_in_special = true
		if roll < 0.5 and not _stoned.has(target):
			play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {}, done)
			sim.after(11, func() -> void:
				if id != _attack_id or fighter.dead or target.dead:
					return
				_turn_to_stone(sim, target)
				sim.shoot(fighter, target, STONE_BEAM, fighter.attack))
		else:
			sim.play_special(fighter, UnitSprite.Action.SPECIAL + 1, 21, {}, done)
			sim.after(16, func() -> void:
				if id == _attack_id and not fighter.dead and not target.dead:
					sim.shoot(fighter, target, SNAKE, fighter.attack))
	else:
		sim.walk(fighter, target.tile)
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_attack_id += 1
		_in_special = false
		sim.stop_special(fighter)


static func _turn_to_stone(sim: BattleSim, target: BattleFighter) -> void:
	if not target.is_unit() or _stoned.has(target):
		return
	_stoned[target] = true
	target.incapacitated = true
	target.walk_point = null
	target.path.clear()
	target.moving = false
	sim.after(STONE_FRAMES, func() -> void:
		_stoned.erase(target)
		target.incapacitated = target.frozen or target.stunned or target.in_air or target.electrocuted)
