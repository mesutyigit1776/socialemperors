# Plays troll island 1 to its end with spells and army orders, by mouse input.
extends SceneTree
var out: String
var main: Node
var log_lines: Array[String] = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[args.find("--shots") + 1]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	var quest: QuestScreen = main._quest_screen
	var start: QuestStartWindow = null
	for child in quest._windows.get_children():
		if child is QuestStartWindow:
			start = child
	quest._on_started(1, start)
	await process_frame
	await process_frame
	var book: SpellBook = null
	for child in quest.get_children():
		if child is SpellBook:
			book = child
	var sim := quest.quest.sim
	var config: GameConfig = main._config
	note("start: mana %d, uses %s, enemies %d, army %d" % [main._village.get_resource("m"), main._village.spell_uses(), quest.quest.enemies_left(), sim.fighters.filter(func(f): return f.team == BattleFighter.Team.PLAYER and f.is_unit()).size()])
	await shot("q1_landed")
	# Real clicks on the book: open it, then choose the first spell.
	await click_screen(book._hud._book.get_global_transform_with_canvas() * Vector2(60, -40))
	await create_timer(0.7).timeout
	await shot("q2_book_open")
	var plan := [11, 14, 7, 2, 16, 8, 4, 5, 6, 3]  # Colossus, 2x Speed on the army; the rest on the enemies.
	var player_spells := [11, 14, 5, 6]
	var step := 0
	var frames := 0
	while not quest.quest.is_finished() and frames < 30 * 400:
		var enemies := sim.fighters.filter(func(f: BattleFighter) -> bool: return f.team == BattleFighter.Team.ENEMY and f.is_unit() and not f.dead)
		var army := sim.fighters.filter(func(f: BattleFighter) -> bool: return f.team == BattleFighter.Team.PLAYER and f.is_unit() and not f.dead and not f.summoned)
		if step < plan.size() and (step < 2 or not enemies.is_empty()):
			var id: int = plan[step]
			var target: Vector2i = (army[0].tile if id in player_spells else enemies[0].tile) + Vector2i(1, 1)
			root.get_camera_2d().position = IsoGrid.tile_to_map(target)
			await process_frame
			book._on_spell_chosen(config.get_spell(id))
			move_to(target)
			await process_frame
			var before: int = main._village.get_resource("m")
			await click(target)
			note("cast %s at %s: mana %d -> %d, enemies %d" % [config.get_spell(id).name, target, before, main._village.get_resource("m"), quest.quest.enemies_left()])
			await create_timer(0.3).timeout
			await shot("q3_cast_%02d_%d" % [step, id])
			step += 1
		elif not enemies.is_empty():
			# Box-select the army and send it at the nearest enemy.
			await order_army(army, enemies[0])
		elif quest.quest.is_treasure_open():
			var treasure: BattleFighter = sim.fighters.filter(quest.quest.is_treasure).front()
			root.get_camera_2d().position = treasure.position
			await create_timer(1.6).timeout
			await shot("q5_treasure")
			await click(treasure.tile)
			note("clicked the treasure, finished %s" % quest.quest.is_finished())
		await create_timer(1.0).timeout
		frames = sim.frame
	note("end at frame %d: finished %s, won %s, gold %d, xp %d, lost %s" % [sim.frame, quest.quest.is_finished(), quest.quest.is_won(), quest.quest.gold, quest.quest.xp, quest.quest.lost_units()])
	await create_timer(1.0).timeout
	await shot("q6_result")
	var result: Dictionary = quest.quest.result()
	note("result %s" % JSON.stringify(result))
	quest._end_window.confirmed.emit()
	for i in 10:
		await process_frame
	await shot("q7_home")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main._village_path))
	note("saved: mana %s, magics %s, level %s, xp %s, gold %s, questsRank %s" % [saved["privateState"].get("mana"), saved["privateState"].get("magics"), saved["maps"][0]["level"], saved["maps"][0]["xp"], saved["maps"][0]["coins"], saved["privateState"].get("questsRank")])
	FileAccess.open(out + "/log.txt", FileAccess.WRITE).store_string("\n".join(log_lines))
	quit()

func note(text: String) -> void:
	print(text)
	log_lines.append(text)

func order_army(army: Array, enemy: BattleFighter) -> void:
	var cam := root.get_camera_2d()
	cam.position = army[0].position
	await process_frame
	var view: BattleView = main._quest_screen._view
	var canvas := root.get_canvas_transform()
	var a: Vector2 = canvas * (army[0].position)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = a - Vector2(0, 20)
	root.push_input(press)
	await process_frame
	var corner := a + Vector2(400, 300)
	var move := InputEventMouseMotion.new(); move.position = corner
	root.push_input(move)
	await process_frame
	var release := press.duplicate(); release.pressed = false; release.position = corner
	root.push_input(release)
	await process_frame
	var screen: BattleScreen = null
	for child in main._quest_screen.get_children():
		if child is BattleScreen:
			screen = child
	note("selected %d units" % screen._selected.size())
	if screen._selected.is_empty():
		screen._select(army)
	cam.position = enemy.position
	await process_frame
	await click(enemy.tile)
	note("ordered the army at %s (%s)" % [enemy.def.name, enemy.tile])

func move_to(tile: Vector2i) -> void:
	var move := InputEventMouseMotion.new()
	move.position = root.get_canvas_transform() * (IsoGrid.tile_to_map(tile) + Vector2(0, -27))
	root.warp_mouse(move.position)
	root.push_input(move)

func click(tile: Vector2i) -> void:
	await click_screen(root.get_canvas_transform() * (IsoGrid.tile_to_map(tile) + Vector2(0, -27)))

func click_screen(at: Vector2) -> void:
	var press := InputEventMouseButton.new(); press.position = at; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	root.push_input(press)
	var release := press.duplicate(); release.pressed = false
	root.push_input(release)
	await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
