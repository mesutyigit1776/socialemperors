class_name MonkAbility
extends BattleAbility
## The Monk (ClericMonkDelegate of the client). In its special attack it
## converts its target, an enemy unit, to its own side: at most
## CONVERSION_LIMIT units in a battle, and then not again for COOLDOWN_FRAMES.
## Bosses, their helpers, eagles, units with CONVERSION_MAX_LIFE or more life,
## and units whose ability protects them cannot be converted: the monk drops
## such a target. See BattleSim.convert().

const CONVERSION_LIMIT := 4  ## MONK_CONVERSION_LIMIT of the client.
const COOLDOWN_FRAMES := 720  ## The conversion particle of the client.
const CONVERSION_MAX_LIFE := 500
const NOT_CONVERTED_SUBCATS: Array[int] = [84, 85, 86]

var _converted := 0
var _cooling := false


func _init() -> void:
	special_intervals = [0]
	special_durations = [60]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if in_special(fighter, 0) and not _cooling and _converted < CONVERSION_LIMIT and target != null and target.is_unit():
		if target.def.subcat_functional in NOT_CONVERTED_SUBCATS or target.def.life >= CONVERSION_MAX_LIFE or (target.ability != null and target.ability.immune_to_conversion):
			sim.set_target(fighter, null)
		elif target.team != fighter.team:
			_converted += 1
			_cooling = true
			sim.particle(fighter, fighter.tile, MagicParticles.CONVERSION, 0, 0)
			sim.after(COOLDOWN_FRAMES, func() -> void: _cooling = false)
			sim.convert(target, fighter.team)
	return fighter.animation == BattleFighter.Pose.ATTACKING
