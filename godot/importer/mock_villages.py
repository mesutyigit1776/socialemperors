"""Makes the mock neighbours of the port: villages of made-up players at
different levels, which the player can visit and attack.

The port has no server, so it has no other players. These villages stand in
for them. They are saves in the format of the server, so a real neighbour or a
save of a real player can take their place: remove the folder of the mock
villages, and put the other saves in the neighbour folders (see
godot/neighbours/neighbour_source.gd).

The villages are made from the game configuration with a fixed random seed, so
each import makes the same villages. Each village is a walled town:
- A closed wall around the town. From the level of the Wall Door, the wall has
  gates. Towers stand in the wall, at the corners and between them; stronger
  villages also have the towers that the client sells for cash.
- In the town, with a free tile between the buildings: the town hall in the
  middle, the buildings that the level allows (the highest upgrade of each
  line), from level 12 a castle, and in the strongest villages a large castle.
- Right behind the wall, the siege engines (catapults, cannons, ballistas);
  in the town, the units of the unit buildings and the villagers.
- Outside the wall, trees, stone and gold on the rest of the land.
Larger villages own more land areas, and their town covers more than one; a
village buys more land when its town does not fit. From level 21 the town
fills all its land, and its buildings spread over it.
The game stores an item at the tile of its bottom right corner (see
VillageMap.footprint()); the generator does the same, and checks that no
items overlap and that all are on the land of the village.
"""

import copy
import math
import random

# name, level, difficulty
MOCKS = [
	("Pebble", 4, "easy"),
	("LadyMaple", 7, "easy"),
	("SirWaffles", 9, "normal"),
	("Grumblefoot", 11, "normal"),
	("Kestrel", 14, "hard"),
	("MoBricks", 17, "normal"),
	("Thornwick", 21, "hard"),
	("PixelPete", 26, "easy"),
	("Bjorn the Bold", 31, "hard"),
	("Queen Ashveil", 38, "brutal"),
]
# Defenders: towers, siege engines and units, relative to a normal village.
STRENGTH = {"easy": 0.6, "normal": 1.0, "hard": 1.5, "brutal": 2.2}
PID_PREFIX = "mock_"

# The first item of each line of buildings; upgrades_to leads to the next one.
TOWN_HALL = 26
TOWN_LINES = [1, 1, 1, 10, 10, 5, 38, 41, 44, 48, 13, 77, 16, 11, 12, 23, 24]  # houses, farms, mill, unit buildings, mines, ranches, market, church
HOUSE = 1
TOWER = 29
WALL = 34
GATE = 37  # Wall Door, 3 x 3
CASH_TOWERS = [429, 474, 1258, 369]  # Water, Infernal, Mythological and Oil Tower
SIEGE = [767, 521, 522, 568, 634, 2012]  # Advanced Catapult, Catapult, Cannon, Fire Cannon, Elf Ballista, Imperial Elf Catapult
CASTLES = [27, 28, 198, 414, 472, 181]  # Castle I to III, Golden, Black and Wizard's Castle (4 x 4)
LARGE_CASTLES = [1231, 1230, 469]  # Magnificent and Legendary Castle (5 x 5), Fortress (6 x 6)
VILLAGER = 500
TREES = [19, 20, 21]
STONES = [69, 70, 71, 72]
GOLD = [73, 74, 75, 76]
DECORATION_SUBCAT = "411"
# The land areas in the order in which the villages buy them: the middle (13),
# then a square of four, then a square of nine.
LAND_ORDER = [13, 12, 17, 18, 7, 8, 9, 14, 19]
LAND_TILES = 20
## From this level the town fills its land: 6 land areas (40 x 60 tiles), from
## level 31 all 9 (60 x 60), with WIDE_MARGIN tiles outside the wall.
WIDE_LEVEL = 21
WIDE_MARGIN = 3
WIDE_TOWN = 24  # A town wider than this has blocks of buildings.
BLOCK = 4
FIRST_DAY = 1759373520  # The timestamp of villages/initial.json.


def _int(value):
	try:
		return int(value)
	except (TypeError, ValueError):
		return 0


def _top_of_line(items, first, level, cash=False):
	"The highest upgrade of the line that the level allows; without cash items unless cash."
	item = items.get(first)
	if item is None or _int(item["min_level"]) > level:
		return None
	while True:
		upgrade = items.get(_int(item["upgrades_to"]))
		if upgrade is None or _int(upgrade["min_level"]) > level or (upgrade["cost_type"] == "c" and not cash):
			return item
		item = upgrade


def _line_units(items, first, level):
	"The units that the buildings of the line up to the level train."
	units = []
	item = items.get(first)
	while item is not None and _int(item["min_level"]) <= level:
		unit = items.get(_int(item["trains"]))
		if unit is not None:
			units.append(unit)
		item = items.get(_int(item["upgrades_to"]))
	return units


def _size(item):
	return max(1, _int(item["width"])), max(1, _int(item["height"]))


class _Map:
	"The owned tiles, the tiles that items cover, and the items in the format of the server."

	def __init__(self, areas, rng):
		self.owned = set()
		for area in areas:
			ax, ay = (area - 1) % 5 * LAND_TILES, (area - 1) // 5 * LAND_TILES
			self.owned.update((x, y) for x in range(ax, ax + LAND_TILES) for y in range(ay, ay + LAND_TILES))
		self.taken = set()
		self.reserved = set()  # Free tiles that must stay free: the paths behind the gates.
		self.entries = []
		self.rng = rng

	def fits(self, left, top, w, h, gap=0):
		inside = all((left + i, top + j) in self.owned for i in range(w) for j in range(h))
		near = {(left + i, top + j) for i in range(-gap, w + gap) for j in range(-gap, h + gap)}
		return inside and not near & self.taken and not {(left + i, top + j) for i in range(w) for j in range(h)} & self.reserved

	def add(self, item, left, top, frame=None):
		"Adds the item with its top left corner at the tile; the entry has the bottom right corner."
		w, h = _size(item)
		tiles = {(left + i, top + j) for i in range(w) for j in range(h)}
		assert not tiles & self.taken and tiles <= self.owned, f"item {item['id']} at {left}, {top} overlaps or leaves the land"
		self.taken |= tiles
		frames = max(1, _int(item["max_frame"]))
		self.entries.append([_int(item["id"]), left + w - 1, top + h - 1, self.rng.randrange(frames) if frame is None else frame, FIRST_DAY, 0, [], {}])

	def place_in(self, item, area, gap, prefer):
		"Places the item in the rectangle area (left, top, right, bottom) at the free place nearest to prefer. Returns False when it does not fit."
		w, h = _size(item)
		left, top, right, bottom = area
		places = [(x, y) for x in range(left, right - w + 2) for y in range(top, bottom - h + 2)]
		places.sort(key=lambda p: abs(p[0] + w / 2 - prefer[0]) + abs(p[1] + h / 2 - prefer[1]) + self.rng.random())
		for x, y in places:
			if self.fits(x, y, w, h, gap):
				self.add(item, x, y)
				return True
		return False


def _owned_rect(owned, margin):
	"The rectangle of the owned land, which is whole areas in a rectangle, without margin tiles at its edges."
	xs = [x for x, _ in owned]
	ys = [y for _, y in owned]
	return (min(xs) + margin, min(ys) + margin, max(xs) - margin, max(ys) - margin)


def _town_rect(owned, side):
	"The square of the town, side tiles with the wall, on the owned land and nearest to its middle; or None."
	xs = [x for x, _ in owned]
	ys = [y for _, y in owned]
	middle = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2)
	best = None
	for left in range(min(xs) + 2, max(xs) - side):
		for top in range(min(ys) + 2, max(ys) - side):
			l, t, r, b = left - 2, top - 2, left + side + 1, top + side + 1
			if (l, t) in owned and (r, b) in owned and (r, t) in owned and (l, b) in owned:
				# The owned land of the generator is made of whole areas in a
				# square, a rectangle or an L, so the corners decide whether the
				# square fits, with 2 free tiles around it for the gates.
				distance = abs(left + side / 2 - middle[0]) + abs(top + side / 2 - middle[1])
				if best is None or distance < best[0]:
					best = (distance, (left, top, left + side - 1, top + side - 1))
	return best[1] if best else None


def make_village(template, items, levels, name, level, difficulty, index):
	"A save of the server for the mock player."
	rng = random.Random(f"{name}/{level}/2")
	strength = STRENGTH[difficulty]
	area_count = 1 + min(len(LAND_ORDER) - 1, level // 5)
	# From WIDE_LEVEL the town fills a rectangle of whole land areas.
	wide = level >= WIDE_LEVEL
	if wide:
		area_count = 6 if level < 31 else 9
	town_hall = _top_of_line(items, TOWN_HALL, level)
	buildings = [item for item in (_top_of_line(items, first, level) for first in TOWN_LINES) if item]
	buildings += [_top_of_line(items, HOUSE, level)] * (level // (2 if wide else 5))
	if wide:
		# A wide town has more farms, mills, mines and ranches.
		buildings += [_top_of_line(items, 10, level)] * (level // 4)
		buildings += [item for item in (_top_of_line(items, first, level) for first in (5, 13, 77, 16, 11, 12)) if item] * (level // 15)
	castles = []
	if level >= 12:
		castles.append(items[rng.choice([c for c in CASTLES if _int(items[c]["min_level"]) <= level])])
	if level >= 30 and strength >= 1.5:
		castles.append(items[rng.choice([c for c in LARGE_CASTLES if _int(items[c]["min_level"]) <= level])])
	# The town is large enough for its buildings with the gaps between them and
	# the band of the siege engines; it grows until all fit.
	need = sum((_size(item)[0] + 1) * (_size(item)[1] + 1) for item in buildings + castles + [town_hall])
	side = max(14, int(math.sqrt(need * 1.2)) + 6)
	while True:
		areas = LAND_ORDER[:area_count]
		village_map = _Map(areas, rng)
		rect = _owned_rect(village_map.owned, WIDE_MARGIN) if wide else _town_rect(village_map.owned, side)
		if rect is None:
			# A town that does not fit buys the next land area.
			if area_count == len(LAND_ORDER):
				raise ValueError(f"{name}: the town of {side} tiles does not fit on the land")
			area_count += 1
			continue
		if _build_town(village_map, items, rect, level, strength, town_hall, buildings, castles, rng):
			break
		if wide:
			raise ValueError(f"{name}: the buildings do not fit in the town")
		side += 2
	_add_resources(village_map, items, level, rng, rect)

	save = copy.deepcopy(template)
	info = save["playerInfo"]
	info.update({"pid": f"{PID_PREFIX}{index}", "name": name, "pic": "", "completed_tutorial": 1, "map_names": [f"{name}'s Empire"],
			"honor_points": level * 12, "attacks_won": level // 2, "attacks_lost": level // 4})
	game_map = save["maps"][0]
	xp = _int(levels[min(level, len(levels)) - 1]["exp_required"])
	game_map.update({"level": level, "xp": xp, "expansions": areas, "items": village_map.entries,
			"coins": 300 * level, "wood": 250 * level, "food": 250 * level, "stone": 150 * level})
	save["privateState"].update({"shieldEndTime": 0, "shieldCooldown": 0, "purchasedShields": [], "PVPattacksReceived": {},
			"attacksWon": level // 2, "attacksLost": level // 4})
	save.pop("version", None)
	return save


def _build_town(village_map, items, rect, level, strength, town_hall, buildings, castles, rng):
	"Builds the wall, the gates, the towers, the buildings and the units. Returns False when the town is too small."
	left, top, right, bottom = rect
	middle = ((left + right + 1) / 2, (top + bottom + 1) / 2)
	ring = [(x, top) for x in range(left, right + 1)] + [(right, y) for y in range(top + 1, bottom + 1)] \
			+ [(x, bottom) for x in range(right - 1, left - 1, -1)] + [(left, y) for y in range(bottom - 1, top, -1)]
	wall = _top_of_line(items, WALL, level)
	tower = _top_of_line(items, TOWER, level)
	# Gates in the middle of the sides: 2 from the level of the Wall Door, 4 from level 30.
	gate = items[GATE] if level >= _int(items[GATE]["min_level"]) else None
	gate_tiles = set()
	if gate:
		cx, cy = (left + right) // 2, (top + bottom) // 2
		places = [(cx - 1, bottom - 1), (cx - 1, top - 1)] + ([(left - 1, cy - 1), (right - 1, cy - 1)] if level >= 30 else [])
		for gx, gy in places:
			gate_tiles |= {(gx + i, gy + j) for i in range(3) for j in range(3)}
			if not village_map.fits(gx, gy, 3, 3):
				return False
			village_map.add(gate, gx, gy, 0)
			# The tiles in front of and behind the gate stay free.
			village_map.reserved |= {(gx + i, gy + j) for i in range(-1, 4) for j in range(-1, 4)}
	# Towers in the wall: at the corners, then at even distances.
	towers = max(4, int(round((2 + level / 3) * strength)), len(ring) // 16) if tower else 0
	cash_share = 0.0 if level < 8 else min(0.5, 0.15 * strength)
	cash_towers = [items[t] for t in CASH_TOWERS if _int(items[t]["min_level"]) <= level]
	corners = [(left, top), (right, top), (right, bottom), (left, bottom)]
	step = max(1, len(ring) // max(1, towers))
	tower_tiles = corners + [ring[i] for i in range(step // 2, len(ring), step)]
	placed_towers = []
	for x, y in tower_tiles:
		near = any(abs(x - tx) + abs(y - ty) < 3 for tx, ty in placed_towers)
		if len(placed_towers) >= towers or near or (x, y) in gate_tiles or not village_map.fits(x, y, 1, 1):
			continue
		chosen = rng.choice(cash_towers) if cash_towers and rng.random() < cash_share else tower
		village_map.add(chosen, x, y)
		placed_towers.append((x, y))
	if wall:
		for x, y in ring:
			if (x, y) not in gate_tiles and village_map.fits(x, y, 1, 1):
				village_map.add(wall, x, y, 0 if y in (top, bottom) else 1)
	# The band right behind the wall is for the siege engines; the town is inside it.
	inner = (left + 3, top + 3, right - 3, bottom - 3)
	village_map.reserved |= {(x, y) for x in range(left + 1, right) for y in range(top + 1, bottom)
			if not (inner[0] <= x <= inner[2] and inner[1] <= y <= inner[3])}
	tw, th = _size(town_hall)
	hall_x, hall_y = int(middle[0] - tw / 2), int(middle[1] - th / 2)
	if not village_map.fits(hall_x, hall_y, tw, th, 1):
		return False
	village_map.add(town_hall, hall_x, hall_y, 0)
	# Castles near the corners of the town, then the buildings from the largest.
	for castle, corner in zip(castles, rng.sample([(inner[0], inner[1]), (inner[2], inner[1]), (inner[0], inner[3]), (inner[2], inner[3])], 4)):
		if not village_map.place_in(castle, inner, 1, corner):
			return False
	# A small town packs its buildings around the town hall. A wide town spreads
	# them over a grid of places across the town, with wider gaps.
	ordered = sorted(buildings, key=lambda item: -_size(item)[0] * _size(item)[1])
	targets = [middle] * len(ordered)
	gap = 1
	if (inner[2] - inner[0]) > WIDE_TOWN:
		# Blocks of BLOCK buildings, with a street of 2 free tiles between the blocks.
		width, height = inner[2] - inner[0] + 1, inner[3] - inner[1] + 1
		blocks = math.ceil(len(ordered) / BLOCK)
		columns = max(1, round(math.sqrt(blocks * width / height)))
		rows = math.ceil(blocks / columns)
		centres = [(inner[0] + (c + 0.5) * width / columns, inner[1] + (r + 0.5) * height / rows) for r in range(rows) for c in range(columns)]
		rng.shuffle(centres)
		targets = [centres[i // BLOCK] for i in range(len(ordered))]
	for item, target in zip(ordered, targets):
		if not village_map.place_in(item, inner, gap, target) and not village_map.place_in(item, inner, 1, target):
			return False
	# Siege engines behind the wall, with free tiles between them.
	siege = [items[s] for s in SIEGE if _int(items[s]["min_level"]) <= level]
	band = [(x, y) for x, y in ring_inside(rect) if (x, y) not in gate_tiles]
	engines = max(int(round((level / 6) * strength)), len(ring) // 24) if siege else 0
	village_map.reserved -= set(band) - _gate_paths(village_map, gate_tiles)
	spacing = max(2, len(band) // max(1, engines))
	placed = 0
	for x, y in band[spacing // 2::spacing]:
		if placed < engines and village_map.fits(x, y, 1, 1):
			village_map.add(rng.choice(siege), x, y)
			placed += 1
	# Units and villagers in the free tiles of the town; decorations between buildings.
	lines = [units for units in (_line_units(items, first, level) for first in (38, 41, 44)) if units]
	free = [(x, y) for x in range(inner[0], inner[2] + 1) for y in range(inner[1], inner[3] + 1) if village_map.fits(x, y, 1, 1)]
	rng.shuffle(free)
	people = [items[VILLAGER]] * (2 + level // 5)
	for _ in range(int(round((3 + level * 0.7) * strength)) if lines else 0):
		line = rng.choice(lines)
		people.append(line[min(len(line) - 1, int(len(line) * (1 - rng.random() ** 2)))])
	decorations = [item for item in items.values() if item["subcat_functional"] == DECORATION_SUBCAT and item["race"] in ("h", "a")
			and str(item["in_store"]) == "1" and item["cost_type"] in ("g", "w", "s", "f") and _int(item["min_level"]) <= level and _size(item) == (1, 1)]
	decorations.sort(key=lambda item: _int(item["id"]))
	people += [rng.choice(decorations) for _ in range(2 + (level * 2 if (inner[2] - inner[0]) > WIDE_TOWN else level // 4))] if decorations else []
	for item in people:
		while free and not village_map.fits(*free[-1], 1, 1):
			free.pop()
		if not free:
			return False
		village_map.add(item, *free.pop())
	return True


def ring_inside(rect):
	"The tiles right behind the wall, around the town."
	left, top, right, bottom = rect
	l, t, r, b = left + 1, top + 1, right - 1, bottom - 1
	return [(x, t) for x in range(l, r + 1)] + [(r, y) for y in range(t + 1, b + 1)] \
			+ [(x, b) for x in range(r - 1, l - 1, -1)] + [(l, y) for y in range(b - 1, t, -1)]


def _gate_paths(village_map, gate_tiles):
	"The tiles around the gates, which stay free."
	return {(x + i, y + j) for x, y in gate_tiles for i in (-1, 0, 1) for j in (-1, 0, 1)}


def _add_resources(village_map, items, level, rng, rect):
	"Trees, stone and gold on the free land outside the wall, more trees than the others."
	left, top, right, bottom = rect
	free = sorted(tile for tile in village_map.owned - village_map.taken - village_map.reserved
			if not (left <= tile[0] <= right and top <= tile[1] <= bottom))
	rng.shuffle(free)
	for x, y in free[:len(free) // 6]:
		if village_map.fits(x, y, 1, 1, 1):
			choice = rng.random()
			village_map.add(items[rng.choice(TREES if choice < 0.7 else STONES if choice < 0.85 else GOLD)], x, y)


def make_mock_villages(config, template):
	"""The mock villages: {file name: save}. template: villages/initial.json of
	the server, which gives the parts of a save that the generator does not set."""
	items = {_int(item["id"]): item for item in config["items"]}
	result = {}
	for index, (name, level, difficulty) in enumerate(MOCKS, start=1):
		save = make_village(template, items, config["levels"], name, level, difficulty, index)
		result[f"{save['playerInfo']['pid']}.save.json"] = save
	return result
