class_name TowersAbility
extends BattleAbility
## Defence buildings whose delegates change the attack.
##
## - dragon_killer (DragonKillerCastleDelegate): each attack takes the nearest
##   dragon in range as target, when there is one. The ray charges for 450 ms,
##   then a beam goes to the target for 0.7 seconds and does the attack when
##   it ends.
## - sky_tower and sky_tower_2 (TowerHighStoneDelegate and
##   TowerHighCashDelegate): a lava ball with the attack, and the target unit
##   burns (5 points every second, 5 times). Sky Tower II has half the attack
##   of its item and fires two balls: the second goes to the nearest other
##   target in range, which becomes its target, or again to the same target.
## - water_tower (WaterTowerDelegate): 7 rows of 5 tiles of water in front of
##   the tower, by its frame, one row every 500 ms. A unit on these tiles flies
##   5 tiles and takes the attack.

const UNITS := {
	1426: "dragon_killer",
	1361: "sky_tower",
	1360: "sky_tower_2",
	429: "water_tower",
}
const RAY_CHARGE := 14  ## 450 ms.
const RAY_FRAMES := 21  ## 0.7 seconds.
const DRAGON_COUNT := 20
const BURN_DAMAGE := 5
const BURN_TICKS := 5
const WATER_ROWS := 7
const WATER_ROW_FRAMES := 15  ## 500 ms.
const WATER_PUSH := 5
## Frame of the water tower -> [step from row to row, step along a row].
const WATER_STEPS := {
	0: [Vector2i(0, 1), Vector2i(1, 0)],
	1: [Vector2i(1, 0), Vector2i(0, 1)],
	2: [Vector2i(0, -1), Vector2i(1, 0)],
	3: [Vector2i(-1, 0), Vector2i(0, 1)],
}

var _kind := ""


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]


func on_added(_sim: BattleSim, fighter: BattleFighter) -> void:
	if _kind == "sky_tower_2":
		fighter.attack /= 2


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	match _kind:
		"dragon_killer":
			var dragons := sim.items_near(fighter.tile, fighter.attack_range, DRAGON_COUNT, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead and item.def.groups == "dragon")
			if not dragons.is_empty():
				sim.set_target(fighter, dragons[0])
			sim.after(RAY_CHARGE, func() -> void:
				var target := fighter.target
				if fighter.dead or target == null or target.dead:
					return
				sim.shoot_beam(fighter, target, target.tile, "p.dragonKillerRay", RAY_FRAMES, fighter.attack))
		"sky_tower":
			_lava_ball(sim, fighter)
		"sky_tower_2":
			_lava_ball(sim, fighter)
			var current := fighter.target
			var others := sim.items_near(fighter.tile, fighter.attack_range, 1, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return item != current and not item.dead and item.is_valid_target())
			if not others.is_empty():
				sim.set_target(fighter, others[0])
			_lava_ball(sim, fighter)
		"water_tower":
			var steps: Array = WATER_STEPS.get(fighter.frame, WATER_STEPS[0])
			for row in range(1, WATER_ROWS + 1):
				sim.after(row * WATER_ROW_FRAMES, func() -> void:
					for i in range(-2, 3):
						var tile: Vector2i = fighter.tile + steps[0] * row + steps[1] * i
						sim.particle(fighter, tile, MagicParticles.WATER, 0, 0, func(attacker: BattleFighter, target: BattleFighter, _value: int) -> void:
							if target != null and target.is_unit() and not target.dead:
								sim.push_in_air(target, attacker, WATER_PUSH)
								sim.receive_attack(target, fighter.def.attack, attacker)))
	return false


static func _lava_ball(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead:
		return
	sim.shoot(fighter, target, "p.lavaBall_01", fighter.attack)
	if target.is_unit():
		sim.incinerate(target, fighter, BURN_DAMAGE, BURN_TICKS, BattleSim.FRAMES_PER_SECOND)
