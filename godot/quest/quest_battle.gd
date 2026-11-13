class_name QuestBattle
extends RefCounted
## A campaign quest: the battle on the map of a quest island, with the rules
## that the base quest class of the client (QuestBase) gives to all quests.
## Each kind of island (QuestIsland.Family) has a subclass with its own rules,
## as the client has a quest class for each island; create() chooses it.
##
## The start follows the order of the client:
## 1. The items of the map take their sides (_team_of()). Items of no race
##    ("n") stay neutral, as in all battles of the port. The units of the
##    island in QuestIsland.free_units join the player when the kind gives
##    them (_gives_map_units()).
## 2. The army lands around the start tile of the island.
## 3. When the player starts the battle (start()), the stars apply
##    (_apply_stars()): by default each enemy unit gets a copy for each star
##    above 1, on the nearest free tile.
##
## During the battle:
## - Each enemy that dies gives its collect_xp, up to max_xp().
## - The gold of the quest (GameConfig.quest_gold, times the multiplier of the
##   stars) is shared: half of it goes in equal parts to the enemies that attack
##   and do not produce, paid when they die; the other half comes with the win.
## - By default the player wins when the last enemy unit is dead.
## - The player loses when the last of their units is dead. The client counts
##   the free units of the island as units of the player, also when the island
##   does not have them (the Viking island counts one advanced catapult), so on
##   such an island the player cannot lose this way; the port does the same.
## - Units that spells and abilities summon do not count: they give no gold or
##   experience, and the player does not lose them.
## - A boss that dies, and on some islands every enemy, can drop an item of a
##   collection for a human player (collectibles).
## The quest ends END_DELAY_FRAMES after a win or a loss, or at once when the
## player retreats. Then a part of the dead units comes back, see result().

signal changed  ## The gold, the experience or the counter changed.
## An item that the player can collect opened: the treasure or a key.
signal collectable_opened(item: BattleFighter)
signal treasure_opened  ## Troll islands: the treasure opened, see TrollQuest.
signal ended  ## The quest ended with a win or a loss; is_won() tells which.

const END_DELAY_FRAMES := 30  ## The client waits 1 second.
const COPY_RINGS := 4
## A team for the islands with QuestIsland.team has at most this number of units.
const TEAM_SIZE := 20
const SUBCAT_TREASURE := 811
const SUBCAT_ACTIVATOR := 812
const SUBCAT_BOSS_STATUE := 813
const SUBCAT_DECORATION := 411
const SUBCAT_SCENERY := 1011
const SUBCAT_TOWN_HALL := 135
const SUBCAT_BOSS := 84
const SUBCAT_BOSS_HELPER := 85
const NOT_COPIED_SUBCATS: Array[int] = [74, 75, 88, 90]  ## Cows, sheep, horses and boars.
const TREASURE_CHEST := 82
const OCTOPUS := 548
const KRAKEN := 549
const RESOURCE_SUBCATS: Array[int] = [125, 126, 127]
## The fields of an entry of the unit list that the client sends.
const WENT := 1
const DIED := 2
const CAME_BACK := 3

var sim: BattleSim
var island: QuestIsland
var stars := 1
## The player pressed the start button. The battle can run before, under the
## start window (see QuestScreen.RUN_UNDER_START_WINDOW), but it ends only after it.
var started := false
var gold := 0
var xp := 0
## The items of collections that the player found: Vector2i(collection, item
## index), see Village.add_collectible().
var collectibles: Array[Vector2i] = []

var _config: GameConfig
var _rng: RandomNumberGenerator
var _rank := 0  # The stars that the player won on the island before.
var _level := 1  # The level of the player.
var _race := "h"  # The race of the player.
var _sprites: SpriteLibrary
var _units: Array[Array] = []  # [unit id, went, died, came back], sorted by unit id.
var _player_units := 0  # The units of the player that are alive, as the client counts them.
var _enemies_left := 0  # The counter of the quest; by default the enemy units.
var _gold_units := 0
var _gold_per_kill := 0
var _gold_on_win := 0
var _won := false
var _end_frame := -1
var _finished := false  # The quest ended with a win or a loss.
var _retreated := false
var _recovered := false
var _free := {}  # The free units of the island: unit id -> number, see _place_map().


## The quest on map for the army (unit id -> number). rank is the number of
## stars that the player won on the island before; level and race are those of
## the player. sprites gives the shot points of the graphics; it can be null.
static func create(quest_island: QuestIsland, map: Village, army: Dictionary, config: GameConfig, rank: int, sprites: SpriteLibrary, rng: RandomNumberGenerator, level := 1, race := "h") -> QuestBattle:
	var quest: QuestBattle
	match quest_island.family:
		QuestIsland.Family.TROLLS:
			quest = TrollQuest.new()
		QuestIsland.Family.CIVILISATION:
			quest = CivilisationQuest.new()
		QuestIsland.Family.YETI, QuestIsland.Family.GOLEM, QuestIsland.Family.WORM:
			quest = KeyQuest.new()
		QuestIsland.Family.DRAGON:
			quest = DragonQuest.new()
		QuestIsland.Family.DRAGON_2:
			quest = Dragon2Quest.new()
		QuestIsland.Family.HEROES:
			quest = HeroesQuest.new()
		QuestIsland.Family.FORGE:
			quest = ForgeQuest.new()
		_:
			quest = HardQuest.new()
	quest.island = quest_island
	quest.sim = BattleSim.new(rng)
	quest.sim.config = config
	quest.sim.player_level = level
	quest._config = config
	quest._rng = rng
	quest._rank = rank
	quest._level = level
	quest._race = race
	quest._sprites = sprites
	var ids := army.keys()
	ids.sort()
	for id: int in ids:
		quest._units.append([id, int(army[id]), 0, 0])
		quest._player_units += int(army[id])
	var water: Array[Vector2i] = []
	for y in IsoGrid.MAP_TILES:
		for x in IsoGrid.MAP_TILES:
			if quest_island.is_water(Vector2i(x, y)):
				water.append(Vector2i(x, y))
	quest.sim.add_water(water)
	quest._place_map(map)
	quest._map_loaded()
	quest._land_army()
	quest.sim.died.connect(quest._on_died)
	quest.sim.converted.connect(quest._on_converted)
	quest.sim.gold_earned.connect(func(amount: int) -> void:
		quest.gold += amount
		quest.changed.emit())
	return quest


## Starts the battle with 1 to 3 stars, see QuestBook.max_stars().
func start(chosen_stars: int) -> void:
	started = true
	stars = chosen_stars
	_apply_stars()
	_divide_reward()
	changed.emit()


## Call after each frame of the battle: ends the quest END_DELAY_FRAMES after a win or a loss.
func update() -> void:
	if started and _end_frame >= 0 and not _finished and sim.frame >= _end_frame:
		_finished = true
		ended.emit()


## The number on the counter of the quest, see counter_texts().
func enemies_left() -> int:
	return _enemies_left


## The title and the text of the counter, as the client shows them, or [] when
## the island shows no counter.
func counter_texts() -> Array[String]:
	var left := enemies_left()
	var text := _config.text("QUEST_ENEMIES_ALIVE_SINGULAR") if left == 1 else _config.text("QUEST_ENEMIES_ALIVE_PLURAL").replace("#0#", str(left))
	return [_config.text("TIMER_EJERCITO_ENEMIGO"), text]


## Civilisation islands count town halls, see CivilisationQuest.
func counts_town_halls() -> bool:
	return false


## Troll islands: the item is the treasure, see TrollQuest.
func is_treasure(_item: BattleFighter) -> bool:
	return false


func is_treasure_open() -> bool:
	return false


func is_finished() -> bool:
	return _finished


func is_won() -> bool:
	return _won


## True when the player can collect item now, with collect().
func is_collectable(_item: BattleFighter) -> bool:
	return false


## The player collects item: the open treasure or a key. Returns false when
## the item cannot be collected.
func collect(_item: BattleFighter) -> bool:
	return false


## The player leaves the battle before its end. The units that are alive come home.
func retreat() -> void:
	_retreated = true


## The result of the quest in the form of the client command "end_quest", for
## Village.end_quest(). The first call also decides which dead units come back:
## recovered_percent() of them, rounded up, chosen at random as the client
## does. The free units of the island always come back. A win can also give
## items ("item_rewards"), which the original server puts in the item store.
func result() -> Dictionary:
	if not _recovered:
		_recovered = true
		var dead := 0
		for entry in _units:
			entry[CAME_BACK] = entry[DIED]
			dead += entry[DIED]
		var lost := dead - ceili(dead * recovered_percent() / 100.0)
		var removed := 0
		var tries := 0
		while removed < lost and tries < 500:
			var entry: Array = _units[_rng.randi_range(0, _units.size() - 1)]
			if entry[CAME_BACK] > 0:
				entry[CAME_BACK] -= 1
				removed += 1
			tries += 1
		for id: int in _free:
			_count(id, CAME_BACK, _free[id])
	var data := {
		"map": 0,
		"resources": {"g": gold, "x": xp},
		"units": _units.map(func(entry: Array) -> Array: return entry.duplicate()),
		"win": 1 if _won else 0,
		"duration": sim.frame / 30,
		"voluntary_end": 1 if _retreated else 0,
		"quest_id": island.id,
		"difficulty": stars,
		"set_unlocked_index": 1,
	}
	if not island.rewards.is_empty():
		data["item_rewards"] = island.rewards.get(_race, {}).duplicate() if _won else {}
	return data


## The units that died and do not come back: unit id -> number. Call after result().
func lost_units() -> Dictionary:
	var lost := {}
	for entry in _units:
		if entry[DIED] > entry[CAME_BACK]:
			lost[entry[0]] = entry[DIED] - entry[CAME_BACK]
	return lost


## The part of the dead units that come back, in percent.
func recovered_percent() -> int:
	return _config.quest_units_back_percent


## The experience of the quest is at most this.
func max_xp() -> int:
	return _config.quest_max_xp


# --- The rules that the kinds of quests change ---


## The side of an item of the map.
func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.race == "n" or def.subcat_functional in [SUBCAT_DECORATION, SUBCAT_TREASURE, SUBCAT_SCENERY]:
		return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.ENEMY


## True when the units of QuestIsland.free_units on the map join the player.
func _gives_map_units() -> bool:
	return true


## Called for each item of the map after it took its side.
func _on_placed(item: BattleFighter) -> void:
	if item.team == BattleFighter.Team.ENEMY and item.is_unit():
		_enemies_left += 1


## Called when all items of the map are in the battle, before the army lands.
func _map_loaded() -> void:
	pass


## By default each enemy unit gets a copy for each star above 1.
func _apply_stars() -> void:
	if stars <= 1:
		return
	for enemy in sim.fighters.filter(func(item: BattleFighter) -> bool: return item.is_unit() and item.team == BattleFighter.Team.ENEMY):
		if not _copies(enemy):
			continue
		for i in stars - 1:
			var tile: Variant = BattleFormation.nearest_free_tile(enemy.tile, COPY_RINGS, sim.is_free)
			if tile == null:
				continue
			var copy := _add(enemy.def, tile, BattleFighter.Team.ENEMY)
			_on_copied(enemy, copy)


func _copies(_enemy: BattleFighter) -> bool:
	return true


func _on_copied(original: BattleFighter, _copy: BattleFighter) -> void:
	_enemies_left += 1
	if _pays_gold(original):
		_gold_units += 1


func _divide_reward() -> void:
	var total := int(_config.quest_gold.get(island.gold_key, 0) * _config.quest_gold_multipliers[stars - 1] * (_config.quest_gold_replayed if _rank >= stars else 1.0))
	# The client divides by zero when no enemy pays gold, which gives 0.
	_gold_per_kill = total / 2 / _gold_units if _gold_units > 0 else 0
	_gold_on_win = total / 2


## An enemy that counts died. By default the counter counts enemy units, and
## the last one wins.
func _on_enemy_died(item: BattleFighter) -> void:
	if item.is_unit():
		_enemies_left -= 1
		changed.emit()
	if _enemies_left <= 0:
		_win()


## The enemy gives gold and experience when it dies.
func _gives_reward(_item: BattleFighter) -> bool:
	return true


## The source of the collection item that an enemy can drop when it dies, or -1.
func _drop_source(item: BattleFighter) -> int:
	return _loot_source(item.def) if item.def.subcat_functional == SUBCAT_BOSS else -1


# --- Common rules ---


## Puts the items of the map in the battle with their sides. The free units
## are QuestIsland.free_units, or on the Kamikaze island all its units of
## QuestIsland.free_all_units.
func _place_map(map: Village) -> void:
	_free = island.free_units.duplicate()
	var free := island.free_units.duplicate()
	for placed in map.items:
		var def := _config.get_item(placed.item_id)
		if def == null:
			continue
		var team := _team_of(def, placed.tile)
		var joins := false
		if _gives_map_units() and def.is_unit() and int(free.get(def.id, 0)) > 0:
			free[def.id] -= 1
			team = BattleFighter.Team.PLAYER
			joins = true
		elif def.id in island.free_all_units:
			team = BattleFighter.Team.PLAYER
			_free[def.id] = int(_free.get(def.id, 0)) + 1
			joins = true
		var item := _add(def, placed.tile, team, placed.frame)
		if joins:
			continue
		_on_placed(item)
		if _pays_gold(item):
			_gold_units += 1
	_player_units += _free_units_counted()


## The number of free units that the client adds to the units of the player.
func _free_units_counted() -> int:
	var count := 0
	for id: int in _free:
		count += int(_free[id])
	return count


## Adds an item to the battle with the graphic of its sprite.
func _add(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team, frame := 0) -> BattleFighter:
	var item := sim.add_item(def, tile, team)
	item.frame = frame
	if _sprites != null:
		item.graphic = BattleGraphic.of(_sprites.get_sprite(def.img_name), def.is_unit(), frame)
	return item


## The army lands on the free tiles nearest to the start tile, unit by unit,
## in the order of the unit ids.
func _land_army() -> void:
	for entry in _units:
		var def := _config.get_item(entry[0])
		for i in entry[WENT]:
			var tile: Variant = BattleFormation.nearest_free_tile(island.start_tile, IsoGrid.MAP_TILES, sim.is_free)
			_add(def, tile if tile != null else island.start_tile, BattleFighter.Team.PLAYER)


## Units of the player that a quest brings during the battle; they come back.
func _add_free_units(def: GameConfig.ItemDef, count: int) -> void:
	_free[def.id] = int(_free.get(def.id, 0)) + count


func _pays_gold(item: Variant) -> bool:
	var fighter := item as BattleFighter
	return fighter != null and fighter.team == BattleFighter.Team.ENEMY and fighter.def.attack > 0 and fighter.def.collect == 0


func _on_died(item: BattleFighter, _killer: BattleFighter) -> void:
	# Summoned units do not count: no gold, no experience, no loss of the player.
	if _finished or item.summoned:
		return
	_drop(_drop_source(item))
	_count_loss(item, item.team)


## A monk converts the unit. The client counts it as a death on its old side,
## and as one more unit of the player when it joins the player.
func _on_converted(unit: BattleFighter, new_team: BattleFighter.Team) -> void:
	if _finished or unit.summoned:
		return
	if new_team == BattleFighter.Team.PLAYER:
		_player_units += 1
	_count_loss(unit, unit.team)


## item died, or left team.
func _count_loss(item: BattleFighter, team: BattleFighter.Team) -> void:
	match team:
		BattleFighter.Team.PLAYER:
			if item.is_unit():
				_count(item.def.id, DIED, 1)
				_player_units -= 1
		BattleFighter.Team.ENEMY:
			if _gives_reward(item):
				if _pays_gold(item):
					gold += _gold_per_kill
				xp = mini(xp + item.def.collect_xp, max_xp())
				changed.emit()
			_on_enemy_died(item)
	if _player_units == 0:
		_end_soon()


## The player finds an item of a collection from the source, as the client
## does with getLoot(). Trolls find nothing.
func _drop(source: int) -> void:
	if source < 0 or _race != "h":
		return
	var roll := _rng.randf() * (Collections.DROP_LIMITS[Collections.Rarity.RARE] if source in [Collections.Source.BOSS, Collections.Source.CHEST] else Collections.HARVEST_ROLL)
	var found := Collections.loot(source, roll, _rng)
	if found != Vector2i.ZERO:
		collectibles.append(found)


## The source of a drop of item, as the client chooses it in getLoot(): items
## of the enemy race of the player are "mobs", the treasure chest a chest, a
## boss a boss, resources a harvest.
func _loot_source(def: GameConfig.ItemDef) -> int:
	if def.race == ("t" if _race == "h" else "h") or def.id in [OCTOPUS, KRAKEN]:
		return Collections.Source.MOBS
	if def.id == TREASURE_CHEST:
		return Collections.Source.CHEST
	if def.subcat_functional == SUBCAT_BOSS:
		return Collections.Source.BOSS
	if def.subcat_functional in RESOURCE_SUBCATS:
		return Collections.Source.HARVEST
	return -1


func _win() -> void:
	if _won:
		return
	_won = true
	gold += _gold_on_win
	changed.emit()
	_end_soon()


func _end_soon(seconds := 1) -> void:
	_end_frame = sim.frame + END_DELAY_FRAMES * seconds


func _count(id: int, field: int, amount: int) -> void:
	for entry in _units:
		if entry[0] == id:
			entry[field] += amount
			return
	var entry := [id, 0, 0, 0]
	entry[field] = amount
	_units.append(entry)
	_units.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
