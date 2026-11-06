class_name VillageEnemies
extends Node
## The enemies of the village between fights. It spawns them when the map
## loads and when the player reaches a level (VillageAttacks), shows the
## attacks that wait, and counts their frames at the speed of the client.
## Every BattleAI.UPDATE_INTERVAL frames, as the AI of the client runs, it asks
## for a fight (fight_needed) when a step of an attack is over (for example
## the wait), or when an enemy and the player are near enough to fight
## (VillageBattle.has_contact()).

signal fight_needed

const FRAME_SECONDS := 1.0 / 30.0

var groups: Array[VillageAttacks.Group] = []
var _village: Village
var _view: VillageView
var _config: GameConfig
var _rng: RandomNumberGenerator
var _is_busy: Callable  # True for a unit of the player that is not on the map now, see UnitOrders.is_busy().
var _time := 0.0
var _frame := 0


func _init(village: Village, view: VillageView, config: GameConfig, rng: RandomNumberGenerator, is_busy: Callable) -> void:
	_village = village
	_view = view
	_config = config
	_rng = rng
	_is_busy = is_busy


## The map loaded, as at the start of the game and after a quest: new idle
## enemies and new attacks; the attacks of before are gone. Returns true when
## the save changed.
func on_map_loaded(now: int) -> bool:
	var attacks := VillageAttacks.new(_village, _config, _rng)
	var placed := attacks.spawn_idle_enemies(now)
	groups = attacks.attacks()
	_show()
	return not placed.is_empty()


## The player reached level. Returns true when the save changed.
func on_level_up(level: int, now: int) -> bool:
	var attacks := VillageAttacks.new(_village, _config, _rng, groups)
	groups.append_array(attacks.attacks())
	var placed := attacks.orc_dragon(level, now)
	_show()
	return not placed.is_empty()


## Adds an attack of kind whose wait is over; for checks.
func add_due_attack(kind: CollectiveAI.Kind) -> void:
	var group := VillageAttacks.new(_village, _config, _rng, groups).attack_of_kind(kind)
	group.frames = group.ai.wait_frames
	groups.append(group)
	_show()


## A fight starts: it takes the attacks.
func take_groups() -> Array[VillageAttacks.Group]:
	var taken := groups
	groups = []
	_show()
	return taken


## The fight ended; the attacks that stay come back.
func set_groups(staying: Array[VillageAttacks.Group]) -> void:
	groups = staying
	_show()


## True when an enemy of an attack stands on tile.
func has_attacker_at(tile: Vector2i) -> bool:
	for group in groups:
		for attacker in group.attackers:
			if attacker.tile == tile and attacker.team == BattleFighter.Team.ENEMY:
				return true
	return false


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		_frame += 1
		for group in groups:
			group.frames += 1
		if _frame % BattleAI.UPDATE_INTERVAL == 0 and _fight_due():
			_time = 0.0
			fight_needed.emit()
			return


func _fight_due() -> bool:
	for group in groups:
		if group.step_due():
			return true
	return VillageBattle.has_contact(_village, groups, _config, _is_busy)


func _show() -> void:
	var units := []
	for group in groups:
		for attacker in group.attackers:
			units.append([attacker.def, attacker.tile])
	_view.show_visitors(units)
