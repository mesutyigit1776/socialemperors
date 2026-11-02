class_name BattleAbility
extends RefCounted
## The special behaviour of one kind of unit or building, like a delegate of the
## original client. The battle calls the hooks of the ability of a fighter at
## the same points where the client calls its delegate. An ability object
## belongs to one fighter; AbilityTable.create() makes a new one for each fighter.
##
## Abilities are added one kind at a time, see AbilityTable and the files in
## abilities/. Timers of the client in milliseconds become frames at 30
## frames per second.

## A special fighter repeats a cycle of animations while it attacks: the normal
## attack, then special attack n after special_intervals[n] frames, which lasts
## special_durations[n] frames. Empty for fighters without special attacks.
var special_intervals: Array[int] = []
var special_durations: Array[int] = []
## A ranged fighter that hits at once, like a melee fighter, instead of shooting.
var ranged_melee := false
## The shot leaves this number of frames after the attack (projectileDelay).
var shot_delay := 0
## The graphic of the shots in <data>/fx, or "" for the shot of BattleProjectile.
var shot_graphic := ""
## The shots are beams: they go from the fighter to the target at once and
## hurt when they end, after beam_frames.
var beam := false
var beam_frames := 15
## The client draws the fighter this much bigger.
var scale := 1.0
## Effects that do not act on the fighter (canBePushedInAir and the others).
var immune_to_push := false
var immune_to_freeze := false
var immune_to_poison := false
var immune_to_swallow := false
var immune_to_conversion := false
var immune_to_stun := false
var immune_to_burn := false
var immune_to_electricity := false
## The fighter is busy with an action of its own: it does not attack normally (__doingStuff).
var busy := false


## Some abilities serve more kinds of items with small differences.
func configure(_item_id: int) -> void:
	pass


## The fighter came into the battle (onInit).
func on_added(_sim: BattleSim, _fighter: BattleFighter) -> void:
	pass


## Called at each attack of fighter in range of its target. Returns false when
## the normal attack must not happen.
func on_attack(_sim: BattleSim, _fighter: BattleFighter) -> bool:
	return true


## Called in each frame while the fighter is alive (onUpdate).
func on_update(_sim: BattleSim, _fighter: BattleFighter) -> void:
	pass


## An attack of amount points on the fighter. Returns false when the fighter
## takes no damage (onRecibirAtaque).
func on_attacked(_sim: BattleSim, _fighter: BattleFighter, _amount: int, _attacker: BattleFighter) -> bool:
	return true


## The fighter did damage points of damage (onDealedDamage).
func on_damage_done(_sim: BattleSim, _fighter: BattleFighter, _damage: int) -> void:
	pass


## The fighter healed amount points (onDealedHealth).
func on_healing_done(_sim: BattleSim, _fighter: BattleFighter, _amount: int) -> void:
	pass


## The fighter killed target (onKilledTarget).
func on_killed(_sim: BattleSim, _fighter: BattleFighter, _target: BattleFighter) -> void:
	pass


## A shot of the fighter landed (onEndProjectile).
func on_shot_landed(_sim: BattleSim, _fighter: BattleFighter, _shot: BattleProjectile) -> void:
	pass


## The fighter stopped fighting: it has no target any more, or it walks away.
func on_leave_fight(_sim: BattleSim, _fighter: BattleFighter) -> void:
	pass


## The fighter died.
func on_died(_sim: BattleSim, _fighter: BattleFighter) -> void:
	pass


## The fighter can be the target of the attacks of others (isValidTarget).
func is_valid_target() -> bool:
	return true


## The direction in which the fighter looks, as the client counts them: 1 up,
## 2 up-right, 3 right, 4 down-right, 5 down, 6 up-left, 7 left, 8 down-left.
static func direction(fighter: BattleFighter) -> int:
	return UnitSprite.direction_to(fighter.position, fighter.face_point, 5)


## The enemy side of fighter.
static func enemy_side(fighter: BattleFighter) -> BattleFighter.Team:
	return BattleFighter.Team.PLAYER if fighter.team == BattleFighter.Team.ENEMY else BattleFighter.Team.ENEMY


## Plays the animation action (UnitSprite.Action) with its length in the graphic
## of the fighter, or fallback frames without graphics. See BattleSim.play_special().
static func play(sim: BattleSim, fighter: BattleFighter, action: int, fallback: int, events := {}, on_end := Callable(), incapacitate := false) -> void:
	sim.play_special(fighter, action, sim.animation_frames(fighter, action, fallback), events, on_end, incapacitate)


## The enemy units within range tiles of tile, at most count, nearest first.
static func enemy_units_near(sim: BattleSim, fighter: BattleFighter, tile: Vector2i, range_tiles: int, count: int, with_centre := true) -> Array[BattleFighter]:
	return sim.items_near(tile, range_tiles, count, enemy_side(fighter), with_centre, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead)


## The living enemies (units and buildings) within range tiles of tile.
static func enemies_near(sim: BattleSim, fighter: BattleFighter, tile: Vector2i, range_tiles: int, count: int, with_centre := true) -> Array[BattleFighter]:
	return sim.items_near(tile, range_tiles, count, enemy_side(fighter), with_centre, func(item: BattleFighter) -> bool: return not item.dead)


## The client throws eggs and similar shots by the direction of the unit.
const DIRECTION_STEPS := {1: Vector2i(0, -1), 2: Vector2i(1, -1), 3: Vector2i(1, 0), 4: Vector2i(1, 1), 5: Vector2i(0, 1), 6: Vector2i(-1, -1), 7: Vector2i(-1, 0), 8: Vector2i(-1, 1)}
const EGG := "p.egg"


## Throws an egg 4 to 7 tiles in front of the fighter, from which a summoned
## unit_id comes on the nearest free tile. on_spawn gets the unit.
static func throw_egg(sim: BattleSim, fighter: BattleFighter, unit_id: int, on_spawn := Callable()) -> void:
	var step: Vector2i = DIRECTION_STEPS[direction(fighter)]
	var tile := fighter.tile + Vector2i(step.x * sim.rng.randi_range(4, 7), step.y * sim.rng.randi_range(4, 7))
	tile = tile.clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
	var team := fighter.team
	sim.shoot_at(fighter, tile, EGG, func(_shot: BattleProjectile) -> void:
		var unit := sim.spawn(sim.config_item(unit_id), tile, team)
		if unit != null and on_spawn.is_valid():
			on_spawn.call(unit))


## count magic particles of type on random tiles within spread tiles of the
## target of the fighter (or of the fighter), each with multiplier times its
## attack, after delay to delay + extra frames (attackSpecialArrowStorm).
static func arrow_storm(sim: BattleSim, fighter: BattleFighter, type: int, count := 10, spread := 2, multiplier := 1.0, delay := 20, extra := 10) -> void:
	var centre := fighter.target.tile if fighter.target != null else fighter.tile
	for i in count:
		var tile := centre + Vector2i(-spread + roundi(sim.rng.randf() * spread * 2), -spread + roundi(sim.rng.randf() * spread * 2))
		sim.particle(fighter, tile, type, int(fighter.attack * multiplier), delay + roundi(sim.rng.randf() * extra))


## Magic particles of type on each tile within spread tiles of the target of
## the fighter (attackSpecialStormSymmetric).
static func storm_symmetric(sim: BattleSim, fighter: BattleFighter, type: int, spread := 2, multiplier := 1.0, delay := 20, extra := 10) -> void:
	var centre := fighter.target.tile if fighter.target != null else fighter.tile
	for dy in range(-spread, spread + 1):
		for dx in range(-spread, spread + 1):
			sim.particle(fighter, centre + Vector2i(dx, dy), type, int(fighter.attack * multiplier), delay + roundi(sim.rng.randf() * extra))


## The fighter walked onto a new tile (onEnterTile).
func on_enter_tile(_sim: BattleSim, _fighter: BattleFighter) -> void:
	pass


## The directions in the order of a turn, as the client counts them.
const DIRECTION_RING: Array[int] = [1, 2, 3, 4, 5, 8, 7, 6]


## True when other is not behind the fighter: the client excludes the three
## directions opposite to the one in which the fighter looks (facesTo).
static func faces_to(fighter: BattleFighter, other: BattleFighter) -> bool:
	var own := DIRECTION_RING.find(direction(fighter))
	var to := DIRECTION_RING.find(UnitSprite.direction_to(fighter.position, other.position, direction(fighter)))
	var turn := (to - own + 8) % 8
	return turn < 3 or turn > 5


## True when the special animation n (from 0) of the cycle is playing.
static func in_special(fighter: BattleFighter, n: int) -> bool:
	return fighter.animation == BattleFighter.Pose.SPECIAL and fighter.special_index == n
