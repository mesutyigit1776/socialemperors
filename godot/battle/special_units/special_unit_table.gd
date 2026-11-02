class_name SpecialUnitTable
extends RefCounted
## The special units of the port by item id, like CreateIsoElement of the
## client, which makes an IsoSpecialUnit subclass for these ids. See SpecialUnit.

const SCRIPTS := {
}


static func has(item_id: int) -> bool:
	return SCRIPTS.has(item_id)


## Adds the portrait buttons of the fighter to its ability.
static func make(sim: BattleSim, fighter: BattleFighter, ability: BattleAbility) -> void:
	var script: Variant = SCRIPTS.get(fighter.def.id)
	if script != null:
		script.make(sim, fighter, ability)
