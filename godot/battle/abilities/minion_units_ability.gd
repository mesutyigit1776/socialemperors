class_name MinionUnitsAbility
extends BattleAbility
## Minions and whirlwinds that the client gives their own delegates.
##
## - horror_1 (HorrorAncientDragonMinionDelegate1): no normal attack; at the
##   frames that are multiples of 17, then 31, then 42 (in turn), its target
##   takes its attack over 6 seconds and cannot act meanwhile.
## - dark_1 and dark_4 (DarkHorrorAncientDragonMinionDelegate1 and 4): each
##   attack also does the attack over 6 seconds to the target, which cannot
##   act meanwhile.
## - dark_2 (DarkHorrorAncientDragonMinionDelegate2): each attack also does
##   the attack again 1 second later.
## - exploder (HorrorAncientDragonMinionDelegate3 and
##   DarkHorrorAncientDragonMinionDelegate3): its attack does nothing; when an
##   enemy unit is in its range it dies, and the 5 nearest enemy units in its
##   range, not on its tile, share its attack and fly 4 tiles.
## - rays_whirlwind (RaysWhirlwindDelegate; it cannot die) and
##   rays_whirlwind_mortal (RaysWhirlwindMortalDelegate): in each frame the 5
##   nearest enemy units within 3 tiles that can fly take its attack and fly 4
##   tiles; when they land, electricity holds them for 15 frames (30 points 5
##   times).
## - soul_whirlwind (InfraworldSoulWhirlwindDelegate): no attack. Each second,
##   the 10 nearest enemy units within 4 tiles, not on its tile, take half its
##   attack and fly 3 tiles. It goes after 12 seconds.

const UNITS := {
	2309: "horror_1",
	2371: "dark_1",
	2374: "dark_4",
	2372: "dark_2",
	2311: "exploder", 2373: "exploder",
	2298: "rays_whirlwind",
	2104: "rays_whirlwind_mortal",
	2110: "soul_whirlwind",
}
const HORROR_INTERVALS: Array[int] = [17, 31, 42]
const SOUL_WHIRLWIND_SECONDS := 12

var _kind := ""
var _interval := 0
var _attack := 0  # Exploder: the attack, which the client takes from the unit.


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["rays_whirlwind", "rays_whirlwind_mortal"]


func on_added(sim: BattleSim, fighter: BattleFighter) -> void:
	match _kind:
		"exploder":
			_attack = fighter.attack
			fighter.attack = 0
		"rays_whirlwind":
			fighter.cannot_die = true
		"soul_whirlwind":
			for second in range(1, SOUL_WHIRLWIND_SECONDS + 1):
				sim.after(second * BattleSim.FRAMES_PER_SECOND, func() -> void:
					if fighter.dead or not fighter in sim.fighters:
						return
					if second == SOUL_WHIRLWIND_SECONDS:
						sim.remove_item(fighter)
						return
					for enemy in sim.items_near(fighter.tile, 4, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
						sim.receive_attack(enemy, fighter.attack / 2, fighter)
						if not enemy.dead:
							sim.push_in_air(enemy, fighter, 3))


func on_update(sim: BattleSim, fighter: BattleFighter) -> void:
	match _kind:
		"horror_1":
			if sim.frame % HORROR_INTERVALS[_interval] != 0:
				return
			_interval = (_interval + 1) % HORROR_INTERVALS.size()
			var target := fighter.target
			var damage := Damages.Simple.new(sim, fighter, fighter.attack)
			if target != null and not target.dead and damage.can_apply(target):
				damage.apply(target)
		"rays_whirlwind", "rays_whirlwind_mortal":
			for enemy in sim.items_near(fighter.tile, 3, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
					return item.is_unit() and not item.dead and not item.in_air and (item.ability == null or not item.ability.immune_to_push)):
				sim.receive_attack(enemy, fighter.attack, fighter)
				if enemy.dead:
					continue
				sim.push_in_air(enemy, fighter, 4)
				var landed := enemy
				sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
					if not landed.dead:
						sim.electrocute(landed, fighter if fighter in sim.fighters else null, 30, 5, 3))


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	match _kind:
		"horror_1", "soul_whirlwind":
			return false
		"dark_1", "dark_4", "dark_2":
			var damage := Damages.Simple.new(sim, fighter, fighter.attack) if _kind != "dark_2" \
					else Damages.Simple.new(sim, fighter, fighter.attack, 1, 1, false)
			if target != null and not target.dead and damage.can_apply(target):
				damage.apply(target)
		"exploder":
			var enemies := sim.items_near(fighter.tile, fighter.attack_range, 5, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead)
			if not enemies.is_empty():
				sim.kill(fighter)
				var push := Damages.PushInAir.new(sim, fighter, _attack / enemies.size(), 4)
				for enemy in enemies:
					if push.can_apply(enemy):
						push.apply(enemy)
				return false
	return true
