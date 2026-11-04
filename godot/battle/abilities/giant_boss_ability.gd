class_name GiantBossAbility
extends BattleAbility
## The Giant Yeti and the Stone Golem boss, and the yeti and golem of the
## summoning spells (YetiDelegate and GolemBigDelegate of the client). Their
## cycle has three special attacks:
## 1. A stomp: each unit or building of the other side on the tiles within 2
##    tiles that are not in the row or the column of the boss takes
##    SPECIAL_DAMAGE, and units fly 4 tiles away.
## 2. Stones fall on about half of the 6 x 6 tiles around the point 4 tiles in
##    front of the boss, after 2 to 4 seconds, each with SPECIAL_DAMAGE.
## 3. Four helpers (a yeti or a golem) come 3 tiles away on each diagonal.
##
## The Golden Golem and the Black Yeti (GolemBigGoldenDelegate and
## YetiBlackDelegate) have a multiplier of 2: the stomp reaches 4 tiles, the
## stones fall on 12 x 12 tiles, the damage is 2 times SPECIAL_DAMAGE, and 9
## helpers come on a grid with a step of 4 tiles (also on the tile of the
## boss). Their special attacks come every 300 frames for 40 frames.

const SPECIAL_DAMAGE := 50  ## DAMAGE_SPECIAL_GOLEM of the client.
const STOMP_RANGE := 2
const STOMP_PUSH := 4
const STONES_DISTANCE := 4
const STONES_HALF := 3
const STONE_DELAY := 60
const STONE_DELAY_RANDOM := 120
## The client puts the stones in front of the boss by its direction.
const STONE_STEPS := {1: Vector2i(0, -1), 2: Vector2i(0, -1), 3: Vector2i(0, -1), 4: Vector2i(1, 0), 5: Vector2i(1, 0), 6: Vector2i(-1, 0), 7: Vector2i(-1, 0), 8: Vector2i(0, 1)}
const HELPER_OFFSET := 3
const YETI := 544
const GOLEM := 537
const YETI_ITEMS: Array[int] = [545, 631, 642]
const STRONG_ITEMS: Array[int] = [641, 642, 665]

var _helper := YETI
var _multiplier := 1


func configure(item_id: int) -> void:
	_helper = YETI if item_id in YETI_ITEMS else GOLEM
	_multiplier = 2 if item_id in STRONG_ITEMS else 1
	var interval := 300 if _multiplier == 2 else 360
	var duration := 40 if _multiplier == 2 else 60
	special_intervals = [interval, interval, interval]
	special_durations = [duration, duration, duration]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var side := enemy_side(fighter)
	var damage := SPECIAL_DAMAGE * _multiplier
	if in_special(fighter, 0):
		var reach := STOMP_RANGE * _multiplier
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx == 0 or dy == 0:
					continue
				for target in sim.items_near(fighter.tile + Vector2i(dx, dy), 0, 1, side, true, _can_hit):
					sim.receive_attack(target, damage, fighter)
					if target.is_unit():
						sim.push_in_air(target, fighter, STOMP_PUSH)
	elif in_special(fighter, 1):
		var centre: Vector2i = fighter.tile + STONE_STEPS[direction(fighter)] * STONES_DISTANCE
		var half := STONES_HALF * _multiplier
		for y in range(centre.y - half, centre.y + half):
			for x in range(centre.x - half, centre.x + half):
				var roll := sim.rng.randf()
				if roll < 0.5:
					sim.particle(fighter, Vector2i(x, y), MagicParticles.STONE, damage, STONE_DELAY + int(roll * STONE_DELAY_RANDOM))
	elif in_special(fighter, 2):
		var offsets := [-HELPER_OFFSET, HELPER_OFFSET] if _multiplier == 1 else [-4, 0, 4]
		for dy in offsets:
			for dx in offsets:
				sim.spawn(sim.config_item(_helper), fighter.tile + Vector2i(dx, dy), fighter.team, false)
	return fighter.animation == BattleFighter.Pose.ATTACKING


static func _can_hit(item: BattleFighter) -> bool:
	return not item.dead and item.is_valid_target()
