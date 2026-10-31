class_name HailSpell
extends BattleSpell
## Ultimate Hail: a stone falls on each tile of the area, each after a random
## delay of up to 100 frames. A stone hurts the enemy building on its tile with
## its full damage, and knocks down the enemy unit on it with a tenth of it. A
## building gets a stone for each of its tiles. Town halls, treasures and
## activators take nothing.

const DAMAGE: Array[int] = [800, 1000, 1500]
const UNIT_SHARE := 0.1
const MAX_DELAY := 100


func cast(sim: BattleSim, tile: Vector2i, level: int) -> void:
	for point in _square_from_corner(tile, area(level)):
		_particle(sim, point, sim.rng.randf() * MAX_DELAY, _attack_frame, func() -> void:
			var enemy := _item_of(sim, point, BattleFighter.Team.ENEMY)
			if enemy == null:
				return
			if enemy.is_unit():
				sim.stun(enemy)
				sim.receive_attack(enemy, int(DAMAGE[level - 1] * UNIT_SHARE), null)
			elif not enemy.def.subcat_functional in [SUBCAT_TOWN_HALL, SUBCAT_ACTIVATOR, SUBCAT_TREASURE]:
				sim.receive_attack(enemy, DAMAGE[level - 1], null), {"depth": "mixed"})


func descriptions(config: GameConfig) -> Array[String]:
	return _area_texts(config, "SPELL_STONERAIN_DESCRIPCION", DAMAGE)
