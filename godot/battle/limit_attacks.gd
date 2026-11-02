class_name LimitAttacks
extends RefCounted
## The limit attacks of LimitDelegate of the client, which the player starts
## with the limit button (BattleAbility.LIMIT_BUTTON) when the limit bar is
## full. The unit cannot walk or attack while one plays.
##
## - Lightning beams: at the shoot frames of the animation, count beams, one
##   every interval_ms, at_once at a time. Each beam goes to a random enemy
##   unit within the attack range of the unit (or to a random tile in the
##   range when there is none) and takes a fifth of the attack of the unit.
## - Healing beams: the same with own wounded units in the range, at most
##   count + 1; each healed unit gets 0.6 of the attack of the unit.
## - Smash: at the attack frames, a whirlwind around the unit (BattleSim.whirlwind()).
## - Special: an action of the unit at the attack frames.

## The settings of a beam attack (initLightingBeamsAttack and initHealingBeamsAttack).
class Beams:
	var action: int  ## UnitSprite.Action of the animation.
	var shoot_frames: Array[int] = []
	var interval_ms := 100.0
	var count := 1
	var graphic := ""
	var seconds := 0.25  ## How long one beam lasts.
	## The client stops the animation while the beams go, then plays the rest.
	var stop_animation := false
	var at_once := 1

	func _init(beam_action: int, frames: Array[int], interval: float, beams: int, beam_graphic: String, beam_seconds: float, stop: bool, together := 1) -> void:
		action = beam_action
		shoot_frames = frames
		interval_ms = interval
		count = beams
		graphic = beam_graphic
		seconds = beam_seconds
		stop_animation = stop
		at_once = together


const FALLBACK_FRAMES := 40


static func lightning_beams(sim: BattleSim, fighter: BattleFighter, beams: Beams) -> void:
	_beams(sim, fighter, beams, false)


static func healing_beams(sim: BattleSim, fighter: BattleFighter, beams: Beams) -> void:
	_beams(sim, fighter, beams, true)


## The smash attack (initSmashAttack): at frames, a whirlwind with multiplier
## times the attack within range tiles that pushes units push tiles away.
static func smash(sim: BattleSim, fighter: BattleFighter, action: int, frames: Array[int], multiplier: float, range_tiles: int, push: int) -> void:
	var events := {}
	for frame in frames:
		events[frame] = func() -> void:
			if not fighter.dead:
				sim.whirlwind(fighter, multiplier, push, range_tiles)
	_play(sim, fighter, action, 0, events)


## A special limit attack (initSpecialUnitAttack): attack runs at frames, or at
## once when there are none.
static func special(sim: BattleSim, fighter: BattleFighter, action: int, frames: Array[int], attack: Callable) -> void:
	if frames.is_empty() or frames == [0]:
		_play(sim, fighter, action, 0, {})
		attack.call()
		return
	var events := {}
	for frame in frames:
		events[frame] = attack
	_play(sim, fighter, action, 0, events)


static func _beams(sim: BattleSim, fighter: BattleFighter, beams: Beams, healing: bool) -> void:
	var interval := maxi(roundi(beams.interval_ms / 1000.0 * BattleSim.FRAMES_PER_SECOND), 1)
	var series := (beams.count - 1) * interval
	var events := {}
	for frame in beams.shoot_frames:
		events[frame] = func() -> void:
			var healed := {}
			for i in beams.count:
				sim.after(i * interval, func() -> void:
					if fighter.dead:
						return
					var targets := _beam_targets(sim, fighter, beams, healing)
					for j in beams.at_once:
						_fire(sim, fighter, beams, healing, targets, healed))
	_play(sim, fighter, beams.action, series if beams.stop_animation else 0, events)


static func _beam_targets(sim: BattleSim, fighter: BattleFighter, beams: Beams, healing: bool) -> Array[BattleFighter]:
	var range_tiles := fighter.def.attack_range
	if healing:
		return sim.items_near(fighter.tile, range_tiles, beams.count + 1, fighter.team, false, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and item.health < item.max_life())
	return sim.items_near(fighter.tile, range_tiles, 20, BattleAbility.enemy_side(fighter), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead)


static func _fire(sim: BattleSim, fighter: BattleFighter, beams: Beams, healing: bool, targets: Array[BattleFighter], healed: Dictionary) -> void:
	var target: BattleFighter = null
	while not targets.is_empty():
		var index := sim.rng.randi_range(0, targets.size() - 1)
		if targets[index].dead:
			targets.remove_at(index)
			continue
		target = targets[index]
		if healing:
			targets.remove_at(index)
		break
	var frames := roundi(beams.seconds * BattleSim.FRAMES_PER_SECOND)
	if target == null:
		sim.shoot_beam(fighter, null, _random_tile(sim, fighter), beams.graphic, frames)
		return
	if healing:
		sim.shoot_beam(fighter, target, target.tile, beams.graphic, frames)
		sim.heal(target, int(fighter.def.attack * 0.6), fighter)
		healed[target] = true
		sim.particle(null, target.tile, MagicParticles.STARS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass)
	else:
		sim.shoot_beam(fighter, target, target.tile, beams.graphic, frames, int(fighter.def.attack * 0.2))


## A random tile within the attack range, not the tile of the fighter.
static func _random_tile(sim: BattleSim, fighter: BattleFighter) -> Vector2i:
	var range_tiles := fighter.def.attack_range
	var tile := Vector2i(roundi(fighter.tile.x - range_tiles + sim.rng.randf() * range_tiles * 2), roundi(fighter.tile.y - range_tiles + sim.rng.randf() * range_tiles * 2))
	if tile.x == fighter.tile.x:
		tile.x -= -1 if sim.rng.randf() < 0.5 else 1
	if tile.y == fighter.tile.y:
		tile.y -= -1 if sim.rng.randf() < 0.5 else 1
	return tile.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))


## Plays the animation of a limit attack, extra frames longer, with the unit
## unable to walk or attack, and marks the limit attack until its end.
static func _play(sim: BattleSim, fighter: BattleFighter, action: int, extra: int, events: Dictionary) -> void:
	var ability := fighter.ability
	ability.in_limit_attack = true
	var frames := sim.animation_frames(fighter, action, FALLBACK_FRAMES) + extra
	sim.play_special(fighter, action, frames, events, func() -> void: ability.in_limit_attack = false, true)
