class_name SpecialUnitTable
extends RefCounted
## The special units of the port by item id, like CreateIsoElement of the
## client, which makes an IsoSpecialUnit subclass for these ids. Each family
## script has a constant UNITS (item id -> kind) and a static
## make(sim, fighter, ability, kind). See SpecialUnit.

static func _families() -> Array:
	return [
		AncientDragons,
		EpicDragons,
		SavageDragons,
		ArmorDragons,
		ExtremeDragons,
		BahamutDragons,
		Dragons,
		Gods,
		Colossi,
		Heroes,
	]


static func _family(item_id: int) -> Variant:
	for family: Variant in _families():
		if family.UNITS.has(item_id):
			return family
	return null


static func has(item_id: int) -> bool:
	return _family(item_id) != null


## Adds the portrait buttons of the fighter to its ability.
static func make(sim: BattleSim, fighter: BattleFighter, ability: BattleAbility) -> void:
	var family: Variant = _family(fighter.def.id)
	if family != null:
		family.make(sim, fighter, ability, family.UNITS[fighter.def.id])
