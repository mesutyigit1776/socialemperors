class_name BattleFighter
extends RefCounted
## One item in a battle: a unit, a building or another item of the map. Only
## BattleSim changes it. Positions are map pixels, see IsoGrid.tile_to_map().

enum Team { PLAYER, ENEMY, NEUTRAL }
## The animation that a unit shows.
enum Pose { IDLE, WALKING, ATTACKING, SPECIAL, DYING }

var def: GameConfig.ItemDef
var team: Team
## The tile of the item. For a building it is the anchor tile of its footprint,
## see Village.footprint(). A unit is on the tile nearest to its position.
var tile: Vector2i
var position: Vector2
var frame := 0  ## The direction of the graphic of a building, as in a save.
## The shot points of the graphic, or null: shots start and aim at the position.
var graphic: BattleGraphic
var look: GameConfig.ItemDef  ## The item whose graphic the unit shows, or null for def; see BattleSim.change_look().
var health: int
var max_health: int  ## The life of the item, or the life that a summoning spell gives.
var attack: int
var defense: int
var attack_interval: int
var attack_range: int
var speed: int  ## Pixels per frame.
var flying: bool
## The client gives each item a random delay of 0 to 4 frames for its attacks.
var attack_delay: int
var ability: BattleAbility
var target: BattleFighter
var targeted_by: Array[BattleFighter] = []
var dead := false
## A spell or an ability brought the unit. Quests do not count it, see QuestBattle.
var summoned := false
## States that spells and abilities give, see BattleSim.stun() and the functions after it.
var incapacitated := false  ## Stunned or frozen: the unit does not walk or attack.
var stunned := false
var frozen := false
var poisoned := false
var burning := false  ## See BattleSim.incinerate().
var electrocuted := false  ## See BattleSim.electrocute().
var converted := false  ## A monk converted the unit to the other side, see BattleSim.convert().
var enlarged := false  ## The unit does 1.5 times the damage and cannot be stunned.
var swallowed := false  ## The unit or building goes into a hole and dies soon.
var opened := false  ## A door that is open, see BattleSim.open_door().
var dizzy := false  ## Stars turn over the unit (DizzyDamage).
var levitating := false  ## The unit floats in the air (LevitateDamage, AttractDamage).
var damage_factor := 1.0  ## The part of each damage that the unit takes (recieveDamageModifier), see ShieldAttack.
var invisible := false  ## Others cannot attack the unit (isInvisible of some delegates).
var cannot_die := false  ## The life does not go below 1 (canDie of the client), during some special attacks.
var untouchable := false  ## Attacks do nothing to the unit, for example under the shield of the Ether Messiah.

# Units only.
var ai: BattleAI
var origin: Vector2i  ## The tile where the unit was at the start.
var added_frame := 0  ## The frame of the battle when the item came on the map.
var attacking := false
var moving := false
var path: Array[Vector2i] = []  ## Tiles after the current walk point.
var walk_point = null  ## The point the unit walks to (Vector2), or null.
var next_point: Vector2  ## The point the unit moves toward in this frame.
var previous_walk_point = null
var animation := Pose.IDLE
var special_index := 0  ## The special attack that comes next, see BattleAbility.
## An animation (UnitSprite.Action) that an ability plays outside the cycle,
## see BattleSim.play_special(); -1 when none plays.
var forced_action := -1
var forced_frames := 0  ## Frames of the forced animation that are left.
var forced_events := {}  # Frame of the forced animation -> Callable.
var forced_frame := 0  # Frames since the forced animation started.
var forced_end := Callable()
var in_air := false  ## The unit flies through the air after a push, see BattleSim.push_in_air().
var special_frames := 0  ## Frames in the current part of the special cycle.
var face_point: Vector2  ## The point that the unit looks at.
var reposition_frames := 0  ## Frames until the unit can follow a walking target again.
var reattack_frames := 0  ## Frames until the unit can walk to its target again.
var remove_frames := 0  ## Frames until a dead unit leaves the map.


func is_unit() -> bool:
	return def.is_unit()


func max_life() -> int:
	return max_health


## Units with BattleSim.SWALLOW_MAX_LIFE or more life are too big to swallow.
func can_be_swallowed() -> bool:
	return not is_unit() or max_health < BattleSim.SWALLOW_MAX_LIFE


func footprint() -> Rect2i:
	return Village.footprint(def, tile)


## Others can attack the fighter, see BattleAbility.is_valid_target().
func is_valid_target() -> bool:
	return not invisible and (ability == null or ability.is_valid_target())


func is_special() -> bool:
	return ability != null and not ability.special_intervals.is_empty()
