class_name UnitSprite
extends ClipSprite
## The graphic of a unit. Each frame of a unit graphic is one action in one
## direction: frame = action * FRAMES_PER_ACTION + direction. Most frames
## contain a clip that plays its own frames at the frame rate of the client;
## the others are still images. Directions 6 to 8 use the frames of directions
## 2 to 4, mirrored around the registration point of the unit, which is on its
## position.

## The actions of the client, in the order of the frames. Special attack n
## (from 0) is the action SPECIAL + n.
enum Action { IDLE, WALKING, ATTACKING, DYING, SPECIAL = 6 }

const FRAMES_PER_ACTION := 5
const LAST_UNMIRRORED_DIRECTION := 5


## The direction (1 to 8) in which a unit at from looks at to. The client keeps
## the direction current when to is less than a third of a tile away.
static func direction_to(from: Vector2, to: Vector2, current: int) -> int:
	var delta := to - from
	if absf(delta.x) < IsoGrid.TILE_SIZE.x / 3 and absf(delta.y) < IsoGrid.TILE_SIZE.y / 3:
		return current
	if delta.x > 0:
		return 2 if delta.y < 0 else (4 if delta.y > 0 else 3)
	if delta.x < 0:
		return 6 if delta.y < 0 else (8 if delta.y > 0 else 7)
	return 1 if delta.y < 0 else (5 if delta.y > 0 else current)


## The frame (0-based) of the graphic that shows action in direction.
static func frame_of(action: Action, direction: int) -> int:
	return action * FRAMES_PER_ACTION + (direction - 4 if is_mirrored(direction) else direction) - 1


static func is_mirrored(direction: int) -> bool:
	return direction > LAST_UNMIRRORED_DIRECTION


## Shows the action in direction (1 to 8). A new action or direction
## starts its clip from the first frame. The dying action plays once.
func show_action(action: Action, direction: int) -> void:
	scale.x = -1 if is_mirrored(direction) else 1
	play(frame_of(action, direction), action != Action.DYING)
