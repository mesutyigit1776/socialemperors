class_name SummonSpell
extends BattleSpell
## Golem's Wrath and Yeti's Trail: a golem or a yeti of the player comes on the
## free tile nearest to the tile, within 4 rings, and stays until it dies.

const GOLEM := 630
const YETI := 631
const LIFE: Array[int] = [4000, 5000, 7000]
const RINGS := 4

var _unit_id: int


func _init(unit_id: int) -> void:
	_unit_id = unit_id


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	# The client does not fade the graphic: it stops at its last frame.
	_particle(sim, tile, 0, _attack_frame, func() -> void: summon_near(sim, tile, _config.get_item(_unit_id), LIFE[level - 1]), {"frames": -1})


## The summoned unit, or null when no tile near tile is free.
static func summon_near(sim: BattleSim, tile: Vector2i, unit: GameConfig.ItemDef, life: int) -> BattleFighter:
	var free: Variant = BattleFormation.nearest_free_tile(tile, RINGS, sim.is_free, tile)
	if free == null:
		return null
	return sim.summon(unit, free, BattleFighter.Team.PLAYER, life)


func descriptions(config: GameConfig) -> Array[String]:
	var texts: Array[String] = []
	for life in LIFE:
		texts.append(_fill(config, "SPELL_SUMMON_DESCRIPCION", [life]))
	return texts
