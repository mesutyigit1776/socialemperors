class_name NecroWingedAbility
extends NecroAbility
## The Necro Winged Warrior (NecroWingedWarriorDelegate of the client), a
## ranged unit that hits like a melee unit. Within 4 tiles of its target,
## every eighth attack is a necro rain (special attack 2) at frame 7: 20 drops
## within 5 tiles of the target with its attack, after 0 to 30 frames. Else
## near the target (2 tiles or less) it hits; farther away it throws two axes
## at frame 15 (special attack 1): one at the target, one at the nearest item
## of the enemy side of the map within 4 tiles of the target. The client looks
## for this second target on the enemy side also when the warrior is an enemy,
## so then the axe hits an ally of the warrior; the port does the same.

const AXE := "p.necroAxe"

var _attacks := 0


func _init() -> void:
	ranged_melee = true


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	_attacks += 1
	var distance := sim.distance(fighter, fighter.target)
	if distance <= 4 and _attacks % 8 == 0:
		play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 20, {7: func() -> void: arrow_storm(sim, fighter, MagicParticles.NECRO_RAIN, 20, 5, 1.0, 0, 30)})
		return false
	if distance <= 2:
		sim.stop_special(fighter)
		return true
	play(sim, fighter, UnitSprite.Action.SPECIAL, 25, {15: func() -> void:
		var target := fighter.target
		if target == null or target.dead:
			return
		sim.shoot(fighter, target, AXE, fighter.attack)
		var second := sim.items_near(target.tile, 4, 1, BattleFighter.Team.ENEMY, false, func(item: BattleFighter) -> bool: return not item.dead and item != fighter)
		sim.shoot(fighter, second[0] if not second.is_empty() else target, AXE, fighter.attack)})
	return false


func on_leave_fight(sim: BattleSim, fighter: BattleFighter) -> void:
	sim.stop_special(fighter)
