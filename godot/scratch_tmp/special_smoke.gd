extends SceneTree
## Scratch: each special unit uses each button against enemy units.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var config := GameConfig.load_from_file(args[args.find("--data") + 1].path_join("config.json"))
	var only := args[args.find("--ids") + 1].split(",") if args.has("--ids") else PackedStringArray()
	var ids: Array = []
	for family: Variant in SpecialUnitTable._families():
		ids.append_array(family.UNITS.keys())
	for id: int in ids:
		if only.size() > 0 and not only.has(str(id)):
			continue
		var def := config.get_item(id)
		if def == null:
			print("MISSING ", id)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = id
		var sim := BattleSim.new(rng)
		sim.config = config
		var unit := sim.add_item(def, Vector2i(30, 30), BattleFighter.Team.PLAYER)
		var enemies: Array[BattleFighter] = []
		for i in 10:
			enemies.append(sim.add_item(config.get_item(509), Vector2i(31 + i % 4, 28 + i / 4 * 2), BattleFighter.Team.ENEMY))
		for f in 40:
			sim.step()
		var used: Array[String] = []
		for b: int in unit.ability.buttons.keys():
			if unit.dead:
				break
			for e in enemies:
				if e.dead and e in sim.fighters:
					sim.remove_item(e)
			enemies.clear()
			for i in 10:
				var e := sim.add_item(config.get_item(509), Vector2i(31 + i % 4, 28 + i / 4 * 2), BattleFighter.Team.ENEMY)
				if e != null:
					enemies.append(e)
			for f in 30:
				sim.step()
			if b == BattleAbility.LIMIT_BUTTON:
				unit.ability.limit = BattleAbility.LIMIT_MAX
			unit.ability.button_state = BattleAbility.ButtonState.IDLE
			var ok := sim.use_button(unit, b)
			var before := sim.fighters.size()
			var start_dead := enemies.filter(func(e: BattleFighter) -> bool: return e.dead).size()
			for f in 400:
				sim.step()
			var killed := enemies.filter(func(e: BattleFighter) -> bool: return e.dead).size() - start_dead
			used.append("%d%s:k%d:m%d" % [b, "" if ok else "x", killed, unit.ability.minions_alive])
		var dead := enemies.filter(func(e: BattleFighter) -> bool: return e.dead).size()
		print("UNIT %d %s buttons=%s enemies_dead=%d life=%d/%d minions=%d" % [id, def.name, ",".join(used), dead, unit.health, unit.max_health, unit.ability.minions_alive])
	quit()
