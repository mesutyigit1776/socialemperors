class_name UnitCard
extends RefCounted
## The card of a unit that the client shows when the mouse is over a unit in
## the first purchase offer (InfoButtonStore6bMC) and in the unit list
## (InfoButtonUnitCollectionMC): the life, attack, attack interval, speed,
## range and population, and the unit in its "thumb" part. The client fits the
## walking unit in a box of THUMB_SIZE, makes it only smaller, and shows it
## only inside the box and a margin of THUMB_MARGIN.

const THUMB_SIZE := Vector2(120, 120)
const THUMB_MARGIN := 8.0
const DIRECTION := 4  ## Down and to the right.


## Fills card and returns the unit graphic in it, or null when the unit has no graphic.
static func fill(card: UiClip, item: GameConfig.ItemDef, sprites: SpriteLibrary) -> UnitSprite:
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
	return unit
