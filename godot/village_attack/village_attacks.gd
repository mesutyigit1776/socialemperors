class_name VillageAttacks
extends RefCounted
## The enemies that come to the village of the player, as the client spawns
## them in its normal mode (MapInitializer):
##
## - Idle enemies (spawn_idle_enemies()): when the map loads, groups of enemy
##   units stand on the land areas at the border of the map, up to
##   IDLE_GROUPS groups. They are items of the save, so they stay until the
##   player kills them.
## - Attacks (attacks()): when the map loads and when the player reaches a new
##   level. From SIEGE_LEVEL, in one of 10 cases, a siege comes; from
##   STAMPEDE_LEVEL a stampede, and from ARMY_LEVEL an army instead (see
##   CollectiveAI). From BANDIT_LEVELS bandits come from the edge of the map
##   and attack after 7, 14 or 21 minutes. These enemies are not in the save:
##   they go when the player leaves the village.
## - The Evil Orc Dragon (orc_dragon()): at each fifth level from
##   ORC_DRAGON_LEVEL, one dragon stands on a land area at the border. It is
##   an item of the save.
##
## The heavy siege of the client (dragons that ask for cash) is off in the
## client (Config.HEAVY_SIEGE), so the port does not have it.

## A unit of an attack, while it is in the village and not in a battle.
class Attacker:
	var def: GameConfig.ItemDef
	var tile: Vector2i
	var health: int
	var team := BattleFighter.Team.ENEMY
	var role := Role.MEMBER

## An attack: its group AI and its units. frames counts the frames of the
## current step that passed in the village.
class Group:
	var ai: CollectiveAI
	var attackers: Array[Attacker] = []
	var frames := 0

	## The current step is over: the group gives its next orders, in a battle.
	func step_due() -> bool:
		return ai.step_frames() >= 0 and frames >= ai.step_frames()

enum Role { MEMBER, SIEGE, GROUP_1, GROUP_2, CAPTAIN }

const ATTACK_CHANCE := 0.1
const SIEGE_LEVEL := 25
const STAMPEDE_LEVEL := 30
const ARMY_LEVEL := 35
## Bandits come from these levels, and wait this many minutes.
const BANDIT_LEVELS := {10: 7, 15: 14, 20: 21}
const ORC_DRAGON_LEVEL := 25
const ORC_DRAGON_EVERY := 5
const ORC_DRAGON := 895
## The land areas at the border of the map (1 to 25, row by row).
const BORDER_AREAS: Array[int] = [1, 2, 3, 4, 5, 6, 10, 11, 15, 16, 20, 21, 22, 23, 24, 25]
const IDLE_GROUPS := 6
## The size of an idle group: from the first number up to the second (not
## included); a troll player gets twice as many.
const IDLE_GROUP_SIZE := Vector2i(3, 5)
## The client searches for a free tile in this many rings around a spawn point.
const NEAR_RINGS := 5
const SIEGE_SPAWN := Vector2i(47, IsoGrid.MAP_TILES - 4)
const ARMY_SPAWN := Vector2i(5, (IsoGrid.MAP_TILES - 17) / 2)

## Enemy units by the race of the player, with the level from which they come.
const HUMAN_ENEMIES := [[525, 1], [526, 4], [527, 8], [530, 12], [531, 16], [528, 20], [529, 20], [547, 26], [601, 28], [590, 30]]
const TROLL_ENEMIES := [[509, 1], [516, 1], [512, 1], [510, 6], [517, 6], [513, 6], [511, 12], [518, 12], [514, 12], [539, 18], [540, 18], [541, 18], [502, 30], [569, 30]]

## The units of the sieges, see siege().
const FOOTMAN := 510
const ARCHER := 517
const SCORPION := 520
const KNIGHT_CAPTAIN := 513
const TROLL_FOOTMEN: Array[int] = [525, 526, 527, 528, 529, 530, 531, 547, 600]
const TROLL_RANGED: Array[int] = [598, 589]
const TROLL_SIEGE: Array[int] = [585, 586, 587, 588]
const TROLL_CAPTAIN := 601
## The units of the stampede by the race of the player: the mounts and the captain.
const STAMPEDE_UNITS := {"h": [601, 597], "t": [603, 541]}
## The units of the army by the race of the player: the villager and the siege engines.
const ARMY_UNITS := {"h": [501, [585, 586]], "t": [581, [521, 520]]}

var _village: Village
var _config: GameConfig
var _rng: RandomNumberGenerator
var _taken := {}  # Tiles that the attackers take, as the client marks them in its tile array.


## groups: the attacks that are in the village already; their units take tiles.
func _init(village: Village, config: GameConfig, rng: RandomNumberGenerator, groups: Array[Group] = []) -> void:
	_village = village
	_config = config
	_rng = rng
	for group in groups:
		for attacker in group.attackers:
			_taken[attacker.tile] = true


## The enemy units that come to the village of a player of race at level.
static func enemy_ids(level: int, race: String) -> Array[int]:
	var ids: Array[int] = []
	for entry: Array in HUMAN_ENEMIES if race == "h" else TROLL_ENEMIES:
		if level >= entry[1]:
			ids.append(entry[0])
	return ids


## The idle enemies that the map gets when it loads (spawnRemainingIdleTrolls):
## new groups until the map has about IDLE_GROUPS groups of enemy units.
## Returns the new items of the save.
func spawn_idle_enemies(now: int) -> Array[Village.PlacedItem]:
	var size := IDLE_GROUP_SIZE * (1 if _village.race == "h" else 2)
	var enemies := _village.items.filter(_village.is_enemy_unit).size()
	var groups := maxi(IDLE_GROUPS - floori(enemies / ((size.x + size.y) / 2.0)), 0)
	return _spawn_at_border(enemy_ids(_village.get_level(), _village.race), groups, size, now)


## The Evil Orc Dragon that comes when the player reaches level, or nothing.
func orc_dragon(level: int, now: int) -> Array[Village.PlacedItem]:
	if level < ORC_DRAGON_LEVEL or level % ORC_DRAGON_EVERY != 0:
		return []
	var ids: Array[int] = [ORC_DRAGON]
	return _spawn_at_border(ids, 1, Vector2i(1, 1), now)


## The attacks that come when the map loads or the player reaches a new level
## (attacksInit of the client).
func attacks() -> Array[Group]:
	var level := _village.get_level()
	var groups: Array[Group] = []
	if level >= ARMY_LEVEL:
		if _rng.randf() <= ATTACK_CHANCE:
			groups.append(_army())
	elif level >= STAMPEDE_LEVEL:
		if _rng.randf() <= ATTACK_CHANCE:
			groups.append(_stampede())
	elif level >= SIEGE_LEVEL:
		if _rng.randf() <= ATTACK_CHANCE:
			groups.append(_siege())
	for from_level: int in BANDIT_LEVELS:
		if level >= from_level:
			groups.append(_bandits(BANDIT_LEVELS[from_level]))
	return groups


## One attack of kind, as attacks() makes it; for checks.
func attack_of_kind(kind: CollectiveAI.Kind) -> Group:
	match kind:
		CollectiveAI.Kind.SIEGE:
			return _siege()
		CollectiveAI.Kind.BIG_MOUNTS:
			return _stampede()
		CollectiveAI.Kind.ARMY:
			return _army()
	return _bandits(BANDIT_LEVELS.values()[0])


## SIEGE: two squads of footmen and archers, siege engines and a captain on a
## horse or a rhino, at the bottom of the map.
func _siege() -> Group:
	var group := _new_group(CollectiveAI.Kind.SIEGE, SIEGE_SPAWN, 1)
	var human := _village.race == "h"
	for row in 2:
		for i in 11:
			if i == 5:
				continue
			var id: int = (FOOTMAN if row == 0 else ARCHER) if human else _pick(TROLL_FOOTMEN if row == 0 else TROLL_RANGED)
			_add(group, id, _near_random(SIEGE_SPAWN + Vector2i(i, row)), Role.GROUP_1 if i < 5 else Role.GROUP_2)
	var engine: int = SCORPION if human else _pick(TROLL_SIEGE)
	for i in 5:
		_add(group, engine, _near_random(SIEGE_SPAWN + Vector2i(i + 3, 3)), Role.SIEGE)
	_add(group, KNIGHT_CAPTAIN if human else TROLL_CAPTAIN, _near_random(SIEGE_SPAWN + Vector2i(5, -2)), Role.CAPTAIN)
	return group


## BIG_MOUNTS: six big mounts in two groups and a captain.
func _stampede() -> Group:
	var group := _new_group(CollectiveAI.Kind.BIG_MOUNTS, SIEGE_SPAWN, 1)
	var units: Array = STAMPEDE_UNITS[_village.race]
	var column := 0
	var last := SIEGE_SPAWN
	for i in 6:
		if i == 3:
			column = 0
		last = _near_random(SIEGE_SPAWN + Vector2i(column, 0 if i <= 3 else 1))
		_add(group, units[0], last, Role.GROUP_1 if i < 3 else Role.GROUP_2)
		column += 1
	var tile: Variant = BattleFormation.nearest_free_tile(last - Vector2i(0, 3), CollectiveAI.WHOLE_MAP, _is_free)
	_add(group, units[1], tile if tile != null else last, Role.CAPTAIN)
	return group


## ARMY: three columns of siege engines and enemy units at the left edge, and a
## villager of the player who runs to the village.
func _army() -> Group:
	var group := _new_group(CollectiveAI.Kind.ARMY, ARMY_SPAWN, 1)
	var units: Array = ARMY_UNITS[_village.race]
	var enemies := enemy_ids(_village.get_level(), _village.race)
	for column in 3:
		for i in 11:
			if i == 5:
				continue
			var id: int = _pick(units[1]) if column == 0 else _pick(enemies)
			_add(group, id, _near_random(ARMY_SPAWN + Vector2i(-column, i)), Role.SIEGE if i < 5 else Role.GROUP_1)
	var villager := _add(group, units[0], _near_random(ARMY_SPAWN + Vector2i(12, 0)), Role.CAPTAIN)
	villager.team = BattleFighter.Team.PLAYER
	return group


## BANDITS: enemy units on a random point of the edge of the map.
func _bandits(minutes: int) -> Group:
	var along := _rng.randi_range(0, IsoGrid.MAP_TILES - 1)
	var edge: Vector2i
	match _rng.randi_range(0, 3):
		0:
			edge = Vector2i(0, along)
		1:
			edge = Vector2i(IsoGrid.MAP_TILES - 1, along)
		2:
			edge = Vector2i(along, 0)
		_:
			edge = Vector2i(along, IsoGrid.MAP_TILES - 1)
	var group := _new_group(CollectiveAI.Kind.BANDITS, edge, minutes)
	var level := _village.get_level()
	var count := maxi(ceili(level / (4.0 if _village.race == "h" else 2.0)), 1)
	var enemies := enemy_ids(level, _village.race)
	for i in count:
		var tile: Variant = BattleFormation.nearest_free_tile(edge, CollectiveAI.WHOLE_MAP, _is_free)
		if tile != null:
			_add(group, _pick(enemies), tile, Role.MEMBER)
	return group


func _new_group(kind: CollectiveAI.Kind, spawn: Vector2i, minutes: int) -> Group:
	var group := Group.new()
	var owned: Array[int] = []
	owned.assign(_village.owned_land)
	group.ai = CollectiveAI.new(kind, spawn, minutes, _village.get_level(), _village.race, owned)
	return group


func _add(group: Group, id: int, tile: Vector2i, role: Role) -> Attacker:
	var attacker := Attacker.new()
	attacker.def = _config.get_item(id)
	attacker.tile = tile
	attacker.health = attacker.def.life
	attacker.role = role
	group.attackers.append(attacker)
	_taken[tile] = true
	return attacker


## Groups of size.x up to size.y (not included) units of ids, the same size for
## all groups, each on a random tile of a random land area at the border.
func _spawn_at_border(ids: Array[int], groups: int, size: Vector2i, now: int) -> Array[Village.PlacedItem]:
	var placed: Array[Village.PlacedItem] = []
	if groups == 0 or ids.is_empty():
		return placed
	var count := size.x + floori(_rng.randf() * (size.y - size.x))
	for g in groups:
		var area: int = BORDER_AREAS[_rng.randi_range(0, BORDER_AREAS.size() - 1)]
		var corner := Vector2i((area - 1) % IsoGrid.LAND_AREAS, (area - 1) / IsoGrid.LAND_AREAS) * IsoGrid.LAND_TILES
		var point := corner + Vector2i(_rng.randi_range(0, IsoGrid.LAND_TILES - 1), _rng.randi_range(0, IsoGrid.LAND_TILES - 1))
		for i in count:
			var tile: Variant = BattleFormation.nearest_free_tile(point, CollectiveAI.WHOLE_MAP, _is_free)
			if tile != null:
				placed.append(_village.add_enemy(_config.get_item(_pick(ids)), tile, now))
	return placed


## The tile itself when it is free, else a random free tile on the nearest ring
## with one, up to NEAR_RINGS rings (encontrarTileProximaLibreRandom).
func _near_random(tile: Vector2i) -> Vector2i:
	if _is_free(tile):
		return tile
	for ring in range(1, NEAR_RINGS + 1):
		var free: Array[Vector2i] = []
		for x in range(tile.x - ring, tile.x + ring + 1):
			for y in [tile.y + ring, tile.y - ring]:
				if _is_free(Vector2i(x, y)):
					free.append(Vector2i(x, y))
		for y in range(tile.y - ring + 1, tile.y + ring):
			for x in [tile.x - ring, tile.x + ring]:
				if _is_free(Vector2i(x, y)):
					free.append(Vector2i(x, y))
		if not free.is_empty():
			return free[_rng.randi_range(0, free.size() - 1)]
	return tile


func _is_free(tile: Vector2i) -> bool:
	return Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile) and _village.is_free(tile) and not _taken.has(tile)


func _pick(ids: Array) -> int:
	return ids[_rng.randi_range(0, ids.size() - 1)]
