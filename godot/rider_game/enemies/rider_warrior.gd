class_name RiderWarrior
extends RiderEnemy
## A warrior with a spear and a shield. When the hero comes near, it runs at
## the hero or throws its spear (40%) and takes its sword. It stabs, cuts or blocks.

const STRENGTH := 2.0
var weapon := "Spear"  ## "Spear" or "Sword", as in the labels of its sprite.


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.warrior", start_x)
	max_health = 350.0
	health = max_health
	text_top = -115.0
	death_sound = "warrior_death"
	_update_bar()


func decide() -> void:
	var delta := x_delta()
	if not combat:
		_pose("idle", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 270.0:
			combat = true
			if game.rng.randf() < 0.6:
				_run("Left")
			else:
				_pose("throw", "Throw", true, 0.0)
				cooldown = 0
				game.play_sound("enemy_swing")
	if not combat or cooldown < 25:
		return
	call_others()
	var reach := 100.0 if weapon == "Spear" else 75.0
	if delta > reach and delta < 1000.0:
		if pose != "runLeft":
			side = "left"
			_run("Left")
	elif delta < -reach and delta > -1000.0:
		if pose != "runRight":
			side = "right"
			_run("Right")
	elif delta > 0.0 and delta <= reach:
		side = "left"
		_attack()
	elif delta <= 0.0 and delta >= -reach:
		side = "right"
		_attack()


func _run(direction: String) -> void:
	block = false
	_pose("run" + direction, "Running%s%s" % [direction, weapon], false, 2.0 if direction == "Right" else -2.0)


## A random attack: the first hit (60%), the second hit (20%) or a block (20%).
func _attack() -> void:
	var direction := "Right" if side == "right" else "Left"
	var roll := game.rng.randf()
	pose = "attack" + direction
	if roll <= 0.6:
		clip.go_to("%sHit%s_1" % [weapon, direction], true)
		game.play_sound("enemy_swing")
	elif roll < 0.8:
		clip.go_to("%sHit%s_2" % [weapon, direction], true)
		game.play_sound("enemy_swing")
	else:
		clip.go_to("%sBlock%s" % [weapon, direction], true)
	cooldown = 0
	set_speed(0.0)


func _pose(name: String, label_start: String, play: bool, speed: float) -> void:
	# The idle poses have the weapon in their labels: IdleLeftSpear, IdleLeftSword.
	set_pose(name, label_start + (weapon if label_start.begins_with("Idle") else ""), play, speed)


func on_frame(frame: int) -> void:
	match frame:
		0, 11, 22, 35, 71, 86, 100, 115, 130, 143, 155, 169, 206, 230, 257, 282, 307, 332, 357, 381, 406, 431, 456, 482:
			clip.playing = false
		47, 185, 209, 233, 258, 283, 308, 333, 358, 382, 407, 432, 457, 483, 519, 555, 591, 630, 642:
			clip.restart("In")
		58:
			game.add_shot(RiderShots.Spear.new(game, clip.position))
		68:
			weapon = "Sword"
			_pose("idle", "IdleLeft", false, 0.0)
		193, 217:
			hit_hero_with(["In", "spear", "spearBlade"], STRENGTH + 10.0)
		245, 270:
			hit_hero_with(["In", "spear", "spearBlade"], STRENGTH + 15.0)
		286, 311, 435, 460:
			block = true
		302, 327, 451, 476:
			block = false
		342, 367:
			hit_hero_with(["In", "sword"], STRENGTH * 2.0 + 8.0)
		389, 414:
			hit_hero_with(["In", "sword"], STRENGTH * 2.0 + 16.0)
		518, 554, 590, 626:
			clip.playing = false
			var inner := clip.part("In")
			if inner != null and inner.node is FlashClip:
				(inner.node as FlashClip).playing = false


func die() -> void:
	clip.go_to("DeathRight%s" % weapon if side == "right" else "DeathLeft%s" % weapon, true)
	set_speed(0.0)


func kicked() -> void:
	block = false
	set_pose("kicked", "Kicked%s%s" % ["Right" if side == "right" else "Left", weapon], false, 0.0)
	cooldown = 0


func stunned() -> void:
	block = false
	set_pose("stunned", "Stunned%s%s" % ["Right" if side == "right" else "Left", weapon], false, 0.0)
