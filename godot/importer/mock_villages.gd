class_name MockVillages
## Makes the mock neighbours of the port: villages of made-up players at
## different levels, which the player can visit and attack.
##
## The port has no server, so it has no other players. These villages stand in
## for them. They are saves in the format of the server, so a real neighbour or a
## save of a real player can take their place: remove the folder of the mock
## villages, and put the other saves in the neighbour folders (see
## godot/neighbours/neighbour_source.gd).
##
## The villages are made from the game configuration with a fixed random seed,
## so each import makes the same villages. The random generator is that of
## Python (PythonRandom), so that the villages stay those of the earlier
## Python importer. Each village is a walled town:
## - A closed wall around the town. From the level of the Wall Door, the wall has
##   gates. Towers stand in the wall, at the corners and between them; stronger
##   villages also have the towers that the client sells for cash.
## - In the town, with a free tile between the buildings: the town hall in the
##   middle, the buildings that the level allows (the highest upgrade of each
##   line), from level 12 a castle, and in the strongest villages a large castle.
## - Right behind the wall, the siege engines (catapults, cannons, ballistas);
##   in the town, the units of the unit buildings and the villagers.
## - Outside the wall, trees, stone and gold on the rest of the land.
## Larger villages own more land areas, and their town covers more than one; a
## village buys more land when its town does not fit. From level 21 the town
## fills all its land, and its buildings spread over it.
## The game stores an item at the tile of its bottom right corner (see
## VillageMap.footprint()); the generator does the same, and checks that no
## items overlap and that all are on the land of the village.
##
## The order of the random numbers decides the villages: a change of the
## order of the steps changes all villages after it.

## name, level, difficulty
const MOCKS := [
	["Pebble", 4, "easy"],
	["LadyMaple", 7, "easy"],
	["SirWaffles", 9, "normal"],
	["Grumblefoot", 11, "normal"],
	["Kestrel", 14, "hard"],
	["MoBricks", 17, "normal"],
	["Thornwick", 21, "hard"],
	["PixelPete", 26, "easy"],
	["Bjorn the Bold", 31, "hard"],
	["Queen Ashveil", 38, "brutal"],
]
## Defenders: towers, siege engines and units, relative to a normal village.
const STRENGTH := {"easy": 0.6, "normal": 1.0, "hard": 1.5, "brutal": 2.2}
const PID_PREFIX := "mock_"

## The first item of each line of buildings; upgrades_to leads to the next one.
const TOWN_HALL := 26
const TOWN_LINES := [1, 1, 1, 10, 10, 5, 38, 41, 44, 48, 13, 77, 16, 11, 12, 23, 24]  # houses, farms, mill, unit buildings, mines, ranches, market, church
const HOUSE := 1
const FARM := 10
const WIDE_LINES := [5, 13, 77, 16, 11, 12]  # The mills, mines and ranches of which a wide town has more.
const UNIT_LINES := [38, 41, 44]
const TOWER := 29
const WALL := 34
const GATE := 37  # Wall Door, 3 x 3
const CASH_TOWERS := [429, 474, 1258, 369]  # Water, Infernal, Mythological and Oil Tower
const SIEGE := [767, 521, 522, 568, 634, 2012]  # Advanced Catapult, Catapult, Cannon, Fire Cannon, Elf Ballista, Imperial Elf Catapult
const CASTLES := [27, 28, 198, 414, 472, 181]  # Castle I to III, Golden, Black and Wizard's Castle (4 x 4)
const LARGE_CASTLES := [1231, 1230, 469]  # Magnificent and Legendary Castle (5 x 5), Fortress (6 x 6)
const VILLAGER := 500
const TREES := [19, 20, 21]
const STONES := [69, 70, 71, 72]
const GOLD := [73, 74, 75, 76]
const DECORATION_SUBCAT := "411"
const DECORATION_RACES := ["h", "a"]
const DECORATION_COSTS := ["g", "w", "s", "f"]
## The land areas in the order in which the villages buy them: the middle (13),
## then a square of four, then a square of nine.
const LAND_ORDER := [13, 12, 17, 18, 7, 8, 9, 14, 19]
const LAND_TILES := 20
const LAND_COLUMNS := 5
## From this level the town fills its land: 6 land areas (40 x 60 tiles), from
## level 31 all 9 (60 x 60), with WIDE_MARGIN tiles outside the wall.
const WIDE_LEVEL := 21
const WIDE_MARGIN := 3
const WIDE_TOWN := 24  # A town wider than this has blocks of buildings.
const BLOCK := 4
const FIRST_DAY := 1759373520  # The timestamp of villages/initial.json.


## The mock villages: {file name: save}, or {"error": text} under the key
## "error". template: villages/initial.json of the server, which gives the
## parts of a save that the generator does not set.
static func make(config: Dictionary, template: Dictionary) -> Dictionary:
	var items := {}
	for item: Dictionary in config["items"]:
		items[_int(item["id"])] = item
	var result := {}
	for index in MOCKS.size():
		var mock: Array = MOCKS[index]
		var save: Variant = _make_village(template, items, config["levels"], mock[0], mock[1], mock[2], index + 1)
		if save is String:
			return {"error": save}
		result["%s.save.json" % save["playerInfo"]["pid"]] = save
	return result


## int() of Python for a value of the configuration, 0 when it is not a number.
static func _int(value: Variant) -> int:
	if value is int or value is float or value is bool:
		return int(value)
	if value is String and value.strip_edges().is_valid_int():
		return value.strip_edges().to_int()
	return 0


## round() of Python: a half goes to the even number.
static func _round(x: float) -> int:
	var low := floorf(x)
	var rest := x - low
	if rest > 0.5 or (rest == 0.5 and int(low) % 2 != 0):
		return int(low) + 1
	return int(low)


static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


## The highest upgrade of the line that the level allows, without cash items; or null.
static func _top_of_line(items: Dictionary, first: int, level: int) -> Variant:
	var item: Variant = items.get(first)
	if item == null or _int(item["min_level"]) > level:
		return null
	while true:
		var upgrade: Variant = items.get(_int(item["upgrades_to"]))
		if upgrade == null or _int(upgrade["min_level"]) > level or _same(upgrade["cost_type"], "c"):
			return item
		item = upgrade
	return null


## The units that the buildings of the line up to the level train.
static func _line_units(items: Dictionary, first: int, level: int) -> Array:
	var units := []
	var item: Variant = items.get(first)
	while item != null and _int(item["min_level"]) <= level:
		var unit: Variant = items.get(_int(item["trains"]))
		if unit != null:
			units.append(unit)
		item = items.get(_int(item["upgrades_to"]))
	return units


static func _size(item: Dictionary) -> Vector2i:
	return Vector2i(maxi(1, _int(item["width"])), maxi(1, _int(item["height"])))


## The values sorted by their number keys. Equal keys keep the order of
## their values, as in Python's sort.
static func _stable_sort(values: Array, keys: Array) -> Array:
	var sorted_keys := PackedFloat64Array(keys)
	sorted_keys.sort()
	var positions := {}  # key -> its values, in order
	for i in keys.size():
		var key := float(keys[i])
		if positions.has(key):
			positions[key].append(values[i])
		else:
			positions[key] = [values[i]]
	var result := []
	for i in sorted_keys.size():
		if i == 0 or sorted_keys[i] != sorted_keys[i - 1]:
			result.append_array(positions[sorted_keys[i]])
	return result


## random.sample(population, k) of Python for a population of at most 21.
static func _sample(random: PythonRandom, population: Array, k: int) -> Array:
	var pool := population.duplicate()
	var result := []
	var n := pool.size()
	for i in k:
		var j := random.randrange(n - i)
		result.append(pool[j])
		pool[j] = pool[n - i - 1]
	return result


static func _choice(random: PythonRandom, values: Array) -> Variant:
	return values[random.randrange(values.size())]


## The owned tiles, the tiles that items cover, and the items in the format of the server.
class LandMap:
	var owned := {}  # Vector2i -> true
	var taken := {}
	var reserved := {}  # Free tiles that must stay free: the paths behind the gates.
	var entries := []
	var random: PythonRandom
	var error := ""

	func _init(areas: Array, p_random: PythonRandom) -> void:
		random = p_random
		for area: int in areas:
			var corner := Vector2i((area - 1) % LAND_COLUMNS * LAND_TILES, (area - 1) / LAND_COLUMNS * LAND_TILES)
			for x in LAND_TILES:
				for y in LAND_TILES:
					owned[corner + Vector2i(x, y)] = true

	func fits(left: int, top: int, w: int, h: int, gap := 0) -> bool:
		for i in w:
			for j in h:
				var tile := Vector2i(left + i, top + j)
				if not owned.has(tile) or reserved.has(tile):
					return false
		for i in range(-gap, w + gap):
			for j in range(-gap, h + gap):
				if taken.has(Vector2i(left + i, top + j)):
					return false
		return true

	## Adds the item with its top left corner at the tile; the entry has the
	## bottom right corner. frame -1: a random frame of the item.
	func add(item: Dictionary, left: int, top: int, frame := -1) -> void:
		var size := MockVillages._size(item)
		for i in size.x:
			for j in size.y:
				var tile := Vector2i(left + i, top + j)
				if taken.has(tile) or not owned.has(tile):
					error = "item %s at %d, %d overlaps or leaves the land" % [item["id"], left, top]
				taken[tile] = true
		var frames := maxi(1, MockVillages._int(item["max_frame"]))
		if frame < 0:
			frame = random.randrange(frames)
		entries.append([MockVillages._int(item["id"]), left + size.x - 1, top + size.y - 1, frame, FIRST_DAY, 0, [], {}])

	## Places the item in the rectangle area [left, top, right, bottom] at the
	## free place nearest to prefer [x, y]. Returns false when it does not fit.
	func place_in(item: Dictionary, area: Array, gap: int, prefer: Array) -> bool:
		var size := MockVillages._size(item)
		var places := []
		var keys := []
		for x in range(area[0], area[2] - size.x + 2):
			for y in range(area[1], area[3] - size.y + 2):
				places.append(Vector2i(x, y))
				keys.append(absf(x + size.x / 2.0 - prefer[0]) + absf(y + size.y / 2.0 - prefer[1]) + random.random())
		for place: Vector2i in MockVillages._stable_sort(places, keys):
			if fits(place.x, place.y, size.x, size.y, gap):
				add(item, place.x, place.y)
				return true
		return false

	## [left, top, right, bottom] of the owned land, which is whole areas in a
	## rectangle, without margin tiles at its edges.
	func owned_rect(margin: int) -> Array:
		var low := Vector2i(1 << 30, 1 << 30)
		var high := -low
		for tile: Vector2i in owned:
			low = low.min(tile)
			high = high.max(tile)
		return [low.x + margin, low.y + margin, high.x - margin, high.y - margin]

	## The square of the town, side tiles with the wall, on the owned land and
	## nearest to its middle; or [].
	func town_rect(side: int) -> Array:
		var whole := owned_rect(0)
		var middle := [(whole[0] + whole[2] + 1) / 2.0, (whole[1] + whole[3] + 1) / 2.0]
		var best := []
		var best_distance := 0.0
		for left in range(whole[0] + 2, whole[2] - side):
			for top in range(whole[1] + 2, whole[3] - side):
				var l: int = left - 2
				var t: int = top - 2
				var r: int = left + side + 1
				var b: int = top + side + 1
				# The owned land of the generator is made of whole areas in a
				# square, a rectangle or an L, so the corners decide whether the
				# square fits, with 2 free tiles around it for the gates.
				if owned.has(Vector2i(l, t)) and owned.has(Vector2i(r, b)) and owned.has(Vector2i(r, t)) and owned.has(Vector2i(l, b)):
					var distance := absf(left + side / 2.0 - middle[0]) + absf(top + side / 2.0 - middle[1])
					if best.is_empty() or distance < best_distance:
						best_distance = distance
						best = [left, top, left + side - 1, top + side - 1]
		return best


## A save of the server for the mock player, or an error text.
static func _make_village(template: Dictionary, items: Dictionary, levels: Array, name: String, level: int, difficulty: String, index: int) -> Variant:
	var random := PythonRandom.from_text("%s/%d/2" % [name, level])
	var strength: float = STRENGTH[difficulty]
	var area_count := 1 + mini(LAND_ORDER.size() - 1, level / 5)
	# From WIDE_LEVEL the town fills a rectangle of whole land areas.
	var wide := level >= WIDE_LEVEL
	if wide:
		area_count = 6 if level < 31 else 9
	var town_hall: Dictionary = _top_of_line(items, TOWN_HALL, level)
	var buildings := TOWN_LINES.map(func(first: int) -> Variant: return _top_of_line(items, first, level)).filter(func(item: Variant) -> bool: return item != null)
	for i in level / (2 if wide else 5):
		buildings.append(_top_of_line(items, HOUSE, level))
	if wide:
		# A wide town has more farms, mills, mines and ranches.
		for i in level / 4:
			buildings.append(_top_of_line(items, FARM, level))
		var more := WIDE_LINES.map(func(first: int) -> Variant: return _top_of_line(items, first, level)).filter(func(item: Variant) -> bool: return item != null)
		for i in level / 15:
			buildings.append_array(more)
	var castles := []
	if level >= 12:
		castles.append(items[_choice(random, CASTLES.filter(func(c: int) -> bool: return _int(items[c]["min_level"]) <= level))])
	if level >= 30 and strength >= 1.5:
		castles.append(items[_choice(random, LARGE_CASTLES.filter(func(c: int) -> bool: return _int(items[c]["min_level"]) <= level))])
	# The town is large enough for its buildings with the gaps between them and
	# the band of the siege engines; it grows until all fit.
	var need := 0
	for item: Dictionary in buildings + castles + [town_hall]:
		need += (_size(item).x + 1) * (_size(item).y + 1)
	var side := maxi(14, int(sqrt(need * 1.2)) + 6)
	var areas: Array
	var land: LandMap
	var rect: Array
	while true:
		areas = LAND_ORDER.slice(0, area_count)
		land = LandMap.new(areas, random)
		rect = land.owned_rect(WIDE_MARGIN) if wide else land.town_rect(side)
		if rect.is_empty():
			# A town that does not fit buys the next land area.
			if area_count == LAND_ORDER.size():
				return "%s: the town of %d tiles does not fit on the land" % [name, side]
			area_count += 1
			continue
		if _build_town(land, items, rect, level, strength, town_hall, buildings, castles, random):
			break
		if wide:
			return "%s: the buildings do not fit in the town" % name
		side += 2
	_add_resources(land, items, random, rect)
	if not land.error.is_empty():
		return "%s: %s" % [name, land.error]

	var save: Dictionary = template.duplicate(true)
	var info: Dictionary = save["playerInfo"]
	info["pid"] = "%s%d" % [PID_PREFIX, index]
	info["name"] = name
	info["pic"] = ""
	info["completed_tutorial"] = 1
	info["map_names"] = ["%s's Empire" % name]
	info["honor_points"] = level * 12
	info["attacks_won"] = level / 2
	info["attacks_lost"] = level / 4
	var game_map: Dictionary = save["maps"][0]
	game_map["level"] = level
	game_map["xp"] = _int(levels[mini(level, levels.size()) - 1]["exp_required"])
	game_map["expansions"] = areas
	game_map["items"] = land.entries
	game_map["coins"] = 300 * level
	game_map["wood"] = 250 * level
	game_map["food"] = 250 * level
	game_map["stone"] = 150 * level
	var state: Dictionary = save["privateState"]
	state["shieldEndTime"] = 0
	state["shieldCooldown"] = 0
	state["purchasedShields"] = []
	state["PVPattacksReceived"] = {}
	state["attacksWon"] = level / 2
	state["attacksLost"] = level / 4
	save.erase("version")
	return save


## Builds the wall, the gates, the towers, the buildings and the units. Returns false when the town is too small.
static func _build_town(land: LandMap, items: Dictionary, rect: Array, level: int, strength: float, town_hall: Dictionary,
		buildings: Array, castles: Array, random: PythonRandom) -> bool:
	var left: int = rect[0]
	var top: int = rect[1]
	var right: int = rect[2]
	var bottom: int = rect[3]
	var middle := [(left + right + 1) / 2.0, (top + bottom + 1) / 2.0]
	var ring := _ring(left, top, right, bottom)
	var wall: Variant = _top_of_line(items, WALL, level)
	var tower: Variant = _top_of_line(items, TOWER, level)
	# Gates in the middle of the sides: 2 from the level of the Wall Door, 4 from level 30.
	var gate: Variant = items[GATE] if level >= _int(items[GATE]["min_level"]) else null
	var gate_tiles := {}
	if gate != null:
		var cx := (left + right) / 2
		var cy := (top + bottom) / 2
		var places := [Vector2i(cx - 1, bottom - 1), Vector2i(cx - 1, top - 1)]
		if level >= 30:
			places += [Vector2i(left - 1, cy - 1), Vector2i(right - 1, cy - 1)]
		for place: Vector2i in places:
			for i in 3:
				for j in 3:
					gate_tiles[place + Vector2i(i, j)] = true
			if not land.fits(place.x, place.y, 3, 3):
				return false
			land.add(gate, place.x, place.y, 0)
			# The tiles in front of and behind the gate stay free.
			for i in range(-1, 4):
				for j in range(-1, 4):
					land.reserved[place + Vector2i(i, j)] = true
	# Towers in the wall: at the corners, then at even distances.
	var towers := maxi(maxi(4, _round((2 + level / 3.0) * strength)), ring.size() / 16) if tower != null else 0
	var cash_share := 0.0 if level < 8 else minf(0.5, 0.15 * strength)
	var cash_towers := CASH_TOWERS.filter(func(t: int) -> bool: return _int(items[t]["min_level"]) <= level).map(func(t: int) -> Dictionary: return items[t])
	var step := maxi(1, ring.size() / maxi(1, towers))
	var tower_tiles := [Vector2i(left, top), Vector2i(right, top), Vector2i(right, bottom), Vector2i(left, bottom)]
	for i in range(step / 2, ring.size(), step):
		tower_tiles.append(ring[i])
	var placed_towers := []
	for tile: Vector2i in tower_tiles:
		var near := placed_towers.any(func(other: Vector2i) -> bool: return absi(tile.x - other.x) + absi(tile.y - other.y) < 3)
		if placed_towers.size() >= towers or near or gate_tiles.has(tile) or not land.fits(tile.x, tile.y, 1, 1):
			continue
		var chosen: Dictionary = _choice(random, cash_towers) if not cash_towers.is_empty() and random.random() < cash_share else tower
		land.add(chosen, tile.x, tile.y)
		placed_towers.append(tile)
	if wall != null:
		for tile: Vector2i in ring:
			if not gate_tiles.has(tile) and land.fits(tile.x, tile.y, 1, 1):
				land.add(wall, tile.x, tile.y, 0 if tile.y == top or tile.y == bottom else 1)
	# The band right behind the wall is for the siege engines; the town is inside it.
	var inner := [left + 3, top + 3, right - 3, bottom - 3]
	for x in range(left + 1, right):
		for y in range(top + 1, bottom):
			if not (inner[0] <= x and x <= inner[2] and inner[1] <= y and y <= inner[3]):
				land.reserved[Vector2i(x, y)] = true
	var hall_size := _size(town_hall)
	var hall_x := int(middle[0] - hall_size.x / 2.0)
	var hall_y := int(middle[1] - hall_size.y / 2.0)
	if not land.fits(hall_x, hall_y, hall_size.x, hall_size.y, 1):
		return false
	land.add(town_hall, hall_x, hall_y, 0)
	# Castles near the corners of the town, then the buildings from the largest.
	var corners := _sample(random, [[inner[0], inner[1]], [inner[2], inner[1]], [inner[0], inner[3]], [inner[2], inner[3]]], 4)
	for i in mini(castles.size(), corners.size()):
		if not land.place_in(castles[i], inner, 1, corners[i]):
			return false
	# A small town packs its buildings around the town hall. A wide town spreads
	# them over a grid of places across the town, with wider gaps.
	var ordered := _stable_sort(buildings, buildings.map(func(item: Dictionary) -> int: return -_size(item).x * _size(item).y))
	var targets := []
	targets.resize(ordered.size())
	targets.fill(middle)
	var gap := 1
	if inner[2] - inner[0] > WIDE_TOWN:
		# Blocks of BLOCK buildings, with a street of 2 free tiles between the blocks.
		var width: int = inner[2] - inner[0] + 1
		var height: int = inner[3] - inner[1] + 1
		var blocks := ceili(ordered.size() / float(BLOCK))
		var columns := maxi(1, _round(sqrt(blocks * width / float(height))))
		var rows := ceili(blocks / float(columns))
		var centres := []
		for r in rows:
			for c in columns:
				centres.append([inner[0] + (c + 0.5) * width / columns, inner[1] + (r + 0.5) * height / rows])
		random.shuffle(centres)
		for i in ordered.size():
			targets[i] = centres[i / BLOCK]
	for i in ordered.size():
		if not land.place_in(ordered[i], inner, gap, targets[i]) and not land.place_in(ordered[i], inner, 1, targets[i]):
			return false
	# Siege engines behind the wall, with free tiles between them.
	var siege := SIEGE.filter(func(s: int) -> bool: return _int(items[s]["min_level"]) <= level).map(func(s: int) -> Dictionary: return items[s])
	var band := _ring(left + 1, top + 1, right - 1, bottom - 1).filter(func(tile: Vector2i) -> bool: return not gate_tiles.has(tile))
	var engines := maxi(_round((level / 6.0) * strength), ring.size() / 24) if not siege.is_empty() else 0
	var paths := _gate_paths(gate_tiles)
	for tile: Vector2i in band:
		if not paths.has(tile):
			land.reserved.erase(tile)
	var spacing := maxi(2, band.size() / maxi(1, engines))
	var placed := 0
	for i in range(spacing / 2, band.size(), spacing):
		var tile: Vector2i = band[i]
		if placed < engines and land.fits(tile.x, tile.y, 1, 1):
			land.add(_choice(random, siege), tile.x, tile.y)
			placed += 1
	# Units and villagers in the free tiles of the town; decorations between buildings.
	var lines := UNIT_LINES.map(func(first: int) -> Array: return _line_units(items, first, level)).filter(func(units: Array) -> bool: return not units.is_empty())
	var free := []
	for x in range(inner[0], inner[2] + 1):
		for y in range(inner[1], inner[3] + 1):
			if land.fits(x, y, 1, 1):
				free.append(Vector2i(x, y))
	random.shuffle(free)
	var people := []
	for i in 2 + level / 5:
		people.append(items[VILLAGER])
	for i in (_round((3 + level * 0.7) * strength) if not lines.is_empty() else 0):
		var line: Array = _choice(random, lines)
		var r := random.random()
		people.append(line[mini(line.size() - 1, int(line.size() * (1 - r * r)))])
	var decorations := items.values().filter(func(item: Dictionary) -> bool:
		return _same(item["subcat_functional"], DECORATION_SUBCAT) and item["race"] in DECORATION_RACES \
				and GameConfigBuilder.python_str(item["in_store"]) == "1" and item["cost_type"] in DECORATION_COSTS \
				and _int(item["min_level"]) <= level and _size(item) == Vector2i.ONE)
	decorations = _stable_sort(decorations, decorations.map(func(item: Dictionary) -> int: return _int(item["id"])))
	if not decorations.is_empty():
		for i in 2 + (level * 2 if inner[2] - inner[0] > WIDE_TOWN else level / 4):
			people.append(_choice(random, decorations))
	for item: Dictionary in people:
		while not free.is_empty() and not land.fits(free[-1].x, free[-1].y, 1, 1):
			free.pop_back()
		if free.is_empty():
			return false
		var tile: Vector2i = free.pop_back()
		land.add(item, tile.x, tile.y)
	return true


## The tiles of the edge of the rectangle, clockwise from its top left corner.
static func _ring(left: int, top: int, right: int, bottom: int) -> Array:
	var ring := []
	for x in range(left, right + 1):
		ring.append(Vector2i(x, top))
	for y in range(top + 1, bottom + 1):
		ring.append(Vector2i(right, y))
	for x in range(right - 1, left - 1, -1):
		ring.append(Vector2i(x, bottom))
	for y in range(bottom - 1, top, -1):
		ring.append(Vector2i(left, y))
	return ring


## The tiles around the gates, which stay free.
static func _gate_paths(gate_tiles: Dictionary) -> Dictionary:
	var paths := {}
	for tile: Vector2i in gate_tiles:
		for i in range(-1, 2):
			for j in range(-1, 2):
				paths[tile + Vector2i(i, j)] = true
	return paths


## Trees, stone and gold on the free land outside the wall, more trees than the others.
static func _add_resources(land: LandMap, items: Dictionary, random: PythonRandom, rect: Array) -> void:
	var whole := land.owned_rect(0)
	var free := []
	for x in range(whole[0], whole[2] + 1):
		for y in range(whole[1], whole[3] + 1):
			var tile := Vector2i(x, y)
			var in_town: bool = rect[0] <= x and x <= rect[2] and rect[1] <= y and y <= rect[3]
			if land.owned.has(tile) and not land.taken.has(tile) and not land.reserved.has(tile) and not in_town:
				free.append(tile)
	random.shuffle(free)
	for tile: Vector2i in free.slice(0, free.size() / 6):
		if land.fits(tile.x, tile.y, 1, 1, 1):
			var choice := random.random()
			var kinds: Array = TREES if choice < 0.7 else STONES if choice < 0.85 else GOLD
			land.add(items[_choice(random, kinds)], tile.x, tile.y)
