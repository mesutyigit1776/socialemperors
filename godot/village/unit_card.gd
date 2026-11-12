class_name UnitCard
extends RefCounted
## The card of a unit that the client shows when the mouse is over a unit in
## the first purchase offer (InfoButtonStore6bMC), the unit list and the super
## pack (InfoButtonUnitCollectionMC): the life, attack, attack interval,
## speed, range and population, and the unit in its "thumb" part. The client
## fits the walking unit in a box of THUMB_SIZE, makes it only smaller, and
## shows it only inside the box and a margin of THUMB_MARGIN. In the unit list
## and the super pack, the unit walks, attacks and makes its first special
## attack in turns, CYCLE_SECONDS each (cycleAnimation).

const THUMB_SIZE := Vector2(120, 120)
const THUMB_MARGIN := 8.0
const DIRECTION := 4  ## Down and to the right.
const CYCLE_SECONDS := 3.0


## Fills card and returns the unit graphic in it, or null when the unit has no
## graphic. With cycle, the unit changes its action every CYCLE_SECONDS.
static func fill(card: UiClip, item: GameConfig.ItemDef, sprites: SpriteLibrary, cycle := false) -> UnitSprite:
	card.set_part_visible("descEspecial", false)
	for pair: Array in [["mcVida/txVida", item.life], ["mcAttack/txAttack", item.attack], ["mcDefense/txDefense", item.attack_interval],
			["mcSpeed/txSpeed", item.velocity], ["mcRange/txRange", item.attack_range], ["mcPop/txPop", item.population]]:
		card.set_text(pair[0], str(pair[1]))
	var sprite := sprites.get_sprite(item.img_name)
	if sprite == null:
		return null
	var frame := UnitSprite.frame_of(UnitSprite.Action.WALKING, DIRECTION)
	var box := Control.new()
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = card.part("thumb").position - Vector2(THUMB_MARGIN, THUMB_MARGIN)
	box.size = THUMB_SIZE + Vector2(THUMB_MARGIN, THUMB_MARGIN) * 2
	card.add_child(box)
	var unit := UnitSprite.new(sprite)
	unit.show_action(UnitSprite.Action.WALKING, DIRECTION)
	var size: Vector2 = sprite.frame_sizes[frame] if frame < sprite.frame_sizes.size() else THUMB_SIZE
	var origin: Vector2 = sprite.frame_origins[frame] if frame < sprite.frame_origins.size() else Vector2.ZERO
	var ratio := maxf(maxf(size.x / THUMB_SIZE.x, size.y / THUMB_SIZE.y), 1.0)
	unit.scale = Vector2.ONE / ratio
	unit.position = Vector2(THUMB_MARGIN, THUMB_MARGIN) + (THUMB_SIZE - size / ratio) / 2 - origin / ratio
	box.add_child(unit)
	if cycle:
		box.add_child(_Cycle.new(unit, sprite.frame_count()))
	return unit


class _Cycle:
	extends Timer
	var _unit: UnitSprite
	var _frames: int
	var _action := UnitSprite.Action.WALKING

	func _init(unit: UnitSprite, frames: int) -> void:
		_unit = unit
		_frames = frames
		wait_time = CYCLE_SECONDS
		autostart = true
		timeout.connect(_next)

	## Walking, then attacking, then the first special attack when the
	## graphic has it, and walking again.
	func _next() -> void:
		if _action == UnitSprite.Action.WALKING:
			_action = UnitSprite.Action.ATTACKING
		elif _action == UnitSprite.Action.ATTACKING and UnitSprite.frame_of(UnitSprite.Action.SPECIAL, DIRECTION) < _frames:
			_action = UnitSprite.Action.SPECIAL
		else:
			_action = UnitSprite.Action.WALKING
		_unit.show_action(_action, DIRECTION)
