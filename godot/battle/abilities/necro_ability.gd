class_name NecroAbility
extends BattleAbility
## The base of the necro units (NecroDelegate of the client): a unit that a
## necro unit kills rises in 30 of 100 cases as a summoned skeleton of the
## side of the necro unit, which dies after 15 seconds.

const PERCENT_RISEN := 0.3
const ALIVE_FRAMES := 450
const MINIONS: Array[int] = [808, 797, 818]  ## Sword, axe and archer skeletons.


func on_killed(sim: BattleSim, fighter: BattleFighter, target: BattleFighter) -> void:
	if not target.is_unit() or sim.rng.randf() >= PERCENT_RISEN:
		return
	var tile := target.tile
	var team := fighter.team
	var id := MINIONS[sim.rng.randi_range(0, MINIONS.size() - 1)]
	# The client adds the skeleton at once; the dead unit still covers its tile here.
	sim.after(1, func() -> void:
		var minion := sim.spawn(sim.config_item(id), tile, team)
		if minion == null:
			return
		sim.particle(null, tile, MagicParticles.LIGHTNING_HUGE, 0, 0)
		sim.after(ALIVE_FRAMES, func() -> void:
			if not minion.dead:
				sim.kill(minion)))
