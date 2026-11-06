class_name TournamentBattle
extends RefCounted
## A match of the weekly tournament (the tournament mode of the client): the
## team of the player against the team of a bot of the configuration
## (GameConfig.tournament_bots), on the map of the tournament.
##
## - All items of the map are neutral. The player's team stands at
##   PLAYER_ORIGIN, the bot's team at BOT_ORIGIN, each in its formation.
## - The player controls their team; TournamentAI controls the bot's team.
##   The match starts with start().
## - The match ends when one team has no units, or when the player withdraws
##   (a loss with 0 points). score() is the score of the client for the point
##   type 0: 50 for a win, and up to 25 for the units of the player that are
##   left and up to 25 for the units of the bot that died.
##
## The formations of the client are lost: the configuration of this project
## has only their names and texts. The port places the units by these texts
## and the pictures of the formation buttons, see formation_cells(). As in
## the client, the units of a formation stand 2 tiles apart.

signal changed  ## The units or the life of a team changed.
signal ended

const PLAYER_ORIGIN := Vector2i(10, 59)
const BOT_ORIGIN := Vector2i(90, 59)
const CELL_TILES := 2
const ROWS := 5
const COLUMNS := 4
const KEEP_INSIDE_FRAMES := 300  ## The client moves the units back into the map every 10 seconds.
const END_DELAY_FRAMES := 90  ## The client closes the match 3 seconds after the end.
const WIN_POINTS := 50
const UNITS_POINTS := 25
const FORMATIONS := 4

var sim: BattleSim
var ai: TournamentAI
var bot_name := ""
var started := false
var won := false
var player_team: Array[BattleFighter] = []
var bot_team: Array[BattleFighter] = []
var _player_slots := 0  # The places of the team, as the client counts them for the score.
var _bot_slots := 0
var _sprites: SpriteLibrary
var _start_frame := 0
var _end_frame := -1
var _finished := false
var _score := 0


## places: the unit ids of the 20 places of the team (0 for an empty place);
## bot_team: the same for the bot. formation: 0 to 3.
static func create(map: Village, places: Array[int], formation: int, bot_places: Array[int], bot_formation: int, config: GameConfig, sprites: SpriteLibrary, rng: RandomNumberGenerator, level := 1) -> TournamentBattle:
	var battle := TournamentBattle.new()
	battle._sprites = sprites
	battle.sim = BattleSim.new(rng)
	battle.sim.config = config
	battle.sim.player_level = level
	for placed in map.items:
		var def := config.get_item(placed.item_id)
		if def != null:
			battle._add(def, placed.tile, BattleFighter.Team.NEUTRAL, placed.frame)
	battle._player_slots = places.size()
	battle._bot_slots = bot_places.size()
	battle.player_team = battle._place_team(places, formation, PLAYER_ORIGIN, false, config)
	battle.bot_team = battle._place_team(bot_places, bot_formation, BOT_ORIGIN, true, config)
	battle.ai = TournamentAI.new(battle.bot_team, battle.player_team)
	battle.sim.died.connect(battle._on_died)
	battle.sim.hit.connect(func(_target: BattleFighter, _attacker: BattleFighter, _damage: int, _critical: bool) -> void: battle.changed.emit())
	return battle


## The cells of formation, strongest unit first: [row, depth], where depth 0
## is the back and COLUMNS - 1 the front. The port follows the texts of the
## client and the pictures of the formation buttons, which show strong units
## as big dots:
## 0 Regular: strong units in the back, weak units in the front.
## 1 Tortoise: strong units in the centre of the back half, surrounded by
##   weaker units.
## 2 Assault: strong units in the middle rows from the back, weak units on the
##   flanks.
## 3 Aggressive: strong units in the front, weak units in the back.
static func formation_cells(formation: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for depth in COLUMNS:
		for row in ROWS:
			cells.append(Vector2i(row, depth))
	var middle := (ROWS - 1) / 2.0
	match formation:
		1:
			var centre := Vector2(middle, 1.0)
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var da := Vector2(a).distance_squared_to(centre)
				var db := Vector2(b).distance_squared_to(centre)
				return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		2:
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				var ra := absf(a.x - middle)
				var rb := absf(b.x - middle)
				return ra < rb or (ra == rb and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		3:
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	return cells


func start() -> void:
	started = true
	ai.started = true
	_start_frame = sim.frame


## Call after each frame of the match.
func update() -> void:
	if not started or _finished:
		return
	if _end_frame >= 0:
		if sim.frame >= _end_frame:
			_finished = true
			ended.emit()
		return
	if (sim.frame - _start_frame) % KEEP_INSIDE_FRAMES == 0 and sim.frame > _start_frame:
		ai.keep_inside(sim)


## The player gives up: a loss with 0 points, at once.
func withdraw() -> void:
	if _finished:
		return
	won = false
	_score = 0
	_end_frame = sim.frame
	ai.state = TournamentAI.State.DONE
	_finished = true
	ended.emit()


func is_finished() -> bool:
	return _finished


func score() -> int:
	return _score


func units_left(team: Array[BattleFighter]) -> int:
	return team.filter(func(unit: BattleFighter) -> bool: return not unit.dead).size()


## The part of the life of the team that is left, from 0 to 1.
func life_left(team: Array[BattleFighter]) -> float:
	var total := 0
	var left := 0
	for unit in team:
		total += unit.max_life()
		left += maxi(unit.health, 0) if not unit.dead else 0
	return float(left) / total if total > 0 else 0.0


## The units of the team stand on the cells of the formation, strongest (most
## life) first, each on the free tile nearest to its cell. The bot's front is
## toward the player.
func _place_team(places: Array[int], formation: int, origin: Vector2i, bot: bool, config: GameConfig) -> Array[BattleFighter]:
	var ids: Array[int] = places.filter(func(id: int) -> bool: return id != 0 and config.get_item(id) != null)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var life_a := config.get_item(a).life
		var life_b := config.get_item(b).life
		return life_a > life_b if life_a != life_b else a < b)
	var cells := formation_cells(formation)
	var team: Array[BattleFighter] = []
	for i in mini(ids.size(), cells.size()):
		var cell := cells[i]
		var column := COLUMNS - 1 - cell.y if bot else cell.y
		var wanted := origin + Vector2i(column * CELL_TILES, -cell.x * CELL_TILES)
		var tile: Variant = BattleFormation.nearest_free_tile(wanted, IsoGrid.MAP_TILES, sim.is_free)
		if tile != null:
			team.append(_add(config.get_item(ids[i]), tile, BattleFighter.Team.ENEMY if bot else BattleFighter.Team.PLAYER))
	return team


func _add(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team, frame := 0) -> BattleFighter:
	var item := sim.add_item(def, tile, team)
	item.frame = frame
	if _sprites != null:
		item.graphic = BattleGraphic.of(_sprites.get_sprite(def.img_name), def.is_unit(), frame)
	return item


func _on_died(unit: BattleFighter, _killer: BattleFighter) -> void:
	if not unit.is_unit() or unit.summoned:
		return
	ai.on_died(sim, unit)
	changed.emit()
	if not started or _end_frame >= 0:
		return
	if units_left(bot_team) == 0:
		_end(true)
	elif units_left(player_team) == 0:
		_end(false)


func _end(victory: bool) -> void:
	won = victory
	var player_left := units_left(player_team)
	# The client counts the empty places of the bot's team as units that died.
	var bot_gone := _bot_slots - units_left(bot_team)
	_score = clampi(roundi((WIN_POINTS if victory else 0) + UNITS_POINTS * float(player_left) / _player_slots + UNITS_POINTS * float(bot_gone) / _bot_slots), 0, 100)
	ai.state = TournamentAI.State.DONE
	_end_frame = sim.frame + END_DELAY_FRAMES
