class_name RiderHero
extends RefCounted
## The hero of the mini-game: a Cossack with a sabre (main.myhero) and the
## sabre and spells in front of him (myhero_additional), both at 90%. The keys:
## A/D or the arrows to run, W or up to jump, 1 to 6 for the skills.
##
## After an attack the hero is in combat for 25 frames: he cannot run, jump or
## attack again. Each skill also waits its own cooldown, and skills 4 to 6
## open at the training levels 3, 5 and 7.

const SCALE := 0.9
const MAX_X_SPEED := 1.7
const JUMP_SPEED := 12.0
const COMBAT_FRAMES := 25
## The skills: the cooldown in frames, the first level, the name on the skill bar.
const SKILL_COOLDOWNS: Array[int] = [1, 2, 150, 350, 450, 375]
const SKILL_LEVELS: Array[int] = [1, 1, 1, 3, 5, 7]
const SKILL_NAMES: Array[String] = ["Valiant Strike", "Flip Strike", "Wrath Bolt", "Regeneration", "Hammer of Reckoning", "Thunderous Arrow"]
## The power of the hero, as the client sets it for the training: 100 x 2.1 and 50 x 9.6.
const MELEE_POWER := 210.0
const SPELL_POWER := 480.0
## The hero stands this many pixels deep in the ground, as the pixel test of the client leaves him (measured in Ruffle).
const SINK := 1.0
## A hamstrung hero walks at this speed.
const HAMSTRUNG_SPEED := 1.6

var game: RiderGame
var body: FlashClip
var weapon: FlashClip
var x := 300.0
var y := 300.0
var vx := 0.0
var vy := 0.0
var xspeed := 0.0
var yspeed := 0.0
var jumping := true
var before_jump_y := 0.0
var combat := false
var inactive := false
var side := "right"
var pose := "idleRight"
## Frames since the last attack; see COMBAT_FRAMES.
var cooldown := 0
## The frames since each skill was used.
var skill_time: Array[int] = SKILL_COOLDOWNS.duplicate()
## False when the hero falls into a pit, dies or ends the level: the keys and
## his own frame logic stop, and the ground does not hold him after a pit.
var controlled := true
var on_ground_test := true
var _keys := {"right": false, "left": false, "up": false}
var _skill_keys_up: Array[bool] = [true, true, true, true, true, true]
var _hamstrung := false
var _hamstring_frames := 0
var _hamstring_time := 0
var _feet_x := Vector2.ZERO  # The left and right end of the feet from the registration point.


func _init(rider_game: RiderGame) -> void:
	game = rider_game
	body = FlashClip.new(game.art, game.art.symbol("main.myhero"))
	body.scale = Vector2(SCALE, SCALE)
	weapon = FlashClip.new(game.art, game.art.symbol("myhero_additional"), {"In": true})
	weapon.scale = Vector2(SCALE, SCALE)
	weapon.set_part("hamsEffect", "visible", false)
	body.go_to("IdleRight", false)
	weapon.go_to("Idle", false)
	var standing := body.rect_in(body)
	_feet_x = Vector2(standing.position.x, standing.end.x) * SCALE
	_place()


## The rectangle of the hero on the screen of the game, as hitTestObject measures it.
func rect() -> Rect2:
	return body.rect_in(game.stage)


## The y of the hero on the ground: where he jumped from while he jumps.
func standing_y() -> float:
	return before_jump_y if jumping else y


## True when the sabre (either blade of the attack now) touches rect.
func sword_hits(target: Rect2) -> bool:
	for blade in ["shablya_1", "shablya_2"]:
		var blade_rect := weapon.part_rect(["In", blade], game.stage)
		if blade_rect.has_area() and blade_rect.intersects(target):
			return true
	return false


func key_down(key: String) -> void:
	if not controlled:
		return
	match key:
		"right":
			_keys.right = true
			_keys.left = false
		"left":
			_keys.left = true
			_keys.right = false
		"up":
			_keys.up = true
		_:
			var skill := int(key)
			if skill >= 1 and skill <= 6 and _skill_keys_up[skill - 1]:
				_skill_keys_up[skill - 1] = false
				use_skill(skill)


func key_up(key: String) -> void:
	if not controlled:
		return
	match key:
		"right":
			_keys.right = false
			if pose != "jumpRight" and not combat:
				_set_pose("stopRight" if vx > 10.0 else "idleRight")
				xspeed = 0.0
		"left":
			_keys.left = false
			if pose != "jumpLeft" and not combat:
				_set_pose("stopLeft" if vx < -10.0 else "idleLeft")
				xspeed = 0.0
		"up":
			_keys.up = false
		_:
			var skill := int(key)
			if skill >= 1 and skill <= 6:
				_skill_keys_up[skill - 1] = true


## True when a skill is open in this level and its cooldown is over, and the hero is free to use it.
func can_use(skill: int) -> bool:
	if combat or game.level_number < SKILL_LEVELS[skill - 1] or skill_time[skill - 1] <= SKILL_COOLDOWNS[skill - 1]:
		return false
	return skill == 1 or not jumping


## A skill of the skill bar, by its key or its button.
func use_skill(skill: int) -> void:
	if not controlled or not can_use(skill):
		return
	skill_time[skill - 1] = 0
	var right := side == "right"
	match skill:
		1:
			if jumping:
				_set_pose("jumpingAttackRight_1" if right else "jumpingAttackLeft_1")
				xspeed /= 3.0
			else:
				if _keys.right or _keys.left:
					vx += 5.0 if right else -5.0
				_set_pose("attackRight_1" if right else "attackLeft_1")
				xspeed = 0.0
		2:
			_set_pose("attackRight_2" if right else "attackLeft_2")
			xspeed /= 4.0
		3:
			_set_pose("attackRight_3" if right else "attackLeft_3")
			xspeed = 0.0
		4:
			game.heal_hero(game.stamina / 5.0)
			_set_pose("healRight" if right else "healLeft")
			xspeed = 0.0
		5:
			_set_pose("attackRight_5" if right else "attackLeft_5")
			xspeed /= 4.0
		6:
			_set_pose("attackRight_4" if right else "attackLeft_4")
			jumping = true
			xspeed /= 1.2
			yspeed -= JUMP_SPEED


## One frame of the logic of the hero: the timers, the fall, and the keys.
func update() -> void:
	if not controlled:
		return
	cooldown += 1
	_hamstring_time += 1
	for skill in skill_time.size():
		skill_time[skill] += 1
	combat = cooldown < COMBAT_FRAMES
	inactive = jumping
	if not jumping and vy > 8.0:
		jumping = true
		body.go_to("JumpRight" if side == "right" else "JumpLeft", false)
		weapon.go_to("Idle", false)
	if inactive:
		return
	for direction in ["right", "left"]:
		if not _keys[direction] or jumping or combat:
			continue
		var sign := 1.0 if direction == "right" else -1.0
		if not _hamstrung:
			xspeed += sign * MAX_X_SPEED
			_set_pose("running" + direction.capitalize())
		else:
			xspeed = sign * HAMSTRUNG_SPEED
			_set_pose("walking" + direction.capitalize())
			weapon.set_part("hamsEffect", "x", -2.0 if direction == "right" else 12.0)
			if _hamstring_time >= _hamstring_frames:
				weapon.set_part("hamsEffect", "visible", false)
				_hamstrung = false
		side = direction
		xspeed = clampf(xspeed, -MAX_X_SPEED, MAX_X_SPEED)
	if _keys.up and not jumping and not combat:
		_set_pose("jumpRight" if side == "right" else "jumpLeft")
		jumping = true
		yspeed -= JUMP_SPEED


## The motion of one frame, as the game screen of the client moves the hero:
## friction, gravity, the speed of the keys and the jump. Returns the x speed,
## by which the screen or the hero moves.
func move() -> float:
	vy = (vy + RiderGame.GRAVITY) * RiderGame.Y_FRICTION
	vx *= RiderGame.X_FRICTION
	if absf(vx) < 1.0:
		vx = 0.0
	if vy <= -RiderGame.MAX_Y_SPEED:
		vy = -RiderGame.MAX_Y_SPEED
		jumping = true
	elif absf(vy) < 0.7:
		vy = 0.0
	if absf(vx) < 1.4:
		vx = 0.0
	vx += xspeed
	vy += yspeed
	if yspeed <= -RiderGame.MAX_Y_SPEED:
		yspeed = 0.0
		jumping = true
	y += vy
	if on_ground_test:
		_land()
	_place()
	return vx


## The ground holds the hero; on the ground he can run and jump again. The
## feet are the bottom of the frame of the hero now.
func _land() -> void:
	var ground := game.level.ground_under(x + _feet_x.x, _feet_x.y - _feet_x.x)
	var foot := body.rect_in(body).end.y * SCALE - SINK
	if y + foot < ground or vy < 0.0:
		return
	y = ground - foot
	vy = 0.0
	jumping = false
	if yspeed != 0.0:
		return
	if pose == "jumpRight" and not combat:
		if xspeed < 1.0:
			_set_pose("idleRight")
			xspeed = 0.0
		else:
			_set_pose("runningRight")
			xspeed = MAX_X_SPEED
	elif pose == "jumpLeft":
		if xspeed > -1.0:
			_set_pose("idleLeft")
			xspeed = 0.0
		else:
			_set_pose("runningLeft")
			xspeed = -MAX_X_SPEED
	elif pose == "jumpingAttackRight_1" or pose == "jumpingAttackLeft_1":
		body.go_to("HeadlessIdleRight" if pose == "jumpingAttackRight_1" else "HeadlessIdleLeft", false)
		xspeed = 0.0


func set_screen_x(new_x: float) -> void:
	x = new_x
	_place()


func _place() -> void:
	body.position = Vector2(x, y)
	weapon.position = body.position


## A shaman pushes the hero away.
func knocked(new_vx: float) -> void:
	vx = new_vx
	inactive = true
	_set_pose("fallingRight" if side == "right" else "fallingLeft")


## An archer cuts the legs of the hero: he walks slower for a number of seconds of the client (25 frames).
func hamstring(seconds: float) -> void:
	_hamstrung = true
	_hamstring_frames = int(seconds * 25)
	_hamstring_time = 0
	weapon.set_part("hamsEffect", "visible", true)


## The hero steps into a pit: he falls through the ground and the keys stop.
func fall_into_pit() -> void:
	on_ground_test = false
	xspeed /= 10.0
	controlled = false


## The hero died: his death animation, and the keys stop.
func die() -> void:
	controlled = false
	vx = 0.0
	vy = 0.0
	_set_pose("heroDeath")


## The hero won the level: he walks on to the right.
func walk_out() -> void:
	_set_pose("walkingRight")
	xspeed = 0.9
	controlled = false


## The hits of the sabre (blade 1 or 2) and of the spells, in the frames of the weapon.
func _hit_enemies(path: PackedStringArray, damage: float, push: float, stun_seconds: float, spell: bool) -> void:
	for enemy: RiderEnemy in game.enemies.duplicate():
		var blade := weapon.part_rect(path, game.stage)
		if not blade.has_area() or not blade.intersects(enemy.clip.rect_in(game.stage)):
			continue
		if damage != 0.0:
			var amount: float
			if spell:
				amount = floorf(SPELL_POWER / 4.0 + damage + game.rng.randf() * 5.0)
			else:
				game.bleed(enemy)
				amount = MELEE_POWER / 5.0 + damage + game.rng.randi_range(0, 4)
			enemy.new_health(amount)
		_push(enemy, push)
		if spell and stun_seconds != 0.0 and not enemy.death:
			enemy.stun(stun_seconds)


## A hit pushes an enemy, and it falls back; the bosses do not move.
func _push(enemy: RiderEnemy, push: float) -> void:
	if push == 0.0 or enemy.death or not enemy.pushable:
		return
	enemy.vx += push
	enemy.vy += 20.0
	enemy.kicked()


## The scripts of the frames of the hero.
func on_body_frame(frame: int) -> void:
	match frame:
		0, 348, 401:
			body.playing = false
			if frame != 0:
				var inner := body.part("heroIn")
				if inner != null and inner.node is FlashClip:
					(inner.node as FlashClip).playing = false
		7, 54, 106, 139, 177, 220, 250, 278, 427, 480, 532, 584, 639, 692:
			_set_pose("idleRight")
		16, 123, 155, 198, 241, 258, 298, 452, 505, 559, 609, 664, 718:
			_set_pose("idleLeft")
		65:
			body.go_to("WalkingLeft", true)
		76:
			body.go_to("RunningRight", true)
		89:
			body.go_to("RunningLeft", true)
		131:
			pose = "idleRight"
		148:
			pose = "idleLeft"
		515, 542:
			jumping = true
			yspeed = -JUMP_SPEED
		520, 547:
			yspeed = 1.0
		524, 551:
			yspeed = 0.0
	match frame:
		532, 559:
			xspeed = 0.0
			yspeed = 0.0
		259, 279, 299, 349, 403, 428, 456, 482, 506, 533, 560, 585, 615, 641, 667, 693:
			body.restart("heroIn")


## The scripts of the frames of the sabre and the spells: the hits.
func on_weapon_frame(frame: int) -> void:
	match frame:
		0:
			weapon.playing = false
		7, 34, 60:
			weapon.go_to("Idle", false)
		9, 36, 61, 88, 113, 140, 167, 192, 231, 257, 284, 310:
			weapon.restart("In")
		15, 43, 67, 95:
			game.play_sound("double_sword2")
			_hit_enemies(["In", "shablya_1"], 15.0, 0.0, 0.0, false)
		24, 51, 76, 103:
			_hit_enemies(["In", "shablya_2"], 15.0, 0.0, 0.0, false)
		86:
			_set_pose("idleRight")
		112:
			_set_pose("idleLeft")
		115, 142:
			game.play_sound("attack2_swing")
		118:
			_hit_enemies(["In", "shablya_2"], 15.0, 35.0, 0.0, false)
		145:
			_hit_enemies(["In", "shablya_2"], 15.0, -35.0, 0.0, false)
		133, 160:
			game.play_sound("hero_jumping")
		173, 198:
			game.play_sound("bolt_sound")
		182:
			_hit_enemies(["In", "effect", "line"], 25.0, 15.0, 0.0, true)
		207:
			_hit_enemies(["In", "effect", "line"], 25.0, -15.0, 0.0, true)
		233, 259:
			game.play_sound("thunder_sound")
		245:
			_hit_enemies(["In", "effect", "line"], 60.0, 30.0, 0.0, true)
		271:
			_hit_enemies(["In", "effect", "line"], 60.0, -30.0, 0.0, true)
		288, 314:
			game.play_sound("stun_sound")
		302, 328:
			_hit_enemies(["In", "effect", "line"], 0.0, 0.0, 4.0, true)


## The poses of the hero: the frames of the hero and of the weapon, and the
## cooldown that an attack starts. A pose that runs already goes on.
func _set_pose(name: String) -> void:
	var right := name.contains("Right")
	match name:
		"idleRight", "idleLeft":
			pose = name
			body.go_to("IdleRight" if right else "IdleLeft", false)
			weapon.go_to("Idle", false)
			side = "right" if right else "left"
			inactive = false
		"walkingRight", "walkingLeft":
			if pose != name:
				pose = name
				body.go_to("WalkingRight" if right else "WalkingLeft", false)
				weapon.go_to("Idle", false)
		"runningRight", "runningLeft":
			if pose != name and pose != ("stopLeft" if right else "stopRight"):
				pose = name
				body.go_to("RunningRight" if right else "RunningLeft", false)
				weapon.go_to("Idle", false)
		"stopRight", "stopLeft":
			if pose != name:
				pose = name
				body.go_to("StopRight" if right else "StopLeft", true)
				weapon.go_to("Idle", false)
		"jumpRight", "jumpLeft":
			pose = name
			body.go_to("JumpRight" if right else "JumpLeft", false)
			weapon.go_to("Idle", false)
			before_jump_y = y
		"fallingRight", "fallingLeft":
			pose = name
			body.go_to("FallingRight" if right else "FallingLeft", true)
			weapon.go_to("Idle", false)
		"heroDeath":
			body.go_to("DeathRight" if side == "right" else "DeathLeft", true)
			game.play_sound("hero_death")
			weapon.go_to("Idle", false)
		"healRight", "healLeft":
			pose = name
			body.go_to("HealRight" if right else "HealLeft", true)
			game.play_sound("healing")
			weapon.go_to("Idle", false)
			cooldown = 0
		"jumpingAttackRight_1", "jumpingAttackLeft_1":
			pose = name
			body.go_to("HeadlessJumpRight" if right else "HeadlessJumpLeft", true)
			weapon.go_to("JumpingAttackRight_1" if right else "JumpingAttackLeft_1", true)
			cooldown = 10
		_:
			# attackRight_1 to attackLeft_5: the same labels in the hero and the weapon.
			pose = name
			var label := "Attack%s_%s" % ["Right" if right else "Left", name.get_slice("_", 1)]
			body.go_to(label, true)
			weapon.go_to(label, true)
			cooldown = {"1": 10, "2": 10, "3": 1, "4": 0, "5": 0}[name.get_slice("_", 1)]
