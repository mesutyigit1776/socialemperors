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


## The limit button with a special attack of the unit (initSpecialUnitAttack).
static func limit_special(ability: BattleAbility, action: int, frames: Array[int], attack: Callable) -> void:
	ability.has_limit = true
	add(ability, BattleAbility.LIMIT_BUTTON, "", "", func(sim: BattleSim, fighter: BattleFighter) -> void:
		LimitAttacks.special(sim, fighter, action, frames, func() -> void: attack.call(sim, fighter)), Callable(), "", 0)


## The usual beams of a limit attack: beams of 0.25 seconds every 100 ms.
static func beams(action: int, frames: Array[int], count: int, graphic: String, interval := 100.0, seconds := 0.25, together := 1) -> LimitAttacks.Beams:
	return LimitAttacks.Beams.new(action, frames, interval, count, graphic, seconds, false, together)
