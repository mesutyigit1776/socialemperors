class_name PvpBattle
extends RefCounted
## An attack on the village of another player, with the rules of the client
## (Assault and PVPManager).
##
## Before the battle:
## - The map of the other player comes without the units of the other race
##   (the trolls that attack that village) and without the buildings outside
##   its land. Trees, deposits and animals stay, but take no side.
## - The loot: a third of each resource of the other player, at most
##   GameConfig.pvp_max_loot for the level of the attacker; a larger amount
##   becomes a random amount from 0.8 to 1.2 times the maximum.
## - The army lands around the start tile that the player chose.
##
## During the battle:
## - Damage to the town hall takes a quarter of the loot of each resource;
##   damage to the buildings that produce a resource takes the other three
##   quarters of that resource, in proportion to their life. Markets and the
##   Troll Coliseum count as gold buildings. A resource without such buildings
##   comes only from the town hall.
## - Each enemy that attacks gives its collect_xp when it dies.
## - The player wins when all these buildings are destroyed, and then takes
##   all the loot. A village without a town hall is won at once, without
##   loot and experience.
## - The player loses when the last unit of the army dies, when the time
##   (GameConfig.pvp_seconds) is over, or when the player withdraws.
## At the end a part of the dead units comes back, see result().

signal changed  ## The loot or the experience changed.
signal ended

const END_DELAY_FRAMES := 30
const FRAMES_PER_SECOND := 30
const LOOT_SHARE := 0.333
const TOWN_HALL_SHARE := 0.25
const SUBCAT_TOWN_HALL := 135
const SUBCAT_DECORATION := 411
const SUBCAT_LOST := 911
const GOLD_BUILDINGS: Array[int] = [23, 188, 189, 266, 325]  ## Markets, the Allies Market and the Troll Coliseum.
const RESOURCE_CODES: Array[String] = ["g", "w", "s", "f"]
const WENT := 1
const DIED := 2
const CAME_BACK := 3

var sim: BattleSim
var loot := {}  ## The resources of the other player that the attack can take: code -> amount.
var taken := {"g": 0.0, "w": 0.0, "s": 0.0, "f": 0.0}  ## The resources that the attack took.
var xp := 0
var has_town_hall := true

var _config: GameConfig
var _rng: RandomNumberGenerator
var _sprites: SpriteLibrary
var _level := 1  # The level of the attacker.
var _units: Array[Array] = []  # [unit id, went, died, came back], sorted by unit id.
var _player_units := 0
var _per_damage := {}  # Resource code -> loot for each point of damage to its buildings.
var _town_hall_per_damage := {}
var _targets: Array[BattleFighter] = []  # The town hall and the resource buildings.
var _won := false
var _timed_out := false
var _retreated := false
var _end_frame := -1
var _finished := false
var _recovered := false


## The loot of an attack on map by a player of the level: code -> amount. map
## has the resources that it shows to an attacker (NeighbourSource.load_village()).
static func loot_of(map: Village, level: int, config: GameConfig, rng: RandomNumberGenerator) -> Dictionary:
	var max_loot := GameConfig.value_for_level(config.pvp_max_loot, level)
	var resources := map.loot_resources()
	var result := {}
	for code in RESOURCE_CODES:
		var amount := int(resources[code] * LOOT_SHARE)
		result[code] = int(max_loot * 0.8 + rng.randf() * max_loot * 0.4) if amount > max_loot else amount
	return result


## map: the village of the other player. army: unit id -> number. loot: see
## loot_of(). level: the level of the attacker.
static func create(map: Village, army: Dictionary, loot_amounts: Dictionary, start_tile: Vector2i, config: GameConfig, sprites: SpriteLibrary, rng: RandomNumberGenerator, level: int) -> PvpBattle:
	var battle := PvpBattle.new()
	battle.sim = BattleSim.new(rng)
	battle.sim.config = config
	battle.sim.player_level = level
	battle._config = config
	battle._rng = rng
	battle._sprites = sprites
	battle._level = level
	battle.loot = loot_amounts.duplicate()
	battle._place_map(map)
	var ids := army.keys()
	ids.sort()
	for id: int in ids:
		battle._units.append([id, int(army[id]), 0, 0])
		battle._player_units += int(army[id])
		for i in int(army[id]):
			var tile: Variant = BattleFormation.nearest_free_tile(start_tile, IsoGrid.MAP_TILES, battle.sim.is_free)
			battle._add(config.get_item(id), tile if tile != null else start_tile, BattleFighter.Team.PLAYER)
	battle.sim.hit.connect(battle._on_hit)
	battle.sim.died.connect(battle._on_died)
	battle.sim.converted.connect(func(unit: BattleFighter, _team: BattleFighter.Team) -> void: battle._on_died(unit, null))
	battle.has_town_hall = battle._targets.any(func(item: BattleFighter) -> bool: return item.def.subcat_functional == SUBCAT_TOWN_HALL)
	if not battle.has_town_hall:
		battle._win()
	return battle


## Call after each frame: the time runs out, and the battle ends
## END_DELAY_FRAMES after a win or a loss.
func update() -> void:
	if _finished:
		return
	if _end_frame < 0 and sim.frame >= _config.pvp_seconds * FRAMES_PER_SECOND:
		_timed_out = true
		_end_frame = sim.frame
	if _end_frame >= 0 and sim.frame >= _end_frame:
		_finished = true
		ended.emit()


func seconds_left() -> int:
	return maxi(_config.pvp_seconds - sim.frame / FRAMES_PER_SECOND, 0)


## The part of the loot that the attack took, from 0 to 1.
func percentage() -> float:
	var total := 0.0
	var got := 0.0
	for code in RESOURCE_CODES:
		total += loot[code]
		got += minf(taken[code], loot[code])
	return got / total if total > 0 else 0.0


func is_finished() -> bool:
	return _finished


func is_won() -> bool:
	return _won


func is_timed_out() -> bool:
	return _timed_out


## The player withdraws: the battle ends as a loss.
func retreat() -> void:
	_retreated = true
	_finished = true


## The result for Village.end_pvp_attack(). The first call also decides which
## dead units come back: the part of GameConfig.pvp_units_back for the level
## of the attacker, rounded up, chosen at random as the client does.
func result() -> Dictionary:
	if not _recovered:
		_recovered = true
		var dead := 0
		for entry in _units:
			entry[CAME_BACK] = entry[DIED]
			dead += entry[DIED]
		var percent: int = _config.pvp_units_back[0 if _level < 10 else (2 if _level > 15 else 1)]
		var lost := dead - ceili(dead * percent / 100.0)
		var removed := 0
		var tries := 0
		while removed < lost and tries < 500:
			var entry: Array = _units[_rng.randi_range(0, _units.size() - 1)]
			if entry[CAME_BACK] > 0:
				entry[CAME_BACK] -= 1
				removed += 1
			tries += 1
	var got := {}
	for code in RESOURCE_CODES:
		got[code] = int(minf(taken[code], loot[code]))
	return {
		"units": _units.map(func(entry: Array) -> Array: return entry.duplicate()),
		"loot": got,
		"xp": xp if has_town_hall else 0,
		"won": _won,
		"percentage": percentage(),
		"voluntary_end": _retreated,
	}


## The units that died and do not come back: unit id -> number. Call after result().
func lost_units() -> Dictionary:
	var lost := {}
	for entry in _units:
		if entry[DIED] > entry[CAME_BACK]:
			lost[entry[0]] = entry[DIED] - entry[CAME_BACK]
	return lost


func _place_map(map: Village) -> void:
	var other_race := "t" if map.race == "h" else "h"
	var lives := {"g": 0, "w": 0, "s": 0, "f": 0}
	var town_hall_life := 0
	for placed in map.items:
		var def := _config.get_item(placed.item_id)
		if def == null:
			continue
		if def.is_unit() and def.race == other_race:
			continue
		if not def.is_unit() and (def.subcat_functional == SUBCAT_LOST or not IsoGrid.land_area_number(placed.tile / IsoGrid.LAND_TILES) in map.owned_land) \
				and def.race != "n":
			continue
		var neutral := def.race == "n" or def.subcat_functional == SUBCAT_DECORATION
		var item := _add(def, placed.tile, BattleFighter.Team.NEUTRAL if neutral else BattleFighter.Team.ENEMY, placed.frame)
		if neutral or def.is_unit():
			continue
		if def.subcat_functional == SUBCAT_TOWN_HALL:
			town_hall_life = item.max_health
			_targets.append(item)
		elif def.collect > 0 and def.collect_type in RESOURCE_CODES:
			lives[def.collect_type] += item.max_health
			_targets.append(item)
		elif def.id in GOLD_BUILDINGS:
			lives["g"] += item.max_health
			_targets.append(item)
	for code in RESOURCE_CODES:
		_per_damage[code] = 0.0 if lives[code] == 0 or loot[code] == 0 else loot[code] * (1.0 - TOWN_HALL_SHARE) / lives[code]
		if town_hall_life > 0:
			_town_hall_per_damage[code] = loot[code] * (TOWN_HALL_SHARE if _per_damage[code] > 0 else 1.0) / town_hall_life
		else:
			_town_hall_per_damage[code] = 0.0


func _add(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team, frame := 0) -> BattleFighter:
	var item := sim.add_item(def, tile, team)
	item.frame = frame
	if _sprites != null:
		item.graphic = BattleGraphic.of(_sprites.get_sprite(def.img_name), def.is_unit(), frame)
	return item


## The damage to a building of _targets takes its part of the loot. The
## health is already lower; below 0 is damage that the building did not have.
func _on_hit(target: BattleFighter, _attacker: BattleFighter, damage: int, _critical: bool) -> void:
	if _finished or not target in _targets:
		return
	var done := damage + mini(target.health, 0)
	if target.def.subcat_functional == SUBCAT_TOWN_HALL:
		for code in RESOURCE_CODES:
			taken[code] += _town_hall_per_damage[code] * done
	else:
		var code: String = target.def.collect_type if target.def.collect > 0 and target.def.collect_type in RESOURCE_CODES else "g"
		taken[code] += _per_damage[code] * done
	changed.emit()


func _on_died(item: BattleFighter, _killer: BattleFighter) -> void:
	if _finished or item.summoned:
		return
	match item.team:
		BattleFighter.Team.PLAYER:
			if item.is_unit():
				_count(item.def.id, DIED)
				_player_units -= 1
				if _player_units <= 0 and not _won:
					_end_soon()
		BattleFighter.Team.ENEMY:
			if item.def.attack > 0:
				xp += item.def.collect_xp
				changed.emit()
			if item in _targets:
				_targets.erase(item)
				if _targets.is_empty():
					_win()


func _win() -> void:
	if _won:
		return
	_won = true
	for code in RESOURCE_CODES:
		taken[code] = float(loot[code]) if has_town_hall else 0.0
	changed.emit()
	_end_soon()


func _end_soon() -> void:
	if _end_frame < 0:
		_end_frame = sim.frame + END_DELAY_FRAMES


func _count(id: int, field: int) -> void:
	for entry in _units:
		if entry[0] == id:
			entry[field] += 1
			return
	var entry := [id, 0, 0, 0]
	entry[field] = 1
	_units.append(entry)
	_units.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
