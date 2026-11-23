extends SceneTree
## Checks the rules of the mini-game of the Rider Academy and the Dragon
## Riding without a window, and the Fast train of the academy.
##
##   godot --headless --path godot --script res://checks/rider_game_check.gd -- --data <data folder>
##
## It needs rider_game/, ui/, config.json and villages/initial.json from an
## import of the unchanged socialemperors files: the levels, the frames of the
## hero and the enemies, and the steps of the riders come from them.
## The exit code is the number of failed checks.

const RIDER_ACADEMY := 1345
const T := 1800000000

var _data: String
var _frames: FrameCache
var _art: RiderArt
var _ui: UiLibrary
var _failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--data")
	if index < 0 or index + 1 >= args.size():
		push_error("Give the data folder: -- --data <folder>")
		quit(1)
		return
	_data = args[index + 1]
	_frames = FrameCache.new()
	root.add_child(_frames)
	_art = RiderArt.load_from(_data, _frames)
	_ui = UiLibrary.load_from(_data, _frames, "rider_game/ui")
	if _art == null or _ui == null:
		push_error("Cannot read the mini-game in '%s'. Import the game files again." % _data)
		quit(1)
		return
	_check_levels()
	_check_sabre()
	_check_skills()
	_check_results()
	_check_fast_train()
	print("rider game checks: %d failed" % _failures)
	quit(_failures)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_failures += 1
		print("FAILED: " + text)


func _game(level: int) -> RiderGame:
	var game := RiderGame.new(_art, _ui, _data, level, 1)
	game.set_process(false)
	game.rng.seed = 5
	root.add_child(game)
	return game


func _steps(game: RiderGame, count: int) -> void:
	for i in count:
		game.step()


## Each level has the enemies of the client, and the ground holds the hero.
func _check_levels() -> void:
	for level in range(1, RiderGame.LEVELS.size() + 1):
		var game := _game(level)
		var expected := 0
		for kind: String in RiderGame.ENEMY_KINDS:
			expected += RiderGame.LEVELS[level].get(kind, []).size()
		_check(game.enemies.size() == expected, "level %d has %d enemies, expected %d" % [level, game.enemies.size(), expected])
		_steps(game, 60)
		var y := game.hero.y
		_steps(game, 30)
		_check(not game.hero.jumping and absf(game.hero.y - y) < 1.0, "level %d: the hero stands on the ground (y %.1f, then %.1f)" % [level, y, game.hero.y])
		game.free()


## A hit of the sabre (skill 1) does 210 / 5 + 15 + 0 to 4 damage to the warrior in front of the hero.
func _check_sabre() -> void:
	var game := _game(1)
	_steps(game, 30)
	var warrior: RiderEnemy = game.enemies[0]
	warrior.x = game.hero.x + 60.0
	warrior.y = game.hero.y
	_steps(game, 5)
	var health := warrior.health
	game.hero.key_down("1")
	game.hero.key_up("1")
	var frames := 0
	while warrior.health == health and frames < 30:
		game.step()
		frames += 1
	_check(health - warrior.health >= 57.0 and health - warrior.health <= 61.0, "the sabre took %.0f health from the warrior, expected 57 to 61" % (health - warrior.health))
	game.free()


## Skills 4 to 6 open at the levels 3, 5 and 7, and each skill waits its cooldown.
func _check_skills() -> void:
	var game := _game(1)
	_steps(game, 30)
	_check(game.hero.can_use(3) and not game.hero.can_use(4), "level 1 has the skills 1 to 3")
	game.hero.use_skill(3)
	_steps(game, RiderHero.COMBAT_FRAMES + 1)
	_check(not game.hero.can_use(3) and game.hero.can_use(2), "Wrath Bolt waits 150 frames; Flip Strike only the end of the attack")
	game.free()
	game = _game(7)
	_steps(game, 30)
	_check(game.hero.can_use(4) and game.hero.can_use(5) and game.hero.can_use(6), "level 7 has all six skills")
	game.hero.use_skill(4)
	_check(game.hero.skill_time[3] == 0 and game._health == game.stamina, "Regeneration heals 100, up to the full health")
	game.free()


## Levels 1 to 7 are won past the end with no enemies, level 8 with the dragon
## dead, and a level is lost when the health reaches 0. The button of the
## result screen reports the result.
func _check_results() -> void:
	var results: Array[bool] = []
	var game := _game(1)
	game.finished.connect(func(won: bool) -> void: results.append(won))
	_steps(game, 30)
	for enemy in game.enemies.duplicate():
		enemy.new_health(2000.0)
	game.hero.key_down("right")
	var frames := 0
	while game.hud.end_screen == null and frames < 900:
		game.step()
		frames += 1
	_check(game.hud.end_screen != null and game.hero.x > RiderGame.EXIT_X, "level 1 is won at the end of the level")
	if game.hud.end_screen != null:
		game.hud.done_pressed.emit()
	_check(results == [true], "the button of the won level reports a win")
	game.free()

	results.clear()
	game = _game(2)
	game.finished.connect(func(won: bool) -> void: results.append(won))
	_steps(game, 30)
	game.hurt_hero(2000.0)
	_check(game.hud.end_screen != null and not game.hero.controlled, "the stakes of a pit (2000) kill the hero")
	game.hud.done_pressed.emit()
	_check(results == [false], "the button of the lost level reports a loss")
	game.free()

	results.clear()
	game = _game(RiderGame.DRAGON_LEVEL)
	game.finished.connect(func(won: bool) -> void: results.append(won))
	_steps(game, 30)
	_check(game.enemies.size() == 1 and game.enemies[0] is RiderFinalBoss, "level 8 is the dragon")
	game.enemies[0].new_health(3000.0)
	_check(game.hud.end_screen != null, "the death of the dragon ends the game")
	game.hud.done_pressed.emit()
	_check(results == [true], "the dragon level reports a win")
	game.free()


## The academy offers Fast train only after the player paid cash to end a wait.
func _check_fast_train() -> void:
	var config := GameConfig.load_from_file(_data.path_join("config.json"))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_data.path_join("villages/initial.json")))
	document["maps"][0].merge({"level": 50, "xp": 2016089205, "expansions": [13, 12]}, true)
	document["maps"][0]["items"].append([RIDER_ACADEMY, 25, 45, 0, T, 0, [], {}])
	document["playerInfo"]["cash"] = 100
	DirAccess.make_dir_recursive_absolute("user://checks")
	var path := "user://checks/rider_game.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	var village := Village.load_from_file(path, config)
	var specials := SpecialActions.new(village, config, RandomNumberGenerator.new())
	var academy := village.item_at(Vector2i(25, 45))
	var ids := func() -> Array:
		return specials.describe(SpecialActions.View.BUILDING, academy, T)[1].map(func(action: Array) -> String: return action[0])
	specials.run("rider:1", academy, T)
	_check(ids.call() == ["rider_train"], "a new rider trains with the mini-game only: %s" % [ids.call()])
	specials.run("rider_train", academy, T)
	specials.run("rider_wait", academy, T)
	_check(ids.call() == ["rider_train", "rider_fast"], "after the wait is paid, Fast train: %s" % [ids.call()])
	_check(specials.run("rider_fast", academy, T).changed and village.rider_wait_seconds(T) > 0, "Fast train does a step and starts the wait")
