class_name BattleProjectile
extends RefCounted
## A shot that flies from a fighter to its target. The damage comes when it lands.
##
## The client has two kinds of shots. Arrows, rocks, axes and cannonballs move a
## fixed number of pixels in each frame and hit when they land near the target.
## The other shots fly for a time that depends on the distance (1000 pixels in a
## second) and hit when the target is still near the point where they were aimed.
## Positions are map pixels, see IsoGrid.tile_to_map(). Shots start and aim at
## the points of BattleGraphic.

enum Kind { STEPPED, TIMED }

## Stepped shots of the client. They hit when they land within HIT_RADIUS of
## the point at which they aim.
## - speed: pixels per frame. offset: random aim offset in pixels.
## - curve: height of the arc, a part of the length of the flight.
## - aim: the part of the target height above its bottom at which the shot aims.
## - graphic: the graphic in <data>/fx. blast: the effect where the shot lands.
## - trail: the effect that the shot leaves in each frame, trails of them.
const ARROW := {"speed": 30.0, "offset": 20.0, "curve": 0.3, "aim": 0.5, "graphic": "p.arrow"}
const FIRE_ARROW := {"speed": 30.0, "offset": 20.0, "curve": 0.3, "aim": 0.5, "graphic": "p.fireArrow"}
const ROYAL_ARROW := {"speed": 30.0, "offset": 20.0, "curve": 0.3, "aim": 0.5, "graphic": "p.royalArrow"}
const LARGE_ARROW := {"speed": 30.0, "offset": 20.0, "curve": 0.3, "aim": 0.5, "graphic": "p.largeArrow"}
const AXE := {"speed": 20.0, "offset": 20.0, "curve": 0.6, "aim": 0.5, "graphic": "p.axes"}
const ROCK := {"speed": 18.0, "offset": 50.0, "curve": 0.6, "aim": 0.1, "graphic": "p.rock", "blast": "b.earth", "trail": "t.smokeBig", "trails": 1}
const BOULDER := {"speed": 30.0, "offset": 50.0, "curve": 1.0, "aim": 0.1, "graphic": "p.rock", "blast": "b.earth", "trail": "t.smokeBig", "trails": 2}
const CANNONBALL := {"speed": 40.0, "offset": 30.0, "curve": 0.5, "aim": 0.1, "graphic": "p.cannonBall", "blast": "b.earth", "trail": "t.smokeBig", "trails": 1}
const STEPPED_SHOTS := {
	# Units: light, medium and heavy archer, archers on horses, the high elf,
	# the troll archer and four elf archers.
	516: ARROW, 517: ARROW, 518: ARROW, 515: ARROW, 557: ARROW, 589: ARROW, 627: ARROW,
	646: FIRE_ARROW, 675: FIRE_ARROW, 633: ROYAL_ARROW,
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
## The graphics of timed shots in <data>/fx. Other shooters shoot DEFAULT_GRAPHIC.
## Units with special attacks have their own shots, which come with them.
const TIMED_GRAPHICS := {
	# Units
	634: "p.largeArrowGold", 605: "p.boulder", 635: "p.boulder",
	522: "p.cannonBall", 588: "p.cannonBall", 542: "p.cannonBall", 583: "p.cannonBall",
	568: "p.fireBall", 638: "p.fireBall", 672: "p.fireBall", 658: "p.fireBall",
	607: "p.destral", 657: "p.hugeFire", 566: "p.napalm", 637: "p.napalm", 696: "p.napalm",
	548: "p.ink", 624: "p.ink", 546: "p.snow",
	693: "p.lightning", 550: "p.lightning", 692: "p.lightning", 553: "p.lightning",
	689: "p.chorrito", 620: "p.chorrito", 680: "p.chorrazo", 622: "p.chorrazo",
	653: "p.poisonSpit", 698: "p.lightMiniBeam", 707: "p.zombieHead", 711: "p.lightBeam",
	# Buildings
	1318: "p.necroFire", 1309: "p.necroFire", 1501: "p.lightBall",
	199: "p.fireBall", 395: "p.fireBall", 198: "p.fireBall", 412: "p.fireBall", 414: "p.fireBall",
	413: "p.fireBall", 474: "p.fireBall", 1251: "p.fireBall",
	214: "p.lightning", 1258: "p.lightning", 384: "p.snow", 426: "p.chorrazo", 1238: "p.pumpkin",
	1407: "p.goldArrow", 447: "p.goldArrow", 1219: "p.goldArrow", 1374: "p.goldArrow",
}
const DEFAULT_GRAPHIC := "p.arrow"
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
var aim: Vector2  ## The aim point of the target when the shot left.
var damage: int  ## Timed shots keep the attack of the shooter when they leave.
var frames_left: int  ## Frames until the shot lands.
var definition: Dictionary  ## Of a stepped shot, see ARROW.
var steps: float  ## A stepped shot moves (end - start) / steps in each frame.
var first_step: float  ## The step at which a stepped shot starts.
var arc: bool  ## A timed shot flies in an arc.


## A shot from attacker to the current position of target.
static func fire(attacker: BattleFighter, target: BattleFighter, rng: RandomNumberGenerator) -> BattleProjectile:
	var shot := BattleProjectile.new()
	shot.attacker = attacker
	shot.target = target
	shot.damage = attacker.attack
	var stepped: Variant = STEPPED_SHOTS.get(attacker.def.id)
	shot.start = attacker.position
	if attacker.graphic != null:
		shot.start += attacker.graphic.shot_start(target.position - attacker.position, stepped != null)
	if stepped != null:
		shot.kind = Kind.STEPPED
		shot.definition = stepped
		shot.aim = stepped_aim(target, stepped["aim"])
		var offset: float = stepped["offset"]
		shot.end = shot.aim + Vector2(rng.randf() * offset - offset / 2, rng.randf() * offset - offset / 2)
		shot.steps = maxf(shot.start.distance_to(shot.end) / stepped["speed"], 1.0)
		# The flight starts at a random step between 0.05 and 0.99.
		shot.first_step = rng.randf() * 0.94 + 0.05
		shot.frames_left = maxi(ceili(shot.steps - shot.first_step), 1)
	else:
		shot.kind = Kind.TIMED
		shot.aim = target.position + (target.graphic.aim() if target.graphic != null else Vector2.ZERO)
		shot.end = shot.aim + Vector2(_random_range(rng, TIMED_AIM_OFFSET.x), _random_range(rng, TIMED_AIM_OFFSET.y))
		var distance := roundf(shot.start.distance_to(shot.end))
		var seconds := roundf(distance / TIMED_PIXELS_PER_SECOND * 100) / 100
		shot.arc = distance >= ARC_DISTANCE and not attacker.def.id in STRAIGHT_SHOOTERS
		if shot.arc:
			seconds *= ARC_TIME
		shot.frames_left = maxi(roundi(seconds * FRAMES_PER_SECOND), 1)
	return shot


## The point of target at which a stepped shot aims, see BattleGraphic.stepped_aim().
static func stepped_aim(target: BattleFighter, vertical_offset: float) -> Vector2:
	return target.position + (target.graphic.stepped_aim(vertical_offset) if target.graphic != null else Vector2.ZERO)


## The graphic of the shot in <data>/fx.
func graphic() -> String:
	return definition["graphic"] if kind == Kind.STEPPED else TIMED_GRAPHICS.get(attacker.def.id, DEFAULT_GRAPHIC)


static func _random_range(rng: RandomNumberGenerator, limit: int) -> int:
	return rng.randi_range(-limit, limit)
