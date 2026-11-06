class_name SurvivalBattle
extends RefCounted
## A survival map (QuestSurvival of the client): the player defends the relic
## in the middle of the map against waves of enemies, as long as they can.
##
## - The army of the player (army(): the strongest MAX_UNITS units of the
##   village) lands around START_TILE. The walls and decorations of the map
##   are neutral; the relic is on the side of the player.
## - After start(), the waves come from 8 points at the border, one point for
##   each wave, see SurvivalMap.Stage. Each stage of waves ends with a boss
##   stage: while the bosses live, extra waves of 5 units come from all 8
##   points, at most MAX_BOSS_WAVES times. AFTER_BOSS_FRAMES after the last
##   boss dies, the next stage starts. When no enemy is left, the next wave
##   comes at once. In the last stage, kamikazes come from all points until
##   MAX_KAMIKAZES enemies are on the map, and again when fewer than
##   MIN_KAMIKAZES are left.
## - The enemies go for the relic (SurvivalAI).
## - The survival ends END_DELAY_FRAMES after the relic is destroyed. The
##   player keeps all units, and gets the reward unit of the time, see
##   SurvivalMap.reward(). The time counts the seconds of the battle.

signal changed  ## The time, the counter of kills, the life of the relic or the text changed.
signal ended

const MAX_UNITS := 30
const MAX_BOSS_WAVES := 2
const BOSS_WAVE_UNITS := 5
const MAX_KAMIKAZES := 80
const MIN_KAMIKAZES := 30
const AFTER_BOSS_FRAMES := 150  ## 5 seconds.
const END_DELAY_FRAMES := 30
const BOSS_SPEED := 2
const RELIC := 1253
## The items of these kinds are neutral: activators, decorations, towers, walls, wonders.
const NEUTRAL_SUBCATS: Array[int] = [812, 411, 211, 221, 511]
const SPAWN_POINTS: Array[Vector2i] = [Vector2i(5, 95), Vector2i(95, 5), Vector2i(95, 95), Vector2i(5, 5), Vector2i(50, 95), Vector2i(95, 50), Vector2i(50, 5), Vector2i(5, 50)]

var sim: BattleSim
var map: SurvivalMap
var relic: BattleFighter
var started := false
var kills := 0
var info_text := ""  ## The text of the next wave or boss, as the client shows it in the bar.
var _config: GameConfig
var _sprites: SpriteLibrary
var _rng: RandomNumberGenerator
var _spawn := 0  # currentSpawn of the client
var _stage := 0  # currentArrEnemiesDefinition
var _waiting_for_boss := false
var _bosses_killed: Array[int] = []
var _boss_waves := 0
var _enemies := 0  # currentEnemiesCount
var _point := 0  # The index of the last spawn point.
var _next_wave_frame := -1  # -1: the wave timer does not run.
var _wave_frames := 0  # The time to the next wave, set by _wave_units().
var _start_frame := 0
var _end_frame := -1
var _finished := false


## The survival on the map of map_id (a quest map) with army: unit id -> number.
static func create(survival_map: SurvivalMap, quest_map: Village, army: Dictionary, config: GameConfig, sprites: SpriteLibrary, rng: RandomNumberGenerator, level := 1) -> SurvivalBattle:
	var battle := SurvivalBattle.new()
	battle.map = survival_map
	battle._config = config
	battle._sprites = sprites
	battle._rng = rng
	battle.sim = BattleSim.new(rng)
	battle.sim.config = config
	battle.sim.player_level = level
	for placed in quest_map.items:
		var def := config.get_item(placed.item_id)
		if def == null:
			continue
		var team := BattleFighter.Team.ENEMY
		if def.id == RELIC:
			team = BattleFighter.Team.PLAYER
		elif def.subcat_functional in NEUTRAL_SUBCATS or def.race == "n":
			team = BattleFighter.Team.NEUTRAL
		var item := battle._add(def, placed.tile, team, placed.frame)
		if def.id == RELIC:
			battle.relic = item
	var ids := army.keys()
	ids.sort()
	for id: int in ids:
		var def := config.get_item(id)
		for i in int(army[id]):
			var tile: Variant = BattleFormation.nearest_free_tile(SurvivalMap.START_TILE, IsoGrid.MAP_TILES, battle.sim.is_free)
			if tile != null:
				battle._add(def, tile, BattleFighter.Team.PLAYER)
	battle.sim.died.connect(battle._on_died)
	return battle


## The units that go to a survival map (getUserArmy of the client): the
## fighting units of the village, strongest attack first, MAX_UNITS at most.
static func army(fighting_units: Dictionary, config: GameConfig) -> Dictionary:
	var ids := fighting_units.keys()
	# The client sorts with a sort that does not keep the order of equal
	# values; the port keeps the order of the unit ids among them.
	ids.sort()
	ids.sort_custom(func(a: int, b: int) -> bool: return config.get_item(a).attack > config.get_item(b).attack)
	var result := {}
	var total := 0
	for id: int in ids:
		var count := mini(int(fighting_units[id]), MAX_UNITS - total)
		result[id] = count
		total += count
		if total >= MAX_UNITS:
			break
	return result


func start() -> void:
	started = true
	_start_frame = sim.frame
	_spawn_wave()


## Call after each frame of the battle.
func update() -> void:
	if not started or _finished:
		return
	if _end_frame >= 0:
		if sim.frame >= _end_frame:
			_finished = true
			ended.emit()
		return
	if _next_wave_frame >= 0 and sim.frame >= _next_wave_frame:
		_next_wave_frame = -1
		_spawn_wave()
	if (sim.frame - _start_frame) % BattleSim.FRAMES_PER_SECOND == 0:
		changed.emit()


func is_finished() -> bool:
	return _finished


## The seconds that the player survived so far.
func seconds() -> int:
	if not started:
		return 0
	var end := _end_frame - END_DELAY_FRAMES if _end_frame >= 0 else sim.frame
	return (end - _start_frame) / BattleSim.FRAMES_PER_SECOND


## The reward unit of the time, or 0.
func reward() -> int:
	return map.reward(seconds())


func _add(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team, frame := 0) -> BattleFighter:
	var item := sim.add_item(def, tile, team)
	item.frame = frame
	if _sprites != null:
		item.graphic = BattleGraphic.of(_sprites.get_sprite(def.img_name), def.is_unit(), frame)
	return item


## spawnEnemies of the client.
func _spawn_wave() -> void:
	var last_stage := _stage >= map.stages.size() - 1
	if relic == null or relic.dead or (_waiting_for_boss and _boss_waves == MAX_BOSS_WAVES) or (last_stage and _enemies >= MAX_KAMIKAZES):
		return
	var boss_was_coming := _waiting_for_boss
	var ids := _wave_units()
	last_stage = _stage >= map.stages.size() - 1
	var point := _new_point()
	var all_points := boss_was_coming or last_stage
	for p in (SPAWN_POINTS.size() if all_points else 1):
		if all_points:
			point = SPAWN_POINTS[p]
		for id in ids:
			var bosses := not boss_was_coming and _waiting_for_boss
			if bosses:
				point = _new_point()
			var tile: Variant = BattleFormation.nearest_free_tile(point, IsoGrid.MAP_TILES, sim.is_free)
			if tile == null:
				continue
			var unit := _add(_config.get_item(id), tile, BattleFighter.Team.ENEMY)
			unit.ai = SurvivalAI.new(unit.def, relic, bosses)
			unit.ai.on_added(sim, unit)
			if unit.ability == null:
				unit.ability = BattleAbility.new()
			unit.ability.immune_to_conversion = true
			if bosses:
				unit.ability.immune_to_electricity = true
				unit.ability.immune_to_freeze = true
				unit.ability.immune_to_swallow = true
				sim.set_speed(unit, BOSS_SPEED)
			_enemies += 1
	_next_wave_frame = sim.frame + _wave_frames
	changed.emit()



## getEnemyIds of the client: the units of the next wave. It also sets the
## time to the next wave and the text of the bar.
func _wave_units() -> Array[int]:
	if not _waiting_for_boss:
		_spawn += 1
	var index := -1
	var first := 0
	for i in map.stages.size():
		if _spawn >= first and _spawn <= first + map.stages[i].waves:
			index = i
			break
		first += map.stages[i].waves
	var found := index >= 0
	if not found:
		index = map.stages.size() - 1
	_wave_frames = (map.stages[index].boss_wait if _waiting_for_boss else map.stages[index].seconds) * BattleSim.FRAMES_PER_SECOND
	if _waiting_for_boss:
		index -= 1
		_boss_waves += 1
	else:
		_stage = index
	var stage := map.stages[index]
	var ids: Array[int] = []
	if stage.boss:
		ids.assign(stage.units)
		_waiting_for_boss = true
		_bosses_killed.clear()
		_boss_waves = 0
	else:
		for i in (BOSS_WAVE_UNITS if _waiting_for_boss else stage.count):
			ids.append(stage.units[_rng.randi_range(0, stage.units.size() - 1)])
	if found and (not _waiting_for_boss or _boss_waves == 0):
		var number := floori((_stage + 1) / 2.0)
		info_text = _config.text("SURVIVAL_BOSS_COMING").replace("#0#", str(number)) if _waiting_for_boss \
				else _config.text("SURVIVAL_WAVE_COMING").replace("#0#", str(_spawn - number))
	return ids


## A random spawn point that is not the last one.
func _new_point() -> Vector2i:
	var at := _rng.randi_range(0, SPAWN_POINTS.size() - 1)
	while at == _point:
		at = _rng.randi_range(0, SPAWN_POINTS.size() - 1)
	_point = at
	return SPAWN_POINTS[at]


## elementKilled of the client.
func _on_died(item: BattleFighter, _killer: BattleFighter) -> void:
	if not started or _end_frame >= 0:
		return
	if item == relic:
		_end_frame = sim.frame + END_DELAY_FRAMES
		_next_wave_frame = -1
		changed.emit()
		return
	var bosses_dead := false
	if item.team == BattleFighter.Team.ENEMY and item.is_unit():
		_enemies -= 1
		kills += 1
		if _waiting_for_boss:
			var stage := map.stages[_stage]
			if item.def.id in stage.units:
				_bosses_killed.append(item.def.id)
			if _bosses_killed.size() == stage.units.size():
				_waiting_for_boss = false
				_next_wave_frame = sim.frame + AFTER_BOSS_FRAMES
				bosses_dead = true
		changed.emit()
	var last_stage := _stage >= map.stages.size() - 1
	if (_enemies == 0 or (last_stage and _enemies < MIN_KAMIKAZES)) and not bosses_dead:
		_next_wave_frame = -1
		_spawn_wave()
