class_name DragonSpell
extends BattleSpell
## Summon Dragon: one of 5 Bahamut dragons comes like a golem, see SummonSpell.
## At level 1 it leaves after 30 seconds, at level 2 after 60 seconds, and at
## level 3 it stays. A dragon that leaves fades for half a second and does not
## die.

const DRAGONS: Array[int] = [862, 853, 875, 891, 846]  # Electric, red, golden, black and green
const LIFE: Array[int] = [4000, 5000, 7000]
const STAY_FRAMES: Array[int] = [900, 1800, 0]
const LEAVE_FRAMES := 15


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	_particle(sim, tile, 0, _attack_frame, func() -> void:
		var dragon_id: int = DRAGONS[floori(sim.rng.randf() * DRAGONS.size())]
		var dragon := SummonSpell.summon_near(sim, tile, _config.get_item(dragon_id), LIFE[level - 1])
		if dragon != null and STAY_FRAMES[level - 1] > 0:
			sim.after(STAY_FRAMES[level - 1] + LEAVE_FRAMES, func() -> void:
				if dragon in sim.fighters:
					sim.remove_item(dragon)))


func descriptions(config: GameConfig) -> Array[String]:
	var texts: Array[String] = []
	for life in LIFE:
		texts.append(_fill(config, "SPELL_SUMMON_DRAGON_DESCRIPTION", [life]))
	return texts
