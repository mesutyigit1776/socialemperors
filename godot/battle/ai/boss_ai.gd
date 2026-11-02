class_name BossAI
extends BattleAI
## The AI of bosses and their helpers (BossIA of the client). A boss looks for
## an enemy within its aggro range when it has no target, also during a forced
## move. It does not help its allies, and when its target dies it waits for
## the next update to find a new one.
##
## When it comes on the map, the client gives the Giant Yeti and the Stone
## Golem boss a life by the level of the player, and the small yeti and golem a
## fixed life.

const SUBCATS: Array[int] = [84, 85]  ## Bosses and their helpers.
const GOLEM_BOSS := 538
const YETI_BOSS := 545
const GOLEM := 537
const YETI := 544
## [minimum level, life], from the highest level down. The client has 1900 for
## the Golem from level 15, probably for 19000; the port keeps the value of the client.
const GOLEM_BOSS_LIFE: Array[Vector2i] = [Vector2i(20, 24000), Vector2i(15, 1900), Vector2i(10, 16000), Vector2i(9, 13000), Vector2i(8, 9000), Vector2i(0, 6000)]
const YETI_BOSS_LIFE: Array[Vector2i] = [Vector2i(20, 12000), Vector2i(15, 9500), Vector2i(10, 8000), Vector2i(9, 6500), Vector2i(8, 4500), Vector2i(0, 3000)]
const GOLEM_LIFE := 100
const YETI_LIFE := 120


func _init(unit: GameConfig.ItemDef) -> void:
	super(unit)
	condition = Condition.AGGRESSIVE


func on_added(sim: BattleSim, unit: BattleFighter) -> void:
	var life := 0
	match unit.def.id:
		GOLEM_BOSS:
			life = _by_level(GOLEM_BOSS_LIFE, sim.player_level)
		YETI_BOSS:
			life = _by_level(YETI_BOSS_LIFE, sim.player_level)
		GOLEM:
			life = GOLEM_LIFE
		YETI:
			life = YETI_LIFE
	if life > 0:
		unit.max_health = life
		unit.health = life


func update(sim: BattleSim, unit: BattleFighter) -> void:
	if not unit.moving and not unit.attacking:
		_turn_now_and_then(sim, unit)
	if unit.target == null:
		var enemy: BattleFighter = sim.nearest_enemy(unit, unit.tile, aggro_range)
		if enemy != null:
			sim.attack(unit, enemy)


func on_attacked(sim: BattleSim, unit: BattleFighter, attacker: BattleFighter, _damage := 0) -> void:
	if unit.dead:
		return
	if unit.target == null or unit.target.attack == 0 or NEAR_ATTACKER_FACTOR * sim.distance(unit, attacker) < sim.distance(unit, unit.target):
		sim.attack(unit, attacker)


func on_ally_attacked(_sim: BattleSim, _unit: BattleFighter, _attacker: BattleFighter) -> void:
	pass


func on_target_dead(sim: BattleSim, unit: BattleFighter, _tile: Vector2i) -> void:
	sim.set_target(unit, null)


static func _by_level(table: Array[Vector2i], level: int) -> int:
	for entry in table:
		if level >= entry.x:
			return entry.y
	return table.back().y
