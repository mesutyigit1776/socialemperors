class_name InstantLimitSpell
extends BattleSpell
## Instant Limit (SpellFullLimitArea of the client): up to 20 units of the
## player within half the area of the middle of the square, which have a limit
## bar, get a full bar when the spell acts, and flash white
## (SpellAlterState.highlightElement, see BattleSim.highlighted).

const MAX_ITEMS := 20
const DELAY := 10


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var middle := tile - Vector2i.ONE * floori(side / 2.0)
	var found := sim.items_near(middle, ceili(side / 2.0), MAX_ITEMS, BattleFighter.Team.PLAYER, true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and item.ability != null and item.ability.has_limit)
	_particle(sim, tile, DELAY, _attack_frame, func() -> void:
		for unit in found:
			unit.ability.limit = unit.ability.limit_max
			sim.highlighted.emit(unit), {"scale": side / 3.0})


func descriptions(config: GameConfig) -> Array[String]:
	return _area_texts(config, "SPELL_FULL_LIMIT_DESCRIPTION", [])
