class_name RiderShots
extends RefCounted
## The shots and spells of the enemies of the mini-game: the spear of the
## warrior, the arrows, and the clouds, ghosts, blasts and fire of the
## shamans. Each is a FlashClip on the screen of the game; update() moves it
## for one frame and returns false when it is gone.


## The angles that the archers and the blasts of the shamans can aim at, in
## degrees: not steeper than 30 degrees up or down.
static func limited_angle(angle: float) -> float:
	if angle >= -90.0 and angle < -30.0:
		return -30.0
	if angle > 30.0 and angle <= 90.0:
		return 30.0
	if angle > -150.0 and angle < -90.0:
		return -150.0
	return angle


class Shot:
	extends RefCounted
	var game: RiderGame
	var clip: FlashClip

	func _init(rider_game: RiderGame, symbol: String) -> void:
		game = rider_game
		clip = FlashClip.new(game.art, game.art.symbol(symbol))

	## One frame; false when the shot is gone.
	func update() -> bool:
		return true

	func on_frame(_frame: int) -> void:
		pass

	func touches_hero() -> bool:
		return clip.rect_in(game.stage).intersects(game.hero.rect())


## A thrown object that flies until it hits the hero once or sticks in the ground.
class Missile:
	extends Shot
	var xspeed := 0.0
	var yspeed := 0.0
	var spin := 0.0  # The turn in degrees in each frame, which grows.
	var stuck := false
	var hit := false
	var blade: PackedStringArray

	func update() -> bool:
		if stuck:
			return true
		_fly()
		var tip := clip.part_rect(blade, game.stage)
		if not hit and tip.has_area() and tip.intersects(game.hero.rect()):
			hit = true
			game.hurt_hero(damage())
		if tip.has_area() and tip.get_center().y >= game.level.ground_y(tip.get_center().x):
			stuck = true
		return clip.position.y < RiderEnemy.FALL_LIMIT

	func _fly() -> void:
		pass

	func damage() -> float:
		return 0.0


class Spear:
	extends Missile

	func _init(rider_game: RiderGame, thrower: Vector2) -> void:
		super(rider_game, "main.spear")
		clip.position = thrower + Vector2(-85.0, -80.0)
		xspeed = 45.0
		yspeed = 4.0
		spin = 1.9
		blade = ["spearBlade"]

	func _fly() -> void:
		yspeed += 2.0
		spin += 0.5
		clip.position += Vector2(-xspeed, yspeed)
		clip.rotation_degrees -= spin

	func damage() -> float:
		return 35.0


class Arrow:
	extends Missile
	var _to_left := true

	func _init(rider_game: RiderGame, archer: Vector2, angle: float) -> void:
		super(rider_game, "main.the_arrow")
		clip.position = archer + Vector2(5.0, -55.0)
		clip.rotation_degrees = angle
		xspeed = 32.0 + game.rng.randf() * 6.0
		game.play_sound("arrow_sound")
		var rotation := wrapf(angle, -180.0, 180.0)
		_to_left = clip.position.x - game.hero.x > 0.0
		if _to_left:
			yspeed = -(180.0 + rotation) / 4.0 if rotation < 0.0 else -(rotation - 180.0) / 3.0
		else:
			yspeed = rotation / 4.0 if rotation < 0.0 else rotation / 3.0
		clip.position.x += 20.0
		blade = ["arrowBlade"]

	func _fly() -> void:
		yspeed += 0.5
		spin += 0.3
		clip.position += Vector2(-xspeed if _to_left else xspeed, yspeed)
		clip.rotation_degrees += -spin if _to_left else spin

	func damage() -> float:
		return 7.0 + game.rng.randi_range(0, 1)


## A spell that hurts the hero while the hero is in it, every `interval` frames, and is gone after `life` frames.
class Area:
	extends Shot
	var interval := 24
	var life := 0
	var damage_min := 15.0
	var damage_random := 2
	var _wait := 0
	var _age := 0

	func update() -> bool:
		_wait += 1
		_age += 1
		if _wait >= interval and touches_hero():
			_wait = 0
			game.hurt_hero(damage_min + game.rng.randi_range(0, damage_random - 1))
		return _age <= life


## The poison cloud of the shaman, at the feet of the hero.
class Cloud:
	extends Area

	func _init(rider_game: RiderGame) -> void:
		super(rider_game, "main.shaman_cloud")
		clip.position = Vector2(game.hero.x, game.hero.standing_y() + 15.0)
		life = 140


## The rain of fire of the great shaman, over the hero.
class Rainfire:
	extends Area

	func _init(rider_game: RiderGame) -> void:
		super(rider_game, "main.shaman_rainfire")
		clip.position = Vector2(game.hero.x, 320.0)
		life = 50

	func on_frame(frame: int) -> void:
		match frame:
			0, 10, 20, 30:
				game.play_sound("shaman_boss_fire")
			34:
				clip.playing = false


## A ghost of the shaman at one side of the hero; it hurts the hero once, in its 20th frame.
class Ghost:
	extends Shot
	var _age := 0
	var _wait := 1

	func _init(rider_game: RiderGame, side: String) -> void:
		super(rider_game, "shaman_ghost_right" if side == "right" else "shaman_ghost_left")
		clip.position = Vector2(game.hero.x + (-70.0 if side == "right" else 120.0), game.hero.standing_y() - 15.0)

	func update() -> bool:
		_wait += 1
		_age += 1
		if _wait == 21 and touches_hero():
			game.hurt_hero(15.0 + game.rng.randi_range(0, 2))
		return _age <= 65


## The blast of the shaman, turned to the hero; it hurts once.
class Blast:
	extends Shot
	var _age := 0
	var _hit := false

	func _init(rider_game: RiderGame, shaman: Vector2, side: String) -> void:
		super(rider_game, "main.shaman_blast")
		clip.position = shaman + (Vector2(57.0, -114.0) if side == "right" else Vector2(0.0, -115.0))
		var delta := clip.position - Vector2(game.hero.x, game.hero.y + 40.0)
		clip.rotation_degrees = RiderShots.limited_angle(rad_to_deg(atan2(-delta.y, -delta.x)))

	func update() -> bool:
		_age += 1
		if not _hit and touches_hero():
			_hit = true
			game.hurt_hero(20.0 + game.rng.randi_range(0, 4))
		return _age <= 20
