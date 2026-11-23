class_name RiderFinalBoss
extends RiderEnemy
## The dragon of level 8, which the nest tames. It runs at the hero and
## attacks within 80 pixels: with lightning every 150 frames, with fire every
## 250 frames, else with its claws. Its death ends the game with a win.

const STRENGTH := 2.0
var _bolt_wait := 0
var _fire_wait := 0


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.final_boss", start_x)
	max_health = 3000.0
	health = max_health
	text_top = -115.0
	death_sound = "boss_death"
	hidden_beyond = INF
	pushable = false
	_update_bar()


func randomizes_speed() -> bool:
	return false


func decide() -> void:
	var delta := x_delta()
	_bolt_wait += 1
	_fire_wait += 1
	if not combat:
		set_pose("idleLeft", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 370.0:
			combat = true
			_bolt_wait = 0
			_fire_wait = 0
			game.play_sound("boss_frase_1")
	if not combat or cooldown < 30:
		return
	if delta > 80.0 and delta < 1000.0:
		if pose != "runningLeft":
			side = "left"
			set_pose("runningLeft", "RunningLeft", false, -2.3)
	elif delta < -80.0 and delta > -1000.0:
		if pose != "runningRight":
			side = "right"
			set_pose("runningRight", "RunningRight", false, 2.3)
	elif absf(delta) <= 80.0:
		side = "left" if delta > 0.0 else "right"
		_attack("Right" if side == "right" else "Left")


func _attack(direction: String) -> void:
	pose = "attack" + direction
	if _bolt_wait >= 150:
		clip.go_to("TeslaBolt" + direction, true)
		game.play_sound("boss_bolt")
		_bolt_wait = 0
		cooldown = -20
	elif _fire_wait >= 250:
		clip.go_to("FireBolt" + direction, true)
		game.play_sound("boss_fire_sound")
		_fire_wait = 0
		cooldown = -35
	else:
		clip.go_to("SwordsHit" + direction, true)
		cooldown = 0
	set_speed(0.0)


func on_frame(frame: int) -> void:
	match frame:
		0, 69, 100, 288, 339, 392, 452:
			clip.playing = false
		39, 51, 70, 82:
			game.play_sound("boss_swing")
		47, 78, 385, 438:
			hit_hero_with(["In", "bolt"], STRENGTH * 2.0 + 50.0)
		281, 329:
			hit_hero_with(["In", "bolt"], STRENGTH * 2.0 + 30.0)
		168, 211:
			clip.playing = false
			var inner := clip.clip("In")
			if inner != null:
				inner.playing = false
		241, 289, 340, 393:
			clip.restart("In")


func new_health(amount: float) -> void:
	var was_alive := not death
	super(amount)
	if was_alive and death:
		game.boss_died()


func die() -> void:
	set_pose("death", "DeathRight" if side == "right" else "DeathLeft", true, 0.0)


func stunned() -> void:
	set_pose("stunned", "StunnedRight" if side == "right" else "StunnedLeft", false, 0.0)
