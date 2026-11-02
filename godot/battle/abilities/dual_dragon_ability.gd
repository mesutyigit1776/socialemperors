class_name DualDragonAbility
extends BattleAbility
## The 2-Head Holydeath Dragon and the 2-Head Frostfire Dragon
## (DualGodsDragonDelegate and FrostFireDragonDelegate of the client). Their
## attacks turn: a fire beam (special attack 2), a freeze beam (special attack
## 3), then both beams (special attack 1). Each beam leaves after the shot
## delay and hurts with its attack when it ends, after 0.7 seconds. A beam goes
## to another unit near the dragon than the last chosen one when there is one.
## When the dragon walks, the attack stops. The beams of the Frostfire Dragon
## also set the target on fire (10 damage every 700 ms, 5 times) or freeze it
## (5 times 700 ms, 10 damage each time) when they start.
##
## Its limit attack (lightning beams) starts only from the button of the
## player, see roadmap step 3.2.

const FIRE_BEAM := "p.fireBeam"
const FREEZE_BEAM := "p.freezeBeam"
const BEAM_FRAMES := 21
const FREEZE := 1
const FIRE := 2
const BOTH := 3
const FROSTFIRE := 2023
const EFFECT_TICKS := 5
const EFFECT_DAMAGE := 10
const EFFECT_INTERVAL := 21  ## 700 ms.

var _next := 2
var _current := 0
var _selected: BattleFighter
var _attack_id := 0
var _beams := 0
var _effects := false


func configure(item_id: int) -> void:
	_effects = item_id == FROSTFIRE


func _init() -> void:
	shot_delay = 13
	shot_graphic = FIRE_BEAM
	beam = true
	beam_frames = BEAM_FRAMES


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _current != 0:
		return false
	_next = _next % 3 + 1
	_current = _next
	_attack_id += 1
	var id := _attack_id
	var action := {FIRE: UnitSprite.Action.SPECIAL + 1, FREEZE: UnitSprite.Action.SPECIAL + 2, BOTH: UnitSprite.Action.SPECIAL}[_current] as int
	sim.play_special(fighter, action, 1 << 20)
	sim.after(shot_delay, func() -> void:
		if id != _attack_id:
			return
		if fighter.dead or (fighter.target == null and not _effects):
			_reset(sim, fighter)
			return
		if fighter.target == null:
			_current = 0
			return
		if _current == BOTH:
			_fire(sim, fighter, FIRE_BEAM, id)
			_fire(sim, fighter, FREEZE_BEAM, id)
		else:
			_fire(sim, fighter, FIRE_BEAM if _current == FIRE else FREEZE_BEAM, id))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.moving:
		_selected = null
		if _current != 0:
			_reset(sim, fighter)


func _fire(sim: BattleSim, fighter: BattleFighter, graphic: String, id: int) -> void:
	var target := _different_target(sim, fighter)
	if target == null:
		return
	_beams += 1
	if _effects and target.is_unit():
		if graphic == FIRE_BEAM:
			sim.incinerate(target, fighter, EFFECT_DAMAGE, EFFECT_TICKS, EFFECT_INTERVAL)
		else:
			sim.freeze_with_damage(target, fighter, EFFECT_DAMAGE, EFFECT_TICKS, EFFECT_INTERVAL)
	sim.shoot(fighter, target, graphic, fighter.attack, func(_shot: BattleProjectile) -> void:
		_beams -= 1
		if id == _attack_id and _beams <= 0:
			_reset(sim, fighter))


func _reset(sim: BattleSim, fighter: BattleFighter) -> void:
	_attack_id += 1
	_current = 0
	_beams = 0
	sim.stop_special(fighter)


## The client keeps the first target, then looks for another unit near the
## dragon than its target and the last chosen one; without one, the beam goes
## to the target.
func _different_target(sim: BattleSim, fighter: BattleFighter) -> BattleFighter:
	if _selected == null or not fighter.target.is_unit():
		_selected = fighter.target
		return fighter.target
	for unit in sim.items_near(fighter.tile, fighter.attack_range, 2, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead and not item.incapacitated):
		if unit != fighter.target and unit != _selected:
			return unit
	return fighter.target
