class_name AngelMechAbility
extends BattleAbility
## The Celestial Mech (MechanicAngelDelegate of the client). In its special
## attack, up to 15 enemy units within 2 tiles, not on its tile, in the
## quarter of the map in front of it fly 4 tiles away and take its attack.

func _init() -> void:
	special_intervals = [105]
	special_durations = [35]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if not in_special(fighter, 0):
		return true
	var facing := direction(fighter)
	for unit in sim.items_near(fighter.tile, 2, 15, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and _in_front(fighter.tile, item.tile, facing)):
		sim.push_in_air(unit, fighter, 4)
		sim.receive_attack(unit, fighter.attack, fighter)
	return false


static func _in_front(own: Vector2i, other: Vector2i, facing: int) -> bool:
	match facing:
		4:
			return other.x >= own.x and other.y >= own.y
		8:
			return other.x <= own.x and other.y >= own.y
		6:
			return other.x <= own.x and other.y <= own.y
		2:
			return other.x >= own.x and other.y <= own.y
		5:
			return other.y > own.y
		1:
			return other.y < own.y
		7:
			return other.x < own.x
		3:
			return other.x > own.x
	return false
