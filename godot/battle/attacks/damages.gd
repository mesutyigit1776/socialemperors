class_name Damages
extends RefCounted
## The kinds of UnitDamage (the damages package of the client). Times of the
## client in seconds and milliseconds become frames at 30 frames per second.

const FPS := BattleSim.FRAMES_PER_SECOND


static func frames(seconds: float) -> int:
	return maxi(roundi(seconds * FPS), 1)


## Hurts the target by damage and pushes a unit tiles away (PushInAirDamage).
class PushInAir extends UnitDamage:
	var damage: float
	var tiles: int

	func _init(battle: BattleSim, from: BattleFighter, amount: float, push_tiles: int) -> void:
		super(battle, from)
		damage = amount
		tiles = push_tiles

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		sim.receive_attack(target, _part(damage, multiplier), _source())
		if target.is_unit() and not target.dead:
			sim.push_in_air(target, attacker, tiles)
			sim.after(FPS, func() -> void: _finish(target, multiplier))
		else:
			_finish(target, multiplier)

	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (not target.is_unit() or target.ability == null or not target.ability.immune_to_push)


## The damages one after the other on each target (SequencedDamage).
class Sequenced extends UnitDamage:
	var damages: Array[UnitDamage] = []
	var _index := {}  # Target -> index of its current damage.

	func add(damage: UnitDamage) -> Sequenced:
		damages.append(damage)
		damage.finished.connect(_on_finished)
		return self

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		_index[target] = 0
		_apply_current(target, multiplier)

	func _on_finished(target: BattleFighter, multiplier: float) -> void:
		if not _index.has(target):
			return
		_index[target] += 1
		_apply_current(target, multiplier)

	func _apply_current(target: BattleFighter, multiplier: float) -> void:
		var index: int = _index[target]
		if index >= damages.size():
			_index.erase(target)
			_finish(target, multiplier)
			return
		var damage := damages[index]
		damage.num_targets = num_targets
		damage.shared = shared
		if damage.can_apply(target):
			damage.apply(target, multiplier)
		else:
			damage.finished.emit(target, multiplier)


## damage points in ticks over seconds; the target cannot act meanwhile when
## incapacitate (SimpleDamage). colour: the colour of the state for the view.
class Simple extends UnitDamage:
	var seconds: float
	var per_tick: float
	var ticks: int
	var incapacitate: bool

	func _init(battle: BattleSim, from: BattleFighter, damage: float, duration := 6.0, tick_count := 5, stop_target := true) -> void:
		super(battle, from)
		seconds = duration
		per_tick = damage / tick_count
		ticks = tick_count
		incapacitate = stop_target

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		if target.is_unit() and incapacitate:
			target.incapacitated = true
		_start(target)
		var interval := Damages.frames(seconds / ticks)
		for i in ticks:
			sim.after(interval * (i + 1), func() -> void:
				if not target.dead:
					sim.receive_attack(target, _part(per_tick, multiplier), _source())
					if target.dead and on_dead.is_valid():
						on_dead.call(target)
				if i == ticks - 1:
					_end(target)
					if target.is_unit() and incapacitate:
						target.incapacitated = target.frozen or target.stunned or target.in_air
					_finish(target, multiplier))

	func _start(_target: BattleFighter) -> void:
		pass

	func _end(_target: BattleFighter) -> void:
		pass


## A Simple damage with the stars of a dizzy unit (DizzyDamage).
class Dizzy extends Simple:
	func _start(target: BattleFighter) -> void:
		target.dizzy = true
		sim.state_changed.emit(target)

	func _end(target: BattleFighter) -> void:
		target.dizzy = false
		sim.state_changed.emit(target)


## A Simple damage on units that can be frozen, with the frozen colour (FreezeDamage).
class Freeze extends Simple:
	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (target.ability == null or not target.ability.immune_to_freeze)

	func _start(target: BattleFighter) -> void:
		target.frozen = true
		sim.state_changed.emit(target)

	func _end(target: BattleFighter) -> void:
		target.frozen = false
		sim.state_changed.emit(target)


## A Simple damage on units that can be poisoned, with the poison colour (PoisonDamage).
class Poison extends Simple:
	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (target.ability == null or not target.ability.immune_to_poison)

	func _start(target: BattleFighter) -> void:
		target.poisoned = true
		sim.state_changed.emit(target)

	func _end(target: BattleFighter) -> void:
		target.poisoned = false
		sim.state_changed.emit(target)


## The target burns (BattleSim.incinerate()) (IncinerateDamage).
class Incinerate extends UnitDamage:
	var per_tick: float
	var ticks: int
	var interval_ms: int
	var incapacitate := false

	func _init(battle: BattleSim, from: BattleFighter, damage_per_tick: float, tick_count: int, tick_ms: int) -> void:
		super(battle, from)
		per_tick = damage_per_tick
		ticks = tick_count
		interval_ms = tick_ms

	func with_incapacitate(value: bool) -> Incinerate:
		incapacitate = value
		return self

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		var interval := Damages.frames(interval_ms / 1000.0)
		sim.incinerate(target, attacker, _part(per_tick, multiplier), ticks, interval)
		if incapacitate:
			target.incapacitated = true
		sim.after(interval * ticks, func() -> void:
			if incapacitate:
				target.incapacitated = target.frozen or target.stunned or target.in_air
			_finish(target, multiplier))

	func can_apply(target: BattleFighter) -> bool:
		return super(target) and target.is_unit() and (target.ability == null or not target.ability.immune_to_burn)


## The target is electrocuted (BattleSim.electrocute()) (ElectrocuteDamage).
class Electrocute extends UnitDamage:
	var per_tick: float
	var ticks: int
	var interval_ms: int

	func _init(battle: BattleSim, from: BattleFighter, damage_per_tick: float, tick_count: int, tick_ms: int, _intermittent := false) -> void:
		super(battle, from)
		per_tick = damage_per_tick
		ticks = tick_count
		interval_ms = tick_ms

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		var interval := Damages.frames(interval_ms / 1000.0)
		sim.electrocute(target, attacker, _part(per_tick, multiplier), ticks, interval)
		# The client ends this damage after a timer of ticks milliseconds, tick_ms times.
		sim.after(Damages.frames(ticks * interval_ms / 1000.0), func() -> void: _finish(target, multiplier))

	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (not target.is_unit() or target.ability == null or not target.ability.immune_to_electricity)


## Kills the target, when its life is max_life or less (DirectKillDamage).
class DirectKill extends UnitDamage:
	var max_life: float

	func _init(battle: BattleSim, from: BattleFighter, life_limit := -1.0) -> void:
		super(battle, from)
		max_life = life_limit

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		if can_apply(target):
			sim.kill(target, _source())
		else:
			_finish(target, multiplier)

	func can_apply(target: BattleFighter) -> bool:
		return super(target) and (max_life < 0 or target.health <= max_life)


## Heals the target by amount (HealthDamage).
class Health extends UnitDamage:
	var amount: float

	func _init(battle: BattleSim, from: BattleFighter, quantity: float) -> void:
		super(battle, from)
		amount = quantity

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		sim.heal(target, floori(amount * multiplier / maxi(num_targets, 1)), attacker)


## Heals the attacker by amount (HealthSelfDamage).
class HealthSelf extends UnitDamage:
	var amount: float

	func _init(battle: BattleSim, from: BattleFighter, quantity: float) -> void:
		super(battle, from)
		amount = quantity

	func apply(_target: BattleFighter, multiplier := 1.0) -> void:
		if not attacker.dead:
			sim.heal(attacker, floori(amount * multiplier), attacker)


## The first damage whose filter takes the target (ChoosedByFilterDamage).
class ChosenByFilter extends UnitDamage:
	var choices: Array = []  # [damage, filter]

	func add(damage: UnitDamage, choice_filter: Callable) -> ChosenByFilter:
		choices.append([damage, choice_filter])
		return self

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		for choice: Array in choices:
			if choice[1].call(target):
				choice[0].apply(target, multiplier)
				return
		_finish(target, multiplier)


## One of the damages at random, by their factors (RandomizedFactorDamage).
## The client subtracts the whole entry instead of its factor while it
## chooses; the port subtracts the factor.
class RandomizedFactor extends UnitDamage:
	var choices: Array = []  # [damage, factor]

	func add(damage: UnitDamage, factor: float) -> RandomizedFactor:
		choices.append([damage, factor])
		return self

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		var total := 0.0
		for choice: Array in choices:
			total += choice[1]
		var roll := sim.rng.randf() * total
		var chosen: UnitDamage = choices.back()[0]
		for choice: Array in choices:
			if roll < choice[1]:
				chosen = choice[0]
				break
			roll -= choice[1]
		if chosen.can_apply(target):
			chosen.apply(target, multiplier)
		else:
			_finish(target, multiplier)


## The damage after delay_ms, on all targets of the wait at once (DelayedDamage).
class Delayed extends UnitDamage:
	var damage: UnitDamage
	var delay_ms: int
	var _targets: Array[BattleFighter] = []

	func _init(battle: BattleSim, from: BattleFighter, inner: UnitDamage, delay: int) -> void:
		super(battle, from)
		damage = inner
		delay_ms = delay

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		_targets.append(target)
		if _targets.size() > 1:
			return
		sim.after(Damages.frames(delay_ms / 1000.0), func() -> void:
			while not _targets.is_empty():
				var next: BattleFighter = _targets.pop_back()
				if next.dead:
					continue
				if damage.can_apply(next):
					damage.apply(next)
				else:
					damage.finished.emit(next, 1.0))


## The target cannot act and dies at the end of an animation of the client
## (DieAnimationDamage). The port does not draw the animation; the target dies
## after ANIMATION_FRAMES.
class DieAnimation extends UnitDamage:
	const ANIMATION_FRAMES := 45

	func _init(battle: BattleSim, from: BattleFighter, _animation := "", _anchor := "enemyAnchor") -> void:
		super(battle, from)

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		if target.is_unit():
			target.incapacitated = true
		sim.after(ANIMATION_FRAMES, func() -> void:
			if not target.dead:
				sim.kill(target, _source()))


## The target rises, takes damage in ticks while it stays up for seconds,
## then falls (LevitateDamage). It cannot act or be pushed meanwhile.
class Levitate extends UnitDamage:
	var stay_seconds: float
	var per_tick: float
	var ticks: int
	var up_seconds := 3.0
	var drop_seconds := 0.2

	func _init(battle: BattleSim, from: BattleFighter, stay: float, damage: float, tick_count: int) -> void:
		super(battle, from)
		stay_seconds = stay
		per_tick = damage / tick_count
		ticks = tick_count

	func with_up_time(seconds: float) -> Levitate:
		up_seconds = seconds
		return self

	func with_drop_time(seconds: float) -> Levitate:
		drop_seconds = seconds
		return self

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		if not can_apply(target) or not target.is_unit():
			return
		target.incapacitated = true
		target.levitating = true
		sim.state_changed.emit(target)
		var up := Damages.frames(up_seconds)
		var interval := Damages.frames(stay_seconds / ticks)
		for i in ticks:
			sim.after(up + interval * (i + 1), func() -> void:
				if not target.dead:
					sim.receive_attack(target, _part(per_tick, multiplier), _source()))
		sim.after(up + interval * ticks + Damages.frames(drop_seconds), func() -> void:
			target.levitating = false
			target.incapacitated = target.frozen or target.stunned or target.in_air
			sim.state_changed.emit(target)
			_finish(target, multiplier))


## The attacker pulls the target to itself for attract_seconds and drains its
## life in ticks: the target loses the points and the attacker gets them
## (AttractDamage). The target goes back to its tile after drop_seconds.
class Attract extends UnitDamage:
	var attract_seconds: float
	var drop_seconds: float
	var per_tick: float
	var ticks: int

	func _init(battle: BattleSim, from: BattleFighter, damage: float, tick_count: int, attract: float, drop: float) -> void:
		super(battle, from)
		attract_seconds = attract
		drop_seconds = drop
		per_tick = damage / tick_count
		ticks = tick_count

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		if not can_apply(target) or not target.is_unit():
			return
		target.incapacitated = true
		target.levitating = true
		sim.state_changed.emit(target)
		var pull := Damages.frames(attract_seconds)
		var interval := Damages.frames(attract_seconds / ticks)
		for i in ticks:
			sim.after(pull + interval * (i + 1), func() -> void:
				if target.dead:
					return
				var points := _part(per_tick, multiplier)
				sim.receive_attack(target, points, _source())
				if not attacker.dead:
					sim.heal(attacker, points, attacker))
		sim.after(pull * 2 + Damages.frames(drop_seconds), func() -> void:
			target.levitating = false
			target.incapacitated = target.frozen or target.stunned or target.in_air
			sim.state_changed.emit(target)
			_finish(target, multiplier))


## Only an animation on the target for seconds (AnimationDummyDamage). The
## port shows nothing; the damage ends after the time.
class AnimationDummy extends UnitDamage:
	var seconds: float

	func _init(battle: BattleSim, from: BattleFighter, _animation: String, duration: float) -> void:
		super(battle, from)
		seconds = duration

	func apply(target: BattleFighter, multiplier := 1.0) -> void:
		sim.after(Damages.frames(seconds), func() -> void: _finish(target, multiplier))


## The target joins the side of the attacker for seconds, then goes back to
## the enemy side of the client (ConvertEnemyToAllieDamage). The client makes
## a new unit with the life of the old one; the port changes the side of the
## same unit (BattleSim.convert()). The client always puts the unit back on
## the enemy side; the port puts it back on its own side.
class ConvertToAlly extends UnitDamage:
	var seconds: int
	var _converted: Array[BattleFighter] = []

	func _init(battle: BattleSim, from: BattleFighter, duration := 6, _colour := 0) -> void:
		super(battle, from)
		seconds = duration

	func apply(target: BattleFighter, _multiplier := 1.0) -> void:
		if not target.is_unit():
			return
		var old_team := target.team
		sim.convert(target, attacker.team)
		target.summoned = true
		_converted.append(target)
		sim.after(seconds * FPS, func() -> void:
			if not target.dead:
				sim.convert(target, old_team)
			_converted.erase(target))
