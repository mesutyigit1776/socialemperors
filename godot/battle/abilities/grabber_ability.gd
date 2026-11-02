class_name GrabberAbility
extends BattleAbility
## The Harpy and Hercules (HarpyDelegate and HerculesDelegate of the client),
## ranged units that hit like melee units and grab weak enemies.
##
## - Harpy: at 3 tiles or more from its target it throws a fireball at frame 9
##   of its fireball animation (special attack 1). Nearer, every eighth attack
##   grabs the best enemy unit within its range - 1 with MAX_LIFE_TO_EAT life
##   or less (special attack 2): both cannot act, and the unit dies at frame 67.
## - Hercules: every tenth attack grabs such a unit within its range (special
##   attack 1), which dies at the end of the animation. Every tenth attack + 5
##   is a smash (special attack 2): at frame 20 up to 10 enemies within 4
##   tiles, not on his tile, take 1.5 times his attack, and units fly 4 tiles away.

const HARPY := 780
const MAX_LIFE_TO_EAT := 350
const FIREBALL := "p.fireBall"

var _harpy := false
var _attacks := 0


func configure(item_id: int) -> void:
	_harpy = item_id == HARPY
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	_attacks += 1
	var distance := sim.distance(fighter, fighter.target)
	if _harpy:
		if distance >= 3:
			play(sim, fighter, UnitSprite.Action.SPECIAL, 20, {9: func() -> void:
				if fighter.target != null and not fighter.target.dead:
					sim.shoot(fighter, fighter.target, FIREBALL, fighter.attack)})
			return false
		if _attacks % 8 == 0:
			return not _grab(sim, fighter, fighter.attack_range - 1, UnitSprite.Action.SPECIAL + 1, 67)
		return true
	if _attacks % 10 == 0:
		return not _grab(sim, fighter, fighter.attack_range, UnitSprite.Action.SPECIAL, -1)
	if _attacks % 10 == 5:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 30, {20: func() -> void:
			for enemy in enemies_near(sim, fighter, fighter.tile, 4, 10, false):
				sim.receive_attack(enemy, int(fighter.attack * 1.5), fighter)
				if enemy.is_unit():
					sim.push_in_air(enemy, fighter, 4)})
		return false
	return true


## Grabs the best eatable enemy unit within range tiles. It dies at frame
## end_frame of the animation, or at its last frame when end_frame is -1.
func _grab(sim: BattleSim, fighter: BattleFighter, range_tiles: int, action: int, end_frame: int) -> bool:
	var prey := sim.nearest_target(fighter, fighter.tile, range_tiles, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS, false)
	if prey == null:
		return false
	prey.incapacitated = true
	var frames := sim.animation_frames(fighter, action, 70)
	var eat := func() -> void:
		if not prey.dead:
			prey.incapacitated = false
			sim.kill(prey, fighter)
	sim.play_special(fighter, action, frames, {end_frame if end_frame > 0 else frames: eat}, Callable(), true)
	return true
