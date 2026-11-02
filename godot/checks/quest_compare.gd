## Plays the quest of --quest with 1 star and a plan of orders, and prints the course of the battle:
## the enemies, each death with its frame, the orders and the result. tools/ruffle_quest.js plays
## the same plan in the original client; docs/GODOT_BATTLES.md, "Comparison with the original
## client", has the method and the result. This is a measurement, not a check: it does not fail.
##
## godot --path godot --script res://checks/quest_compare.gd -- --data <data folder>
##     --village <copy of a save> --quest <quest id> --plan "<frame>:attack:<x>,<y>;...;<frame>:treasure"
##
## attack: all units of the army attack the enemy nearest to the tile, as "select all" and a click
## on the enemy do. treasure: the player collects the open treasure. --frames sets the last frame.
## The script changes the village file, so give it a copy.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var plan_text: String = args[args.find("--plan") + 1] if args.has("--plan") else ""
	var last_frame: int = int(args[args.find("--frames") + 1]) if args.has("--frames") else 30 * 300
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var screen: QuestScreen = main._quest_screen
	if screen == null:
		print("give --quest <quest id>")
		quit(1)
		return
	for child in screen._windows.get_children():
		if child is QuestStartWindow:
			screen._on_started(1, child)
	await process_frame
	var quest := screen.quest
	var sim := quest.sim
	sim.died.connect(func(f: BattleFighter, killer: BattleFighter) -> void:
		var side := "enemy" if f.team == BattleFighter.Team.ENEMY else "own"
		print("frame %d: died %s %s at %s, killer %s" % [sim.frame, side, f.def.name, f.tile, killer.def.name if killer else "-"]))
	for f in _units(sim, BattleFighter.Team.ENEMY):
		print("enemy %s at %s" % [f.def.name, f.tile])
	var army := _units(sim, BattleFighter.Team.PLAYER)
	print("army: %d units, landing at %s" % [army.size(), army[0].tile if army else Vector2i.ZERO])
	var plan: Array = []
	for step in plan_text.split(";", false):
		var part := step.split(":")
		var xy := part[2].split(",") if part.size() > 2 else PackedStringArray(["0", "0"])
		plan.append([int(part[0]), part[1], Vector2i(int(xy[0]), int(xy[1]))])
	while not quest.is_finished() and sim.frame < last_frame:
		if not plan.is_empty() and sim.frame >= plan[0][0]:
			var step: Array = plan.pop_front()
			if step[1] == "attack":
				var enemies := _units(sim, BattleFighter.Team.ENEMY)
				enemies.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool:
					return (a.tile - step[2]).length_squared() < (b.tile - step[2]).length_squared())
				if not enemies.is_empty():
					sim.order(_units(sim, BattleFighter.Team.PLAYER), enemies[0].tile)
					print("frame %d: order attack %s at %s" % [sim.frame, enemies[0].def.name, enemies[0].tile])
			elif step[1] == "treasure" and quest.is_treasure_open():
				quest.collect(sim.fighters.filter(quest.is_treasure).front())
				print("frame %d: treasure" % sim.frame)
		await process_frame
	print("end at frame %d: finished %s, won %s, gold %d, xp %d, lost %s" % [sim.frame, quest.is_finished(), quest.is_won(), quest.gold, quest.xp, quest.lost_units()])
	quit()


static func _units(sim: BattleSim, team: BattleFighter.Team) -> Array[BattleFighter]:
	var list: Array[BattleFighter] = []
	for f in sim.fighters:
		if f.team == team and f.is_unit() and not f.dead and not f.summoned:
			list.append(f)
	return list
