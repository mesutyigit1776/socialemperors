class_name DualDragonAbility
extends BattleAbility
## The two-head dragons (DualGodsDragonDelegate, FrostFireDragonDelegate,
## DoubleHeadDragonDelegate and DoubleHeadDragon2Delegate of the client).
## Their attacks turn: the first beam, the second beam, then both beams, each
## in its own special animation. Each beam leaves after the shot delay and
## hurts with the attack when it ends. A beam goes to another unit near the
## dragon than the last chosen one when there is one. When the dragon walks,
## the attack stops. Some beams also act on the target when they start: they
## set it on fire, freeze it or hold it with electricity (10 damage each
## time, 5 times).
##
## Its limit attack starts only from the button of the player, see
## special_units/.

const FIRE_BEAM := "p.fireBeam"
const FREEZE_BEAM := "p.freezeBeam"
const FREEZE := 1
const FIRE := 2
const BOTH := 3
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SP3 := SP1 + 2
## Item id -> [the beam of attack 2, the beam of attack 1, the animations of
## attack 2, 1 and both, the effect of each beam ("burn", "freeze", "shock" or
## ""), the frames between the effect ticks, the frames of a beam].
const KINDS := {
	2043: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP3, SP1], ["", ""], 21, 21],  # 2-Head Holydeath Dragon
	2045: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP3, SP1], ["", ""], 21, 21],
	2023: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP3, SP1], ["burn", "freeze"], 21, 21],  # 2-Head Frostfire Dragon
	2026: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP3, SP1], ["burn", "freeze"], 21, 21],
	714: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP1, SP3], ["burn", "freeze"], 30, 30],  # DoubleHeadDragonDelegate
	836: [FIRE_BEAM, FREEZE_BEAM, [SP2, SP1, SP3], ["burn", "freeze"], 30, 30],
	736: ["p.lightBeam", "p.electricityBeam", [SP2, SP1, SP3], ["shock", "shock"], 30, 30],  # DoubleHeadDragon2Delegate
	838: ["p.lightBeam", "p.electricityBeam", [SP2, SP1, SP3], ["shock", "shock"], 30, 30],
}
const EFFECT_TICKS := 5
const EFFECT_DAMAGE := 10

var _next := 2
var _current := 0
var _selected: BattleFighter
var _attack_id := 0
var _beams := 0
var _kind: Array = KINDS[2043]
var _effects := false


func configure(item_id: int) -> void:
	_kind = KINDS.get(item_id, KINDS[2043])
	_effects = _kind[3][0] != ""
	beam_frames = _kind[5]


func _init() -> void:
	shot_delay = 13
	shot_graphic = FIRE_BEAM
	beam = true
	beam_frames = 21


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _current != 0:
		return false
	_next = _next % 3 + 1
	_current = _next
	_attack_id += 1
	var id := _attack_id
	var action: int = _kind[2][{FIRE: 0, FREEZE: 1, BOTH: 2}[_current]]
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
			_fire(sim, fighter, 0, id)
			_fire(sim, fighter, 1, id)
		else:
			_fire(sim, fighter, 0 if _current == FIRE else 1, id))
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if fighter.moving:
		_selected = null
		if _current != 0:
			_reset(sim, fighter)


## Fires beam 0 (the beam of attack 2) or beam 1.
func _fire(sim: BattleSim, fighter: BattleFighter, which: int, id: int) -> void:
	sim.sound_played.emit(SoundEffect.MAGIC_FIRE, -1)
	var target := _different_target(sim, fighter)
	if target == null:
		return
	_beams += 1
	if target.is_unit():
		match _kind[3][which]:
			"burn":
				sim.incinerate(target, fighter, EFFECT_DAMAGE, EFFECT_TICKS, _kind[4])
			"freeze":
				sim.freeze_with_damage(target, fighter, EFFECT_DAMAGE, EFFECT_TICKS, _kind[4])
			"shock":
				sim.electrocute(target, fighter, EFFECT_DAMAGE, EFFECT_TICKS, _kind[4])
	sim.shoot_beam(fighter, target, target.tile, _kind[which], beam_frames, fighter.attack, func(_shot: BattleProjectile) -> void:
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
