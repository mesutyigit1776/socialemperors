class_name DeadlyDragonAbility
extends BattleAbility
## The Deadly Dragon Boss of the second dragon island (DeadlyDragonBossDelegate
## of the client).
##
## - Attacks do not hurt it. Only the quest hurts it (hurt()), when an egg is
##   destroyed, and kills it (kill()). The client lets the next attack through
##   after such a wound; the quest uses it at once.
## - It shoots a red beam. In its special attack it throws an egg 4 to 7
##   tiles in front of it, from which a summoned Black Draggy comes, while it
##   has fewer than MAX_DRAGGIES of them alive. The draggy attacks the target
##   of the dragon.
## - When an egg is attacked, the dragon attacks the attacker, and keeps this
##   target for TARGET_FRAMES before a new attack on an egg changes it.
## - No effect of spells or abilities acts on it.
## - The second dragon island draws it at twice its size (QuestBossDragon2);
##   no other battle has it.

const BEAM := "p.electricityRedBeam"
const BLACK_DRAGGY := 725
const MAX_DRAGGIES := 3
const TARGET_FRAMES := 600  ## 20 seconds.

var _invulnerable := true
var _target_assigned := false
var _draggies := 0


func _init() -> void:
	special_intervals = [35]
	special_durations = [16]
	scale = 2.0
	shot_delay = 12
	shot_graphic = BEAM
	immune_to_push = true
	immune_to_freeze = true
	immune_to_poison = true
	immune_to_swallow = true
	immune_to_conversion = true
	immune_to_stun = true
	immune_to_burn = true
	immune_to_electricity = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0) and _draggies < MAX_DRAGGIES:
		_throw_egg(sim, fighter)
		return false
	return true


func on_attacked(_sim: BattleSim, _fighter: BattleFighter, _amount: int, _attacker: BattleFighter) -> bool:
	if not _invulnerable:
		_invulnerable = true
		return true
	return false


func egg_attacked(sim: BattleSim, fighter: BattleFighter, attacker: BattleFighter) -> void:
	if _target_assigned or fighter.dead:
		return
	_target_assigned = true
	sim.attack(fighter, attacker)
	sim.after(TARGET_FRAMES, func() -> void: _target_assigned = false)


## The quest wounds the dragon by amount (an attack of the dragon on itself).
func hurt(sim: BattleSim, fighter: BattleFighter, amount: int) -> void:
	_invulnerable = false
	sim.receive_attack(fighter, amount, fighter)


func kill(sim: BattleSim, fighter: BattleFighter) -> void:
	_invulnerable = false
	sim.kill(fighter)


func _throw_egg(sim: BattleSim, fighter: BattleFighter) -> void:
	throw_egg(sim, fighter, BLACK_DRAGGY, func(draggy: BattleFighter) -> void:
		_draggies += 1
		sim.died.connect(func(item: BattleFighter, _killer: BattleFighter) -> void:
			if item == draggy:
				_draggies -= 1)
		if fighter.target != null and not fighter.target.dead:
			sim.attack(draggy, fighter.target))
