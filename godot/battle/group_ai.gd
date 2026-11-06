class_name GroupAI
extends RefCounted
## The AI of a group of units (AbstractCollectiveAI of the client). The AI of
## each unit of the group calls it: update() every BattleAI.UPDATE_INTERVAL
## frames, before the unit looks for targets itself (when update() returns
## false, it does not), and the hooks when the unit arrives, is attacked or
## kills its target. See CollectiveAI and TournamentAI.


func update(_sim: BattleSim, _unit: BattleFighter) -> bool:
	return true


## A unit of the group killed its target.
func on_target_dead(_sim: BattleSim, _unit: BattleFighter, _target: BattleFighter) -> void:
	pass


## A unit of the group reached the end of its walk.
func on_arrived(_sim: BattleSim, _unit: BattleFighter) -> void:
	pass


## attacker hit a unit of the group.
func on_attacked(_sim: BattleSim, _unit: BattleFighter, _attacker: BattleFighter) -> void:
	pass
