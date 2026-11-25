class_name RiderEnemy
extends RefCounted
## An enemy of the mini-game. As in the client, each enemy stands on an
## invisible platform that falls on the ground and moves; the enemy is drawn
## 21 pixels below the top of its platform. The subclasses decide what the
## enemy does (decide()) and what happens in the frames of its animations
## (on_frame()).

## The platform: its size (the shape of main.platform), and the place above
## the ground where it waits while it is far from the hero.
const PLATFORM_SIZE := Vector2(44.5, 22.0)
const FAR_FROM_HERO := 700.0
const WAITING_Y := 220.0
const DRAWN_BELOW_PLATFORM := 21.0
## An enemy that falls below this line dies.
const FALL_LIMIT := 600.0
## The enemy is hidden while it is further than this from the hero.
var hidden_beyond := 650.0
## The text of a hit fades by this much in each frame and moves up 1 pixel.
const TEXT_FADE := 0.05

var game: RiderGame
var clip: FlashClip
var max_health := 1.0
var health := 1.0
var side := "left"
var combat := false
var death := false
var block := false  ## The hits do no damage (the block of the warrior).
var pushable := true  ## The hits of the hero push the enemy; not the bosses.
## Frames since the last attack; negative while the enemy is stunned.
var cooldown := 0
var pose := ""
## The platform, in the coordinates of the screen of the game.
var x := 0.0
var y := WAITING_Y
var vx := 0.0
var vy := 0.0
var xspeed := 0.0
var _text: Label
var _text_y := 0.0
## The bars of the subclasses: the y of the text of a hit, and the sound of the death.
var text_top := -115.0
var death_sound := ""


## expand: the parts that the enemy plays or turns itself, see FlashClip.
func _init(rider_game: RiderGame, symbol: String, start_x: float, expand: Dictionary = {}) -> void:
	game = rider_game
	expand["health_Bar"] = true
	clip = FlashClip.new(game.art, game.art.symbol(symbol), expand)
	x = start_x
	_text = game.make_hit_text()
	var text_part := clip.part("minusHealth_txt")
	_text.position.x = text_part.node.position.x if text_part != null else 0.0
	_text.modulate.a = 0.0
	clip.add_child(_text)
	_update_bar()


## The distance from the hero on the screen: positive when the enemy is on the right.
func x_delta() -> float:
	return clip.position.x - game.hero.x


## One frame of the platform, before the enemy decides: gravity, the speed of
## the pose, and the ground. An enemy that falls out dies.
func move() -> void:
	var gravity := 0.0 if absf(x - game.hero.x) > FAR_FROM_HERO else RiderGame.GRAVITY
	if gravity == 0.0:
		y = WAITING_Y
	vy = (vy + gravity) * RiderGame.Y_FRICTION
	vx *= RiderGame.X_FRICTION
	if absf(vx) < 1.0:
		vx = 0.0
	if vy <= -RiderGame.MAX_Y_SPEED:
		vy = -RiderGame.MAX_Y_SPEED
	elif absf(vy) < 0.7:
		vy = 0.0
	# The client slows the platforms a second time.
	vx = vx * RiderGame.X_FRICTION + xspeed
	if absf(vx) < 1.0:
		vx = 0.0
	x += vx
	y += vy
	var ground := game.level.ground_under(x, PLATFORM_SIZE.x)
	if y + PLATFORM_SIZE.y > ground:
		y = ground - PLATFORM_SIZE.y
		vy = 0.0
	clip.position = Vector2(x, y + DRAWN_BELOW_PLATFORM)
	if clip.position.y > FALL_LIMIT:
		new_health(2000)


## One frame of the enemy while it lives: the subclass decides, and the text of the last hit fades.
func update() -> void:
	clip.visible = absf(x_delta()) <= hidden_beyond
	cooldown += 1
	decide()
	if _text.modulate.a >= 0.0:
		_text.modulate.a -= TEXT_FADE
		_text_y -= 1.0
		_text.position.y = _text_y


## What the enemy does in this frame; see the subclasses.
func decide() -> void:
	pass


## The frame events of the animations: the subclasses hit the hero, shoot and cast here.
func on_frame(_frame: int) -> void:
	pass


## The enemy loses health; a blocking warrior loses none.
func new_health(amount: float) -> void:
	if death:
		return
	if block:
		_show_text("block")
		return
	health -= amount
	_show_text("-%d" % amount)
	_update_bar()
	if health <= 0.0:
		_text.modulate.a = 0.0
		clip.set_part("health_Bar", "visible", false)
		game.play_sound(death_sound)
		die()
		death = true


## The death animation of the subclass.
func die() -> void:
	pass


## A hit of the hero pushes the enemy; see RiderHero.kick_enemy().
func kicked() -> void:
	pass


## A spell of the hero stuns the enemy for a number of seconds of the client (25 frames).
func stun(seconds: float) -> void:
	cooldown = int(-seconds * 25)
	stunned()


func stunned() -> void:
	pass


## The pose of the enemies when the hero dies.
func won() -> void:
	clip.go_to("WinningRight" if side == "right" else "WinningLeft", false)


## Puts the other enemies up to 150 pixels on the right into combat, as the client does.
func call_others() -> void:
	for other: RiderEnemy in game.enemies:
		if other.clip.position.x > clip.position.x and other.clip.position.x < clip.position.x + 150.0:
			other.combat = true


## Plays a pose: label of the sprite, whether it plays, the speed of the platform.
func set_pose(name: String, label: String, play: bool, speed: float) -> void:
	pose = name
	clip.go_to(label, play)
	set_speed(speed)


## The speed of the platform, with a random part of up to 0.2, as platformSpeed() of the client.
func set_speed(speed: float) -> void:
	xspeed = speed + (game.rng.randf() / 5.0 if randomizes_speed() else 0.0)


## The bosses move at the given speed.
func randomizes_speed() -> bool:
	return true


## True when a part of the enemy touches the hero; path names the part, for example ["In", "sword"].
func touches_hero(path: PackedStringArray) -> bool:
	var rect := clip.part_rect(path, game.stage)
	return rect.has_area() and rect.intersects(game.hero.rect())


## Hurts the hero when the part touches it: damage plus a random 0 to random_max - 1.
func hit_hero_with(path: PackedStringArray, damage: float, random_max := 5) -> void:
	if touches_hero(path):
		game.hurt_hero(damage + game.rng.randi_range(0, random_max - 1))


func _show_text(text: String) -> void:
	_text.text = UiClip.drawable(_text, text)
	_text.modulate.a = 1.0
	_text_y = text_top
	_text.position.y = _text_y


func _update_bar() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var bar := clip.clip("health_Bar")
	if bar != null:
		bar.set_part("bar", "scale_x", ratio)
	clip.set_part("health_Bar", "alpha", (1.0 - ratio) / 3.0)
