class_name NecroUnitsAbility
extends NecroAbility
## Four necro units (NecroMultiArmsDelegate, NecroSharkDelegate,
## NecroWarriorDelegate and NecroWormDelegate of the client). The units they
## kill can rise as skeletons (NecroAbility).
##
## - Necro Multi-arms: every seventh attack, from the first, it spins (special
##   attack 1) for 5 seconds: once each second, up to 20 enemy units within 2
##   tiles fly 3 tiles away and take its attack / 2.2. It can walk while it
##   spins. The other attacks hit at frame 9.
## - Necro Shark Monster (hits like a melee unit): every twelfth attack is a ray
##   (special attack 2) at frame 35 that poisons up to 20 enemy units within 3
##   tiles (20 damage, 2 times); else every fourth attack is a scissors blow
##   (special attack 1) at frame 11 on up to 10 enemies in its range in front of
##   it: its attack, and units fly 2 tiles away.
## - Necro Warrior (hits like a melee unit): near its target it hits at frame
##   12; farther away in its range it shoots two eye beams at frame 15.
## - Necro Worm: next to its target, every sixth attack it eats the best enemy
##   unit within its range - 1 with 350 life or less (special attack 1, both
##   cannot act): at frame 26 the unit takes 10 times its life. Else it spits.

const MULTI_ARMS := 803
const SHARK := 805
const WARRIOR := 795
const WORM := 816
const MAX_LIFE_TO_EAT := 350
const SPINS := 5

var _kind := 0
var _attacks := 0
var _spinning := false


func configure(item_id: int) -> void:
	_kind = item_id
	match item_id:
		SHARK, WARRIOR:
			ranged_melee = true
		WORM:
			shot_graphic = "p.necroSpit"
			shot_delay = 5


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var distance := sim.distance(fighter, fighter.target)
	match _kind:
		MULTI_ARMS:
			if _attacks % 7 == 0:
				_spin(sim, fighter)
			else:
				_hit_at(sim, fighter, 9)
			_attacks += 1
			return false
		SHARK:
			_attacks += 1
			if _attacks % 12 == 0:
				play(sim, fighter, UnitSprite.Action.SPECIAL + 1, 45, {35: func() -> void:
					for unit in enemy_units_near(sim, fighter, fighter.tile, 3, 20, false):
						sim.poison(unit, 20, 2, 0, fighter)})
				return false
			if _attacks % 4 == 0:
				play(sim, fighter, UnitSprite.Action.SPECIAL, 20, {11: func() -> void:
					for enemy in sim.items_near(fighter.tile, fighter.attack_range, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return not item.dead and faces_to(fighter, item)):
						sim.receive_attack(enemy, fighter.attack, fighter)
						if enemy.is_unit():
							sim.push_in_air(enemy, fighter, 2)})
				return false
			return true
		WARRIOR:
			if distance <= 2:
				_hit_at(sim, fighter, 12)
			else:
				play(sim, fighter, UnitSprite.Action.SPECIAL, 25, {15: func() -> void:
					if fighter.target != null and not fighter.target.dead:
						sim.shoot(fighter, fighter.target, "p.necroWarrior", fighter.attack)
						sim.shoot(fighter, fighter.target, "p.necroWarrior", fighter.attack)})
			return false
	# The worm.
	_attacks += 1
	if distance <= 2 and _attacks % 6 == 0:
		var prey := sim.nearest_target(fighter, fighter.tile, fighter.attack_range - 1, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.incapacitated and item.def.life <= MAX_LIFE_TO_EAT and item.def.subcat_functional != BattleSim.SUBCAT_BOSS, false)
		if prey != null:
			prey.incapacitated = true
			play(sim, fighter, UnitSprite.Action.SPECIAL, 35, {26: func() -> void:
				if not prey.dead:
					prey.incapacitated = false
					sim.receive_attack(prey, prey.def.life * 10, fighter)}, Callable(), true)
			return false
	return true


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	if busy and fighter.moving and not _spinning:
		sim.stop_special(fighter)


func _hit_at(sim: BattleSim, fighter: BattleFighter, frame: int) -> void:
	play(sim, fighter, UnitSprite.Action.ATTACKING, frame + 6, {frame: func() -> void:
		if fighter.target != null and not fighter.target.dead:
			sim.receive_attack(fighter.target, fighter.attack, fighter)})


func _spin(sim: BattleSim, fighter: BattleFighter) -> void:
	_spinning = true
	fighter.forced_action = UnitSprite.Action.SPECIAL
	fighter.forced_frames = SPINS * BattleSim.FRAMES_PER_SECOND
	busy = true
	for i in SPINS:
		sim.after(i * BattleSim.FRAMES_PER_SECOND, func() -> void:
			if fighter.dead:
				return
			for unit in enemy_units_near(sim, fighter, fighter.tile, 2, 20):
				sim.push_in_air(unit, fighter, 3)
				sim.receive_attack(unit, int(fighter.attack / 2.2), fighter))
	sim.after(SPINS * BattleSim.FRAMES_PER_SECOND, func() -> void: _spinning = false)
