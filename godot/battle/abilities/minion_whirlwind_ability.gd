class_name MinionWhirlwindAbility
extends BattleAbility
## The whirlwind that some gods and colossi summon (MinionWhirlwindDelegate
## of the client). It cannot die. Every 0.75 seconds, up to 5 enemy units
## within 3 tiles take its attack and fly 4 tiles. One second after it comes,
## it moves one time to the nearest enemy unit within 9 tiles that can act.
## The unit that summons it removes it, see stop().

const DAMAGE_FRAMES := 22  ## 0.75 seconds.
const DAMAGE_RANGE := 3
const DAMAGE_COUNT := 5
const PUSH := 4
const DETECTION_RANGE := 9

var _stopped := false


func on_added(sim: BattleSim, fighter: BattleFighter) -> void:
	fighter.cannot_die = true
	sim.after(DAMAGE_FRAMES, func() -> void: _hit(sim, fighter))
	sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
		if fighter.dead or fighter.moving:
			return
		var enemy := sim.nearest_target(fighter, fighter.tile, DETECTION_RANGE, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.incapacitated, false)
		if enemy != null:
			sim.order_walk(fighter, enemy.tile))


func _hit(sim: BattleSim, fighter: BattleFighter) -> void:
	if _stopped or fighter.dead or not fighter in sim.fighters:
		return
	for enemy in BattleAbility.enemy_units_near(sim, fighter, fighter.tile, DAMAGE_RANGE, DAMAGE_COUNT):
		if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
			continue
		sim.receive_attack(enemy, fighter.attack, fighter)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, PUSH)
	sim.after(DAMAGE_FRAMES, func() -> void: _hit(sim, fighter))


## Summons the whirlwind item_id on tile for seconds, then stops and removes it.
static func summon(sim: BattleSim, owner: BattleFighter, item_id: int, tile: Vector2i, seconds: int) -> void:
	var whirl := sim.spawn(sim.config_item(item_id), tile, owner.team)
	if whirl == null:
		return
	sim.after(seconds * BattleSim.FRAMES_PER_SECOND, func() -> void:
		if whirl.ability is MinionWhirlwindAbility:
			whirl.ability._stopped = true
		if whirl in sim.fighters:
			sim.remove_item(whirl))
