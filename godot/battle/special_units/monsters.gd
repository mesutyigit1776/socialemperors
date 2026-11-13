class_name Monsters
extends SpecialUnit
## Monsters and warriors whose buttons the client writes in their unit
## classes.

const UNITS := {
	2067: "invisible_killer",
	2102: "medieval_samurai",
	2101: "ether_messiah",
	715: "muerte",
	2137: "swap_monster",
	782: "spiky_spider",
}
const COOLDOWN_OLD := 25
const MESSIAH := 2101
const MESSIAH_AXE_SECONDS := 6


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	match kind:
		"invisible_killer":
			# For 8 seconds no enemy can attack the unit.
			add(ability, 0, "Invisible", "invisible_button_2067", func(_s: BattleSim, _f: BattleFighter) -> void:
				_stars(sim, unit)
				unit.invisible = true
				sim.state_changed.emit(unit)
				sim.after(8 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					unit.invisible = false
					sim.state_changed.emit(unit)
					if not unit.dead:
						_stars(sim, unit)))
		"ether_messiah":
			add(ability, 0, "Mega Slash", "2101_botones_ataques_sw1", _messiah_axe(sim, unit), has_target(), "No target within range")
			# For 10 seconds attacks do nothing to the Messiah.
			add(ability, 1, "Ultra Fireball", "2101_botones_ataques_sw2", SpecialAttacks.Frames.new(sim, unit, SP2, [35], func() -> void:
				if unit.untouchable:
					return
				unit.untouchable = true
				sim.after(10 * BattleSim.FRAMES_PER_SECOND, func() -> void: unit.untouchable = false)), Callable(), "No target within range")
			# For 8 seconds, at frame 5 of each loop, the 10 nearest enemy units
			# within 5 tiles take a quarter of the attack and fly 5 tiles.
			add(ability, 2, "Hyper Whirlwind", "2101_botones_ataques_sw5", SpecialAttacks.Frames.new(sim, unit, SP3, [5], func() -> void:
				for enemy in sim.items_near(unit.tile, 5, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.receive_attack(enemy, unit.attack / 4, unit)
					if not enemy.dead:
						sim.push_in_air(enemy, unit, 5), 8).with_incapacitate(false))
			# Two ghosts of the Messiah go 5 tiles up and down from him and do
			# the axe attack; then the Messiah does it too. The ghosts go away
			# after their attack.
			add(ability, 3, "God Minions", "2101_botones_ataques_sw3", func(_s: BattleSim, _f: BattleFighter) -> void:
				unit.incapacitated = true
				sim.state_changed.emit(unit)
				for ghost_step: Array in [[Vector2i(0, 5), 15], [Vector2i(0, -5), 18]]:
					var ghost := sim.spawn(sim.config_item(MESSIAH), unit.tile + ghost_step[0], unit.team)
					if ghost == null:
						continue
					sim.after(ghost_step[1], func() -> void:
						if ghost.dead:
							return
						_messiah_axe(sim, ghost).execute()
						sim.after(MESSIAH_AXE_SECONDS * BattleSim.FRAMES_PER_SECOND + 15, func() -> void:
							if ghost in sim.fighters:
								sim.remove_item(ghost)))
				sim.after(18, func() -> void:
					if not unit.dead:
						_messiah_axe(sim, unit).execute()))
		"medieval_samurai":
			# The first unit of the directional attack dies when it has at most
			# 500 life, else it takes 300 points and flies 10 tiles; the
			# others take a quarter of the attack and fly 4 tiles.
			add(ability, 0, "Mega Slash", "2102_1_v2", SpecialAttacks.Frames.new(sim, unit, SP1, [27], func() -> void:
				var first := true
				for enemy in directional_hits(sim, unit, 10):
					if enemy.dead:
						continue
					if first:
						first = false
						if enemy.max_life() <= 500:
							sim.kill(enemy, unit)
						else:
							sim.receive_attack(enemy, 300, unit)
							sim.push_in_air(enemy, unit, 10)
					else:
						sim.receive_attack(enemy, int(atk / 4), unit)
						sim.push_in_air(enemy, unit, 4)), has_target(), "No target within range")
			add(ability, 1, "Ultra Fireball", "2102_2_v2", SpecialAttacks.Frames.new(sim, unit, SP2, [23], func() -> void:
				var wave := Damages.Sequenced.new(sim, unit).add(Damages.PushInAir.new(sim, unit, atk, 7)).add(Damages.Freeze.new(sim, unit, 30, 3, 3))
				for enemy in sim.items_near(unit.tile, 5, 10, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					if wave.can_apply(enemy):
						wave.apply(enemy)), Callable(), "No target within range")
			add(ability, 2, "Hyper Whirlwind", "2102_3_v2", SpecialAttacks.Frames.new(sim, unit, SP4, [15], func() -> void:
				circular_push(sim, unit, 5, 10, int(atk / 4), 6), 8))
			add(ability, 3, "God Minions", "2102_4_v2", SpecialAttacks.Frames.new(sim, unit, SP3, [20], func() -> void: sim.heal(unit, 500, unit)))
		"muerte":
			# The target within 3 tiles takes 500 points.
			add(ability, 0, "¡Muerte súbita!", "botonMuerte", func(_s: BattleSim, _f: BattleFighter) -> void:
				sim.play_special(unit, SP1, 28, {11: func() -> void:
					var target := unit.target
					if target != null and not target.dead and sim.distance(unit, target) <= 3:
						sim.receive_attack(target, 500, unit)
						if target.dead:
							sim.particle(unit, target.tile, MagicParticles.SOUL, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)}, Callable(), true),
					Callable(), "", COOLDOWN_OLD)
		"swap_monster":
			# The monster chews its target in range with at most 500 life.
			var chew_target := func(fighter: BattleFighter) -> bool:
				var target := fighter.target
				return target != null and target.is_unit() and not target.dead and sim.distance(fighter, target) <= fighter.attack_range and target.max_life() <= 500
			add(ability, 0, "", "2137_1", func(_s: BattleSim, _f: BattleFighter) -> void:
				var prey := unit.target
				sim.play_special(unit, SP1, maxi(sim.animation_frames(unit, SP1, 30), 18), {17: func() -> void:
					if not prey.dead:
						prey.incapacitated = true
						prey.swallowed = true
						sim.state_changed.emit(prey)}, func() -> void:
							if not prey.dead:
								sim.kill(prey, unit), true),
					func(_s: BattleSim, fighter: BattleFighter) -> bool: return chew_target.call(fighter), NO_TARGET)
			var frames: Array[int] = []
			for frame in range(20, 106, 5):
				frames.append(frame)
			add(ability, 1, "", "2137_2", SpecialAttacks.Frames.new(sim, unit, SP3, frames, func() -> void:
				circular_push(sim, unit, 6, 10, int(atk), 7)))
			# 10 minions for 12 seconds, when none is alive.
			add(ability, 2, "", "2137_3", SpecialAttacks.Frames.new(sim, unit, SP2, [17], func() -> void:
				var minions := unit.ability.spawn_minions(sim, unit, 2146, 10)
				for minion in minions:
					minion.grows_in = true
				sim.after(12 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					for minion in minions:
						if not minion.dead:
							sim.kill(minion, unit))), below_minions(1), "10 " + MINIONS_MAX)
		"spiky_spider":
			add(ability, 0, "spikyspider_jump", "spikyspider_jump", SpecialAttacks.Frames.new(sim, unit, SP3, [37], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 20, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead):
					sim.push_in_air(enemy, unit, 7)
					sim.receive_attack(enemy, int(atk), unit)
					if unit.target == null and not enemy.dead:
						sim.set_target(unit, enemy)), Callable(), "", COOLDOWN_OLD)
			# Its own shot at the 5 nearest enemies within 15 tiles.
			add(ability, 1, "spikyspider_spikes", "spikyspider_spikes", SpecialAttacks.Frames.new(sim, unit, SP1, [19], func() -> void:
				for enemy in sim.items_near(unit.tile, 15, 5, BattleAbility.enemy_side(unit), true, func(item: BattleFighter) -> bool: return not item.dead):
					sim.shoot(unit, enemy, "", unit.attack)), Callable(), "", COOLDOWN_OLD)
			# Three small spiders for 15 seconds, when there are none.
			var spiders: Array[BattleFighter] = []
			add(ability, 2, "spikyspider_spiders", "spikyspider_spiders", SpecialAttacks.Frames.new(sim, unit, SP2, [22], func() -> void:
				if not spiders.is_empty():
					return
				for i in 3:
					var spider := sim.spawn(sim.config_item(783), unit.tile, unit.team)
					if spider == null:
						continue
					if spider.ability != null:
						spider.ability.scale = 0.5
					if unit.target != null:
						sim.set_target(spider, unit.target)
					spiders.append(spider)
				sim.after(15 * BattleSim.FRAMES_PER_SECOND, func() -> void:
					for spider in spiders:
						if not spider.dead:
							sim.kill(spider, null)
					spiders.clear())), Callable(), "", COOLDOWN_OLD)


static func _stars(sim: BattleSim, unit: BattleFighter) -> void:
	sim.particle(unit, unit.tile, MagicParticles.STARS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass, true)


## For 6 seconds, at frame 5 of each loop, each unit of a directional attack
## of 5 tiles with a radius of 3 takes 5 points.
static func _messiah_axe(sim: BattleSim, unit: BattleFighter) -> SpecialAttacks.Frames:
	return SpecialAttacks.Frames.new(sim, unit, SP1, [5], func() -> void:
		for enemy in directional_hits(sim, unit, 5, 3):
			if not enemy.dead:
				sim.receive_attack(enemy, 5, unit), MESSIAH_AXE_SECONDS)
