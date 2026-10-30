class_name BattleGraphic
extends RefCounted
## The points of the graphic of an item where shots start and where shots aim,
## relative to the position of the item. The client measures them on the
## graphic that the item shows; without a graphic, both are the position.
##
## - A shot starts at the shot point of the graphic, else at a part of its
##   height: 0.6 for arrows, rocks and other stepped shots, 0.75 for the other
##   shots. Buildings start the other shots always at 0.75.
## - A stepped shot aims at the bottom of the target graphic, raised by a part
##   of its height that depends on the shot. The other shots aim at 0.75 of the
##   height.
##
## The client uses the frame that the item shows at that moment. The port uses
## the attack frame in the direction of the target for the shooter, and for a
## target unit the idle frame looking down. These frames differ little in height.
## The client puts the registration point of a building graphic half the width
## of the frame left of the position and the height of the frame above it
## (IsoElement), and the registration point of a unit graphic on the position. The client also looks for a hit point in
## the target graphic; the graphics of the game do not have one.

const SHOT_HEIGHT := 0.75
const STEPPED_SHOT_HEIGHT := 0.6
const TARGET_DIRECTION := 5  ## Down.

var _sprite: SpriteLibrary.ItemSprite
var _is_unit: bool
var _frame: int  ## The frame of a building.


## The graphic of an item, or null when its graphic has no shot data.
static func of(sprite: SpriteLibrary.ItemSprite, is_unit: bool, frame: int) -> BattleGraphic:
	if sprite == null or sprite.frame_origins.is_empty():
		return null
	var graphic := BattleGraphic.new()
	graphic._sprite = sprite
	graphic._is_unit = is_unit
	graphic._frame = frame
	return graphic


## Where a shot at a target at offset from the item starts.
func shot_start(offset: Vector2, stepped: bool) -> Vector2:
	var direction := UnitSprite.direction_to(Vector2.ZERO, offset, TARGET_DIRECTION)
	var frame := UnitSprite.frame_of(UnitSprite.Action.ATTACKING, direction) if _is_unit else _frame
	var point: Variant = _sprite.get_shot_point(frame)
	if point != null and (_is_unit or stepped):
		var mirror := Vector2(-1, 1) if _is_unit and UnitSprite.is_mirrored(direction) else Vector2.ONE
		return (_registration(frame) + point) * mirror
	return Vector2(0, -_sprite.get_frame_size(frame).y * (STEPPED_SHOT_HEIGHT if stepped else SHOT_HEIGHT))


## Where a stepped shot aims: vertical_offset is the part of the height above the bottom.
func stepped_aim(vertical_offset: float) -> Vector2:
	var rect := _body_rect()
	return Vector2(0, rect.end.y - rect.size.y * vertical_offset)


## Where the other shots aim.
func aim() -> Vector2:
	return Vector2(0, -_body_rect().size.y * SHOT_HEIGHT)


func _body_rect() -> Rect2:
	var frame := UnitSprite.frame_of(UnitSprite.Action.IDLE, TARGET_DIRECTION) if _is_unit else _frame
	return Rect2(_registration(frame) + _sprite.get_frame_rect(frame).position, _sprite.get_frame_size(frame))


## The registration point of frame relative to the position of the item.
func _registration(frame: int) -> Vector2:
	if _is_unit:
		return Vector2.ZERO
	var size := _sprite.get_frame_size(frame)
	return Vector2(-floorf(size.x / 2), -size.y)
