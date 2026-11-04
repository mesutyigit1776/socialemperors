class_name MonsterUnitsAbility
extends BattleAbility
## Monsters whose delegates of the client change the normal attack. Their
## buttons are in special_units/heroes.gd.
##
## - mother_monster (MotherMonsterDelegate): a purple ball 18 frames after the
##   attack; attack 5 of each 5 (special attack 1) fires 6 balls, at frames 25
##   to 55. A ball that hits a unit poisons it (25 points, 5 times). The
##   client draws these balls 1.6 times bigger; the port does not.
## - mother_minion (MotherMonsterMinionDelegate): a hit. It starts small; after
##   each 4 attacks it grows one step, to the scales 0.7, 0.85 and 1, with an
##   attack of 45, 55 and 65. After the first step, attack 4 of each 4 (special
##   attack 1, frame 25) eats a target unit with at most 500 life: the unit
##   cannot act and dies at the end of the animation.
## - punky_draggy (PunkyDraggyDelegate): a fireball 10 frames after the
##   attack. With each attack, one time in five, also 10 fire meteors fall
##   near the target (special attack 1 for 2 seconds).
## - invisible_killer (InvisibleKillerDelegate): a hit; attack 5 of each 6 is
##   a whirlwind (special attack 1) for 6 seconds: at frames 12 and 18 of each
##   loop of the animation the 5 nearest enemy units within 4 tiles take half
##   the attack and fly 4 tiles. It does not attack meanwhile.

const UNITS := {
	2127: "mother_monster",
	2128: "mother_minion",
	769: "punky_draggy",
	2067: "invisible_killer",
}
const SP1 := UnitSprite.Action.SPECIAL
const MOTHER_BALL_DELAY := 18
const MOTHER_BALL_FRAMES: Array[int] = [25, 31, 37, 43, 49, 55]
const MOTHER_POISON := 25
const MOTHER_POISON_TICKS := 5
const MINION_START_SCALE := 0.6
const MINION_SCALES: Array[float] = [0.7, 0.85, 1.0]
const MINION_ATTACKS: Array[int] = [45, 55, 65]
const MINION_FREQ := 4
const SMALL_LIFE := 500
const PUNKY_SPECIAL_FRAMES := 60  ## 2 seconds.
const WHIRLWIND_FRAMES := 180  ## 6 seconds.

var _kind := ""
var _count := 1
var _step := 0


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["mother_minion", "invisible_killer"]
	match _kind:
		"mother_minion":
			scale = MINION_START_SCALE
		"punky_draggy":
			shot_graphic = "p.fireBall"
			shot_delay = 10
		"invisible_killer":
			_count = 0


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	match _kind:
		"mother_monster":
			if fighter.forced_action >= 0:
				return false
			if _count == 5:
				var events := {}
				for frame in MOTHER_BALL_FRAMES:
					events[frame] = func() -> void: _mother_ball(sim, fighter)
				play(sim, fighter, SP1, 60, events, Callable(), true)
			else:
				sim.after(MOTHER_BALL_DELAY, func() -> void:
					if fighter.animation == BattleFighter.Pose.ATTACKING:
						_mother_ball(sim, fighter))
			_count = _count % 5 + 1
			return false
		"mother_minion":
			if fighter.forced_action >= 0:
				return false
			if _count == MINION_FREQ and _step > 0:
				var prey := [null]
				play(sim, fighter, SP1, 40, {25: func() -> void:
					var food := fighter.target
					if not fighter.dead and _edible(fighter, food):
						prey[0] = food
						food.incapacitated = true
						food.swallowed = true
						sim.state_changed.emit(food)}, func() -> void:
					var food: BattleFighter = prey[0]
					if food != null and not food.dead:
						sim.kill(food, fighter), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count += 1
			if _count > MINION_FREQ:
				_count = 1
				_grow(sim, fighter)
			return false
		"punky_draggy":
			if sim.rng.randf() * 10 > 8:
				sim.play_special(fighter, SP1, PUNKY_SPECIAL_FRAMES)
				arrow_storm(sim, fighter, MagicParticles.FIRE_METEOR, 10)
			return true
		"invisible_killer":
			if fighter.forced_action >= 0:
				return false
			if _count == 5:
				var loop := maxi(sim.animation_frames(fighter, SP1, 20), 19)
				var events := {}
				var start := 0
				while start < WHIRLWIND_FRAMES:
					for frame in [12, 18]:
						events[start + frame] = func() -> void:
							for enemy in sim.items_near(fighter.tile, 4, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
									return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
								sim.receive_attack(enemy, fighter.attack / 2, fighter)
								if not enemy.dead:
									sim.push_in_air(enemy, fighter, 4)
					start += loop
				sim.play_special(fighter, SP1, WHIRLWIND_FRAMES, events)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			_count = _count + 1 if _count < 5 else 0
			return false
	return true


static func _mother_ball(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if fighter.dead or target == null or target.dead:
		return
	sim.shoot(fighter, target, "p.necroSpit", fighter.attack, func(_shot: BattleProjectile) -> void:
		if target.is_unit() and not target.dead:
			sim.poison(target, MOTHER_POISON, MOTHER_POISON_TICKS, 0, fighter if fighter in sim.fighters else null))


static func _edible(fighter: BattleFighter, unit: BattleFighter) -> bool:
	return unit != null and unit.is_unit() and unit.team != fighter.team and not unit.dead and not unit.incapacitated \
			and unit.def.life <= SMALL_LIFE and unit.def.subcat_functional != BattleSim.SUBCAT_BOSS


## Mother Monster minion: one growth step, while it is smaller than scale 1.
func _grow(sim: BattleSim, fighter: BattleFighter) -> void:
	if scale >= 1.0 or fighter.dead or _step >= MINION_SCALES.size():
		return
	scale = MINION_SCALES[_step]
	fighter.attack = MINION_ATTACKS[_step]
	_step += 1
	sim.particle(fighter, fighter.tile, MagicParticles.STARS, 0, 0)
	sim.state_changed.emit(fighter)
