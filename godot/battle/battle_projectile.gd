class_name BattleProjectile
extends RefCounted
## A shot that flies from a fighter to its target. The damage comes when it lands.
##
## The client has two kinds of shots. Arrows, rocks, axes and cannonballs move a
## fixed number of pixels in each frame and hit when they land near the target.
## The other shots fly for a time that depends on the distance (1000 pixels in a
## second) and hit when the target is still near the point where they were aimed.
## Positions are map pixels, see IsoGrid.tile_to_map().

enum Kind { STEPPED, TIMED }

## Stepped shots: [pixels per frame, random aim offset in pixels]. They hit
## when they land within HIT_RADIUS of the target.
const ARROW := [30.0, 20.0]
const AXE := [20.0, 20.0]
const ROCK := [18.0, 50.0]
const BOULDER := [30.0, 50.0]
const CANNONBALL := [40.0, 30.0]
const STEPPED_SHOTS := {
	# Units: light, medium and heavy archer, archers on horses, the high elf,
	# the troll archer and two elf archers.
	516: ARROW, 517: ARROW, 518: ARROW, 515: ARROW, 557: ARROW, 589: ARROW, 627: ARROW,
	646: ARROW, 675: ARROW, 633: ARROW,
	520: ARROW, 586: ARROW, 602: ARROW,  # Large arrows of the scorpions and the mobile tower.
	521: ROCK, 587: ROCK,  # Catapults
	767: BOULDER,
	530: AXE, 551: AXE, 598: AXE,  # Axe throwers
	# Buildings: towers I to V and similar towers, then the castles.
	29: ARROW, 30: ARROW, 31: ARROW, 243: ARROW, 291: ARROW, 303: ARROW, 304: ARROW,
	32: ARROW, 376: ARROW, 347: ARROW,
	27: CANNONBALL, 28: CANNONBALL, 323: CANNONBALL, 324: CANNONBALL, 181: CANNONBALL,
	33: CANNONBALL, 348: CANNONBALL, 270: CANNONBALL, 1230: CANNONBALL, 1231: CANNONBALL,
	1234: CANNONBALL, 1443: CANNONBALL,
}
const HIT_RADIUS := 100.0
## Timed shots fly this number of pixels in a second.
const TIMED_PIXELS_PER_SECOND := 1000.0
## A timed shot over a longer distance flies in an arc, which takes ARC_TIME times as long.
const ARC_DISTANCE := 300.0
const ARC_TIME := 1.6
## Random aim offset of a timed shot, in whole pixels: -15..15 and -10..10.
const TIMED_AIM_OFFSET := Vector2i(15, 10)
## Shooters whose timed shots always fly straight: lightning, fire of the dragon
## boss, heads of the big zombie, and many dragons and wizards.
const STRAIGHT_SHOOTERS: Array[int] = [
	214, 1258, 550, 553, 692, 693, 657, 707,
	633, 634, 638, 652, 672, 683, 690, 691, 695, 698, 708, 710, 719, 723, 725, 733, 744,
	749, 754, 769, 771, 772, 773, 775, 778, 784, 785, 786, 799, 826, 849, 850, 853, 854,
	855, 856, 2014, 2090,
]
const FRAMES_PER_SECOND := 30.0

var kind: Kind
var attacker: BattleFighter
var target: BattleFighter
var start: Vector2
var end: Vector2  ## Where the shot lands.
var aim: Vector2  ## Where the target was when the shot left.
var damage: int  ## Timed shots keep the attack of the shooter when they leave.
var frames_left: int  ## Frames until the shot lands.


## A shot from attacker to the current position of target.
static func fire(attacker: BattleFighter, target: BattleFighter, rng: RandomNumberGenerator) -> BattleProjectile:
	var shot := BattleProjectile.new()
	shot.attacker = attacker
	shot.target = target
	shot.start = attacker.position
	shot.aim = target.position
	shot.damage = attacker.attack
	var stepped: Variant = STEPPED_SHOTS.get(attacker.def.id)
	if stepped != null:
		shot.kind = Kind.STEPPED
		var offset: float = stepped[1]
		shot.end = shot.aim + Vector2(rng.randf() * offset - offset / 2, rng.randf() * offset - offset / 2)
		var steps := maxf(shot.start.distance_to(shot.end) / stepped[0], 1.0)
		# The flight starts at a random step between 0.05 and 0.99.
		shot.frames_left = maxi(ceili(steps - (rng.randf() * 0.94 + 0.05)), 1)
	else:
		shot.kind = Kind.TIMED
		shot.end = shot.aim + Vector2(_random_range(rng, TIMED_AIM_OFFSET.x), _random_range(rng, TIMED_AIM_OFFSET.y))
		var distance := roundf(shot.start.distance_to(shot.end))
		var seconds := roundf(distance / TIMED_PIXELS_PER_SECOND * 100) / 100
		if distance >= ARC_DISTANCE and not attacker.def.id in STRAIGHT_SHOOTERS:
			seconds *= ARC_TIME
		shot.frames_left = maxi(roundi(seconds * FRAMES_PER_SECOND), 1)
	return shot


static func _random_range(rng: RandomNumberGenerator, limit: int) -> int:
	return rng.randi_range(-limit, limit)
