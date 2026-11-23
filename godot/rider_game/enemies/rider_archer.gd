class_name RiderArcher
extends RiderEnemy
## An archer. It shoots arrows at the hero from 100 to 300 pixels, walks
## nearer from further away, and runs away when the hero is nearer than 100
## pixels. When it ran far, it cuts the legs of the hero instead (the hero then
## walks slower for 2 seconds of the client).

var _aim := 0.0  # The angle of the bow in degrees, from the archer to the hero.
var _hamstring_wait := 0
var _start_x := 0.0  # The place of the archer on the terrain at the start.


func _init(rider_game: RiderGame, start_x: float) -> void:
	super(rider_game, "main.archer", start_x, {"In": true})
	max_health = 200.0
	health = max_health
	text_top = -110.0
	death_sound = "archer_death"
	_start_x = start_x - game.level.terrain_x()
	_update_bar()


func decide() -> void:
	var delta := x_delta()
	_aim = RiderShots.limited_angle(rad_to_deg(atan2(-(clip.position.y - (game.hero.y + 68.0)), -delta)))
	var on_terrain := clip.position.x - game.level.terrain_x()
	_hamstring_wait += 1
	if not combat:
		set_pose("idleLeft", "IdleLeft", false, 0.0)
		side = "left"
		if delta < 270.0:
			combat = true
	if not combat or cooldown < 24:
		return
	call_others()
	if delta > 100.0 and delta < 300.0:
		side = "left"
		_shoot("Left")
	elif delta < -100.0 and delta > -300.0:
		side = "right"
		_shoot("Right")
	elif delta > 0.0 and delta <= 100.0:
		if pose == "runningRight":
			return
		if on_terrain > _start_x + 200.0 and _hamstring_wait > 144:
			side = "left"
			_hamstring("Left")
		else:
			side = "right"
			_move("runningRight", "RunningRight", 2.4)
	elif delta <= 0.0 and delta >= -100.0:
		if pose == "runningLeft":
			return
		if on_terrain < _start_x - 400.0 and _hamstring_wait > 144:
			side = "right"
			_hamstring("Right")
		else:
			side = "left"
			_move("runningLeft", "RunningLeft", -2.4)
	elif delta <= -300.0:
		if pose != "walkingRight":
			side = "right"
			_move("walkingRight", "RunningRight", 1.5)
	elif delta >= 300.0:
		if pose != "walkingLeft":
			side = "left"
			_move("walkingLeft", "RunningLeft", -1.5)


func _move(name: String, label: String, speed: float) -> void:
	set_pose(name, label, false, speed)
	cooldown = 0


func _shoot(direction: String) -> void:
	set_pose("shoot" + direction, "Shoot" + direction, true, 0.0)
	cooldown = 0


func _hamstring(direction: String) -> void:
	set_pose("hamstring" + direction, "Hamstring" + direction, true, 3.0 if direction == "Right" else -3.0)
	cooldown = 0
	_hamstring_wait = 0


## The bow turns to the hero: the angle when the archer looks right, the mirror when it looks left.
func _turn_bow(right: bool) -> void:
	var inner := clip.clip("In")
	if inner != null:
		inner.set_part("ShootingPart", "rotation", _aim if right else 180.0 - _aim)


func on_frame(frame: int) -> void:
	match frame:
		0, 9, 19, 31, 43, 55:
			clip.playing = false
		66, 91:
			clip.restart("In")
			var inner := clip.clip("In")
			if inner != null:
				inner.restart("ShootingPart")
			_turn_bow(frame == 66)
		70, 95:
			_turn_bow(frame == 70)
		75, 100:
			game.add_shot(RiderShots.Arrow.new(game, clip.position, _aim))
			_turn_bow(frame == 75)
		90:
			clip.go_to("IdleRight", true)
		114, 164:
			clip.go_to("IdleLeft", true)
		139:
			clip.go_to("IdleRight", true)
		115, 140, 165, 201, 238, 249:
			clip.restart("In")
		117, 118, 119, 120, 121, 122, 142, 143, 144, 145, 146, 147, 148:
			if touches_hero(["In"]):
				game.hero.hamstring(2.0)
		200, 236:
			clip.playing = false
			var inner := clip.clip("In")
			if inner != null:
				inner.playing = false


func die() -> void:
	set_pose("death", "DeathRight" if side == "right" else "DeathLeft", true, 0.0)


func kicked() -> void:
	set_pose("kicked", "KickedRight" if side == "right" else "KickedLeft", false, 0.0)
	cooldown = 0


func stunned() -> void:
	set_pose("stunned", "StunnedRight" if side == "right" else "StunnedLeft", false, 0.0)
