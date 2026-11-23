class_name RiderShaman
extends RiderEnemy
## A shaman. Within 220 pixels of the hero it casts a spell: a poison cloud at
## the hero, ghosts at both sides of the hero, or a blast. When the hero comes
## nearer than 140 pixels, it pushes the hero away, at most every 150 frames.
## Further away it walks to the hero.

var _push_wait := 0


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.shaman", start_x)
	max_health = 200.0
	health = max_health
	text_top = -105.0
	death_sound = "shaman_death"
	hidden_beyond = 450.0
	_update_bar()


func decide() -> void:
	var delta := x_delta()
	_push_wait += 1
	if not combat:
		set_pose("idleLeft", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 270.0:
			combat = true
	if not combat or cooldown < 50:
		return
	call_others()
	if delta <= 0.0 and delta > -220.0:
		side = "right"
		_cast_or_push("Right", delta > -140.0)
	elif delta > 0.0 and delta < 220.0:
		side = "left"
		_cast_or_push("Left", delta < 140.0)
	elif delta <= -220.0:
		if pose != "walkingRight":
			side = "right"
			set_pose("walkingRight", "WalkingRight", false, 1.1)
	elif delta >= 220.0:
		if pose != "walkingLeft":
			side = "left"
			set_pose("walkingLeft", "WalkingLeft", false, -1.1)


func _cast_or_push(direction: String, near: bool) -> void:
	if near and _push_wait >= 150:
		set_pose("discard" + direction, "Discard" + direction, true, 0.0)
		cooldown = 0
		_push_wait = 0
		game.play_sound("shaman_cast_4")
		return
	# The three spells, with their sounds: 30%, 30% and 40%.
	var roll := game.rng.randf()
	var spell := 1 if roll <= 0.3 else (2 if roll < 0.6 else 3)
	set_pose("cast" + direction, "Cast%s_%d" % [direction, spell], true, 0.0)
	game.play_sound("shaman_cast_%d" % spell)
	cooldown = 0


func on_frame(frame: int) -> void:
	var delta := x_delta()
	match frame:
		0, 148, 170, 193, 216, 240, 265, 288, 311:
			clip.playing = false
		34, 55, 76, 102, 128, 149, 171, 194, 217, 241, 266, 289:
			clip.restart("In")
		54, 101:
			set_pose("idleRight", "IdleRight", false, 0.0)
		75, 127:
			set_pose("idleLeft", "IdleLeft", false, 0.0)
		84:
			if delta < 0.0 and delta > -140.0:
				game.hero.knocked(32.0)
		110:
			if delta > 0.0 and delta < 140.0:
				game.hero.knocked(-32.0)
		138, 159:
			game.add_shot(RiderShots.Cloud.new(game))
		178:
			game.add_shot(RiderShots.Ghost.new(game, "right"))
		202:
			game.add_shot(RiderShots.Ghost.new(game, "left"))
		237:
			game.add_shot(RiderShots.Blast.new(game, clip.position, "right"))
		261:
			game.add_shot(RiderShots.Blast.new(game, clip.position, "left"))
		347, 383:
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
