class_name Dragon2Quest
extends QuestBattle
## The second dragon island (QuestBossDragon2 of the client).
##
## - All items of the map are neutral. Two rocks close the path at
##   PATH_ROCKS. Two Golden Dragon Bosses and the Deadly Dragon Boss come on
##   the map, and EGGS Huge Eggs, which are enemies.
## - When both golden dragons are dead, the rocks leave the path after 1.5
##   seconds.
## - The Deadly Dragon cannot be hurt by attacks (DeadlyDragonAbility). Each
##   egg that is destroyed takes a part of its life; when the last egg is
##   destroyed, the dragon dies after 1.5 seconds and the player wins. An
##   attack on an egg makes the dragon attack the attacker.
## - The stars set the attack, speed and life of the dragons and the life of
##   the eggs. The quest gives no experience; the dragons and eggs pay gold.

const EGG := 434
const ROCK := 945
const PATH_ROCKS: Array[Vector2i] = [Vector2i(29, 43), Vector2i(31, 43)]
const GOLDEN_DRAGON := 739
const DEADLY_DRAGON := 1532
const DRAGONS: Array[int] = [GOLDEN_DRAGON, GOLDEN_DRAGON, DEADLY_DRAGON]
const DRAGON_TILES: Array[Vector2i] = [Vector2i(12, 90), Vector2i(16, 79), Vector2i(79, 33)]
const EGG_TILES: Array[Vector2i] = [Vector2i(69, 52), Vector2i(67, 55), Vector2i(64, 53), Vector2i(67, 49), Vector2i(94, 54), Vector2i(93, 50), Vector2i(92, 7), Vector2i(94, 10)]
const AGGRO_RANGE := 20
const DEADLY_AGGRO_RANGE := 25
const DEADLY_DRAGON_LIFE := 30000
## Golden dragons: [attack, speed, life] for 1, 2 and 3 stars.
const GOLDEN_STATS: Array[Vector3i] = [Vector3i(40, 4, 8000), Vector3i(45, 5, 10000), Vector3i(50, 6, 12000)]
## The Deadly Dragon: [attack, speed] and the life of the eggs for 1, 2 and 3 stars.
const DEADLY_STATS: Array[Vector2i] = [Vector2i(100, 7), Vector2i(120, 8), Vector2i(140, 9)]
const EGG_LIFE: Array[int] = [5000, 7000, 9000]
const DELAY_FRAMES := 45  ## 1.5 seconds.

var _rocks: Array[BattleFighter] = []
var _dragons: Array[BattleFighter] = []
var _eggs: Array[BattleFighter] = []
var _golden_killed := 0
var _eggs_killed := 0


func counter_texts() -> Array[String]:
	return []


func recovered_percent() -> int:
	return _config.quest_units_back_boss


func deadly_dragon() -> BattleFighter:
	return _dragons[2] if _dragons.size() > 2 else null


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	return BattleFighter.Team.ENEMY if def.id in [EGG, 437] else BattleFighter.Team.NEUTRAL


func _gives_map_units() -> bool:
	return false


func _on_placed(_item: BattleFighter) -> void:
	pass


func _map_loaded() -> void:
	for tile in PATH_ROCKS:
		_rocks.append(_add(_config.get_item(ROCK), tile, BattleFighter.Team.NEUTRAL))
	for i in DRAGONS.size():
		var tile: Variant = BattleFormation.nearest_free_tile(DRAGON_TILES[i], IsoGrid.MAP_TILES, sim.is_free)
		if tile == null:
			continue
		var dragon := _add(_config.get_item(DRAGONS[i]), tile, BattleFighter.Team.ENEMY)
		dragon.ai.aggro_range = DEADLY_AGGRO_RANGE if DRAGONS[i] == DEADLY_DRAGON else AGGRO_RANGE
		_dragons.append(dragon)
	for egg_tile in EGG_TILES:
		var tile: Variant = BattleFormation.nearest_free_tile(egg_tile, IsoGrid.MAP_TILES, sim.is_free)
		if tile != null:
			_eggs.append(_add(_config.get_item(EGG), tile, BattleFighter.Team.ENEMY))
	sim.hit.connect(_on_hit)


func _free_units_counted() -> int:
	return 0


func _apply_stars() -> void:
	for dragon in _dragons:
		var attack: int
		var speed: int
		var life: int
		if dragon.def.id == DEADLY_DRAGON:
			attack = DEADLY_STATS[stars - 1].x
			speed = DEADLY_STATS[stars - 1].y
			life = DEADLY_DRAGON_LIFE
		else:
			attack = GOLDEN_STATS[stars - 1].x
			speed = GOLDEN_STATS[stars - 1].y
			life = GOLDEN_STATS[stars - 1].z
		dragon.attack = attack
		sim.set_speed(dragon, speed)
		dragon.max_health = life
		dragon.health = life
	for egg in _eggs:
		egg.max_health = EGG_LIFE[stars - 1]
		egg.health = egg.max_health


## The client pays gold for the eggs and the two golden dragons.
func _divide_reward() -> void:
	_gold_units = EGG_TILES.size() + 2
	super()


func _gives_reward(item: BattleFighter) -> bool:
	if item in _eggs or (item in _dragons and item.def.id == GOLDEN_DRAGON):
		gold += _gold_per_kill
		changed.emit()
	return false


func _on_enemy_died(item: BattleFighter) -> void:
	if item in _dragons and item.def.id == GOLDEN_DRAGON:
		_golden_killed += 1
		if _golden_killed == 2:
			sim.after(DELAY_FRAMES, _open_path)
	elif item in _eggs:
		_eggs_killed += 1
		var dragon := deadly_dragon()
		if _eggs_killed == EGG_TILES.size():
			sim.after(DELAY_FRAMES, _kill_dragon)
		if dragon != null and dragon.ability is DeadlyDragonAbility:
			dragon.ability.hurt(sim, dragon, DEADLY_DRAGON_LIFE / EGG_TILES.size() - 100)


func _open_path() -> void:
	for rock in _rocks:
		sim.remove_item(rock)
	_rocks.clear()


func _kill_dragon() -> void:
	var dragon := deadly_dragon()
	if dragon != null and dragon.ability is DeadlyDragonAbility:
		dragon.ability.kill(sim, dragon)
	_win()


## An attack on an egg makes the Deadly Dragon attack the attacker.
func _on_hit(target: BattleFighter, attacker: BattleFighter, _damage: int, _critical: bool) -> void:
	var dragon := deadly_dragon()
	if target in _eggs and attacker != null and dragon != null and dragon.ability is DeadlyDragonAbility:
		dragon.ability.egg_attacked(sim, dragon, attacker)


func _end_soon(seconds := 1) -> void:
	# The client waits 3 seconds after a loss on this island.
	super(3 if _player_units == 0 and not _won else seconds)
