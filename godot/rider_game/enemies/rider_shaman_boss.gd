class_name RiderShamanBoss
extends RiderEnemy
## The great shaman at the end of level 6. Near the hero (80 pixels) it cuts
## with a knife or pushes the hero away, at 80 to 150 pixels it strikes with
## lightning, and further away (up to 220 pixels) it calls a rain of fire.

var _push_wait := 0


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.shaman_boss", start_x)
	max_health = 1000.0
	health = max_health
	text_top = -105.0
	death_sound = "shaman_death"
	pushable = false
	_update_bar()


func randomizes_speed() -> bool:
	return false


func decide() -> void:
	var delta := x_delta()
	_push_wait += 1
	if not combat:
		set_pose("idleLeft", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 270.0:
			combat = true
	if not combat or cooldown < 25:
		return
	call_others()
	if delta <= 0.0 and delta > -220.0:
		side = "right"
		_attack("Right", -delta)
	elif delta > 0.0 and delta < 220.0:
		side = "left"
		_attack("Left", delta)
	elif delta <= -220.0:
		if pose != "walkingRight":
			side = "right"
			set_pose("walkingRight", "WalkingRight", false, 1.8)
	elif delta >= 220.0:
		if pose != "walkingLeft":
			side = "left"
			set_pose("walkingLeft", "WalkingLeft", false, -1.8)


func _attack(direction: String, distance: float) -> void:
	if distance < 80.0:
		if _push_wait >= 150:
			set_pose("discard" + direction, "Discard" + direction, true, 0.0)
			cooldown = 0
			_push_wait = 0
			game.play_sound("shaman_cast_4")
		else:
			set_pose("hit" + direction, "Hit" + direction, true, 0.0)
			cooldown = 0
			game.play_sound("enemy_swing")
	elif distance < 150.0:
		set_pose("flash" + direction, "Flash" + direction, true, 0.0)
		cooldown = 0
		game.play_sound("shaman_boss_bolt")
	else:
		# The client waits 50 frames more after this spell.
		set_pose("cast" + direction, "Cast%s_1" % direction, true, 0.0)
		cooldown = -50


func on_frame(frame: int) -> void:
	var delta := x_delta()
	match frame:
		0, 106, 128, 151, 174, 198, 223:
			clip.playing = false
		34, 60, 86, 107, 129, 152, 175, 199:
			clip.restart("In")
		42:
			if delta < 0.0 and delta > -160.0:
				game.hero.knocked(40.0)
		68:
			if delta > 0.0 and delta < 160.0:
				game.hero.knocked(-40.0)
		59:
			set_pose("idleRight", "IdleRight", false, 0.0)
		85:
			set_pose("idleLeft", "IdleLeft", false, 0.0)
		96, 117:
			game.add_shot(RiderShots.Rainfire.new(game))
		139, 162:
			hit_hero_with(["In", "knife"], 10.0, 2)
		189:
			hit_hero_with(["In", "flash"], 15.0, 2)
			if delta < 0.0 and delta > -120.0:
				game.hero.knocked(20.0)
		213:
			hit_hero_with(["In", "flash"], 15.0, 2)
			if delta > 0.0 and delta < 120.0:
				game.hero.knocked(-20.0)
		259, 295:
			clip.playing = false
			var inner := clip.clip("In")
			if inner != null:
				inner.playing = false


func die() -> void:
	set_pose("death", "DeathRight" if side == "right" else "DeathLeft", true, 0.0)


func kicked() -> void:
	set_pose("kicked", "KickedRight" if side == "right" else "KickedLeft", true, 0.0)
	cooldown = 0


func stunned() -> void:
	set_pose("stunned", "StunnedRight" if side == "right" else "StunnedLeft", false, 0.0)
