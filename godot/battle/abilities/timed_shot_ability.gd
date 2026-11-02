class_name TimedShotAbility
extends BattleAbility
## Units that play an attack animation for each shot and shoot at a frame of
## it (CelestialDraggyDelegate, CentauroDelegate, ElfArcherDelegate,
## ElfCatapultDelegate and AntimatterGolemDelegate of the client). Some of
## them hit at once when the target is near (the centaur within 2 tiles).

## Item id -> [shot graphic, frame of the shot, action (UnitSprite.Action),
## distance at which it hits at once (or -1), fallback frames of the animation].
const UNITS := {
	814: ["p.crystalBall", 10, UnitSprite.Action.ATTACKING, -1, 20],  # Celestial Draggy
	756: ["p.centauroKnife", 12, UnitSprite.Action.SPECIAL, 2, 20],  # Centaur
	2006: ["p.elfArrow", 9, -1, -1, 0],  # Imperial Elf Archer: shot after 9 frames, no lock
	2098: ["p.antimatter", 15, -1, -1, 0],  # Antimatter Golem: shot after 500 ms
	2036: ["p.horusSpear", 12, -1, -1, 0],  # Golden Paladin: spear after 400 ms
}

var _shot := ""
var _frame := 0
var _action := -1
var _near := -1
var _fallback := 20


func configure(item_id: int) -> void:
	var data: Array = UNITS[item_id]
	_shot = data[0]
	_frame = data[1]
	_action = data[2]
	_near = data[3]
	_fallback = data[4]


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	var target := fighter.target
	if _near >= 0 and sim.distance(fighter, target) <= _near:
		sim.receive_attack(target, fighter.attack, fighter)
		return false
	var shoot := func() -> void:
		if not fighter.dead and fighter.target != null and not fighter.target.dead:
			sim.shoot(fighter, fighter.target, _shot, fighter.attack)
	if _action < 0:
		sim.after(_frame, shoot)
	else:
		play(sim, fighter, _action, _fallback, {_frame: shoot})
	return false
