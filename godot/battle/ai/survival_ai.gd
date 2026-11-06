class_name SurvivalAI
extends BattleAI
## The enemies of a survival map (IASurvival of the client) go for the relic.
## An enemy that the player attacks fights back until its next update, then
## turns to the relic again. A boss does not fight back and always walks to
## the relic. When the relic is gone, the enemies fight as other units do.

var relic: BattleFighter
var boss := false
var _looking := true  # LOOKING_FOR_TREASURE of the client.


func _init(unit: GameConfig.ItemDef, relic_item: BattleFighter, is_boss: bool) -> void:
	super(unit)
	relic = relic_item
	boss = is_boss
	condition = Condition.DEFENSIVE


func update(sim: BattleSim, unit: BattleFighter) -> void:
	if relic == null or relic.dead:
		super(sim, unit)
		return
	if not unit.attacking or not _looking or boss:
		_look_for_relic(sim, unit)


func on_attacked(sim: BattleSim, unit: BattleFighter, attacker: BattleFighter, damage := 0) -> void:
	if boss and relic != null and not relic.dead:
		return
	super(sim, unit, attacker, damage)
	if unit.target == attacker:
		_looking = false


func on_target_dead(sim: BattleSim, unit: BattleFighter, tile: Vector2i) -> void:
	if relic == null or relic.dead:
		super(sim, unit, tile)
		return
	sim.set_target(unit, null)
	_look_for_relic(sim, unit)


## The unit attacks the relic; when it does not attack yet, or it is a boss,
## it walks to the free tile nearest to the relic.
func _look_for_relic(sim: BattleSim, unit: BattleFighter) -> void:
	_looking = true
	if unit.target != relic:
		sim.attack(unit, relic)
	if not unit.attacking or boss:
		var tile: Variant = BattleFormation.nearest_free_tile(relic.tile, 4, sim.is_free)
		if tile != null:
			sim.walk(unit, tile)
