class_name VillageBattle
extends RefCounted
## A fight in the village of the player. The client has one engine for the
## village and its fights; the port runs the village with its own model and
## turns the village into a BattleSim while enemies fight in it:
##
## - The units of the player and their buildings are on the side of the
##   player; wild animals, trees and deposits are neutral; the other units of
##   the save (the idle enemies) and the attacks (VillageAttacks.Group) are
##   enemies. The attacks keep their group AI and the frames that they waited.
## - Destroyed buildings of the player stay on the map, see
##   BattleSim.in_own_village.
## - The fight ends when it is calm (is_calm()) for CALM_FRAMES frames: no
##   unit fights, no shot flies, no unit of an attack walks, and no step of an
##   attack is due.
## - apply() writes the result to the village, as the commands of the client
##   do: units of the player that died leave the map ("sell" with the reason
##   KILL), enemies that died give their reward ("kill"), and the units of the
##   player stay where the fight left them. The server does not keep the life
##   of buildings; the village keeps the damage of the player's units and
##   buildings for the session, as the client does (Village.health()).

signal ended
## A unit says a line, for example a captain of a siege.
signal said(unit: BattleFighter, text: String)

const CALM_FRAMES := 2 * BattleAI.UPDATE_INTERVAL
## Enemies take targets in this range (BattleAI.AGGRO_RANGE); a building of
## the player attacks enemies in its attack range.
const CONTACT_RANGE := BattleAI.AGGRO_RANGE
const SUBCAT_TOWN_HALL := 135

var sim: BattleSim
var groups: Array[VillageAttacks.Group] = []
var _village: Village
var _config: GameConfig
var _sprites: SpriteLibrary
var _placed := {}  # BattleFighter -> Village.PlacedItem of the save.
var _attackers := {}  # BattleFighter -> [VillageAttacks.Group, VillageAttacks.Role]
var _calm_frames := 0
static var _conditions := {}  # Item id -> BattleAI.Condition, see _fights().
var _ended := false
var kills := 0  ## Enemy units that died.
var losses := 0  ## Units of the save of the player that died.


## A fight on the village with the attacks in groups. sprites gives the shot
## points of the graphics; it can be null. is_busy is true for a unit of the
## player that is not on the map, for example while it harvests.
func _init(village: Village, attacks: Array[VillageAttacks.Group], config: GameConfig, sprites: SpriteLibrary, rng: RandomNumberGenerator, is_busy: Callable) -> void:
	_village = village
	_config = config
	_sprites = sprites
	groups = attacks
	sim = BattleSim.new(rng)
	sim.config = config
	sim.player_level = village.get_level()
	sim.in_own_village = true
	for placed in village.items:
		var def := config.get_item(placed.item_id)
		if def != null and not is_busy.call(placed):
			var fighter := _add(def, placed.tile, _team_of(placed, def), placed.frame)
			# A building that burned down stays with a little life, see apply().
			fighter.health = maxi(village.health(placed), 1)
			fighter.units_inside = village.units_in(placed).size()
			_placed[fighter] = placed
	for group in groups:
		_add_group(group)
	sim.died.connect(_on_died)


func _on_died(fighter: BattleFighter, _killer: BattleFighter) -> void:
	if not fighter.is_unit() or fighter.summoned:
		return
	if fighter.team == BattleFighter.Team.ENEMY:
		kills += 1
	elif fighter.team == BattleFighter.Team.PLAYER and _placed.has(fighter):
		losses += 1


## The side of an item of the save.
func _team_of(placed: Village.PlacedItem, def: GameConfig.ItemDef) -> BattleFighter.Team:
	if def.is_unit():
		if _village.is_own_unit(placed):
			return BattleFighter.Team.PLAYER
		return BattleFighter.Team.NEUTRAL if _village.is_wild_animal(placed) else BattleFighter.Team.ENEMY
	match _village.quest_roles.get(placed):
		Village.QuestRole.ENEMY:
			return BattleFighter.Team.ENEMY
		Village.QuestRole.NEUTRAL, Village.QuestRole.OBJECTIVE:
			return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.NEUTRAL if def.race == "n" else BattleFighter.Team.PLAYER


## The units of the group come into the battle with their life, and the group
## AI continues its step.
func _add_group(group: VillageAttacks.Group) -> void:
	var ai := group.ai
	for role: Array in [ai.units, ai.siege, ai.group_1, ai.group_2]:
		role.clear()
	ai.captain = null
	ai.step_start = sim.frame - group.frames
	ai.said.connect(func(unit: BattleFighter, text: String) -> void: said.emit(unit, text))
	for attacker in group.attackers:
		var tile: Variant = BattleFormation.nearest_free_tile(attacker.tile, CollectiveAI.WHOLE_MAP, sim.is_free)
		var fighter := _add(attacker.def, tile if tile != null else attacker.tile, attacker.team)
		fighter.health = attacker.health
		match attacker.role:
			VillageAttacks.Role.SIEGE:
				ai.add(fighter, ai.siege)
			VillageAttacks.Role.GROUP_1:
				ai.add(fighter, ai.group_1)
			VillageAttacks.Role.GROUP_2:
				ai.add(fighter, ai.group_2)
			VillageAttacks.Role.CAPTAIN:
				ai.add(fighter)
				ai.captain = fighter
			_:
				ai.add(fighter)
		_attackers[fighter] = [group, attacker.role]


func _add(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team, frame := 0) -> BattleFighter:
	var item := sim.add_item(def, tile, team)
	item.frame = frame
	if _sprites != null:
		item.graphic = BattleGraphic.of(_sprites.get_sprite(def.img_name), def.is_unit(), frame)
	return item


## Call after each frame: ends the fight after CALM_FRAMES calm frames.
func update() -> void:
	if _ended:
		return
	_calm_frames = _calm_frames + 1 if is_calm() else 0
	if _calm_frames >= CALM_FRAMES:
		_ended = true
		ended.emit()


## No shot flies, no unit fights, no unit of an attack walks, and no step of
## an attack is due. Bandits that find no target stand still in the client;
## the fight then ends, and the village starts a new one when they can fight.
func is_calm() -> bool:
	if not sim.projectiles.is_empty():
		return false
	for group in groups:
		if group.ai.is_step_due(sim.frame) or group.ai.is_busy():
			return false
	for fighter in sim.fighters:
		if fighter.is_unit() and not fighter.dead and fighter.target != null and not fighter.target.dead \
				and fighter.target.team != fighter.team and fighter.target.team != BattleFighter.Team.NEUTRAL:
			return false
	return true


## Writes the result to the village and returns the attacks that stay in it,
## with the frames of their step.
func apply() -> Array[VillageAttacks.Group]:
	for fighter: BattleFighter in _placed:
		var placed: Village.PlacedItem = _placed[fighter]
		if not fighter.is_unit():
			if fighter.team == BattleFighter.Team.PLAYER:
				_village.set_health(placed, fighter.health if not fighter.dead else 0)
			elif fighter.dead and fighter.team == BattleFighter.Team.ENEMY:
				_village.kill_enemy(fighter.def, placed)  # A wall or tower of a quest in the town.
			continue
		if _village.is_own_unit(placed):
			# A unit that a monk converted fought for the other side: the player lost it.
			if fighter.dead or fighter.team != BattleFighter.Team.PLAYER:
				_village.lose_unit(placed)
			else:
				_village.set_health(placed, fighter.health)
				if fighter.tile != placed.tile:
					_village.move_unit(placed, fighter.tile, placed.frame)
		elif fighter.dead and _team_of(placed, fighter.def) == BattleFighter.Team.ENEMY:
			_village.kill_enemy(fighter.def, placed)
	var staying: Array[VillageAttacks.Group] = []
	for group in groups:
		group.attackers.clear()
		group.frames = sim.frame - group.ai.step_start
	for fighter: BattleFighter in _attackers:
		var group: VillageAttacks.Group = _attackers[fighter][0]
		if fighter.dead:
			if fighter.team == BattleFighter.Team.ENEMY:
				_village.kill_enemy(fighter.def)
			continue
		if not fighter in sim.fighters:
			continue  # The unit retreated and left the map.
		var attacker := VillageAttacks.Attacker.new()
		attacker.def = fighter.def
		attacker.tile = fighter.tile
		attacker.health = fighter.health
		attacker.team = fighter.team
		attacker.role = _attackers[fighter][1]
		group.attackers.append(attacker)
	for group in groups:
		if group.attackers.any(func(attacker: VillageAttacks.Attacker) -> bool: return attacker.team == BattleFighter.Team.ENEMY):
			staying.append(group)
	return staying


## True when an enemy in the village and the player are near enough to fight,
## as the AI of the client would find it: an enemy unit that fights has a
## unit or building of the player that the client targets within
## CONTACT_RANGE tiles, a unit of the player that fights has an enemy unit
## within CONTACT_RANGE tiles, or a building of the player has an enemy in its
## attack range. Units that only flee or never fight (villagers, healers,
## passive units) do not start a fight. Bandits that attack search the whole
## map; the client takes a target only when its score is not below 0, see
## BattleSim.SCORE_BASE.
static func has_contact(village: Village, attacks: Array[VillageAttacks.Group], config: GameConfig, is_busy: Callable) -> bool:
	var enemies: Array[Vector2i] = []
	var fighting_enemies: Array[Vector2i] = []
	var searching: Array[Vector2i] = []
	for placed in village.items:
		if village.is_enemy_unit(placed):
			enemies.append(placed.tile)
			if _fights(config.get_item(placed.item_id)):
				fighting_enemies.append(placed.tile)
	for placed: Village.PlacedItem in village.quest_roles:
		if village.quest_roles[placed] == Village.QuestRole.ENEMY:
			enemies.append(placed.tile)
			if config.get_item(placed.item_id).attack > 0:
				fighting_enemies.append(placed.tile)
	for group in attacks:
		var searches := group.ai.kind == CollectiveAI.Kind.BANDITS and group.ai.step == CollectiveAI.ATTACK
		for attacker in group.attackers:
			if attacker.team != BattleFighter.Team.ENEMY:
				continue
			enemies.append(attacker.tile)
			if searches:
				searching.append(attacker.tile)
			elif _fights(attacker.def):
				fighting_enemies.append(attacker.tile)
	if enemies.is_empty():
		return false
	for placed in village.items:
		var def := config.get_item(placed.item_id)
		if def == null or is_busy.call(placed) or not _is_player_item(village, placed, def):
			continue
		var bonus := _score_bonus(def)
		if bonus >= 0 and _any_within(fighting_enemies, placed.tile, CONTACT_RANGE):
			return true
		if def.is_unit() and _fights(def) and _any_within(enemies, placed.tile, CONTACT_RANGE):
			return true
		if not def.is_unit() and def.attack > 0 and _any_within(enemies, placed.tile, def.attack_range):
			return true
		if bonus < 0:
			continue
		for tile in searching:
			var offset := tile - placed.tile
			var squared := offset.x * offset.x + offset.y * offset.y + (BattleSim.NO_ATTACK_PENALTY if def.attack == 0 else 0)
			if BattleSim.SCORE_BASE - squared + bonus > -1:
				return true
	return false


## True for a unit that attacks: its AI looks for enemies (see BattleAI).
static func _fights(def: GameConfig.ItemDef) -> bool:
	if def.attack <= 0:
		return false
	if not _conditions.has(def.id):
		_conditions[def.id] = BattleAI.create(def).condition
	return _conditions[def.id] in [BattleAI.Condition.AGGRESSIVE, BattleAI.Condition.DEFENSIVE]


static func _any_within(tiles: Array[Vector2i], centre: Vector2i, reach: int) -> bool:
	for tile in tiles:
		var offset := tile - centre
		if offset.x * offset.x + offset.y * offset.y <= reach * reach:
			return true
	return false


static func _is_player_item(village: Village, placed: Village.PlacedItem, def: GameConfig.ItemDef) -> bool:
	return village.is_own_unit(placed) if def.is_unit() else def.race != "n" and not village.quest_roles.has(placed)


## The part of the client's target score for the kind of item, or -1 for an
## item that the client does not target.
static func _score_bonus(def: GameConfig.ItemDef) -> int:
	if def.is_unit():
		return BattleSim.SCORE_UNIT
	if def.subcat_functional == SUBCAT_TOWN_HALL:
		return BattleSim.SCORE_TOWN_HALL
	if def.collect > 0:
		return BattleSim.SCORE_PRODUCER
	if def.attack > 0:
		return BattleSim.SCORE_ATTACKER
	return -1


## The fighter of a unit of the save, or null.
func fighter_of(placed: Village.PlacedItem) -> BattleFighter:
	for fighter: BattleFighter in _placed:
		if _placed[fighter] == placed:
			return fighter
	return null
