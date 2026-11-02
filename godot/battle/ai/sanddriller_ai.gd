class_name SanddrillerAI
extends ThreatAI
## The AI of the Sanddriller, which the Rockdriller boss brings (IASandDriller
## of the client): it attacks by threat, and it dies on the slime of the boss.

const LIFE := 10000
const ATTACK := 100
const ATTACK_INTERVAL := 20
const SPEED := 2

var boss: RockdrillerAI


func _init(unit: GameConfig.ItemDef) -> void:
	super(unit)
	condition = Condition.DEFENSIVE


func on_added(sim: BattleSim, unit: BattleFighter) -> void:
	unit.max_health = LIFE
	unit.health = LIFE
	unit.attack = ATTACK
	unit.attack_interval = ATTACK_INTERVAL
	sim.set_speed(unit, SPEED)


func update(sim: BattleSim, unit: BattleFighter) -> void:
	super(sim, unit)
	attack_threatening_target(sim, unit)
	if boss != null and boss.has_slime(sim, unit.tile):
		sim.kill(unit)
