class_name OrcUnitsAbility
extends BattleAbility
## The orcs of the client whose delegates change the normal attack: they
## count their attacks and make a special attack at some counts. The buttons
## of the orcs that are special units are in special_units/gladiators.gd.
##
## - crusher (OrcCrusherDelegate): the target takes the attack 10 frames
##   after the attack starts.
## - kamikaze (OrcKamikaze): a barrel flies to the target in 12 frames; where
##   it lands, the 2 nearest enemy units within 2 tiles take the attack and
##   fly 1 tile, and a building target takes the attack.
## - boomerang (OrcBoomerangDelegate): each fifth attack is a jump (special
##   attack 1, frame 34): the 20 nearest enemy units within 4 tiles take 1.2
##   times the attack and fly 4 tiles.
## - spear (OrcSpearWarriorDelegate): a lance (12 frames). Attacks 3 and 6 of
##   each 9 at a unit are a poisoned lance: at frame 19 of special attack 1
##   the target is poisoned (the attack a second, 2 times). Attack 9 of each 9,
##   when the target is nearer than 2 tiles, is a whirlwind (special attack
##   2): 12 times, at frame 15 of each loop, the 4 nearest enemies in range
##   take the attack, and units fly 3 tiles.
## - monster_rider (MonsterOrcRiderDelegate): each twelfth attack swallows the
##   nearest enemy unit in range when its item has at most 500 life and it is
##   not a boss (special attack 2, frame 16); each eighth attack is a wave
##   (special attack 1, frame 33): the 10 nearest enemy units within 6 tiles
##   fly 5 tiles and are dizzy for 6 seconds.
## - boar_rider (OrcBoarRiderDelegate): each fifth attack (special attack 1,
##   frame 20): the 3 nearest enemy units within 2 tiles of the target take
##   the attack and fly 2 tiles.
## - battering_ram (OrcBatteringRam): a smash at frame 18: a building target
##   takes the attack; for a unit target, the 5 nearest enemy units within 2
##   tiles of it take a quarter of the attack, and each flies 3 tiles one time
##   in two. Each fifth attack at a building (special attack 1, frame 28)
##   does 3 times the attack.
## - dual_axe (OrcDualAxeDelegate): a hit. Attack 5 (special attack 2, frame
##   20) kills a target unit with at most 500 life, else does 3 times the
##   attack, and the target flies 4 tiles. Attack 10 (special attack 1): at 6
##   frames, the 3 nearest enemy units within 2 tiles take the attack and fly
##   5 tiles.
## - priest (OrcPriestDelegate): an energy ball (8 frames). Each sixth attack
##   it also heals itself by 4 times its attack when it is hurt (special
##   attack 1, frame 20). Near the target (2 tiles or less), each fifth attack
##   is a smash (special attack 2, frames 25, 30 and 35): the 10 nearest enemy
##   units within 3 tiles, not on its tile, take half the attack and are held
##   by electricity (5 points a second for 5 seconds).
## - spider_rider (OrcSpiderRiderDelegate): two cannon balls 30 frames after
##   the attack. Near the target, each sixth attack is a smash (special attack
##   1, frame 28): the 5 nearest enemy units within 4 tiles take the attack,
##   and those with at most 500 life freeze (5 points a second for 5 seconds).
##   Farther away, each fourth attack is a web (special attack 2, frame 17):
##   the target takes the attack, and a unit with at most 500 life freezes.
## - two_heads (TwoHeadedOrc): a spiked ball 20 frames after the attack: the
##   target takes the attack and jumps, and the 2 nearest enemy units within 2
##   tiles of it, not on its tile, take a quarter of the attack and jump.
##   Attack 5 (special attack 2) throws 4 fireballs; attack 10 (special attack
##   1, frame 45) fires a ray at a target in range, which does the attack and
##   then 2 times the attack when it ends.

const UNITS := {
	2027: "crusher",
	2046: "kamikaze",
	2068: "boomerang",
	2030: "spear",
	2056: "monster_rider",
	2029: "boar_rider",
	2074: "battering_ram",
	2061: "dual_axe",
	2054: "priest",
	2031: "spider_rider",
	2066: "two_heads",
}
const SP1 := UnitSprite.Action.SPECIAL
const SP2 := SP1 + 1
const DIZZY_SECONDS := 6
const SMALL_LIFE := 500
const BARREL := "p.barril"
const LANCE := "p.orcWarriorLance"
const POISONED_LANCE := "p.orcWarriorLancePoisoned"
const ENERGY_BALL := "p.energyBall"
const CANNON_BALL := "p.cannonBall"
const WEB := "p.spiderWeb"
const FIREBALL := "p.catapultFireball"
const RAY := "p.dragonKillerRay"

var _kind := ""
var _count := 0  # The attacks so far, as the client counts them.
var _second_count := 0  # A second counter (near and far attacks).


func configure(item_id: int) -> void:
	_kind = UNITS[item_id]
	ranged_melee = _kind in ["monster_rider", "boar_rider", "two_heads"]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if target == null or target.dead:
		return true
	var distance := sim.distance(fighter, target)
	match _kind:
		"crusher":
			sim.after(10, func() -> void:
				if not fighter.dead and fighter.target != null and not fighter.target.dead:
					sim.receive_attack(fighter.target, fighter.attack, fighter))
			return false
		"kamikaze":
			sim.after(12, func() -> void:
				if fighter.dead or target.dead:
					return
				var tile := target.tile
				sim.shoot_at(fighter, tile, BARREL, func(_shot: BattleProjectile) -> void:
					sim.effect("b.explosion", tile)
					for enemy in sim.items_near(tile, 2, 2, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
						sim.receive_attack(enemy, fighter.attack, _alive(sim, fighter))
						if not enemy.dead:
							sim.push_in_air(enemy, fighter, 1)
					if not target.is_unit() and not target.dead:
						sim.receive_attack(target, fighter.attack, _alive(sim, fighter))))
			return false
		"boomerang":
			_count += 1
			if _count % 5 != 0:
				return true
			_count = 0
			play(sim, fighter, SP1, 40, {34: func() -> void:
				for enemy in sim.items_near(fighter.tile, 4, 20, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
					sim.push_in_air(enemy, fighter, 4)
					sim.receive_attack(enemy, int(fighter.attack * 1.2), fighter)}, Callable(), true)
			return false
		"spear":
			_count += 1
			if (_count % 9 == 3 or _count % 9 == 6) and target.is_unit():
				play(sim, fighter, SP1, 30, {19: func() -> void:
					if fighter.target != null and fighter.target.is_unit() and not fighter.target.dead:
						sim.poison(fighter.target, fighter.attack, 2, 0, fighter)})
				_shot_after(sim, fighter, target, 12, POISONED_LANCE)
			elif _count % 9 == 0 and distance < 2:
				var loop := sim.animation_frames(fighter, SP2, 30)
				var events := {}
				for i in 12:
					events[i * loop + 15] = func() -> void: _spear_whirlwind(sim, fighter)
				sim.play_special(fighter, SP2, 11 * loop + 15, events)
			else:
				_shot_after(sim, fighter, target, 12, LANCE)
			return false
		"monster_rider":
			_count += 1
			if _count % 12 == 0:
				var prey := sim.nearest_enemy(fighter, fighter.tile, fighter.attack_range)
				if prey != null and prey.is_unit():
					sim.set_target(fighter, prey)
					play(sim, fighter, SP2, 30, {16: func() -> void:
						var eaten := fighter.target
						if eaten != null and eaten.is_unit() and not eaten.dead and eaten.def.life <= SMALL_LIFE and eaten.def.subcat_functional != BattleSim.SUBCAT_BOSS:
							sim.receive_attack(eaten, eaten.def.life * 2, fighter)}, Callable(), true)
				return false
			if _count % 8 != 0:
				return true
			play(sim, fighter, SP1, 40, {33: func() -> void:
				for enemy in sim.items_near(fighter.tile, 6, 10, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
					if enemy.ability != null and enemy.ability.immune_to_push:
						continue
					sim.push_in_air(enemy, fighter, 5)
					sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not enemy.dead and not enemy.dizzy:
							Damages.Dizzy.new(sim, fighter, 0, DIZZY_SECONDS, 1).apply(enemy))}, Callable(), true)
			return false
		"boar_rider":
			_count += 1
			var normal := _count != 5
			if not normal:
				play(sim, fighter, SP1, 30, {20: func() -> void:
					if fighter.target != null and not fighter.target.dead:
						_push_near(sim, fighter, fighter.target.tile, 2, 3, fighter.attack, 2)}, Callable(), true)
			if _count >= 5:
				_count = 0
			return normal
		"battering_ram":
			_count += 1
			if _count == 5 and not target.is_unit():
				play(sim, fighter, SP1, 40, {28: func() -> void:
					var smashed := fighter.target
					if smashed == null or smashed.dead:
						return
					if smashed.is_unit():
						_push_near(sim, fighter, smashed.tile, 2, 5, fighter.attack / 4, 8)
					else:
						sim.receive_attack(smashed, fighter.attack * 3, fighter)}, Callable(), true)
			else:
				sim.after(18, func() -> void: _ram_smash(sim, fighter))
			if _count >= 5:
				_count = 0
			return false
		"dual_axe":
			_count += 1
			if _count == 5:
				play(sim, fighter, SP2, 30, {20: func() -> void:
					var cut := fighter.target
					if cut == null or cut.dead or not cut.is_unit():
						return
					if cut.max_life() <= SMALL_LIFE:
						sim.kill(cut, fighter)
					else:
						sim.receive_attack(cut, fighter.attack * 3, fighter)
					sim.push_in_air(cut, fighter, 4)}, Callable(), true)
			elif _count == 10:
				var events := {}
				for frame in [36, 40, 46, 52, 59, 65]:
					events[frame] = func() -> void: _push_near(sim, fighter, fighter.tile, 2, 3, fighter.attack, 5)
				play(sim, fighter, SP1, 70, events, Callable(), true)
			else:
				sim.receive_attack(target, fighter.attack, fighter)
			if _count >= 10:
				_count = 0
			return false
		"priest":
			_count += 1
			if _count == 6 and fighter.health < fighter.max_life():
				play(sim, fighter, SP1, 30, {20: func() -> void: sim.heal(fighter, fighter.attack * 4, fighter)}, Callable(), true)
			if _count >= 6:
				_count = 0
			if distance > 2:
				_shot_after(sim, fighter, target, 8, ENERGY_BALL)
				return false
			_second_count += 1
			if _second_count == 5:
				var events := {}
				for frame in [25, 30, 35]:
					events[frame] = func() -> void:
						for enemy in sim.items_near(fighter.tile, 3, 10, enemy_side(fighter), false, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead and not item.electrocuted):
							sim.receive_attack(enemy, fighter.attack / 2, fighter)
							sim.electrocute(enemy, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND)
				play(sim, fighter, SP2, 40, events, Callable(), true)
			else:
				_shot_after(sim, fighter, target, 8, ENERGY_BALL)
			if _second_count >= 5:
				_second_count = 0
			return false
		"spider_rider":
			if distance <= 2:
				_count += 1
				if _count == 6:
					play(sim, fighter, SP1, 40, {28: func() -> void: _spider_smash(sim, fighter)}, Callable(), true)
				else:
					_cannon_balls(sim, fighter, target)
				if _count >= 6:
					_count = 0
			else:
				_second_count += 1
				if _second_count == 4:
					play(sim, fighter, SP2, 30, {17: func() -> void:
						var webbed := fighter.target
						if webbed != null and not webbed.dead:
							sim.shoot(fighter, webbed, WEB, fighter.attack, func(_shot: BattleProjectile) -> void:
								if webbed.dead:
									return
								SpecialUnit.show_particle(sim, fighter, webbed.tile, MagicParticles.SPIDERWEB)
								if webbed.is_unit() and webbed.max_life() <= SMALL_LIFE:
									sim.freeze_with_damage(webbed, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND))}, Callable(), true)
				else:
					_cannon_balls(sim, fighter, target)
				if _second_count >= 4:
					_second_count = 0
			return false
		"two_heads":
			_count += 1
			if _count == 5:
				var near := sim.nearest_enemy(fighter, fighter.tile, fighter.attack_range)
				if near != null:
					sim.set_target(fighter, near)
				var events := {}
				for frame in [40, 51, 62, 73]:
					events[frame] = func() -> void:
						if fighter.target != null and not fighter.target.dead:
							var tile := fighter.target.tile
							sim.shoot(fighter, fighter.target, FIREBALL, fighter.attack, func(_shot: BattleProjectile) -> void: sim.effect("b.earthFire", tile))
				play(sim, fighter, SP2, 80, events, Callable(), true)
			elif _count == 10:
				var near := sim.nearest_enemy(fighter, fighter.tile, fighter.attack_range)
				if near != null:
					sim.set_target(fighter, near)
				play(sim, fighter, SP1, 50, {45: func() -> void:
					var shot := fighter.target
					if shot == null or shot.dead or sim.distance(fighter, shot) > fighter.attack_range:
						return
					sim.shoot_beam(fighter, shot, shot.tile, RAY, 35, fighter.attack, func(_beam: BattleProjectile) -> void:
						if not shot.dead:
							sim.receive_attack(shot, fighter.attack * 2, _alive(sim, fighter)))}, Callable(), true)
			else:
				sim.after(20, func() -> void: _spiked_ball(sim, fighter))
			if _count >= 10:
				_count = 0
			return false
	return true


static func _alive(sim: BattleSim, fighter: BattleFighter) -> BattleFighter:
	return fighter if fighter in sim.fighters else null


## A shot of graphic at target after delay frames, as the client starts its
## shots with a timer; the shot does the attack.
static func _shot_after(sim: BattleSim, fighter: BattleFighter, target: BattleFighter, delay: int, graphic: String) -> void:
	sim.after(delay, func() -> void:
		if not fighter.dead and not target.dead:
			sim.shoot(fighter, target, graphic, fighter.attack))


## The count nearest enemy units within range_tiles of tile that can fly take
## damage and fly push tiles.
static func _push_near(sim: BattleSim, fighter: BattleFighter, tile: Vector2i, range_tiles: int, count: int, damage: int, push: int) -> void:
	for enemy in sim.items_near(tile, range_tiles, count, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, damage, fighter)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, push)


static func _spear_whirlwind(sim: BattleSim, fighter: BattleFighter) -> void:
	for enemy in sim.items_near(fighter.tile, fighter.attack_range, 4, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return not item.dead):
		sim.receive_attack(enemy, fighter.attack, fighter)
		if enemy.is_unit() and not enemy.dead:
			sim.push_in_air(enemy, fighter, 3)


static func _ram_smash(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if fighter.dead or target == null or target.dead:
		return
	if not target.is_unit():
		sim.receive_attack(target, fighter.attack, fighter)
		return
	for enemy in sim.items_near(target.tile, 2, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, fighter.attack / 4, fighter)
		if not enemy.dead and sim.rng.randi_range(0, 1) == 1:
			sim.push_in_air(enemy, fighter, 3)


static func _spider_smash(sim: BattleSim, fighter: BattleFighter) -> void:
	SpecialUnit.show_particle(sim, fighter, fighter.tile, MagicParticles.SPIDERWEB_LARGE)
	for enemy in sim.items_near(fighter.tile, 4, 5, enemy_side(fighter), true, func(item: BattleFighter) -> bool: return item.is_unit() and not item.dead):
		sim.receive_attack(enemy, fighter.attack, fighter)
		if not enemy.dead and enemy.max_life() <= SMALL_LIFE:
			sim.freeze_with_damage(enemy, fighter, 5, 5, BattleSim.FRAMES_PER_SECOND)
			SpecialUnit.show_particle(sim, fighter, enemy.tile, MagicParticles.SPIDERWEB)


static func _cannon_balls(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	sim.after(30, func() -> void:
		if fighter.dead or target.dead:
			return
		for i in 2:
			sim.shoot(fighter, target, CANNON_BALL, fighter.attack))


static func _spiked_ball(sim: BattleSim, fighter: BattleFighter) -> void:
	var target := fighter.target
	if fighter.dead or target == null or target.dead:
		return
	var tile := target.tile
	sim.receive_attack(target, fighter.attack, fighter)
	if target.is_unit() and not target.dead:
		sim.push_in_air(target, fighter, 0, 15)
	for enemy in sim.items_near(tile, 2, 2, enemy_side(fighter), false, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
		sim.receive_attack(enemy, fighter.attack / 4, fighter)
		if not enemy.dead:
			sim.push_in_air(enemy, fighter, 0, 15)
