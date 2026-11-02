class_name InfernalDragonAbility
extends BattleAbility
## The Infernal Dragon (InfernalDragonDelegate of the client).
##
## - Next to its target it hits with its tail (special attack 1): a whirlwind
##   at frame 15, see BattleSim.whirlwind().
## - Farther away in its range, in half of the attacks it rains meteors
##   (special attack 2): at frame 18, 10 meteors fall within 2 tiles of the
##   target with its attack. The other attacks breathe huge fire 13 frames later.
## - Out of range it walks to the target. When it walks, the attack stops.
##
## Its limit attack (lightning beams) starts only from the button of the
## player, see roadmap step 3.2.

const FIRE := "p.hugeFire"

var _in_special := false


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if _in_special:
		return false
	var distance := sim.distance(fighter, fighter.target)
	var roll := sim.rng.randf()
	var done := func() -> void: _in_special = false
	if distance <= 1:
		_in_special = true
		play(sim, fighter, UnitSprite.Action.SPECIAL, 30, {15: func() -> void: sim.whirlwind(fighter)}, done)
	elif distance <= fighter.attack_range:
		_in_special = true
		if roll > 0.5:
			play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, {18: func() -> void: arrow_storm(sim, fighter, MagicParticles.FIRE_METEOR, 10, 2, 1.0, 0)}, done)
		else:
			var target := fighter.target
			play(sim, fighter, UnitSprite.Action.ATTACKING, 20, {}, done)
			sim.after(13, func() -> void:
				if not fighter.dead and fighter.target == target and not target.dead:
					sim.shoot(fighter, target, FIRE, fighter.attack))
	else:
		sim.walk(fighter, fighter.target.tile)
	return false


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if _in_special and fighter.moving:
		_in_special = false
		sim.stop_special(fighter)
