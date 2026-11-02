class_name UnitDamage
extends RefCounted
## What a special attack does to each target (AbstractDamage of the client).
## A damage belongs to the attacker. apply() acts on one target; multiplier
## scales the amount, and a shared damage divides the amount by num_targets.
## finished is emitted when the damage on a target is over, so that a
## SequencedDamage can start the next one. The subclasses are in Damages.

signal finished(target: BattleFighter, multiplier: float)

var sim: BattleSim
var attacker: BattleFighter
var num_targets := 1
var shared := false
var filter := Callable()  ## (target) -> bool, or an invalid Callable.
var on_dead := Callable()  ## (target) runs when the damage kills target.


func _init(battle: BattleSim, from: BattleFighter) -> void:
	sim = battle
	attacker = from


func apply(_target: BattleFighter, _multiplier := 1.0) -> void:
	pass


func can_apply(target: BattleFighter) -> bool:
	return target != null and not target.dead and (not filter.is_valid() or filter.call(target))


func with_shared(value: bool) -> UnitDamage:
	shared = value
	return self


func with_filter(function: Callable) -> UnitDamage:
	filter = function
	return self


## The points of amount for one target.
func _part(amount: float, multiplier: float) -> int:
	return int(amount * multiplier / maxi(num_targets, 1))


func _finish(target: BattleFighter, multiplier: float) -> void:
	finished.emit(target, multiplier)


## The attacker when it is still in the battle, else null, for receive_attack().
func _source() -> BattleFighter:
	return attacker if attacker in sim.fighters else null
