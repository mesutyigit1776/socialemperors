class_name GodUnitsAbility
extends BattleAbility
## The normal attacks of gods and colossi whose delegates change them. Their
## buttons and limits are in special_units/gods.gd and colossi.gd.
##
## - heaven_god (GodElementalHeavenDelegate): a ray at frame 27 that does the
##   attack and pushes a unit 5 tiles.
## - forest_god (GodElementalForest): a hit; at frame 16 of each attack the 5
##   nearest enemy units in range that can fly jump.
## - iron_god (GodGenesisIronDelegate): 4 knives, at frame 13 and then every 5
##   frames; only the first does damage.
## - wind_god (GodGenesisWindDelegate): an arrow at frame 26.
## - wind_colossus (GenesisWindColossusDelegate): a tornado 13 frames after the
##   attack.
## - ice_colossus and shadow_colossus (GenesisIceColossusDelegate and
##   GenesisShadowColossusDelegate): the 3 (2) nearest units of the enemy side
##   of the player within its range share the attack at frame 8 (frames 10
##   and 20) and fly 5 (3) tiles. The client looks for these units on the
##   enemy side of the player also when the colossus is an enemy.
## - fire_colossus (ColossusFireDelegate): a giant fireball 9 frames after the
##   attack.
## - tiny_fire and tiny_water (TinyFireGodDelegate and TinyWaterGodDelegate):
##   a hit; in each 31 attacks, attack 6, 12, 18, 24 and 30 are special:
##   fire: a slash along 6 tiles that burns (5 points a second for 8 seconds)
##   and makes the units jump; a giant fireball (special attack 2, frame 61)
##   whose blast does 3 times the attack to the 10 nearest enemy units within
##   5 tiles and pushes them 8 tiles; a whirlwind for 5 seconds; 3 minions
##   (item 2076) while at most 3 are alive; and a fire rain (special attack 5,
##   every 5 frames from frame 35 to 115) that burns the 10 nearest enemy
##   units within 5 tiles. water: a ground smash along 6 tiles (the attack and
##   7 tiles of push); it eats up to 3 enemy units within 2 tiles with at most
##   500 life (special attack 3, frames 24, 32 and 40; they die at the end); a
##   whirlwind for 5 seconds (half the attack, 6 tiles); 3 minions (item 2084);
##   and a wave (special attack 4, every 5 frames from frame 35 to 130) that
##   does 1.5 times the attack to the 10 nearest enemy units within 7 tiles
##   and pushes them 8 tiles.

const UNITS := {
	2093: "heaven_god",
	2079: "forest_god",
	2169: "iron_god",
	2156: "wind_god",
	2162: "wind_colossus",
	2235: "ice_colossus",
	2236: "shadow_colossus",
	2077: "fire_colossus",
	2153: "tiny_fire",
	2155: "tiny_water",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const SP3 := SP1 + 2
const SP4 := SP1 + 3
const SP5 := SP1 + 4
const TINY_FREQ := 6
const VULCANO_MINION := 2076
const WATER_MINION := 2084
const SMALL_LIFE := 500

var _kind := ""
var _count := 0


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["forest_god", "tiny_fire", "tiny_water", "ice_colossus", "shadow_colossus"]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	match _kind:
		"heaven_god":
			sim.after(27, func() -> void:
				if fighter.dead or target.dead:
					return
				sim.shoot(fighter, target, "p.heavenRay", fighter.attack, func(_shot: BattleProjectile) -> void:
					if target.is_unit() and not target.dead:
						sim.push_in_air(target, fighter, 5)))
			return false
		"forest_god":
			sim.after(16, func() -> void:
				if fighter.dead:
					return
				for enemy in sim.items_near(fighter.tile, fighter.attack_range, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.push_in_air(enemy, fighter, 0, 20))
			return true
		"iron_god":
			for i in 4:
				sim.after(13 + i * 5, func() -> void:
					if not fighter.dead and not target.dead:
						sim.shoot(fighter, target, "p.godKnife", fighter.attack if i == 0 else -1))
			return false
		"wind_god":
			_shot_after(sim, fighter, target, 26, "p.windArrow")
			return false
		"wind_colossus":
			_shot_after(sim, fighter, target, 13, "p.necroTornado")
			return false
		"ice_colossus", "shadow_colossus":
			var ice := _kind == "ice_colossus"
			var hit := sim.items_near(fighter.tile, fighter.attack_range, 3 if ice else 2, BattleFighter.Team.ENEMY, true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead)
			if hit.is_empty():
				return false
			var events := {}
			for frame in ([8] if ice else [10, 20]):
				events[frame] = func() -> void:
					for enemy in hit:
						if enemy.dead:
							continue
						if enemy.ability == null or not enemy.ability.immune_to_push:
							sim.push_in_air(enemy, fighter, 5 if ice else 3)
						sim.receive_attack(enemy, fighter.attack / hit.size(), fighter)
			play(sim, fighter, UnitSprite.Action.ATTACKING, 25, events, Callable(), true)
			return false
		"fire_colossus":
			sim.after(9, func() -> void:
				if fighter.dead or target.dead:
					return
				var tile := target.tile
				sim.shoot(fighter, target, "p.giantFireball", fighter.attack, func(_shot: BattleProjectile) -> void: sim.effect("b.giantFireExplosion", tile)))
			return false
		"tiny_fire", "tiny_water":
			_tiny_attack(sim, fighter, target)
			_count = _count + 1 if _count < TINY_FREQ * 5 else 0
			return false
	return true


static func _shot_after(sim: BattleSim, fighter: BattleFighter, target: BattleFighter, delay: int, graphic: String) -> void:
	sim.after(delay, func() -> void:
		if not fighter.dead and not target.dead:
			sim.shoot(fighter, target, graphic, fighter.attack))


func _tiny_attack(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	var fire := _kind == "tiny_fire"
	if _count == TINY_FREQ:
		play(sim, fighter, SP1 if fire else SP2, 45, {(40 if fire else 23): func() -> void:
			for enemy in SpecialUnit.directional_hits(sim, fighter, 6):
				if enemy.dead:
					continue
				if fire:
					if enemy.ability != null and enemy.ability.immune_to_burn:
						continue
					sim.push_in_air(enemy, fighter, 0, 20)
					sim.receive_attack(enemy, fighter.attack, fighter)
					sim.incinerate(enemy, fighter, 5, 8, BattleSim.FRAMES_PER_SECOND)
				elif enemy.ability == null or not enemy.ability.immune_to_push:
					sim.receive_attack(enemy, fighter.attack, fighter)
					sim.push_in_air(enemy, fighter, 7)}, Callable(), true)
	elif _count == TINY_FREQ * 2:
		if fire:
			play(sim, fighter, SP2, 65, {61: func() -> void: _mega_ball(sim, fighter)}, Callable(), true)
		else:
			var prey := sim.items_near(fighter.tile, 2, 15, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead and item.max_life() <= SMALL_LIFE).slice(0, 3)
			if prey.is_empty():
				return
			var events := {}
			for i in prey.size():
				events[24 + i * 8] = func() -> void:
					if not prey[i].dead:
						prey[i].incapacitated = true
						prey[i].swallowed = true
						sim.state_changed.emit(prey[i])
			play(sim, fighter, SP3, 45, events, func() -> void:
				for unit: BattleFighter in prey:
					if unit.swallowed and not unit.dead:
						sim.kill(unit, fighter), true)
	elif _count == TINY_FREQ * 3:
		var loop := maxi(sim.animation_frames(fighter, SP3 if fire else SP1, 20), 18)
		var events := {}
		var start := 0
		while start < 5 * BattleSim.FRAMES_PER_SECOND:
			for frame in ([12, 17] if fire else [16]):
				events[start + frame] = func() -> void:
					var reach := 5 if fire else fighter.attack_range + 1
					for enemy in sim.items_near(fighter.tile, reach, 5 if fire else 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
						sim.receive_attack(enemy, fighter.attack if fire else fighter.attack / 2, fighter)
						sim.push_in_air(enemy, fighter, 5 if fire else 6)
			start += loop
		sim.play_special(fighter, SP3 if fire else SP1, 5 * BattleSim.FRAMES_PER_SECOND, events)
	elif _count == TINY_FREQ * 4:
		if minions_alive + 3 <= 6:
			spawn_minions(sim, fighter, VULCANO_MINION if fire else WATER_MINION, 3)
	elif _count == TINY_FREQ * 5:
		var events := {}
		var frame := 35
		while frame <= (115 if fire else 130):
			events[frame] = func() -> void:
				for enemy in sim.items_near(fighter.tile, 5 if fire else 7, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if fire:
						if enemy.ability == null or not enemy.ability.immune_to_burn:
							sim.receive_attack(enemy, fighter.attack, fighter)
							sim.incinerate(enemy, fighter, 5, 8, BattleSim.FRAMES_PER_SECOND)
					elif enemy.ability == null or not enemy.ability.immune_to_push:
						sim.receive_attack(enemy, int(fighter.attack * 1.5), fighter)
						sim.push_in_air(enemy, fighter, 8)
			frame += 5
		play(sim, fighter, SP5 if fire else SP4, 135, events, Callable(), not fire)
	else:
		sim.receive_attack(target, fighter.attack, fighter)


static func _mega_ball(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if target == null or target.dead:
		return
	var tile := target.tile
	sim.shoot(fighter, target, "p.giantFireball", fighter.attack, func(_shot: BattleProjectile) -> void:
		sim.effect("b.giantFireExplosion", tile)
		for enemy in sim.items_near(tile, 5, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
				return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
			sim.receive_attack(enemy, fighter.attack * 3, fighter if fighter in sim.fighters else null)
			if not enemy.dead:
				sim.push_in_air(enemy, fighter, 8))
