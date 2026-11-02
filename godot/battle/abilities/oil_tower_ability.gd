class_name OilTowerAbility
extends BattleAbility
## The Oil Tower (OilTowerDelegate of the client). Each attack pours burning
## oil on a line of 7 tiles in front of the tower, by its direction (the frame
## of the building): a unit on these tiles burns, 5 damage every second, 5 times.

## Frame of the tower -> the offsets of the 7 tiles.
const LINES := {
	0: [Vector2i(-3, 1), Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	1: [Vector2i(1, -3), Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	2: [Vector2i(-3, -1), Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -1)],
	3: [Vector2i(-1, -3), Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3)],
}
const DAMAGE := 5
const TICKS := 5


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	for offset: Vector2i in LINES.get(fighter.frame, LINES[0]):
		sim.particle(fighter, fighter.tile + offset, MagicParticles.FIRE_RED, 0, 0, func(attacker: BattleFighter, target: BattleFighter, _value: int) -> void:
			if target != null and target.is_unit():
				sim.incinerate(target, attacker, DAMAGE, TICKS, BattleSim.FRAMES_PER_SECOND))
	return false
