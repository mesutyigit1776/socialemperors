class_name EtherShieldSpell
extends BattleSpell
## Ether Shield: the items on the square take less damage for a time.
##
## The port does what the client does, with its errors:
## - The client reads the area of the next level: at level 1 the shield covers
##   7 tiles, at level 2 it covers 9, and at level 3 it covers none.
## - The shield protects the items of all sides, also enemies.
## - The spell keeps the id of its last shield only. When the player casts it
##   again before the first shield ends, the first shield stays for the rest of
##   the battle.
## Set FIX_CLIENT_ERRORS to true to protect the marked square at each level,
## only for the items of the player, and to end each shield after its time.

const FIX_CLIENT_ERRORS := false
const DAMAGE_FACTOR: Array[float] = [0.7, 0.55, 0.4]
const SECONDS: Array[int] = [20, 30, 40]

var _shield_id := 0


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var factor := DAMAGE_FACTOR[level - 1]
	if FIX_CLIENT_ERRORS:
		var shield_id := sim.add_shield(tile, area(level), factor, BattleFighter.Team.PLAYER)
		_particle(sim, 0, SECONDS[level - 1] * BattleSim.FRAMES_PER_SECOND, sim.remove_shield.bind(shield_id))
		return
	var next_area: int = def.areas[level] if level < def.areas.size() else 0
	_shield_id = sim.add_shield(tile, next_area, factor)
	_particle(sim, 0, SECONDS[level - 1] * BattleSim.FRAMES_PER_SECOND, func() -> void: sim.remove_shield(_shield_id))
