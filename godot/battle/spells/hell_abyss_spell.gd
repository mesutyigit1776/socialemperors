class_name HellAbyssSpell
extends BattleSpell
## Hell Abyss: a hole opens in the middle of the square and swallows the enemy
## units and buildings within half the area (rounded up) of it. Bosses, town
## halls, treasures, activators and units with 500 life or more stay.

const DELAY := 10


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	var side := area(level)
	var centre := tile - Vector2i.ONE * (ceili(side / 2.0) - 1)
	# The client does not fade the hole: its graphic stops at its last frame.
	var look := {"scale": (level * 2 + 3) / 5.0, "frames": -1}
	_particle(sim, centre, DELAY, _attack_frame, func() -> void:
		var found := sim.items_near(centre, ceili(side / 2.0), side * side, BattleFighter.Team.ENEMY, true, _can_fall)
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
