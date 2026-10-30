class_name DoubleStatSpell
extends BattleSpell
## 2x Speed and 2x Range: up to 20 items of the player within half the area of
## the middle of the square get twice their speed or range for 15, 30 or 45
## seconds, then the value of their configuration. An item that the same spell
## changed before gets its normal value first, so the effects do not add up.
##
## 2x Range also takes buildings, but the client changes only units: at the
## first building it stops with an error. The units before the building keep
## the double range for the rest of the battle, and the units after it get
## nothing. The port does the same. Quests have no buildings of the player.

enum Stat { SPEED, RANGE }

const MULTIPLIER := 2
const SECONDS: Array[int] = [15, 30, 45]
const MAX_ITEMS := 20
const DELAY := 10

var _stat: Stat
var _changed: Array[Array] = []  # The items of each cast whose time is not over.


func _init(stat: Stat) -> void:
	_stat = stat


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var middle := tile - Vector2i.ONE * floori(side / 2.0)
	var found := sim.items_near(middle, ceili(side / 2.0), MAX_ITEMS, BattleFighter.Team.PLAYER, true, func(item: BattleFighter) -> bool:
		return not item.dead and (_stat == Stat.RANGE or item.is_unit()))
	found.reverse()
	_particle(sim, DELAY, _attack_frame, func() -> void:
		var items: Array[BattleFighter] = []
		for item in found:
			if not item.is_unit():
				return
			for earlier in _changed:
				if item in earlier:
					earlier.erase(item)
					_reset(sim, item)
			_double(sim, item)
			items.append(item)
		_changed.append(items)
		sim.after(SECONDS[level - 1] * BattleSim.FRAMES_PER_SECOND, func() -> void:
			for item in items:
				_reset(sim, item)
			_changed.erase(items)))


func _double(sim: BattleSim, unit: BattleFighter) -> void:
	if _stat == Stat.SPEED:
		sim.set_speed(unit, unit.speed * MULTIPLIER)
	else:
		sim.set_attack_range(unit, unit.attack_range * MULTIPLIER)


func _reset(sim: BattleSim, unit: BattleFighter) -> void:
	if _stat == Stat.SPEED:
		sim.set_speed(unit, unit.def.velocity)
	else:
		sim.set_attack_range(unit, unit.def.attack_range)
