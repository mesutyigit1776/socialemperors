class_name PhoenixEggAbility
extends BattleAbility
## The egg of a phoenix (PhoenixEggDelegate of the client). When nobody
## destroys it within 5 seconds, its phoenix comes out on its tile with a
## quarter of its life, and does not come back again; the egg then stays as
## an empty shell that cannot die.

const HATCH_FRAMES := 150
const PHOENIX_OF_EGG := {1254: 744, 1282: 775}

var _phoenix := 775
var _hatched := false


func configure(item_id: int) -> void:
	_phoenix = PHOENIX_OF_EGG.get(item_id, 775)


func on_added(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.after(HATCH_FRAMES, func() -> void:
		if fighter.dead or _hatched:
			return
		_hatched = true
		var tile := fighter.tile
		sim.remove_item(fighter)
		var phoenix := sim.spawn(sim.config_item(_phoenix), tile, fighter.team, false)
		if phoenix == null:
			return
		phoenix.health = phoenix.health / 4
		if phoenix.ability is PhoenixAbility:
			phoenix.ability.resurrect = false)
