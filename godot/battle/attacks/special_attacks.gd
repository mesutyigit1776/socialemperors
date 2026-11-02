class_name SpecialAttacks
extends RefCounted
## The special attacks that the portrait buttons start (the specials package
## of the client). Each attack belongs to one unit; execute() starts it.
## Animations are UnitSprite actions with the numbers of the client
## (ANIMATION_ATTACKING_SPECIAL1 is 6). Frames are frames of the animation,
## from 1. Times of the client in seconds become frames at 30 per second.
##
## The client takes some attack points and shot points from named clips of
## the unit graphic; the port uses the tile of the unit, as the client does
## when the clip is missing.

const FPS := BattleSim.FRAMES_PER_SECOND
const FALLBACK_FRAMES := 40


## The base of the attacks (AbstractSpecialAttack).
class Attack extends RefCounted:
	var sim: BattleSim
	var unit: BattleFighter
	var shared := false
	var filter := Callable()
	var invulnerable := false
	var end_action := Callable()

	func _init(battle: BattleSim, owner: BattleFighter) -> void:
		sim = battle
		unit = owner

	func with_shared(value: bool) -> Attack:
		shared = value
		return self

	func with_invulnerable(value: bool) -> Attack:
		invulnerable = value
		return self

	func with_end_action(action: Callable) -> Attack:
		end_action = action
		return self

	func with_filter(function: Callable) -> Attack:
		filter = function
		return self

	## The action of the portrait button: (sim, fighter) -> void.
	func button_action() -> Callable:
		return func(_sim: BattleSim, _fighter: BattleFighter) -> void: execute()

	func execute() -> void:
		if invulnerable:
			unit.cannot_die = true

	func _end() -> void:
		if invulnerable:
			unit.cannot_die = false
		if end_action.is_valid():
			end_action.call()

	## 1 / count for a shared attack, else 1.
	func _share(count: int) -> float:
		return 1.0 / count if shared and count > 0 else 1.0

	## The enemy units within range_tiles of tile, at most count, nearest first.
	func _enemies(tile: Vector2i, range_tiles: int, count: int, extra := Callable()) -> Array[BattleFighter]:
		return sim.items_near(tile, range_tiles, count, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (not extra.is_valid() or extra.call(item)))

	func _allies(tile: Vector2i, range_tiles: int, count: int) -> Array[BattleFighter]:
		return sim.items_near(tile, range_tiles, count, unit.team, true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead)

	## Applies damage to targets, with the share of the client.
	func _damage_all(damage: UnitDamage, targets: Array[BattleFighter], count: int, multiplier := -1.0) -> void:
		if damage.shared:
			damage.num_targets = mini(targets.size(), count)
		var factor := multiplier if multiplier >= 0 else _share(targets.size())
		for target in targets:
			if damage.can_apply(target):
				damage.apply(target, factor)

	## The forced animation until its end, action at each of frames
	## (setForcedAnimAndCheckFramesTillEnd).
	func _play_till_end(animation: int, frames: Array, action: Callable, incapacitate := true, on_end := Callable()) -> void:
		var events := {}
		for frame: int in frames:
			events[maxi(frame, 1)] = action
		var length := sim.animation_frames(unit, animation, FALLBACK_FRAMES)
		for frame: int in frames:
			length = maxi(length, frame)
		sim.play_special(unit, animation, length, events, on_end if on_end.is_valid() else _end, incapacitate)

	## The forced animation in a loop for seconds, action at frames of each loop
	## (setForcedAnimAndCheckFrames).
	func _play_for(seconds: float, animation: int, frames: Array, action: Callable, incapacitate := true) -> void:
		var total := maxi(roundi(seconds * FPS), 1)
		var loop := sim.animation_frames(unit, animation, FALLBACK_FRAMES)
		var events := {}
		var start := 0
		while start < total:
			for frame: int in frames:
				if start + frame <= total:
					events[start + maxi(frame, 1)] = action
			start += maxi(loop, 1)
		sim.play_special(unit, animation, total, events, _end, incapacitate)

	## The point in front of the unit at its attack range (getDirectionalTargetPoint).
	func _front_tile(distance: int) -> Vector2i:
		var step: Vector2i = BattleAbility.TILE_STEPS[BattleAbility.direction(unit)]
		return (unit.tile + step * distance).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))


## Damage around an attack point at frames of an animation
## (AreaDamageSpecialAttack, WaypointAreaSpecialAttack).
class Area extends Attack:
	var animation: int
	var frames: Array
	var damage: UnitDamage
	var range_tiles: int
	var count: int
	var points := 1  ## Attack points (waypoints); the port uses the tile of the unit for each.

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, hurt: UnitDamage, area_range: int, units: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		damage = hurt
		range_tiles = area_range
		count = units

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _on_frame)

	func _on_frame() -> void:
		if unit.dead:
			return
		var targets := _enemies(unit.tile, range_tiles, count, filter)
		_damage_all(damage, targets, count)


## A rain of magic particles of type over the target (RainSpecialAttack and
## attackSpecialStormTimed): every delay seconds for duration seconds, a
## particle with multiplier times the attack falls on a random tile within
## radius of the target, or, every second time, on the next enemy unit in range.
class Rain extends Attack:
	var radius: int
	var duration: float
	var animation: int
	var particle: int
	var damage: UnitDamage
	var hit_delay: int
	var multiplier := 1.0
	var delay := 0.1
	var frames: Array = [30]
	var _last_target: BattleFighter

	func _init(battle: BattleSim, owner: BattleFighter, rain_radius: float, seconds: float, anim: int, type: int, hurt: UnitDamage, delay_frames := 0) -> void:
		super(battle, owner)
		radius = int(rain_radius)
		duration = seconds
		animation = anim
		particle = type
		damage = hurt
		hit_delay = delay_frames

	func with_multiplier(value: float) -> Rain:
		multiplier = value
		return self

	func with_delay(seconds: float) -> Rain:
		delay = seconds
		return self

	func with_frames(frame_list: Array) -> Rain:
		frames = frame_list
		return self

	func execute() -> void:
		super()
		_play_till_end(animation, frames, start)

	## The rain itself, without the animation.
	func start() -> void:
		var centre := unit.tile
		if unit.target != null and sim.distance(unit, unit.target) <= unit.attack_range:
			centre = unit.target.tile
		var interval := maxi(roundi(delay * FPS), 1)
		var drops := int(duration / delay)
		for i in drops:
			sim.after(interval * (i + 1), func() -> void:
				if unit.dead:
					return
				var tile := centre + Vector2i(sim.rng.randi_range(-radius, radius), sim.rng.randi_range(-radius, radius))
				if i % 2 == 0:
					var next := _next_target()
					if next != null:
						tile = next.tile
				sim.particle(unit, tile, particle, int(unit.attack * multiplier), hit_delay, _on_hit))

	func _next_target() -> BattleFighter:
		for enemy in _enemies(unit.tile, unit.attack_range, 50):
			if enemy != _last_target:
				_last_target = enemy
				return enemy
		return null

	func _on_hit(_attacker: BattleFighter, target: BattleFighter, _value: int) -> void:
		if damage != null and target != null and target.is_unit() and damage.can_apply(target):
			damage.apply(target)


## Damage around the unit every 1.5 seconds (or interval_ms) for duration seconds, after
## delay frames, during an animation (WhirlwindSpecialAttack); with an end
## damage on the units within 10 tiles.
class Whirlwind extends Attack:
	var interval_ms := 1500
	var animation: int
	var duration: int
	var delay_frames: int
	var damage: UnitDamage
	var range_tiles: int
	var count: int
	var end_damage: UnitDamage

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, seconds: int, delay: int, hurt: UnitDamage, area_range: int, units: int) -> void:
		super(battle, owner)
		animation = anim
		duration = seconds
		delay_frames = delay
		damage = hurt
		range_tiles = area_range
		count = units

	func with_end_damage(hurt: UnitDamage) -> Whirlwind:
		end_damage = hurt
		return self

	func with_interval(milliseconds: int) -> Whirlwind:
		interval_ms = milliseconds
		return self

	func execute() -> void:
		super()
		var interval := roundi(interval_ms / 1000.0 * FPS)
		var times := duration * 1000 / interval_ms
		var total := delay_frames + interval * times
		sim.play_special(unit, animation, total, {}, Callable(), false)
		for i in times:
			sim.after(delay_frames + interval * (i + 1), func() -> void:
				if not unit.dead:
					_damage_all(damage, _enemies(unit.tile, range_tiles, count, filter), count))
		sim.after(total, _finish_whirl)

	func _finish_whirl() -> void:
		if end_damage != null and not unit.dead:
			var targets := _enemies(unit.tile, 10, count)
			_damage_all(end_damage, targets, count, 1.0 / maxi(targets.size(), 1))
		sim.stop_special(unit)
		_end()


## Shots at the target at frames of each loop of an animation for duration
## seconds (EnergyBallsSpecialAttack); where a shot lands, damage on the enemy
## units within range_tiles, and a magic particle.
class EnergyBalls extends Attack:
	var animation: int
	var frames: Array
	var duration: float
	var graphic: String
	var damage: UnitDamage
	var range_tiles: int
	var count: int
	var shot_damage := true
	var impact_particle := -1
	var directional := false  ## Without a target, shoot in front of the unit.
	var offset := 0.0

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, seconds: float, shot_graphic: String, hurt: UnitDamage = null, area_range := 10, units := 5) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		duration = seconds
		graphic = shot_graphic
		damage = hurt
		range_tiles = area_range
		count = units

	func with_shot_damage(value: bool) -> EnergyBalls:
		shot_damage = value
		return self

	func with_impact_particle(type: int) -> EnergyBalls:
		impact_particle = type
		return self

	func with_directional(value: bool, target_offset := 0.0) -> EnergyBalls:
		directional = value
		offset = target_offset
		return self

	func execute() -> void:
		super()
		_play_for(duration, animation, frames, _shoot)

	func _shoot() -> void:
		if unit.dead:
			return
		var target := unit.target
		if target != null and not target.dead:
			sim.shoot(unit, target, graphic, unit.attack if shot_damage else -1, func(shot: BattleProjectile) -> void: _impact(IsoGrid.map_to_tile(shot.end)))
		elif directional:
			var tile := _front_tile(unit.attack_range)
			sim.shoot_at(unit, tile, graphic, func(_shot: BattleProjectile) -> void: _impact(tile))

	func _impact(tile: Vector2i) -> void:
		if damage != null:
			var targets := _enemies(tile, range_tiles, count)
			_damage_all(damage, targets, count, 1.0 / maxi(targets.size(), 1))
		if impact_particle >= 0:
			sim.particle(unit, tile, impact_particle, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass)


## Shots at the nearest enemies at frames of an animation; each shot that lands
## hurts all of them with damage (ShootProjectilesSpecialAttack).
class ShootProjectiles extends Attack:
	var animation: int
	var frames: Array
	var damage: UnitDamage
	var graphic: String
	var per_burst := 1
	var range_tiles: int
	var count := 3
	var incapacitate := false
	## The client shoots an empty shot at 400 pixels a frame, or no shot: the
	## damage comes at once, with the blast effect on each target.
	var instant := false
	var blast := ""
	var _enemies_now: Array[BattleFighter] = []

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, hurt: UnitDamage, shot_graphic := "", _points := 1, burst := 1, stop_unit := false) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		damage = hurt
		graphic = shot_graphic
		per_burst = burst
		range_tiles = owner.attack_range
		incapacitate = stop_unit

	func with_count(units: int) -> ShootProjectiles:
		count = units
		return self

	func with_range(tiles: int) -> ShootProjectiles:
		range_tiles = tiles
		return self

	func with_blast(graphic_name: String) -> ShootProjectiles:
		blast = graphic_name
		instant = true
		return self

	func with_instant() -> ShootProjectiles:
		instant = true
		return self

	func execute() -> void:
		super()
		_enemies_now = _enemies(unit.tile, range_tiles, count)
		_play_till_end(animation, frames, _shoot, incapacitate)

	func _shoot() -> void:
		if _enemies_now.is_empty() or unit.dead:
			return
		for i in per_burst:
			var target := _enemies_now[i % _enemies_now.size()]
			if target.dead:
				continue
			if instant:
				if blast != "":
					for item in _enemies_now:
						sim.effect(blast, item.tile)
				_hit_all()
			else:
				sim.shoot(unit, target, graphic, -1, func(_shot: BattleProjectile) -> void: _hit_all())

	func _hit_all() -> void:
		var alive: Array[BattleFighter] = []
		alive.assign(_enemies_now.filter(func(item: BattleFighter) -> bool: return not item.dead))
		_damage_all(damage, alive, count, 1.0)


## Summoned units come next to the unit (SpawnMinionSpecialAttack); the button
## works while fewer than max_minions are alive.
class SpawnMinion extends Attack:
	var minion: int
	var number: int
	var max_minions: int
	var random_range := Vector2i(-1, -1)

	func _init(battle: BattleSim, owner: BattleFighter, minion_id: int, minion_count: int, maximum := 4) -> void:
		super(battle, owner)
		minion = minion_id
		number = minion_count
		max_minions = maximum

	func with_random_count(low: int, high: int) -> SpawnMinion:
		random_range = Vector2i(low, high)
		max_minions = high
		return self

	func execute() -> void:
		var spawned := number
		if random_range.x >= 0:
			spawned = random_range.x + int(sim.rng.randf() * (random_range.y - random_range.x + 1))
		unit.ability.spawn_minions(sim, unit, minion, spawned)

	func can_use() -> Callable:
		return func(_sim: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive < max_minions


## Several kinds of summoned units at once, up to their numbers
## (SpawnMultipleMinionsSpecialAttack).
class SpawnMultiple extends Attack:
	var minion_ids: Array
	var numbers: Array
	var _alive: Array = []

	func _init(battle: BattleSim, owner: BattleFighter, ids: Array, counts: Array) -> void:
		super(battle, owner)
		minion_ids = ids
		numbers = counts
		_alive.resize(ids.size())
		_alive.fill(0)

	func execute() -> void:
		# The client counts the units as alive again without checking which died.
		for i in minion_ids.size():
			unit.ability.spawn_minions(sim, unit, minion_ids[i], numbers[i] - _alive[i])
			_alive[i] = numbers[i]


## The unit grabs up to points enemy units within distance at the grab frames
## and eats them at the eat frames (EatSpecialAttack). Bosses and units that
## cannot act are not grabbed.
class Eat extends Attack:
	var animation: int
	var grab_frames: Array
	var eat_frames: Array
	var damage: UnitDamage
	var points: int
	var distance: int
	var incapacitate := false
	var _held: Array[BattleFighter] = []

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, grab: Array, eat: Array, hurt: UnitDamage, grab_points: Array, max_distance: int) -> void:
		super(battle, owner)
		animation = anim
		grab_frames = grab
		eat_frames = eat
		damage = hurt
		points = grab_points.size()
		distance = max_distance

	func with_incapacitate(value: bool) -> Eat:
		incapacitate = value
		return self

	func execute() -> void:
		super()
		if _prey().is_empty():
			return
		var events := {}
		for frame: int in grab_frames:
			events[frame] = _grab
		for frame: int in eat_frames:
			events[frame] = _eat
		var length := sim.animation_frames(unit, animation, FALLBACK_FRAMES)
		for frame: int in grab_frames + eat_frames:
			length = maxi(length, frame)
		sim.play_special(unit, animation, length, events, _end, incapacitate)

	func _prey() -> Array[BattleFighter]:
		return _enemies(unit.tile, distance, points, func(item: BattleFighter) -> bool:
			return not item.incapacitated and item.def.subcat_functional != BattleSim.SUBCAT_BOSS and (not filter.is_valid() or filter.call(item)))

	func _grab() -> void:
		for prey in _prey():
			prey.incapacitated = true
			prey.swallowed = true
			sim.state_changed.emit(prey)
			_held.append(prey)

	func _eat() -> void:
		while not _held.is_empty():
			var prey: BattleFighter = _held.pop_back()
			prey.incapacitated = prey.frozen or prey.stunned or prey.in_air
			prey.swallowed = false
			sim.state_changed.emit(prey)
			if damage.can_apply(prey):
				damage.apply(prey)


## A magic particle on the middle of the enemy units in range; the units
## float up and fall when the particle acts, and take damage then
## (SealAreaSpecialAttack).
class SealArea extends Attack:
	var animation: int
	var frames: Array
	var range_tiles: int
	var count: int
	var particle: int
	var damage: UnitDamage
	var levitate := true
	var levitation_damage: UnitDamage

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, area_range: int, units: int, type: int, hurt: UnitDamage, float_units := true, _height := 300.0, float_damage: UnitDamage = null) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		range_tiles = area_range
		count = units
		particle = type
		damage = hurt
		levitate = float_units
		levitation_damage = float_damage

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _seal)

	func _seal() -> void:
		var targets := _enemies(unit.tile, range_tiles, count)
		var centre := unit.tile
		var pushable := targets.filter(func(item: BattleFighter) -> bool: return item.ability == null or not item.ability.immune_to_push)
		if not pushable.is_empty():
			var sum := Vector2.ZERO
			for item: BattleFighter in pushable:
				sum += Vector2(item.tile)
			centre = Vector2i(sum / pushable.size())
		var floating: Array[BattleFighter] = []
		if levitate:
			for target in _enemies(centre, range_tiles, count):
				if target.incapacitated or (target.ability != null and target.ability.immune_to_push):
					continue
				target.incapacitated = true
				target.levitating = true
				sim.state_changed.emit(target)
				floating.append(target)
				if levitation_damage != null and levitation_damage.can_apply(target):
					levitation_damage.apply(target)
		sim.particle(unit, centre, particle, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void:
			if not floating.is_empty():
				for target in floating:
					target.levitating = false
					target.incapacitated = target.frozen or target.stunned or target.in_air
					sim.state_changed.emit(target)
				_damage_all(damage, floating, count)
			else:
				_damage_all(damage, _enemies(centre, range_tiles, count), count), true)


## Beams from the unit to the enemy units within range, each with damage /
## count points (AreaMultiBeamSpecialAttack). The regular kind also sends the
## beams that have no target to points on a circle around the unit
## (RegularAreaMultiBeamSpecialAttack).
class MultiBeam extends Attack:
	var animation: int
	var frames: Array
	var graphic: String
	var range_tiles: int
	var count: int
	var damage: float
	var beam_seconds := 1.0
	var regular := false
	var hold_enemies := false
	var timeout := 0.0
	var _held: Array[BattleFighter] = []

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, beam_graphic: String, area_range: int, units: int, total_damage: float, seconds := 1.0, circle := false) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		graphic = beam_graphic
		range_tiles = area_range
		count = units
		damage = total_damage / units
		beam_seconds = seconds
		regular = circle

	func with_hold_enemies(value: bool) -> MultiBeam:
		hold_enemies = value
		return self

	func with_timeout(seconds: float) -> MultiBeam:
		timeout = seconds
		return self

	func execute() -> void:
		super()
		if timeout > 0:
			_play_for(timeout, animation, frames, _beams)
		else:
			_play_till_end(animation, frames, _beams, true, _release)

	func _beams() -> void:
		if unit.dead:
			return
		var targets := _enemies(unit.tile, range_tiles, count)
		var frames_long := Damages.frames(beam_seconds)
		var factor := 1.0 if regular else _share(targets.size())
		var circle := SpecialAttacks.area_points(count, range_tiles)
		for target in targets:
			sim.shoot_beam(unit, target, target.tile, graphic, frames_long, int(damage * factor))
			if hold_enemies:
				target.incapacitated = true
				_held.append(target)
			if regular:
				SpecialAttacks.remove_closest(circle, target.tile - unit.tile)
		if regular:
			for point in circle:
				sim.shoot_beam(unit, null, unit.tile + point, graphic, frames_long)

	func _release() -> void:
		for target in _held:
			if not target.dead:
				target.incapacitated = target.frozen or target.stunned or target.in_air
		_held.clear()
		_end()


## A magic particle on each own unit in range; when it acts, damage (usually
## a Health damage) on the own units in range (HealthAreaSpecialAttack).
class HealthArea extends Attack:
	var animation: int
	var frames: Array
	var range_tiles: int
	var count: int
	var particle: int
	var damage: UnitDamage

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, area_range: int, units: int, type: int, heal: UnitDamage) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		range_tiles = area_range
		count = units
		particle = type
		damage = heal

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _start)

	func _start() -> void:
		for ally in _allies(unit.tile, range_tiles, count):
			if ally == unit:
				continue
			sim.particle(unit, ally.tile, particle, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: _heal(), true)

	func _heal() -> void:
		var allies := _allies(unit.tile, range_tiles, count)
		if damage.shared:
			damage.num_targets = mini(allies.size(), count)
		for ally in allies:
			if ally != unit and damage.can_apply(ally):
				damage.apply(ally, 1.0)


## A magic particle and damage on each enemy unit in range (ParticleSpecialAttack).
class ParticleAttack extends Attack:
	var animation: int
	var frames: Array
	var range_tiles: int
	var count: int
	var particle: int
	var damage: UnitDamage

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, area_range: int, units: int, type: int, hurt: UnitDamage) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		range_tiles = area_range
		count = units
		particle = type
		damage = hurt

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _hit)

	func _hit() -> void:
		var targets := _enemies(unit.tile, range_tiles, count)
		for target in targets:
			sim.particle(unit, target.tile, particle, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass)
			if damage.shared:
				damage.num_targets = mini(targets.size(), count)
			if damage.can_apply(target):
				damage.apply(target, 1.0)


## The unit heals itself by amount at frames (SelfHealingSpecialAttack).
class SelfHealing extends Attack:
	var animation: int
	var frames: Array
	var amount: int

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, quantity: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		amount = quantity

	func execute() -> void:
		super()
		_play_till_end(animation, frames, func() -> void: sim.heal(unit, amount, unit))


## The unit takes reduction times the damage for seconds (ShieldAttack).
class Shield extends Attack:
	var reduction: float
	var seconds: int

	func _init(battle: BattleSim, owner: BattleFighter, _anim: int, factor: float, duration: int, _graphic := "") -> void:
		super(battle, owner)
		reduction = factor
		seconds = duration

	func execute() -> void:
		super()
		unit.damage_factor *= reduction
		sim.state_changed.emit(unit)
		sim.after(seconds * FPS, func() -> void:
			unit.damage_factor /= reduction
			sim.state_changed.emit(unit))


## The enemy units in range attack with 10 points for seconds, and take damage
## (PowerDownSpecialAttack, stats modifier SM_SET_10 of the client).
class PowerDown extends Attack:
	const WEAK_ATTACK := 10
	var animation: int
	var frames: Array
	var range_tiles: int
	var seconds: int
	var damage: UnitDamage

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, area_range: int, duration: int, hurt: UnitDamage = null) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		range_tiles = area_range
		seconds = duration
		damage = hurt

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _weaken)

	func _weaken() -> void:
		var enemies := _enemies(unit.tile, range_tiles, 100, filter)
		for enemy in enemies:
			enemy.attack = WEAK_ATTACK
			if damage != null:
				damage.apply(enemy)
		sim.after(seconds * FPS, func() -> void:
			for enemy in enemies:
				if not enemy.dead:
					enemy.attack = enemy.def.attack)


## The own units in range get a buff graphic for seconds (powerUpSpecialAttack).
## The client changes only the look of the units; so does the port.
class PowerUp extends Attack:
	var animation: int
	var frames: Array

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, _area_range: int, _duration: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list

	func execute() -> void:
		super()
		_play_till_end(animation, frames, func() -> void: pass)


## The unit runs to the tile at its attack range in front of it, damages the
## enemy units near it every 100 ms on the way, and comes back (ChargeAttack).
class Charge extends Attack:
	var animation: int
	var frames: Array
	var damage: UnitDamage
	var range_tiles: int
	var count: int

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, hurt: UnitDamage, area_range: int, units: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		damage = hurt
		range_tiles = area_range
		count = units

	func execute() -> void:
		super()
		var start := unit.tile
		var goal := _front_tile(unit.attack_range)
		var run := FPS  # 1 second there, 1 second back.
		sim.play_special(unit, animation, 15 + run * 2, {}, _end, true)
		for i in range(0, run, 3):
			sim.after(15 + i, func() -> void:
				if unit.dead:
					return
				var tile := Vector2i(Vector2(start).lerp(Vector2(goal), float(i) / run).round())
				_damage_all(damage, _enemies(tile, range_tiles, count), count))


## Copies of a unit come around the unit and do an attack each; after seconds
## they go (GhostSpecialAttack). The unit cannot act meanwhile.
class Ghosts extends Attack:
	var ghost_id: int
	var number: int
	var radius: int
	var seconds: int
	var make_attack: Callable  ## (sim, ghost) -> Attack
	var _attacks: Array[Attack] = []  # Kept until the end: nothing else holds them.

	func _init(battle: BattleSim, owner: BattleFighter, unit_id: int, ghosts: int, area_radius: int, duration: int, attack_maker: Callable) -> void:
		super(battle, owner)
		ghost_id = unit_id
		number = ghosts
		radius = area_radius
		seconds = duration
		make_attack = attack_maker

	func execute() -> void:
		super()
		var ghosts: Array[BattleFighter] = []
		for point in SpecialAttacks.area_points(number, radius):
			var ghost := sim.spawn(sim.config_item(ghost_id), unit.tile + point, unit.team)
			if ghost == null:
				continue
			ghost.incapacitated = true
			ghosts.append(ghost)
			sim.after(roundi(0.6 * FPS), func() -> void:
				if not ghost.dead:
					var attack: Attack = make_attack.call(sim, ghost)
					_attacks.append(attack)
					attack.execute())
		unit.incapacitated = true
		sim.after(seconds * FPS, func() -> void:
			for ghost in ghosts:
				if not ghost.dead:
					sim.kill(ghost, unit)
			_attacks.clear()
			unit.incapacitated = unit.frozen or unit.stunned or unit.in_air
			_end())


## Eggs at the target at frames of each loop; each egg brings the next of
## the summoned units while fewer than their number are alive (EasterEggsSpecialAttack).
class EasterEggs extends Attack:
	var animation: int
	var seconds: float
	var frames: Array
	var graphics: Array
	var minion_ids: Array
	var _next_minion := 0
	var _next_graphic := 0

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, duration: float, frame_list: Array, shot_graphics: Array, ids: Array) -> void:
		super(battle, owner)
		animation = anim
		seconds = duration
		frames = frame_list
		graphics = shot_graphics
		minion_ids = ids

	func execute() -> void:
		super()
		_play_for(seconds, animation, frames, _throw)

	func _throw() -> void:
		if unit.dead or unit.ability.minions_alive >= minion_ids.size():
			return
		var tile := unit.target.tile if unit.target != null and not unit.target.dead else _front_tile(unit.attack_range)
		var graphic: String = graphics[_next_graphic]
		_next_graphic = (_next_graphic + 1) % graphics.size()
		sim.shoot_at(unit, tile, graphic, func(_shot: BattleProjectile) -> void:
			if unit.ability.minions_alive < minion_ids.size():
				unit.ability.spawn_minions(sim, unit, minion_ids[_next_minion], 1, tile)
				_next_minion = (_next_minion + 1) % minion_ids.size())

	func can_use() -> Callable:
		return func(_sim: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive < minion_ids.size()


## The unit throws its tongue at the nearest enemy unit, pulls it in and eats
## it at the end of the animation (TongueSpecialAttack).
class Tongue extends Attack:
	var animation: int
	var frame: int
	var graphic: String
	var _prey: BattleFighter

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, shoot_frame: int, _grab_frame: int, tongue_graphic: String, _point := "projectilePoint") -> void:
		super(battle, owner)
		animation = anim
		frame = shoot_frame
		graphic = tongue_graphic

	func execute() -> void:
		super()
		_play_till_end(animation, [frame], _launch, true, _swallow)

	func _launch() -> void:
		var prey := sim.nearest_enemy(unit, unit.tile, 1000)
		if prey == null or not prey.is_unit():
			return
		_prey = prey
		prey.incapacitated = true
		sim.shoot_beam(unit, prey, prey.tile, graphic, roundi(0.75 * FPS))

	func _swallow() -> void:
		if _prey != null and not _prey.dead:
			sim.kill(_prey, unit)
		_prey = null
		_end()


## The enemy units in range turn around the unit for 3 seconds, shrink, and
## take damage when they come back (WhirlHoleSpecialAttack).
class WhirlHole extends Attack:
	const TURN_FRAMES := 90
	var animation: int
	var frames: Array
	var damage: UnitDamage
	var range_tiles: int
	var count: int

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, hurt: UnitDamage, area_range: int, units: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		damage = hurt
		range_tiles = area_range
		count = units

	func execute() -> void:
		super()
		_play_till_end(animation, frames, _turn)

	func _turn() -> void:
		var targets := _enemies(unit.tile, range_tiles, count)
		if damage.shared:
			damage.num_targets = mini(targets.size(), count)
		for target in targets:
			if target.levitating:
				continue
			target.incapacitated = true
			target.levitating = true
			sim.state_changed.emit(target)
			sim.after(TURN_FRAMES, func() -> void:
				target.levitating = false
				target.incapacitated = target.frozen or target.stunned or target.in_air
				sim.state_changed.emit(target)
				if not target.dead:
					damage.apply(target))


## number points on a circle of radius tiles (computeAreaPoints of the client).
## The unit takes no damage for seconds and shoots its own shot at one of
## the count nearest enemy units within range_tiles at the frames of the
## animation (StealthSpecialAttack with the Enel Epic Dragon). The client
## also makes the unit and its beam half transparent.
class Stealth extends Attack:
	var animation: int
	var frames: Array
	var seconds: int
	var range_tiles: int
	var count: int
	var _factor := 1.0

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, duration: int, area_range: int, units: int) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		seconds = duration
		range_tiles = area_range
		count = units

	func execute() -> void:
		super()
		_factor = unit.damage_factor
		unit.damage_factor = 0.0
		_play_for(seconds, animation, frames, _shoot)

	func _shoot() -> void:
		var enemies := _enemies(unit.tile, range_tiles, count)
		if not unit.dead and enemies.size() > 0:
			sim.shoot(unit, enemies[sim.rng.randi_range(0, enemies.size() - 1)], "", unit.attack)

	func _end() -> void:
		unit.damage_factor = _factor
		super()


## An action of the unit at frames of an animation, for the attacks that the
## client writes in the unit class itself: once until the end of the
## animation (setForcedAnimAndCheckFramesTillEnd), or in a loop for seconds
## (setForcedAnimAndCheckFrames) when seconds is above 0.
class Frames extends Attack:
	var animation: int
	var frames: Array
	var seconds: float
	var action: Callable
	var incapacitate := true

	func _init(battle: BattleSim, owner: BattleFighter, anim: int, frame_list: Array, frame_action: Callable, duration := 0.0) -> void:
		super(battle, owner)
		animation = anim
		frames = frame_list
		action = frame_action
		seconds = duration

	func execute() -> void:
		super()
		if seconds > 0:
			_play_for(seconds, animation, frames, action, incapacitate)
		else:
			_play_till_end(animation, frames, action, incapacitate)


static func area_points(number: int, radius: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for i in number:
		var angle := TAU / number * i
		points.append(Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius)))
	return points


static func remove_closest(points: Array[Vector2i], offset: Vector2i) -> void:
	var best := -1
	var best_distance := INF
	for i in points.size():
		var d := Vector2(points[i]).distance_to(Vector2(offset))
		if d < best_distance:
			best_distance = d
			best = i
	if best >= 0:
		points.remove_at(best)
