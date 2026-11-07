"""Makes the mock neighbours of the port: villages of made-up players at
different levels, which the player can visit and attack.

The port has no server, so it has no other players. These villages stand in
for them. They are saves in the format of the server, so a real neighbour or a
save of a real player can take their place: remove the folder of the mock
villages, and put the other saves in the neighbour folders (see
godot/neighbours/neighbour_source.gd).

The villages are made from the game configuration with a fixed random seed, so
each import makes the same villages. Each village has the buildings that its
level allows, at the highest upgrade of each line, a town hall in the middle,
units of its unit buildings, towers and walls for its difficulty, decorations
and resources.
"""

import copy
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
# Defenders: towers, units and walls, relative to a normal village.
STRENGTH = {"easy": 0.6, "normal": 1.0, "hard": 1.5, "brutal": 2.2}
PID_PREFIX = "mock_"

# The first item of each line of buildings; upgrades_to leads to the next one.
TOWN_HALL = 26
CORE_LINES = [1, 1, 1, 10, 10, 5, 38, 41, 44, 48]  # houses, farms, mill, barracks, archery, stables, workshop
OUTER_LINES = [13, 77, 16, 11, 12, 23, 24]  # mines, ranches, market, church
TOWER = 29
WALL = 34
VILLAGER = 500
TREES = [19, 20, 21]
STONES = [69, 70, 71, 72]
GOLD = [73, 74, 75, 76]
DECORATION_SUBCAT = "411"
# The land areas in the order in which the villages buy them; 13 is the middle.
LAND_ORDER = [13, 18, 17, 12, 7, 8, 9, 14, 19]
LAND_TILES = 20
FIRST_DAY = 1759373520  # The timestamp of villages/initial.json.


def _int(value):
	try:
		return int(value)
	except (TypeError, ValueError):
		return 0


def _top_of_line(items, first, level):
	"The highest upgrade of the line that the level allows, without the items for cash."
	item = items.get(first)
	if item is None or _int(item["min_level"]) > level:
		return None
	while True:
		upgrade = items.get(_int(item["upgrades_to"]))
		if upgrade is None or _int(upgrade["min_level"]) > level or upgrade["cost_type"] == "c":
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


class _Land:
	"The tiles of the owned land areas and the tiles that items cover."

	def __init__(self, areas):
		self.owned = set()
		for area in areas:
			ax, ay = (area - 1) % 5 * LAND_TILES, (area - 1) // 5 * LAND_TILES
			self.owned.update((x, y) for x in range(ax, ax + LAND_TILES) for y in range(ay, ay + LAND_TILES))
		self.taken = set()

	def fits(self, x, y, w, h, margin=0):
		tiles = [(x + i, y + j) for i in range(-margin, w + margin) for j in range(-margin, h + margin)]
		inside = all((x + i, y + j) in self.owned for i in range(w) for j in range(h))
		return inside and not any(tile in self.taken for tile in tiles)

	def take(self, x, y, w, h):
		self.taken.update((x + i, y + j) for i in range(w) for j in range(h))


def _place_near(land, rng, centre, w, h, margin, max_distance=40):
	"The free place nearest to centre, with some randomness, or None."
	cx, cy = centre
	places = [(cx + dx, cy + dy) for dx in range(-max_distance, max_distance + 1) for dy in range(-max_distance, max_distance + 1)]
	places.sort(key=lambda p: abs(p[0] - cx) + abs(p[1] - cy) + rng.random() * 3)
	for x, y in places:
		if land.fits(x, y, w, h, margin):
			return x, y
	return None


def make_village(template, items, levels, name, level, difficulty, index):
	"A save of the server for the mock player."
	rng = random.Random(f"{name}/{level}")
	strength = STRENGTH[difficulty]
	save = copy.deepcopy(template)
	areas = LAND_ORDER[:1 + min(len(LAND_ORDER) - 1, level // 5)]
	land = _Land(areas)
	entries = []

	def add(item, x, y, frame=None):
		w, h = _int(item["width"]) or 1, _int(item["height"]) or 1
		land.take(x, y, w, h)
		frames = max(1, _int(item["max_frame"]))
		entries.append([_int(item["id"]), x, y, rng.randrange(frames) if frame is None else frame, FIRST_DAY, 0, [], {}])

	def add_near(item, centre, margin, max_distance=40):
		place = _place_near(land, rng, centre, _int(item["width"]) or 1, _int(item["height"]) or 1, margin, max_distance)
		if place is not None:
			add(item, *place)
		return place

	add(items[TOWN_HALL], 48, 48, 0)
	core = [_top_of_line(items, first, level) for first in CORE_LINES]
	core += [_top_of_line(items, 1, level)] * (level // 6)  # more houses in bigger villages
	for item in filter(None, core):
		add_near(item, (50, 50), 1, 12)
	# The wall goes around the core, the other buildings outside it.
	core_tiles = [(e[1], e[2]) for e in entries]
	left = min(x for x, _ in core_tiles) - 2
	top = min(y for _, y in core_tiles) - 2
	right = max(x for x, _ in core_tiles) + 5
	bottom = max(y for _, y in core_tiles) + 5
	ring = [(x, top) for x in range(left, right + 1)] + [(x, bottom) for x in range(left, right + 1)]
	ring += [(left, y) for y in range(top + 1, bottom)] + [(right, y) for y in range(top + 1, bottom)]
	tower = _top_of_line(items, TOWER, level)
	wall = _top_of_line(items, WALL, level)
	towers = int(round((1 + level / 4) * strength)) if tower else 0
	corners = [(left, top), (right, top), (left, bottom), (right, bottom)]
	gaps = {((left + right) // 2, top), ((left + right) // 2, bottom), (left, (top + bottom) // 2), (right, (top + bottom) // 2)}
	spots = corners + rng.sample(ring, len(ring))
	for spot in spots:
		if towers > 0 and spot not in gaps and land.fits(*spot, 1, 1):
			add(tower, *spot)
			towers -= 1
	if wall and strength * level >= 6:
		for x, y in ring:
			if (x, y) not in gaps and land.fits(x, y, 1, 1):
				add(wall, x, y)
	for item in filter(None, (_top_of_line(items, first, level) for first in OUTER_LINES)):
		add_near(item, (50, 50), 1)
	# Units stand inside the wall; villagers work in the village.
	lines = [units for units in (_line_units(items, first, level) for first in CORE_LINES[6:]) if units]
	for _ in range(2 + level // 5):
		add_near(items[VILLAGER], (50, 50), 0, 15)
	for _ in range(int(round((3 + level * 0.8) * strength)) if lines else 0):
		# Footmen, archers and riders more often than siege engines, and
		# the stronger units of a line more often than the first ones.
		line = rng.choices(lines, weights=[1 if units is lines[-1] and len(lines) == 4 else 3 for units in lines])[0]
		add_near(line[min(len(line) - 1, int(len(line) * (1 - rng.random() ** 2)))], (50, 50), 0, 15)
	decorations = [item for item in items.values() if item["subcat_functional"] == DECORATION_SUBCAT and item["race"] in ("h", "a")
			and str(item["in_store"]) == "1" and item["cost_type"] in ("g", "w", "s", "f") and _int(item["min_level"]) <= level and _int(item["width"]) <= 2]
	decorations.sort(key=lambda item: _int(item["id"]))
	for _ in range(3 + level // 2 if decorations else 0):
		add_near(rng.choice(decorations), (rng.randint(35, 65), rng.randint(35, 65)), 0, 20)
	# Resources in the free land, more trees than stone and gold.
	free = sorted(land.owned - land.taken)
	rng.shuffle(free)
	for x, y in free[:len(free) // 9]:
		if land.fits(x, y, 1, 1):
			choice = rng.random()
			add(items[rng.choice(TREES if choice < 0.7 else STONES if choice < 0.85 else GOLD)], x, y)

	info = save["playerInfo"]
	info.update({"pid": f"{PID_PREFIX}{index}", "name": name, "pic": "", "completed_tutorial": 1, "map_names": [f"{name}'s Empire"],
			"honor_points": level * 12, "attacks_won": level // 2, "attacks_lost": level // 4})
	game_map = save["maps"][0]
	xp = _int(levels[min(level, len(levels)) - 1]["exp_required"])
	game_map.update({"level": level, "xp": xp, "expansions": areas, "items": entries,
			"coins": 300 * level, "wood": 250 * level, "food": 250 * level, "stone": 150 * level})
	save["privateState"].update({"shieldEndTime": 0, "shieldCooldown": 0, "purchasedShields": [], "PVPattacksReceived": {},
			"attacksWon": level // 2, "attacksLost": level // 4})
	save.pop("version", None)
	return save


def make_mock_villages(config, template):
	"""The mock villages: {file name: save}. template: villages/initial.json of
	the server, which gives the parts of a save that the generator does not set."""
	items = {_int(item["id"]): item for item in config["items"]}
	result = {}
	for index, (name, level, difficulty) in enumerate(MOCKS, start=1):
		save = make_village(template, items, config["levels"], name, level, difficulty, index)
		result[f"{save['playerInfo']['pid']}.save.json"] = save
	return result
