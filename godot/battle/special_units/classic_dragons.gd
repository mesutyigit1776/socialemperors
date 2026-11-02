class_name ClassicDragons
extends SpecialUnit
## The first special dragons, whose attacks the client writes in the unit
## classes. Their cooldown is 25 seconds; the riders (the second id) have the
## limit button.

const UNITS := {
	2037: "rainbow", 2038: "rainbow",
	847: "vulcano", 851: "vulcano",
}
const RIDERS: Array[int] = [2038, 851]
const COOLDOWN_OLD := 25


static func make(sim: BattleSim, unit: BattleFighter, ability: BattleAbility, kind: String) -> void:
	var atk := float(unit.def.attack)
	var rider := unit.def.id in RIDERS
	match kind:
		"rainbow":
			# The dragon becomes another dragon for 20 seconds; it teleports
			# when it walks.
			var forms := [[777, "Crystal Dragon", "2037_botones_ataques_sw1"], [847, "Vulcano Dragon", "2037_botones_ataques_sw2"],
					[826, "Death Dragon", "2037_botones_ataques_sw"], [862, "Electric Bahamut", "2037_botones_ataques_sw4"]]
			for i in forms.size():
				var form: Array = forms[i]
				add(ability, i, form[1], form[2], SpecialAttacks.Frames.new(sim, unit, SP1, [8], func() -> void:
					transform(sim, unit, form[0], 20, SP2)), Callable(), "", COOLDOWN_OLD)
			ability.teleports = true
			if rider:
				limit_lightning(ability, beams(SP3, [16], 50, LIMIT_RED_BEAM))
		"vulcano":
			add(ability, 0, "Shoot Fireballs", "botonbolas_847", SpecialAttacks.Frames.new(sim, unit, SP2, [16, 20, 24, 28, 32, 36], func() -> void:
				var target := unit.target
				if target != null and not target.dead and sim.distance(unit, target) <= unit.attack_range:
					sim.shoot(unit, target, "p.lavaBall_01", unit.attack), 5), Callable(), "", COOLDOWN_OLD)
			add(ability, 1, "Fireball Rain", "botonlluvia_847", SpecialAttacks.Frames.new(sim, unit, SP3, [25], func() -> void:
				BattleAbility.storm_symmetric(sim, unit, MagicParticles.FIRE_METEOR, 3, 1, 7, 20)), Callable(), "", COOLDOWN_OLD)
			var whirl := SpecialAttacks.Frames.new(sim, unit, SP1, [18, 24], func() -> void:
				for enemy in sim.items_near(unit.tile, 2, 10, BattleAbility.enemy_side(unit), false, func(item: BattleFighter) -> bool:
						return item.is_unit() and not item.dead and (item.ability == null or not item.ability.immune_to_push)):
					sim.incinerate(enemy, unit, int(atk / 3), 5, BattleSim.FRAMES_PER_SECOND)
					sim.push_in_air(enemy, unit, 2), 10)
			whirl.incapacitate = false
			add(ability, 2, "Whirlwind Attack", "botongiro_847", whirl, Callable(), "", COOLDOWN_OLD)
			add(ability, 3, "Spawn Draggies", "botonGreenDraggis", func(_s: BattleSim, _f: BattleFighter) -> void: egg_minion(sim, unit, 849),
					below_minions(3), "3 draggies max", COOLDOWN_OLD)
			if rider:
				limit_lightning(ability, beams(SP1, [17], 50, LIMIT_RED_BEAM))
