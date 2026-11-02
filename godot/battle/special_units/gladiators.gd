class_name Gladiators
extends SpecialUnit
## Gladiators, orcs and elf warriors with one or two buttons that the client
## writes in their unit classes. The Red Bull Rider has no button: it pushes
## the enemies near it while it walks.

const UNITS := {
	2151: "chariot",
	2109: "monster",
	2117: "priest",
	2157: "caesar",
	2144: "minotaur",
	2068: "orc_boomerang",
	2062: "orc_spectrum",
	2019: "bull_rider",
	2020: "silver_paladin",
}
const COOLDOWN_OLD := 25
## The frame of the boomerang animation for each direction of the client;
## at that frame the boomerang hits the enemies on that side.
const BOOMERANG_FRAMES := {50: 1, 55: 2, 60: 3, 25: 4, 30: 5, 45: 6, 40: 7, 35: 8}


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rng := unit.attack_range
	match kind:
		"chariot":
			add(ability, 0, "", "2151_1", SpecialAttacks.Frames.new(sim, unit, SP1, [30], func() -> void:
				circular_push(sim, unit, 5, 5, int(atk * 1.25), 6)))
		"monster":
			# For 5 seconds, every 500 ms after 20 frames: the 10 nearest
			# enemies within 4 tiles take a quarter of the attack and fly, and
			# an axe flies at a random enemy in range.
			add(ability, 0, "Multiple Mega Attack", "btn_monster_gladiator_whirlwind", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 20 + 5 * BattleSim.FRAMES_PER_SECOND, {}, Callable(), false)
				for i in 10:
					sim.after(20 + 15 * (i + 1), func() -> void:
						if unit.dead:
							return
						circular_push(sim, unit, 4, 10, int(atk * 0.25))
						var enemies := sim.items_near(unit.tile, rng, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead)
						if not enemies.is_empty():
							sim.shoot(unit, enemies[sim.rng.randi_range(0, enemies.size() - 1)], "p.axeMonster", unit.attack)))
			add(ability, 1, "Jump and Smash", "btn_monster_gladiator_smash", SpecialAttacks.Frames.new(sim, unit, SP2, [45], func() -> void:
				circular_push(sim, unit, 4, 10, int(atk), 5)))
		"priest":
			add(ability, 0, "Spawn Minion", "2117_priest_glad_sp1", SpecialAttacks.Frames.new(sim, unit, SP1, [26], func() -> void:
				var minion := sim.spawn(sim.config_item(2118), unit.tile, unit.team)
				if minion != null:
					unit.ability.add_minion(sim, minion)), below_minions(3), "3 minions max", COOLDOWN_OLD)
		"caesar":
			add(ability, 0, "Mega Slash", "2157_1", SpecialAttacks.Frames.new(sim, unit, SP1, [30], func() -> void:
				for enemy in directional_hits(sim, unit, 5, 4, 5):
					if enemy.dead or (enemy.ability != null and enemy.ability.immune_to_push):
						continue
					sim.receive_attack(enemy, int(atk * 1.5), unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, 5)))
			# For 4 seconds, every 600 ms after 13 frames, the 4 nearest
			# enemies within 6 tiles take the attack and fly 5 tiles.
			add(ability, 1, "Ultra Fireball", "2157_2", SpecialAttacks.Whirlwind.new(sim, unit, SP2, 4, 13,
					Damages.PushInAir.new(sim, unit, atk, 5), 6, 4).with_interval(600))
			# Two tigers for 20 seconds.
			add(ability, 2, "Hyper Whirlwind", "2157_3", SpecialAttacks.Frames.new(sim, unit, SP3, [20], func() -> void:
				var tigers := unit.ability.spawn_minions(sim, unit, 2158, 2)
				sim.after(20 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					for tiger in tigers:
						if not tiger.dead:
							sim.kill(tiger, unit))), below_minions(2), "2 " + MINIONS_MAX)
		"minotaur":
			add(ability, 0, "Mega Slash", "red3_2075", SpecialAttacks.Frames.new(sim, unit, SP1, [33], func() -> void: _rock_holes(sim, unit)))
			# The units of a short directional attack fly 20 tiles and take 4
			# times the attack when they land.
			add(ability, 1, "Ultra Fireball", "red2_2075", SpecialAttacks.Frames.new(sim, unit, SP2, [18], func() -> void:
				for enemy in directional_hits(sim, unit, 3, 2, 3):
					if enemy.dead or enemy.in_air or (enemy.ability != null and enemy.ability.immune_to_push):
						continue
					var target := enemy
					sim.push_in_air(target, unit, 20)
					sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
						if not target.dead:
							sim.receive_attack(target, int(atk * 4), unit))), has_target(), "No target within range")
		"orc_boomerang":
			var events := {}
			for frame: int in BOOMERANG_FRAMES:
				var side: int = BOOMERANG_FRAMES[frame]
				events[frame] = func() -> void: _boomerang_hit(sim, unit, side)
			add(ability, 0, "Boomerang", "btn_orc_boomerang", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP2, maxi(sim.animation_frames(unit, SP2, 60), 60), events, Callable(), true), Callable(), "", COOLDOWN_OLD)
		"orc_spectrum":
			add(ability, 0, "Fireball Attack", "button1_2062", SpecialAttacks.Frames.new(sim, unit, SP1, [30], func() -> void:
				var target := unit.target
				if target == null or target.dead:
					return
				sim.shoot(unit, target, "p.catapultFireball", -1, func(shot: BattleProjectile) -> void:
					var tile := IsoGrid.map_to_tile(shot.end)
					sim.particle(unit, tile, MagicParticles.FIRE_EXPLOSION_SMALL, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
					for enemy in sim.items_near(tile, 2, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
							return item.is_unit() and not item.dead):
						sim.receive_attack(enemy, int(atk), unit)
						if not enemy.dead:
							sim.push_in_air(enemy, unit, 2))), has_target(), "No targets in range")
			add(ability, 1, "Fire Whirlwind", "button2_2062", SpecialAttacks.Frames.new(sim, unit, SP2, [50, 55, 60, 65, 70, 75], func() -> void:
				for enemy in sim.items_near(unit.tile, 4, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_burn)):
					sim.receive_attack(enemy, int(atk / 2), unit)
					sim.incinerate(enemy, unit, 10, 5, BattleSim.FRAMES_PER_SECOND)))
		"bull_rider":
			# Every 500 ms while it walks, the 10 nearest enemies within 2 tiles
			# take a quarter of the attack and fly 1 tile.
			var push := func(again: Callable) -> void:
				if unit.dead:
					return
				if unit.moving:
					circular_push(sim, unit, 2, 10, int(atk / 4), 1)
				sim.after(15, again.bind(again))
			sim.after(15, push.bind(push))
		"silver_paladin":
			add(ability, 0, "Whirlwind Attack", "btn_whirlWind_2020", SpecialAttacks.Frames.new(sim, unit, SP1, [25, 30, 35], func() -> void:
				circular_push(sim, unit, 3, 10, int(atk / 2), 2), 4), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Auto Heal", "btn_autoHeal_2020", SpecialAttacks.Frames.new(sim, unit, SP2, [25], func() -> void:
				sim.heal(unit, 500, unit)), Callable(), "", COOLDOWN_OLD)


## The boomerang hits the 5 nearest enemy units within 7 tiles on the side
## of direction: they fly 2 tiles and take 1.5 times the attack.
static func _boomerang_hit(sim: BattleSim, unit: BattleFighter, direction: int) -> void:
	if unit.dead:
		return
	var here := unit.tile
	var on_side := func(item: BattleFighter) -> bool:
		var d := item.tile - here
		match direction:
			1: return d.y < 0
			2: return d.x >= 0 and d.y <= 0
			3: return d.x > 0
			4: return d.x >= 0 and d.y >= 0
			5: return d.y > 0
			6: return d.x <= 0 and d.y <= 0
			7: return d.x < 0
			_: return d.x <= 0 and d.y >= 0
	for enemy in sim.items_near(here, 7, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
			return item.is_unit() and not item.dead and on_side.call(item)):
		sim.push_in_air(enemy, unit, 2)
		sim.receive_attack(enemy, int(unit.def.attack * 1.5), unit)


## Rock holes of the Minotaur: of the 5 nearest enemy units within 8 tiles,
## every second one with at most 500 life falls into a hole and dies; the
## other holes open on random tiles in range.
static func _rock_holes(sim: BattleSim, unit: BattleFighter) -> void:
	var enemies := sim.items_near(unit.tile, 8, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead)
	var holes: Array[Vector2i] = []
	for i in 5:
		var prey: BattleFighter = enemies[i] if i < enemies.size() else null
		if i % 2 == 0 and prey != null:
			if prey.dead or prey.tile in holes or prey.max_life() > 500:
				continue
			prey.incapacitated = true
			holes.append(prey.tile)
			sim.particle(unit, prey.tile, MagicParticles.ROCK_HOLE, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void:
				prey.swallowed = true
				sim.state_changed.emit(prey)
				sim.after(BattleSim.FRAMES_PER_SECOND, func() -> void:
					if not prey.dead:
						sim.kill(prey, unit)), true)
		else:
			var reach := unit.attack_range
			var tile := (unit.tile + Vector2i(sim.rng.randi_range(-reach, reach), sim.rng.randi_range(-reach, reach))).clamp(Vector2i.ZERO, Vector2i.ONE * (IsoGrid.MAP_TILES - 1))
			if not tile in holes:
				holes.append(tile)
				sim.particle(unit, tile, MagicParticles.ROCK_HOLE, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)
