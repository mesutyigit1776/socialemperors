class_name RiderSkeleton
extends RiderEnemy
## A skeleton with an axe. It runs at the hero and hits within 100 pixels.

const STRENGTH := 2.0


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.skeleton", start_x)
	max_health = 550.0
	health = max_health
	text_top = -115.0
	death_sound = "skeleton_death"
	hidden_beyond = 450.0
	_update_bar()


func decide() -> void:
	var delta := x_delta()
	if not combat:
		set_pose("idleLeft", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 270.0:
			combat = true
	if not combat or cooldown < 27:
		return
	call_others()
	if delta > 100.0 and delta < 1000.0:
		if pose != "runningLeft":
			side = "left"
			set_pose("runningLeft", "RunningLeft", false, -1.8)
	elif delta < -100.0 and delta > -1000.0:
		if pose != "runningRight":
			side = "right"
			set_pose("runningRight", "RunningRight", false, 1.8)
	elif absf(delta) <= 100.0:
		side = "left" if delta > 0.0 else "right"
		var direction := "Right" if side == "right" else "Left"
		# The first hit (60%) with its own sound, or the second hit.
		if game.rng.randf() <= 0.6:
			set_pose("hit" + direction, "Hit%s_1" % direction, true, 0.0)
			game.play_sound("skeleton_hit")
		else:
			set_pose("hit" + direction, "Hit%s_2" % direction, true, 0.0)
			game.play_sound("enemy_swing")
		cooldown = 0


func on_frame(frame: int) -> void:
	match frame:
		0, 11, 22, 37, 51, 64, 221, 242, 264, 285:
			clip.playing = false
		76, 112, 148, 160, 200, 222, 243, 265:
			clip.restart("In")
		111, 147:
			clip.playing = false
			var inner := clip.clip("In")
			if inner != null:
				inner.playing = false
		212, 234:
			hit_hero_with(["In", "axe"], STRENGTH * 2.0 + 20.0)
		251, 273:
			hit_hero_with(["In", "axe"], STRENGTH * 2.0 + 15.0)


func die() -> void:
	set_pose("death", "DeathRight" if side == "right" else "DeathLeft", true, 0.0)


func kicked() -> void:
	set_pose("kicked", "KickedRight" if side == "right" else "KickedLeft", false, 0.0)
	cooldown = 0


func stunned() -> void:
	set_pose("stunned", "StunnedRight" if side == "right" else "StunnedLeft", false, 0.0)
