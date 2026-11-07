class_name TownQuests
extends RefCounted
## The quests in the town: a chain of 30 quests (TownQuestBook) on the map of
## the player, one at a time.
##
## The client 1.4.07 has the rules of these quests, but nothing starts them
## (only its admin console does), and a quest that is in a save cannot end
## (the client reads a timer of its screen that it does not create). The port
## plays them with these rules:
##
## - A quest starts when the map is open and more than
##   Village.TOWN_QUEST_WAIT seconds passed since the end of the last one; a
##   new player gets the first quest at once, after the tutorial. Its number is
##   "idCurrentTreasure" after the race filter of the client (playable_id()).
## - The quest puts its sites in land areas at the border that the player
##   does not own, and keeps the state in "currentQuestVars" with the server
##   command "set_quest_var": "quest" (its number), "sites" (the top left
##   tiles), "activators" (the sites whose activator the player collected)
##   and "wave" (the boss waves that came).
## - An activator or the treasure opens when no enemy unit is within
##   GUARD_RANGE tiles (the ACTIVATOR_AREA of the client). The client opened
##   the treasure of a camp only when no enemy unit was left on the whole map,
##   also the idle enemies at the border; the port asks only for the enemies
##   near it.
## - When all activators are collected, the boss waves come one after the
##   other. Then the treasure opens; collecting it ends the quest. A quest
##   without a treasure ends when the last wave is dead.
## - The end gives gold and experience by the level of the player
##   (reward()), the units and items of the quest, and sends
##   "collect_treasure" with the number of the next quest. The walls, towers
##   and decorations of the quest go away.

## Activators and the treasure open when no enemy unit is this near (tiles in
## x and in y).
const GUARD_RANGE := 7
## Tiles around a spawn point in which the units of a quest find a free tile.
const NEAR_RINGS := 6
const MAX_EXTRA_GUARDS := 10

var _village: Village
var _config: GameConfig
var _rng: RandomNumberGenerator
var _quest_id := -1  # The quest on the map, or -1.
var _def: Dictionary
var _sites: Array[Vector2i] = []
var _activators_done: Array = []
var _waves_spawned := 0


func _init(village: Village, config: GameConfig, rng: RandomNumberGenerator) -> void:
	_village = village
	_config = config
	_rng = rng
	var vars := village.town_quest_vars()
	var id := playable_id(village.town_quest_id(), village.race)
	if vars.get("spawned", false) and int(vars.get("quest", -1)) == id and TownQuestBook.QUESTS.has(id):
		_quest_id = id
		_def = TownQuestBook.QUESTS[id]
		for site: Variant in vars.get("sites", []):
			_sites.append(Vector2i(int(site[0]), int(site[1])))
		_activators_done = vars.get("activators", []).map(func(index: Variant) -> int: return int(index))
		_waves_spawned = int(vars.get("wave", 0))
		_mark_roles()


## The quest that the player of race plays for the number id of the save: the
## troll town skips the quests of humans, and both races skip 9 and 11
## (setCorrectQuest of the client).
static func playable_id(id: int, race: String) -> int:
	if race == "t":
		if id == 0 or id >= 15:
			return 1
		if id in [3, 4]:
			return 5
		if id >= 6 and id <= 9:
			return 10
		if id == 11:
			return 12
	elif id == 9 or id == 11:
		return id + 1
	return id


## Gold and experience at the end of a quest, by the level of the player
## (finalizeQuest of the client). The client gives nothing at level 26, which
## is between its last two bands; the port gives the last band.
static func reward(level: int) -> Vector2i:
	for band: Array in [[5, 250, 50], [10, 350, 60], [15, 450, 70], [20, 550, 80], [25, 650, 90]]:
		if level <= band[0]:
			return Vector2i(band[1], band[2])
	return Vector2i(750, 100)


func is_active() -> bool:
	return _quest_id >= 0


func quest_id() -> int:
	return _quest_id


## The configuration texts of the quest: "title", "text", "end_title", "end_text".
func text_name(key: String) -> String:
	return _def.get(key, "")


## Seconds until the next quest can start.
func seconds_to_next(now: int) -> int:
	return maxi(Village.TOWN_QUEST_WAIT - (now - _village.town_quest_time()), 0)


## A new quest can start: none is on the map and the wait is over. The server
## keeps the state of the quest only after the wait (see Village.set_town_quest_var()).
func can_start(now: int) -> bool:
	return not is_active() and now - _village.town_quest_time() > Village.TOWN_QUEST_WAIT \
			and TownQuestBook.QUESTS.has(playable_id(_village.town_quest_id(), _village.race))


## Starts the quest: its sites, the first wave when it has no activators, and
## the helpers near the town hall. Returns false when no quest can start.
func start(now: int) -> bool:
	if not can_start(now):
		return false
	_quest_id = playable_id(_village.town_quest_id(), _village.race)
	_def = TownQuestBook.QUESTS[_quest_id]
	_sites.clear()
	_activators_done = []
	_waves_spawned = 0
	var sites: Array = _def["sites"]
	var areas := _site_areas(sites.size())
	for i in sites.size():
		var grid: Array = sites[i]
		var size := Vector2i(grid[0].length(), grid.size())
		var corner := _area_corner(areas[i])
		var origin := corner + Vector2i(_rng.randi_range(0, IsoGrid.LAND_TILES - size.x), _rng.randi_range(0, IsoGrid.LAND_TILES - size.y))
		_sites.append(origin)
		_clear(Rect2i(origin, size))
		_spawn_site(grid, origin, now)
	if _def.get("guards", false):
		var treasure := _treasure()
		var count := clampi(ceili(_village.get_level() / 4.0), 2, MAX_EXTRA_GUARDS)
		var ids := VillageAttacks.enemy_ids(_village.get_level(), _village.race)
		for i in count:
			_add_unit(ids[_rng.randi_range(0, ids.size() - 1)], treasure.tile if treasure != null else _sites[0], now)
	var hall := _village.town_hall()
	for id: int in _def.get("helpers", []):
		if _for_player(id):
			_add_unit(id, hall.tile if hall != null else Vector2i(50, 50), now)
	_village.set_town_quest_var("spawned", true, now)
	_village.set_town_quest_var("quest", _quest_id, now)
	_village.set_town_quest_var("sites", _sites.map(func(site: Vector2i) -> Array: return [site.x, site.y]), now)
	_village.set_town_quest_var("activators", [], now)
	_village.set_town_quest_var("wave", 0, now)
	update(now)
	return true


## Spawns the next boss wave when it is due and ends a quest without a
## treasure when it is over. Call it after fights and when the map loads.
## Returns true when the map changed.
func update(now: int) -> bool:
	if not is_active():
		return false
	var waves: Array = _def.get("waves", [])
	if not _activators_complete():
		return false
	if _waves_spawned < waves.size() and (_waves_spawned == 0 or not _wave_alive(_waves_spawned - 1)):
		var at := _treasure().tile if _treasure() != null else _site_centre(0)
		for id: int in waves[_waves_spawned]:
			_add_unit(id, at, now)
		_waves_spawned += 1
		_village.set_town_quest_var("wave", _waves_spawned, now)
		return true
	if not _def.has("treasure") and _waves_done():
		_finish(now, _site_centre(0))
		return true
	if _def.has("treasure") and _treasure() == null:
		# The treasure is not on the map (an old or changed save): the quest ends.
		_finish(now, _site_centre(0))
		return true
	return false


## True when the player can collect the item of the quest now.
func is_open(placed: Village.PlacedItem) -> bool:
	if not is_active() or _village.quest_roles.get(placed) != Village.QuestRole.OBJECTIVE:
		return false
	if _is_treasure(placed) and not (_activators_complete() and _waves_done()):
		return false
	return not _guarded(placed.tile)


## The player clicks an item of the quest. Returns a message; "" when the
## item is not an open item of the quest. A collected activator goes away with
## the decorations of its site; the treasure ends the quest.
func collect(placed: Village.PlacedItem, now: int) -> String:
	if not is_open(placed):
		return ""
	if _is_treasure(placed):
		var tile := placed.tile
		_village.collect_quest_treasure(placed)
		_finish(now, tile)
		return "done"
	var site := _site_of(placed.tile)
	_village.remove_free_item(placed)
	for other: Village.PlacedItem in _village.quest_roles.keys():
		if _village.quest_roles[other] == Village.QuestRole.NEUTRAL and _site_of(other.tile) == site:
			_village.remove_free_item(other)
	_activators_done.append(site)
	_village.set_town_quest_var("activators", _activators_done.duplicate(), now)
	update(now)
	return "%d of %d collected." % [_activators_done.size(), _activator_count()]


## What the player does now, for the HUD.
func progress_text() -> String:
	if not is_active():
		return ""
	var count := _activator_count()
	if not _activators_complete():
		return "Kill the guards and collect the %s: %d of %d." % [_config.get_item(_def["activator"]).name, _activators_done.size(), count]
	if not _waves_done():
		var names: Array = _def["waves"][_waves_spawned - 1].map(func(id: int) -> String: return _config.get_item(id).name)
		return "Kill %s." % ", ".join(PackedStringArray(names))
	var treasure := _treasure()
	if treasure == null:
		return ""
	var name := _config.get_item(treasure.item_id).name
	return "Click on %s." % name if is_open(treasure) else "Kill the enemies near %s." % name


## The quest's items that the player can collect now.
func open_items() -> Array[Village.PlacedItem]:
	var result: Array[Village.PlacedItem] = []
	for placed: Village.PlacedItem in _village.quest_roles:
		if is_open(placed):
			result.append(placed)
	return result


## The tile to show at the start: the treasure, else the first site.
func focus_tile() -> Vector2i:
	var treasure := _treasure()
	return treasure.tile if treasure != null else _site_centre(0)


func _finish(now: int, at: Vector2i) -> void:
	var gold_xp := reward(_village.get_level())
	var resource: String = _def.get("resource", "")
	var next := (_quest_id + 1) % TownQuestBook.QUEST_COUNT
	if _village.finish_town_quest(gold_xp.x, gold_xp.y, next, gold_xp.x if resource == "f" else 0, gold_xp.x if resource == "s" else 0, now) != Village.Placement.OK:
		return
	var prize: Dictionary = _def.get("prize", {})
	var given: Array = prize.get(_village.race, []) + _def.get("rewards", [])
	for id: int in given:
		var item := _config.get_item(id)
		if item.is_unit():
			if _for_player(id):
				_add_unit(id, at, now)
		else:
			_village.store_quest_reward(id)
	for placed: Village.PlacedItem in _village.quest_roles.keys():
		_village.remove_free_item(placed)
	_quest_id = -1
	_sites.clear()


## The land areas for the sites: border areas that the player does not own,
## then other areas that the player does not own, then any area.
func _site_areas(count: int) -> Array[int]:
	var border: Array[int] = []
	var inner: Array[int] = []
	var owned: Array[int] = []
	for area in range(1, IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS + 1):
		if area in _village.owned_land:
			owned.append(area)
		elif area in VillageAttacks.BORDER_AREAS:
			border.append(area)
		else:
			inner.append(area)
	var result: Array[int] = []
	for group: Array in [border, inner, owned]:
		var shuffled := group.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var swap: int = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = swap
		result.append_array(shuffled)
	return result.slice(0, count)


static func _area_corner(area: int) -> Vector2i:
	return Vector2i((area - 1) % IsoGrid.LAND_AREAS, (area - 1) / IsoGrid.LAND_AREAS) * IsoGrid.LAND_TILES


## Removes the trees, deposits, scenery, wild animals and enemy units in the
## area of a site that the player does not own, as the client cleans the area
## of a quest (the client keeps the animals; the port removes them so that the
## items of the quest fit).
func _clear(area: Rect2i) -> void:
	for placed in _village.items.duplicate():
		if not area.intersects(VillageMap.footprint(_config.get_item(placed.item_id), placed.tile)):
			continue
		if IsoGrid.land_area_number(placed.tile / IsoGrid.LAND_TILES) in _village.owned_land:
			continue
		var item := _config.get_item(placed.item_id)
		if _village.is_enemy_unit(placed) or _village.is_wild_animal(placed) or (not item.is_unit() and item.race == "n" and not _village.quest_roles.has(placed)):
			_village.remove_free_item(placed)


func _spawn_site(grid: Array, origin: Vector2i, now: int) -> void:
	var enemy_ids := VillageAttacks.enemy_ids(_village.get_level(), _village.race)
	for row in grid.size():
		var line: String = grid[row]
		for column in line.length():
			var character := line[column]
			var tile := origin + Vector2i(column, row)
			if character == "e":
				_add_unit(enemy_ids[_rng.randi_range(0, enemy_ids.size() - 1)], tile, now)
				continue
			var id := _item_for(character)
			if id <= 0:
				continue
			var item := _config.get_item(id)
			if item.is_unit():
				_add_unit(id, tile, now)
			elif _fits(item, tile):
				var placed := _village.place_quest_item(item, tile, now)
				_village.quest_roles[placed] = _role_for(character)


## The item of a character of a site, or 0.
func _item_for(character: String) -> int:
	match character:
		"#", "T":
			return TownQuestBook.ENEMY_BUILDINGS[_village.race][character]
		"X":
			return _def["treasure"].get(_village.race, 0)
		"A":
			return _def["activator"]
	return _def.get("legend", {}).get(character, 0)


static func _role_for(character: String) -> Village.QuestRole:
	match character:
		"#", "T":
			return Village.QuestRole.ENEMY
		"X", "A":
			return Village.QuestRole.OBJECTIVE
	return Village.QuestRole.NEUTRAL


## Gives the items of the save at the tiles of the sites their roles again
## after the map loads.
func _mark_roles() -> void:
	var sites: Array = _def["sites"]
	for i in mini(sites.size(), _sites.size()):
		var grid: Array = sites[i]
		for row in grid.size():
			for column in grid[row].length():
				var character: String = grid[row][column]
				var id := _item_for(character)
				if id <= 0 or character == "e" or _config.get_item(id).is_unit():
					continue
				var placed := _village.item_at(_sites[i] + Vector2i(column, row))
				if placed != null and placed.item_id == id and placed.tile == _sites[i] + Vector2i(column, row):
					_village.quest_roles[placed] = _role_for(character)


func _fits(item: GameConfig.ItemDef, tile: Vector2i) -> bool:
	var area := VillageMap.footprint(item, tile)
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).encloses(area):
		return false
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not _village.is_free(Vector2i(x, y)):
				return false
	return true


func _add_unit(id: int, near: Vector2i, now: int) -> void:
	var tile := near if _village.is_free(near) else _village.random_free_tile_near(near, NEAR_RINGS, _rng)
	if tile != VillageMap.ANY_TILE:
		_village.place_quest_item(_config.get_item(id), tile, now)


## The race of the player can own the unit: units of the other race would be
## enemies in the village (Village.is_own_unit()).
func _for_player(id: int) -> bool:
	var race := _config.get_item(id).race
	return race != ("t" if _village.race == "h" else "h")


func _treasure() -> Village.PlacedItem:
	for placed: Village.PlacedItem in _village.quest_roles:
		if _is_treasure(placed):
			return placed
	return null


func _is_treasure(placed: Village.PlacedItem) -> bool:
	return _def.has("treasure") and placed.item_id == _def["treasure"].get(_village.race, 0) \
			and _village.quest_roles.get(placed) == Village.QuestRole.OBJECTIVE


func _activator_count() -> int:
	var count := 0
	for grid: Array in _def["sites"]:
		for line: String in grid:
			count += line.count("A")
	return count


func _activators_complete() -> bool:
	return _activators_done.size() >= _activator_count()


func _waves_done() -> bool:
	var waves: Array = _def.get("waves", [])
	return _waves_spawned >= waves.size() and (waves.is_empty() or not _wave_alive(waves.size() - 1))


func _wave_alive(index: int) -> bool:
	var ids: Array = _def["waves"][index]
	for placed in _village.items:
		if placed.item_id in ids and _village.is_enemy_unit(placed):
			return true
	return false


## An enemy unit is within GUARD_RANGE of the tile.
func _guarded(tile: Vector2i) -> bool:
	for placed in _village.items:
		if _village.is_enemy_unit(placed) and absi(placed.tile.x - tile.x) <= GUARD_RANGE and absi(placed.tile.y - tile.y) <= GUARD_RANGE:
			return true
	return false


func _site_of(tile: Vector2i) -> int:
	var sites: Array = _def["sites"]
	for i in _sites.size():
		var grid: Array = sites[i]
		if Rect2i(_sites[i], Vector2i(grid[0].length(), grid.size())).has_point(tile):
			return i
	return -1


func _site_centre(index: int) -> Vector2i:
	var grid: Array = _def["sites"][index]
	return _sites[index] + Vector2i(grid[0].length(), grid.size()) / 2 if index < _sites.size() else Vector2i(50, 50)
