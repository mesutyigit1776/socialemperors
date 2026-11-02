class_name SpecialUnit
extends RefCounted
## The portrait buttons of the special units (IsoSpecialUnit and its
## subclasses of the client, one for each kind of unit). Each file in
## special_units/ has a static make(sim, fighter, ability) that adds the
## buttons of its units to the ability; SpecialUnitTable maps the item ids.
## Only the player uses the buttons, see BattleSim.use_button().

const COOLDOWN := 24  ## Seconds; the default cooldown of the client.
const LIMIT_RED_BEAM := "p.electricityRedBeam"  ## BeamDefinition.ELECTRICITY_BEAM_RED
const LIMIT_GREEN_BEAM := "p.healingBeamGreen"  ## BeamDefinition.HEALING_BEAM_GREEN
const NO_TARGET := "NO_VALID_TARGET_IN_RANGE"  ## Text key of the client.
const MINIONS_MAX := "MINIONS_MAX"
## The special animations (ANIMATION_ATTACKING_SPECIAL1 to 9 of the client).
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SP3 := SP1 + 2
const SP4 := SP1 + 3
const SP5 := SP1 + 4
const SP6 := SP1 + 5
const SP7 := SP1 + 6
const SP8 := SP1 + 7
const SP9 := SP1 + 8


## Adds button id with the name, the picture and the action, an Attack of
## SpecialAttacks or a Callable (sim, fighter) -> void.
static func add(ability: BattleAbility, id: int, name: String, thumb: String, action: Variant, can_use := Callable(), cant := "", cooldown := COOLDOWN, cast := 0) -> BattleAbility.UnitButton:
	var run: Callable = action.button_action() if action is SpecialAttacks.Attack else action
	var button := BattleAbility.UnitButton.new(id, name, thumb, cast, cooldown, run, can_use, cant)
	ability.buttons[id] = button
	return button


## The client lets a button work only while the target is a unit in range (hasTarget).
static func has_target() -> Callable:
	return func(sim: BattleSim, fighter: BattleFighter) -> bool:
		return fighter.target != null and not fighter.target.dead and fighter.target.is_unit() and sim.distance(fighter, fighter.target) <= fighter.attack_range


static func has_target_in_range(tiles: int) -> Callable:
	return func(sim: BattleSim, fighter: BattleFighter) -> bool:
		return fighter.target != null and not fighter.target.dead and fighter.target.is_unit() and sim.distance(fighter, fighter.target) <= tiles


## A target unit with a maximum life from low to high, nearer than tiles
## (the attack range when tiles is -1) (hasTargetWithLife).
static func has_target_life(low: int, high: int, tiles := -1) -> Callable:
	return func(sim: BattleSim, fighter: BattleFighter) -> bool:
		var target := fighter.target
		var limit := fighter.attack_range if tiles < 0 else tiles
		return target != null and not target.dead and target.is_unit() and sim.distance(fighter, target) < limit \
				and target.max_life() >= low and target.max_life() <= high


## A button that summons minions while fewer than the maximum of the attack
## are alive (checkMaxMinions; the attack sets the maximum of the unit).
static func add_minions(ability: BattleAbility, id: int, name: String, thumb: String, attack: SpecialAttacks.SpawnMinion) -> void:
	add(ability, id, name, thumb, attack, attack.can_use(), "%d %s" % [attack.max_minions, MINIONS_MAX])


## The enemy units that the directional attack of the client hits
## (doDirectionalAttack): on the tile of the unit and on length tiles in front
## of it, the units within radius of each tile, at most 10 for each tile. A
## unit can be in the list more than once. The list stops after max_hits + 1
## units when max_hits is not -1. The client has only four directions here,
## and for the down direction it uses the next tile length times.
static func directional_hits(sim: BattleSim, unit: BattleFighter, length: int, radius := 4, max_hits := -1) -> Array[BattleFighter]:
	var step := Vector2i.ZERO
	match BattleAbility.direction(unit):
		1, 2: step = Vector2i(0, -1)
		3, 4, 5: step = Vector2i(1, 0)
		6: step = Vector2i(-1, 0)
	var points: Array[Vector2i] = [unit.tile]
	for i in range(1, length + 1):
		points.append(unit.tile + (Vector2i(0, 1) if step == Vector2i.ZERO else step * i))
	var hits: Array[BattleFighter] = []
	for point in points:
		for enemy in sim.items_near(point, radius, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead):
			hits.append(enemy)
			if max_hits != -1 and hits.size() > max_hits:
				return hits
	return hits


## A minion comes out of an egg that the unit throws 4 to 8 tiles in front
## of it (spawnMinionFromEgg).
static func egg_minion(sim: BattleSim, unit: BattleFighter, minion_id: int) -> void:
	var step: Vector2i = BattleAbility.TILE_STEPS[BattleAbility.direction(unit)]
	var tile := (unit.tile + step * sim.rng.randi_range(4, 8)).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
	sim.shoot_at(unit, tile, "p.egg", func(_shot: BattleProjectile) -> void:
		var minion := sim.spawn(sim.config_item(minion_id), tile, unit.team)
		if minion != null:
			unit.ability.add_minion(sim, minion))


## The count nearest enemy units within range_tiles that can fly take damage
## and fly push tiles (attackCircularPushInAir).
static func circular_push(sim: BattleSim, unit: BattleFighter, range_tiles: int, count: int, damage: int, push := 3) -> void:
	for enemy in sim.items_near(unit.tile, range_tiles, count, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, damage, unit)
		if not enemy.dead:
			sim.push_in_air(enemy, unit, push)


## The picture name of button number (from 1) of a unit: "<id>_<name>_button_<number>".
static func thumb(item_id: int, name: String, number: int) -> String:
	return "%d_%s_button_%d" % [item_id, name, number]


## A button that works while fewer than maximum minions are alive (checkMaxMinions).
static func below_minions(maximum: int) -> Callable:
	return func(_sim: BattleSim, fighter: BattleFighter) -> bool: return fighter.ability.minions_alive < maximum


## The limit button with a smash attack (initSmashAttack of the delegate).
static func limit_smash(ability: BattleAbility, action: int, frames: Array[int], multiplier: float, range_tiles: int, push: int) -> void:
	ability.has_limit = true
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		LimitAttacks.smash(sim, fighter, action, frames, multiplier, range_tiles, push), Callable(), "", 0)


## The limit button with lightning beams (initLightingBeamsAttack of the delegate).
static func limit_lightning(ability: BattleAbility, beams: LimitAttacks.Beams) -> void:
	ability.has_limit = true
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		LimitAttacks.lightning_beams(sim, fighter, beams), Callable(), "", 0)


## The limit button with healing beams (initHealingBeamsAttack of the delegate).
static func limit_healing(ability: BattleAbility, beams: LimitAttacks.Beams) -> void:
	ability.has_limit = true
	ability.limit_type = BattleAbility.LimitType.HEALTH
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		LimitAttacks.healing_beams(sim, fighter, beams), Callable(), "", 0)


## The limit button that makes the unit fly for 10 seconds (onFlyingMode):
## it can then pass over walls and water.
static func limit_flying(ability: BattleAbility) -> void:
	ability.has_limit = true
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		fighter.flying = true
		sim.state_changed.emit(fighter)
		sim.after(10 * BattleSim.FRAMES_PER_SECOND, func() -> void:
			fighter.flying = fighter.def.flying
			sim.state_changed.emit(fighter)), Callable(), "", 0)


## A combo (initCombo): while units with all of ids are on the map, the cast
## and cooldown times of the unit go twice as fast (reduceCooldown). The
## client checks every 500 ms; it does not check the side of the units.
static func combo(sim: BattleSim, unit: BattleFighter, ids: Array) -> void:
	var check := func(again: Callable) -> void:
		if unit.dead:
			return
		var present := ids.all(func(id: int) -> bool:
			return sim.fighters.any(func(item: BattleFighter) -> bool: return item.def.id == id and not item.dead))
		unit.ability.cooldown_speed = 2 if present else 1
		sim.after(15, again.bind(again))
	sim.after(15, check.bind(check))


## The limit button with a special attack of the unit (initSpecialUnitAttack).
## can_use and cant are those of the button (canDoSpecialUnitAttack).
static func limit_special(ability: BattleAbility, action: int, frames: Array[int], attack: Callable, can_use := Callable(), cant := "") -> void:
	ability.has_limit = true
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		LimitAttacks.special(sim, fighter, action, frames, func() -> void: attack.call(sim, fighter)), can_use, cant, 0)


## The usual beams of a limit attack: beams of 0.25 seconds every 100 ms.
static func beams(action: int, frames: Array[int], count: int, graphic: String, interval := 100.0, seconds := 0.25, together := 1) -> LimitAttacks.Beams:
	return LimitAttacks.Beams.new(action, frames, interval, count, graphic, seconds, false, together)
