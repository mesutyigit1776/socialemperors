class_name HellAbyssSpell
extends BattleSpell
## Hell Abyss: a hole opens in the middle of the square and swallows the enemy
## units and buildings within half the area (rounded up) of it. Bosses, town
## halls, treasures, activators and units with 500 life or more stay.

const DELAY := 10


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	open_hole(sim, tile - Vector2i.ONE * (ceili(side / 2.0) - 1), side, (level * 2 + 3) / 5.0, DELAY, BattleFighter.Team.ENEMY, false)


## A hole on centre for a square of side tiles swallows the items of team.
## Hades opens it with units_only (SpellCrack.onlyAffectUnits of the client).
func open_hole(sim: BattleSim, centre: Vector2i, side: int, scale: float, delay: int, team: BattleFighter.Team, units_only: bool) -> void:
	# The client does not fade the hole: its graphic stops at its last frame.
	var look := {"scale": scale, "frames": -1}
	_particle(sim, centre, delay, _attack_frame, func() -> void:
		var found := sim.items_near(centre, ceili(side / 2.0), side * side, team, true, func(item: BattleFighter) -> bool:
			return _can_fall(item) and (not units_only or item.is_unit()))
		for i in range(found.size() - 1, -1, -1):
			# With an even area the client keeps the middle row and column.
			var middle := centre + Vector2i.ONE * (side / 2)
			if side % 2 == 0 and (found[i].tile.x == middle.x or found[i].tile.y == middle.y):
				continue
			sim.swallow(found[i]), look)


static func _can_fall(item: BattleFighter) -> bool:
	return not item.dead and not _is_protected(item)


func descriptions(config: GameConfig) -> Array[String]:
	return _area_texts(config, "SPELL_CRACK_DESCRIPCION", [])
