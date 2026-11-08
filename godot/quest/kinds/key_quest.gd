class_name KeyQuest
extends QuestBattle
## The boss islands with keys: the Arctic island of the Yeti (QuestBossYeti of
## the client), the Desert island of the Golem (QuestBossGolem) and the island
## of the Rockdriller (QuestBossWorm).
##
## - The enemy units stand in GROUPS groups, by the part of the island. When
##   the last unit of a group is dead, the key (activator) of the group opens.
##   Only the units of the groups give experience.
## - The player collects an open key with a click. When the player has all
##   keys, the boss comes: on the Arctic island the gate in front of the Giant
##   Yeti opens, on the Desert island the altar becomes the Stone Golem, and
##   the Rockdriller comes out of the ground near the centre.
## - On the Arctic island each key also frees 3 penguins, which join the player.
## - The stars do not copy the enemies. They make the boss stronger, and with 3
##   stars a second boss comes. The player wins when the bosses are dead.
## - A win gives items (QuestIsland.rewards).

const GROUPS := 4
## The Arctic island puts each unit in the group of the nearest of these points.
const YETI_GROUP_POINTS: Array[Vector2i] = [Vector2i(18, 38), Vector2i(18, 59), Vector2i(29, 79), Vector2i(58, 78)]
const PENGUIN := 546
const PENGUINS_PER_KEY := 3
const PENGUIN_OFFSETS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-2, 1), Vector2i(1, -2)]
const SUBCAT_STABLE := 331
const GOLEM_BOSS := 538
const ROCKDRILLER_BOSS := 566
const ROCKDRILLER_START := Vector2i(49, 49)
## The life of the boss for 1, 2 and 3 stars. The attack does not change.
const LIFE_MULTIPLIERS: Array[float] = [1.0, 2.0, 2.0]
const ROCKDRILLER_LIFE_MULTIPLIERS: Array[float] = [0.8, 2.0, 2.0]
## The second boss with 3 stars comes on the free tile nearest to this offset
## from the boss (Arctic) or from the altar (Desert, Rockdriller).
const SECOND_BOSS_OFFSET_YETI := Vector2i(0, 3)
const SECOND_BOSS_OFFSET := Vector2i(3, 0)
## The Rockdriller and the Sanddriller pay no gold on this island.
const NO_GOLD_NAMES: Array[String] = ["Sanddriller", "Rockdriller"]

var _groups: Array[Array] = []  # Group -> the enemy units in it that are alive.
var _keys: Array = [null, null, null, null]  # Group -> its key (BattleFighter), or null.
var _open_keys: Array[BattleFighter] = []
var _collected := 0
var _statue: BattleFighter  # The gate of the Arctic island or the altar of the Desert island.
var _bosses: Array[BattleFighter] = []
var _boss_killed := 0
var _boss_released := false  # The player collected all keys.


func _init() -> void:
	for i in GROUPS:
		_groups.append([])


func counter_texts() -> Array[String]:
	# The client hides the counter when the boss comes.
	if _boss_released:
		return []
	var left := _keys_left()
	match island.family:
		QuestIsland.Family.YETI:
			return [_config.text("QUEST_YETI_LLAVES"), _config.text("QUEST_YETI_FALTAN").replace("#0#", str(left))]
		QuestIsland.Family.GOLEM:
			return [_config.text("QUEST_GOLEM_GEMAS"), str(left)]
	# The client hides the title on this island.
	return ["", _config.text("QUEST_GUSANO_BRASEROS").replace("#0#", str(left))]


func enemies_left() -> int:
	return _keys_left()


func recovered_percent() -> int:
	return _config.quest_units_back_boss


func is_collectable(item: BattleFighter) -> bool:
	return item in _open_keys


## The player collects an open key.
func collect(item: BattleFighter) -> bool:
	if not item in _open_keys or _finished:
		return false
	_open_keys.erase(item)
	sim.remove_item(item)
	_collected += 1
	if _keys_left() <= 0:
		_bring_boss()
	elif island.family == QuestIsland.Family.YETI:
		_player_units += PENGUINS_PER_KEY
		_add_free_units(_config.get_item(PENGUIN), PENGUINS_PER_KEY)
	if island.family == QuestIsland.Family.YETI:
		for offset in PENGUIN_OFFSETS:
			var tile: Variant = BattleFormation.nearest_free_tile(item.tile + offset, IsoGrid.MAP_TILES, sim.is_free)
			if tile != null:
				_add(_config.get_item(PENGUIN), tile, BattleFighter.Team.PLAYER)
	changed.emit()
	return true


## The bosses that are on the map now.
func bosses() -> Array[BattleFighter]:
	return _bosses


func _keys_left() -> int:
	return _keys.filter(func(key: Variant) -> bool: return key != null).size() - _collected


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.subcat_functional in [SUBCAT_DECORATION, SUBCAT_SCENERY] or (island.family != QuestIsland.Family.WORM and def.subcat_functional == SUBCAT_STABLE):
		return BattleFighter.Team.NEUTRAL
	if island.family == QuestIsland.Family.WORM or def.subcat_functional in [SUBCAT_ACTIVATOR, SUBCAT_BOSS_STATUE]:
		# The client leaves these items on the side of their race.
		return BattleFighter.Team.NEUTRAL if def.race == "n" else BattleFighter.Team.ENEMY
	return BattleFighter.Team.ENEMY


func _on_placed(item: BattleFighter) -> void:
	var group := _group_of(item.tile)
	var subcat := item.def.subcat_functional
	if subcat == SUBCAT_ACTIVATOR:
		# A later key of the same group takes the place of an earlier one.
		_keys[group] = item
		item.frame = group
	elif subcat == SUBCAT_BOSS_STATUE and island.family != QuestIsland.Family.WORM:
		_statue = item
	elif subcat == SUBCAT_BOSS and island.family == QuestIsland.Family.YETI:
		_bosses.append(item)
	elif item.is_unit() and item.team == BattleFighter.Team.ENEMY:
		if island.family != QuestIsland.Family.WORM or item.def.race in ["t", "e"] or subcat == SUBCAT_BOSS_HELPER:
			_groups[group].append(item)


func _group_of(tile: Vector2i) -> int:
	match island.family:
		QuestIsland.Family.YETI:
			var best := 0
			for i in YETI_GROUP_POINTS.size():
				if Vector2(tile - YETI_GROUP_POINTS[i]).length() < Vector2(tile - YETI_GROUP_POINTS[best]).length():
					best = i
			return best
		QuestIsland.Family.GOLEM:
			return (0 if tile.y <= 54 else 2) if tile.x <= 50 else (1 if tile.y <= 54 else 3)
	return (0 if tile.y < 50 else 2) if tile.x < 50 else (1 if tile.y < 50 else 3)


## The client counts the free units of the Arctic island with an error that
## adds nothing, so there the free units do not keep the player in the quest.
func _free_units_counted() -> int:
	return 0 if island.family == QuestIsland.Family.YETI else super()


func _apply_stars() -> void:
	# The boss of the Arctic island is on the map from the start.
	if island.family == QuestIsland.Family.YETI and not _bosses.is_empty():
		var boss := _bosses[0]
		_multiply_life(boss, LIFE_MULTIPLIERS[stars - 1])
		if stars == 3:
			_add_second_boss(boss.def, boss.tile + SECOND_BOSS_OFFSET_YETI)


func _pays_gold(item: Variant) -> bool:
	var fighter := item as BattleFighter
	return super(item) and not (island.family == QuestIsland.Family.WORM and fighter.def.name in NO_GOLD_NAMES)


func _gives_reward(_item: BattleFighter) -> bool:
	# Only gold here: the experience comes from the units of the groups, see _on_enemy_died().
	return false


func _on_enemy_died(item: BattleFighter) -> void:
	for group in GROUPS:
		if item in _groups[group]:
			xp = mini(xp + item.def.collect_xp, max_xp())
			_groups[group].erase(item)
			if _groups[group].is_empty() and _keys[group] != null:
				_open_keys.append(_keys[group])
				collectable_opened.emit(_keys[group])
			break
	if _pays_gold(item):
		gold += _gold_per_kill
	changed.emit()
	if item in _bosses:
		_boss_killed += 1
		if _boss_killed >= (2 if stars == 3 else 1):
			_win()


func _bring_boss() -> void:
	_boss_released = true
	match island.family:
		QuestIsland.Family.YETI:
			sim.remove_item(_statue)
			_statue = null
		QuestIsland.Family.GOLEM:
			var tile := _statue.tile
			sim.remove_item(_statue)
			var boss := _add(_config.get_item(GOLEM_BOSS), tile, BattleFighter.Team.ENEMY)
			_bosses.append(boss)
			_multiply_life(boss, LIFE_MULTIPLIERS[stars - 1])
			if stars == 3:
				_add_second_boss(boss.def, tile + SECOND_BOSS_OFFSET)
			_statue = null
		QuestIsland.Family.WORM:
			var tile: Variant = BattleFormation.nearest_free_tile(ROCKDRILLER_START, IsoGrid.MAP_TILES, sim.is_free)
			if tile == null:
				return
			var boss := _add(_config.get_item(ROCKDRILLER_BOSS), tile, BattleFighter.Team.ENEMY)
			sim.sound_played.emit(SoundEffect.ROCKDRILLER, -1)
			_bosses.append(boss)
			_multiply_life(boss, ROCKDRILLER_LIFE_MULTIPLIERS[stars - 1])
			if stars == 3:
				_add_second_boss(boss.def, boss.tile + SECOND_BOSS_OFFSET)
	changed.emit()


## The second boss with 3 stars has the life of a boss with 3 stars.
func _add_second_boss(def: GameConfig.ItemDef, near: Vector2i) -> void:
	var tile: Variant = BattleFormation.nearest_free_tile(near, IsoGrid.MAP_TILES, sim.is_free)
	if tile == null:
		return
	var boss := _add(def, tile, BattleFighter.Team.ENEMY)
	_bosses.append(boss)
	_multiply_life(boss, (ROCKDRILLER_LIFE_MULTIPLIERS if island.family == QuestIsland.Family.WORM else LIFE_MULTIPLIERS)[2])


## The client multiplies the life that the boss got when it came on the map
## (see BossAI), and fills it.
func _multiply_life(boss: BattleFighter, factor: float) -> void:
	boss.max_health = int(boss.max_health * factor)
	boss.health = boss.max_health
