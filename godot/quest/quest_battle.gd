class_name QuestBattle
extends RefCounted
## A campaign quest: the battle on the map of a quest island with the rules of
## its family (QuestIsland.Family), as the quest classes of the client apply them.
##
## The start follows the order of the client:
## 1. The items of the map take their sides. On a troll island the treasure,
##    decorations and scenery are neutral, the units of the island in
##    QuestIsland.free_units join the player, and everything else is an enemy.
##    On a civilisation island only the scenery (and on Atlantis also walls and
##    decorations) is neutral. Trees, rocks and other items of no race stay
##    neutral, as in all battles of the port.
## 2. The army lands around the start tile of the island.
## 3. When the player starts the battle (start()), each enemy unit gets a copy
##    for each star above 1, on the nearest free tile. Civilisation islands do
##    not copy animals.
##
## During the battle:
## - Each enemy that dies gives its collect_xp, up to GameConfig.quest_max_xp.
## - The gold of the quest (GameConfig.quest_gold, times the multiplier of the
##   stars) is shared: half of it goes in equal parts to the enemies that attack
##   and do not produce, paid when they die; the other half comes with the win.
## - Troll islands: when the last enemy unit is dead, the treasure opens; the
##   player wins when they collect it. Civilisation islands: the player wins
##   when the last town hall falls.
## - The player loses when the last of their units is dead. The client counts
##   the free units of the island as units of the player, also when the island
##   does not have them (the Viking island counts one advanced catapult), so on
##   such an island the player cannot lose this way; the port does the same.
## - Units that spells summon do not count: they give no gold or experience,
##   and the player does not lose them.
## The quest ends END_DELAY_FRAMES after a win or a loss, or at once when the
## player retreats. Then a part of the dead units comes back, see result().

signal changed  ## The gold, the experience or the number of enemies left changed.
signal treasure_opened
signal ended  ## The quest ended with a win or a loss; is_won() tells which.

const END_DELAY_FRAMES := 30  ## The client waits 1 second.
const COPY_RINGS := 4
const SUBCAT_TREASURE := 811
const SUBCAT_DECORATION := 411
const SUBCAT_SCENERY := 1011
const SUBCAT_TOWN_HALL := 135
const NOT_COPIED_SUBCATS: Array[int] = [74, 75, 88, 90]  ## Cows, sheep, horses and boars.
## The fields of an entry of the unit list that the client sends.
const WENT := 1
const DIED := 2
const CAME_BACK := 3

var sim: BattleSim
var island: QuestIsland
var stars := 1
var gold := 0
var xp := 0

var _config: GameConfig
var _rng: RandomNumberGenerator
var _rank := 0  # The stars that the player won on the island before.
var _units: Array[Array] = []  # [unit id, went, died, came back], sorted by unit id.
var _player_units := 0  # The units of the player that are alive, as the client counts them.
var _enemies_left := 0  # Troll islands: enemy units. Civilisation islands: town halls.
var _gold_units := 0
var _gold_per_kill := 0
var _gold_on_win := 0
var _treasure: BattleFighter
var _treasure_open := false
var _won := false
var _end_frame := -1
var _finished := false  # The quest ended with a win or a loss.
var _retreated := false
var _recovered := false
var _free := {}  # The free units of the island: unit id -> number, see _place_map().


## The quest on map for the army (unit id -> number). rank is the number of
## stars that the player won on the island before. sprites gives the shot
## points of the graphics; it can be null.
static func create(quest_island: QuestIsland, map: Village, army: Dictionary, config: GameConfig, rank: int, sprites: SpriteLibrary, rng: RandomNumberGenerator) -> QuestBattle:
	var quest := QuestBattle.new()
	quest.island = quest_island
	quest.sim = BattleSim.new(rng)
	quest._config = config
	quest._rng = rng
	quest._rank = rank
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
	quest._place_map(map, sprites)
	quest._land_army(sprites)
	quest.sim.died.connect(quest._on_died)
	return quest


## Starts the battle with 1 to 3 stars, see QuestBook.max_stars().
func start(chosen_stars: int) -> void:
	stars = chosen_stars
	if stars > 1:
		for enemy in sim.fighters.filter(func(item: BattleFighter) -> bool: return item.is_unit() and item.team == BattleFighter.Team.ENEMY):
			if island.family == QuestIsland.Family.CIVILISATION and enemy.def.subcat_functional in NOT_COPIED_SUBCATS:
				continue
			for i in stars - 1:
				var tile: Variant = BattleFormation.nearest_free_tile(enemy.tile, COPY_RINGS, sim.is_free)
				if tile == null:
					continue
				var copy := sim.add_item(enemy.def, tile, BattleFighter.Team.ENEMY)
				copy.graphic = enemy.graphic
				if island.family == QuestIsland.Family.TROLLS:
					_enemies_left += 1
				if _pays_gold(enemy):
					_gold_units += 1
	var total := int(_config.quest_gold.get(island.gold_key, 0) * _config.quest_gold_multipliers[stars - 1] * (_config.quest_gold_replayed if _rank >= stars else 1.0))
	# The client divides by zero when no enemy pays gold, which gives 0.
	_gold_per_kill = total / 2 / _gold_units if _gold_units > 0 else 0
	_gold_on_win = total / 2
	changed.emit()


## Call after each frame of the battle: ends the quest END_DELAY_FRAMES after a win or a loss.
func update() -> void:
	if _end_frame >= 0 and not _finished and sim.frame >= _end_frame:
		_finished = true
		ended.emit()


## Troll islands: the number of enemy units left. Civilisation islands: town halls.
func enemies_left() -> int:
	return _enemies_left


func counts_town_halls() -> bool:
	return island.family == QuestIsland.Family.CIVILISATION


func is_finished() -> bool:
	return _finished


func is_won() -> bool:
	return _won


func is_treasure(item: BattleFighter) -> bool:
	return item == _treasure


## The player collects the open treasure of a troll island and wins.
func collect(item: BattleFighter) -> bool:
	if item != _treasure or not _treasure_open or _finished:
		return false
	_treasure_open = false
	_treasure = null
	sim.remove_item(item)
	_win()
	return true


func is_treasure_open() -> bool:
	return _treasure_open


## The player leaves the battle before its end. The units that are alive come home.
func retreat() -> void:
	_retreated = true


## The result of the quest in the form of the client command "end_quest", for
## Village.end_quest(). The first call also decides which dead units come back:
## GameConfig.quest_units_back_percent of them, rounded up, chosen at random as
## the client does. The free units of the island always come back.
func result() -> Dictionary:
	if not _recovered:
		_recovered = true
		var dead := 0
		for entry in _units:
			entry[CAME_BACK] = entry[DIED]
			dead += entry[DIED]
		var lost := dead - ceili(dead * _config.quest_units_back_percent / 100.0)
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
	return {
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


## The units that died and do not come back: unit id -> number. Call after result().
func lost_units() -> Dictionary:
	var lost := {}
	for entry in _units:
		if entry[DIED] > entry[CAME_BACK]:
			lost[entry[0]] = entry[DIED] - entry[CAME_BACK]
	return lost


## Puts the items of the map in the battle with their sides. The free units
## are QuestIsland.free_units, or on the Kamikaze island all its units of
## QuestIsland.free_all_units.
func _place_map(map: Village, sprites: SpriteLibrary) -> void:
	_free = island.free_units.duplicate()
	var free := island.free_units.duplicate()
	for placed in map.items:
		var def := _config.get_item(placed.item_id)
		if def == null:
			continue
		var team := _team_of(def)
		# Only the troll islands give the player the free units on the map.
		if island.family == QuestIsland.Family.TROLLS and def.is_unit() and int(free.get(def.id, 0)) > 0:
			free[def.id] -= 1
			team = BattleFighter.Team.PLAYER
		elif def.id in island.free_all_units:
			team = BattleFighter.Team.PLAYER
			_free[def.id] = int(_free.get(def.id, 0)) + 1
		var item := sim.add_item(def, placed.tile, team)
		item.frame = placed.frame
		if sprites != null:
			item.graphic = BattleGraphic.of(sprites.get_sprite(def.img_name), def.is_unit(), placed.frame)
		if team == BattleFighter.Team.ENEMY and def.is_unit() and island.family == QuestIsland.Family.TROLLS:
			_enemies_left += 1
		elif team == BattleFighter.Team.ENEMY and def.subcat_functional == SUBCAT_TOWN_HALL and island.family == QuestIsland.Family.CIVILISATION:
			_enemies_left += 1
		elif def.subcat_functional == SUBCAT_TREASURE and island.family == QuestIsland.Family.TROLLS:
			_treasure = item
		if _pays_gold(item):
			_gold_units += 1
	for id: int in _free:
		_player_units += int(_free[id])


func _team_of(def: GameConfig.ItemDef) -> BattleFighter.Team:
	if def.race == "n" or def.subcat_functional == SUBCAT_SCENERY or def.subcat_functional in island.neutral_subcats:
		return BattleFighter.Team.NEUTRAL
	if island.family == QuestIsland.Family.TROLLS and def.subcat_functional in [SUBCAT_TREASURE, SUBCAT_DECORATION]:
		return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.ENEMY


## The army lands on the free tiles nearest to the start tile, unit by unit,
## in the order of the unit ids.
func _land_army(sprites: SpriteLibrary) -> void:
	for entry in _units:
		var def := _config.get_item(entry[0])
		for i in entry[WENT]:
			var tile: Variant = BattleFormation.nearest_free_tile(island.start_tile, IsoGrid.MAP_TILES, sim.is_free)
			if tile == null:
				tile = island.start_tile
			var unit := sim.add_item(def, tile, BattleFighter.Team.PLAYER)
			if sprites != null:
				unit.graphic = BattleGraphic.of(sprites.get_sprite(def.img_name), true, 0)


func _pays_gold(item: Variant) -> bool:
	var fighter := item as BattleFighter
	return fighter != null and fighter.team == BattleFighter.Team.ENEMY and fighter.def.attack > 0 and fighter.def.collect == 0


func _on_died(item: BattleFighter, _killer: BattleFighter) -> void:
	# Summoned units do not count: no gold, no experience, no loss of the player.
	if _finished or item.summoned:
		return
	match item.team:
		BattleFighter.Team.PLAYER:
			if item.is_unit():
				_count(item.def.id, DIED, 1)
				_player_units -= 1
		BattleFighter.Team.ENEMY:
			if _pays_gold(item):
				gold += _gold_per_kill
			xp = mini(xp + item.def.collect_xp, _config.quest_max_xp)
			if island.family == QuestIsland.Family.TROLLS and item.is_unit():
				_enemies_left -= 1
			elif island.family == QuestIsland.Family.CIVILISATION and item.def.subcat_functional == SUBCAT_TOWN_HALL:
				_enemies_left -= 1
			changed.emit()
	if _enemies_left <= 0 and item.team != BattleFighter.Team.NEUTRAL:
		if island.family == QuestIsland.Family.TROLLS:
			_open_treasure()
		else:
			_win()
	if _player_units == 0:
		_end_soon()


func _open_treasure() -> void:
	if _treasure != null and not _treasure_open:
		_treasure_open = true
		treasure_opened.emit()


func _win() -> void:
	if _won:
		return
	_won = true
	gold += _gold_on_win
	changed.emit()
	_end_soon()


func _end_soon() -> void:
	_end_frame = sim.frame + END_DELAY_FRAMES


func _count(id: int, field: int, amount: int) -> void:
	for entry in _units:
		if entry[0] == id:
			entry[field] += amount
			return
	var entry := [id, 0, 0, 0]
	entry[field] = amount
	_units.append(entry)
	_units.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
