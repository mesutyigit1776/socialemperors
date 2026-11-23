class_name RiderGame
extends Node2D
## The mini-game of the Dragon Riding and the Rider Academy (SagaOTDC.swf of
## the client): one training level on a screen of 650 x 500 pixels. The
## Rider Academy plays the level of its next training step (1 to 7), the
## Dragon Riding plays level 8, the dragon.
##
## The hero runs to the right; the screen follows him while he is between the
## start and the end of the level (x0 from -100 to the length of the level),
## then he moves on the screen. Levels 1 to 7 are won when all enemies are dead
## and the hero walks past x 500 at the end; level 8 when the dragon dies. The
## level is lost when the health of the hero reaches 0. The game runs at the
## 30 frames per second of the client. `finished` reports the result after
## the player clicks the button of the result screen.

signal finished(won: bool)

const SIZE := Vector2(650.0, 500.0)
## The level of the dragon, which the Dragon Riding plays.
const DRAGON_LEVEL := 8
const FRAME_SECONDS := 1.0 / 30.0
const GRAVITY := 0.98
const X_FRICTION := 0.85
const Y_FRICTION := 0.96
const MAX_Y_SPEED := 12.0
## The health of the hero (the stamina of the client without upgrades), and the
## health that comes back every REGENERATION_FRAMES frames.
const STAMINA := 500.0
const REGENERATION := 5.0
const REGENERATION_FRAMES := 100
## The hero stays between these x on the screen while the screen does not follow him.
const HERO_MIN_X := 20.0
const HERO_MAX_X := 670.0
## Levels 1 to 7 end when the hero passes this x with no enemy left.
const EXIT_X := 500.0
## The background of the client (sprite 55 of the file) is lighter: its colour times 0.8 plus 51.
const BACKGROUND_MULTIPLY := 0.8
const BACKGROUND_ADD := 51.0 / 255.0
## The text "Training Level N" of the client.
const LEVEL_TEXT_PLACE := Vector2(422.55 + 65.45, 11.75 - 2.0)
const LEVEL_TEXT_SIZE := Vector2(150.6, 24.65)
const LEVEL_TEXT_COLOR := Color("#4e97f1")
## The text of a hit at an enemy.
const HIT_TEXT_WIDTH := 29.75
## A warrior that a crow brings comes in at this place.
const CROW_WARRIOR_PLACE := Vector2(800.0, 280.0)

## The length of each level (xmax_level of the client) and the x of its enemies at the start.
const LEVELS := {
	1: {"length": 2700, "warriors": [2100]},
	2: {"length": 4700, "warriors": [1000, 3100, 3200]},
	3: {"length": 8500, "warriors": [2300, 4000, 4100, 8200], "archers": [1000, 2500, 6600, 8100]},
	4: {"length": 11000, "warriors": [3200, 3300, 8700], "archers": [1100, 1170, 6200, 7600, 9600, 9700],
		"shamans": [2100, 4800, 5000, 6300, 9500]},
	5: {"length": 13000, "warriors": [1300, 4050, 4800, 9280, 10500, 10800], "archers": [2550, 2800, 5000, 5150, 9400, 10600],
		"shamans": [1200, 3150, 3900, 6050, 8100, 12050, 12250], "skeletons": [6800, 11600]},
	6: {"length": 15000, "warriors": [3000, 3300, 5000, 7700, 10700, 10800], "archers": [3200, 5450, 6000, 6200, 8700, 9400, 13350],
		"shamans": [1700, 3850, 4000, 4100, 6600, 9000, 11850, 13500], "skeletons": [2000, 7550, 11700, 13250], "shaman_boss": [14400]},
	7: {"length": 17000, "warriors": [1550, 4780, 9350, 9440, 11150, 12450, 15080, 15240],
		"archers": [1400, 2900, 6000, 8450, 9550, 9900, 11450, 14700, 16250, 16380, 16450],
		"shamans": [2830, 4720, 11000, 11360, 13930, 15000], "skeletons": [4670, 7000, 7100, 11250, 12500, 15150]},
	DRAGON_LEVEL: {"length": 900, "final_boss": [1250]},
}
## The kinds of enemies, in the order in which the client places them.
const ENEMY_KINDS: Array[String] = ["warriors", "archers", "shamans", "skeletons", "final_boss", "shaman_boss"]

var art: RiderArt
var ui: UiLibrary
var rng := RandomNumberGenerator.new()
var level_number := 1
var stamina := STAMINA
var stage: Node2D = self
var hero: RiderHero
var level: RiderLevel
var hud: RiderHud
var enemies: Array[RiderEnemy] = []
var _bodies: Array[RiderEnemy] = []  # Dead enemies, which play their death.
var _shots: Array = []  # RiderShots.Shot
var _clips: Array = []  # [FlashClip, Callable or null]: the clips that play, with their frame scripts.
var _sounds_dir := ""
var _streams := {}  # Sound name -> AudioStream, or null.
var _health := STAMINA
var _regeneration_time := 0
var _x0 := 0.0  # How far the hero went, from the start.
var _length := 0.0
var _time := 0.0
var _running := true  # False after the hero died: the scene stops, the animations go on.
var _paused := false
var _pause_key_down := false
var _level_end := false
var _ended := false
var _top: Node2D  # The layer of the hero and the skill bar; the shots are added above it.
var _result_won := false


## data_dir: the folder of the import. level: 1 to 8. rider_type: 1 to 3, the picture at the health bar.
func _init(rider_art: RiderArt, ui_library: UiLibrary, data_dir: String, level_to_play: int, rider_type: int) -> void:
	art = rider_art
	ui = ui_library
	level_number = clampi(level_to_play, 1, LEVELS.size())
	_sounds_dir = data_dir.path_join("rider_game/sounds")
	rng.randomize()
	var settings: Dictionary = LEVELS[level_number]
	_length = settings.length
	var background_id: int = art.parts(art.symbol("main.the_game_itself"), 0)[0].id
	var background := Sprite2D.new()
	background.centered = false
	background.offset = art.frames(background_id).origin
	background.texture = art.frames(background_id).get_frame(0)
	background.material = FlashClip.color_material(Color(BACKGROUND_MULTIPLY, BACKGROUND_MULTIPLY, BACKGROUND_MULTIPLY), Color(BACKGROUND_ADD, BACKGROUND_ADD, BACKGROUND_ADD, 0.0))
	add_child(background)
	level = RiderLevel.new(self, level_number)
	add_child(level.terrain)
	var level_text := Label.new()
	level_text.text = "Training Level %d" % level_number
	level_text.position = LEVEL_TEXT_PLACE
	level_text.size = LEVEL_TEXT_SIZE
	level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_text.add_theme_font_override("font", ui.named_font("Eras Bold ITC"))
	level_text.add_theme_font_size_override("font_size", 18)
	level_text.add_theme_color_override("font_color", LEVEL_TEXT_COLOR)
	add_child(level_text)
	add_child(level.details)
	hud = RiderHud.new(ui, level_number, rider_type)
	add_child(hud.health_bar)
	hud.show_health(_health, stamina)
	hud.skill_pressed.connect(func(skill: int) -> void: hero.use_skill(skill))
	hud.done_pressed.connect(_on_done)
	hero = RiderHero.new(self)
	for kind in ENEMY_KINDS:
		for start_x: int in settings.get(kind, []):
			_add_enemy(_make_enemy(kind, float(start_x)))
	_top = Node2D.new()
	add_child(_top)
	_top.add_child(hero.body)
	_top.add_child(hero.weapon)
	_top.add_child(hud.skill_bar)
	add_clip(hero.body, hero.on_body_frame)
	add_clip(hero.weapon, hero.on_weapon_frame)


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		if not _paused:
			step()


## One frame of the client.
func step() -> void:
	if _running:
		hero.update()
		_move()
		for enemy: RiderEnemy in enemies.duplicate():
			if not enemy.death:
				enemy.update()
		for shot: RiderShots.Shot in _shots.duplicate():
			if not shot.update():
				_shots.erase(shot)
				remove_clip(shot.clip)
		level.update()
		_regeneration_time += 1
		if _regeneration_time >= REGENERATION_FRAMES:
			_regeneration_time = 0
			_health = minf(_health + REGENERATION, stamina)
		hud.show_health(_health, stamina)
	hud.update(hero)
	for entry: Array in _clips.duplicate():
		var clip: FlashClip = entry[0]
		if not is_instance_valid(clip):
			continue
		clip.tick()
		var script: Callable = entry[1]
		# A script can go to another frame, whose script then runs too.
		var steps := 0
		var entered := clip.take_entered()
		while not entered.is_empty() and steps < 8:
			for frame in entered:
				if script.is_valid():
					script.call(frame)
			entered = clip.take_entered()
			steps += 1


## The motion of one frame: the hero, the enemies, and the screen that follows the hero.
func _move() -> void:
	var dx := hero.move()
	var follows := _x0 > -100.0 and _x0 < _length
	for enemy: RiderEnemy in enemies.duplicate():
		enemy.move()
		if follows:
			enemy.x -= dx
			enemy.clip.position.x -= dx
		if enemy.death:
			enemies.erase(enemy)
			_bodies.append(enemy)
	if follows:
		level.scroll(-dx)
		for body in _bodies:
			body.clip.position.x -= dx
		for shot: RiderShots.Shot in _shots:
			shot.clip.position.x -= dx
	else:
		var x := hero.x + dx
		if x < HERO_MIN_X or x > HERO_MAX_X:
			hero.vx = 0.0
			x = clampf(x, HERO_MIN_X, HERO_MAX_X)
		hero.set_screen_x(x)
		if x > EXIT_X and enemies.is_empty() and not _level_end and level_number < DRAGON_LEVEL:
			_level_end = true
			_show_end("won")
			hero.walk_out()
	_x0 += hero.vx


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var name := _key_name(key.physical_keycode)
	if name.is_empty():
		return
	get_viewport().set_input_as_handled()
	if name == "pause":
		if key.pressed and not _pause_key_down and _running:
			_paused = not _paused
		_pause_key_down = key.pressed
		return
	if _paused:
		return
	if key.pressed:
		hero.key_down(name)
	else:
		hero.key_up(name)


static func _key_name(code: Key) -> String:
	match code:
		KEY_RIGHT, KEY_D:
			return "right"
		KEY_LEFT, KEY_A:
			return "left"
		KEY_UP, KEY_W:
			return "up"
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			return str(code - KEY_0)
		KEY_8, KEY_9:
			return "pause"
	return ""


## A clip that plays in each frame; frame_script gets each frame that it enters.
func add_clip(clip: FlashClip, frame_script := Callable()) -> void:
	_clips.append([clip, frame_script])


func remove_clip(clip: FlashClip) -> void:
	for entry: Array in _clips:
		if entry[0] == clip:
			_clips.erase(entry)
			break
	clip.queue_free()


## A shot of an enemy, above all other parts of the screen, as in the client.
func add_shot(shot: RiderShots.Shot) -> void:
	_shots.append(shot)
	add_child(shot.clip)
	add_clip(shot.clip, shot.on_frame)


func _add_enemy(enemy: RiderEnemy) -> void:
	enemies.append(enemy)
	add_child(enemy.clip)
	add_clip(enemy.clip, enemy.on_frame)


func _make_enemy(kind: String, start_x: float) -> RiderEnemy:
	match kind:
		"warriors":
			return RiderWarrior.new(self, start_x)
		"archers":
			return RiderArcher.new(self, start_x)
		"shamans":
			return RiderShaman.new(self, start_x)
		"skeletons":
			return RiderSkeleton.new(self, start_x)
		"shaman_boss":
			return RiderShamanBoss.new(self, start_x)
	return RiderFinalBoss.new(self, start_x)


## A crow that flew away brings a warrior, which fights at once.
func add_warrior_from_crow() -> void:
	var warrior := RiderWarrior.new(self, CROW_WARRIOR_PLACE.x)
	warrior.y = CROW_WARRIOR_PLACE.y
	warrior.combat = true
	_add_enemy(warrior)
	move_child(warrior.clip, _top.get_index())


## The text of a hit at an enemy: Georgia 10, white, in the middle of its field.
func make_hit_text() -> Label:
	var text := Label.new()
	text.size = Vector2(HIT_TEXT_WIDTH, 15.35)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", ui.named_font("Georgia"))
	text.add_theme_font_size_override("font_size", 10)
	text.add_theme_color_override("font_color", Color.WHITE)
	return text


## The blood of a sabre hit at an enemy: one of four.
func bleed(enemy: RiderEnemy) -> void:
	play_sound("flash_sound")
	var blood := enemy.clip.clip("blood")
	if blood != null:
		blood.go_to(["one", "two", "three", "four"][rng.randi_range(0, 3)], true)


func hurt_hero(amount: float) -> void:
	if not _running:
		return
	_health -= amount
	hud.show_change("minusHealth_txt", "-%d" % amount, 201.0)
	if _health <= 0.0:
		_health = 0.0
		hud.show_health(_health, stamina)
		_hero_died()
		return
	hud.show_health(_health, stamina)


func heal_hero(amount: float) -> void:
	_health = minf(_health + amount, stamina)
	hud.show_change("addHealth_txt", "+%d" % amount, 231.0)


## The dragon died: the game is won.
func boss_died() -> void:
	_show_end("complete")


## Plays a sound of the mini-game by the name of its class, when the sounds are on.
func play_sound(name: String) -> void:
	if not SoundPlayer.are_effects_on():
		return
	if not _streams.has(name):
		var path := _sounds_dir.path_join(name + ".mp3")
		_streams[name] = AudioStreamMP3.load_from_file(path) if FileAccess.file_exists(path) else null
	if _streams[name] == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[name]
	player.volume_db = linear_to_db(SoundPlayer.EFFECT_VOLUME)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _hero_died() -> void:
	_running = false
	hero.die()
	for enemy in enemies:
		enemy.won()
	_show_end("lost")


func _show_end(kind: String) -> void:
	if _ended:
		return
	_ended = true
	add_child(hud.show_end(kind, level_number))
	_result_won = kind != "lost"


func _on_done() -> void:
	finished.emit(_result_won)

