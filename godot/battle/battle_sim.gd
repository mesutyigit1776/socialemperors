class_name BattleSim
extends RefCounted
## A battle without graphics: the rules of the original client, one frame at a
## time, at 30 frames per second. A view can draw it, and the checks can run it
## with a fixed random seed.
##
## The battle has the items of a map: units and buildings of the player, of
## the enemy, and neutral items such as trees. Units find enemies, walk to them,
## fight back and call their neighbours for help. Towers and castles shoot at
## enemies in their range. Healers heal the units of their side.
##
## Not here yet: spells and magic shields, the special attacks of most units,
## the scripts of the quests, and the rules of the game modes (what a dead unit or
## building gives or costs). The signals tell the other parts what happens.

## target lost damage points. critical: the attack was a critical hit.
signal hit(target: BattleFighter, attacker: BattleFighter, damage: int, critical: bool)
signal healed(target: BattleFighter, amount: int)
signal shot_fired(shot: BattleProjectile)
signal shot_landed(shot: BattleProjectile)
## fighter died. killer is null when no fighter killed it.
signal died(fighter: BattleFighter, killer: BattleFighter)

## A unit checks its attack every ATTACK_CHECK_FRAMES frames, and attacks when
## the frame is also a multiple of its attack interval.
const ATTACK_CHECK_FRAMES := 5
const ANIMATION_FRAMES := 2  ## The client updates the animation every 2 frames.
const MAX_ATTACK_DELAY := 4
## After a unit walks toward its target, it waits 300 ms before it walks again.
const FOLLOW_WAIT_FRAMES := 9
const DEAD_UNIT_FRAMES := 120  ## A dead unit stays on the map for 4 seconds.
const CRITICAL_PERCENT := 10.0
const CRITICAL_MULTIPLIER := 1.5
const DAMAGE_VARIANCE := 8.0  ## The damage is the attack plus a random value from -4 to 4.
## Units of an element do 1.35 times the damage to units of the element that they beat.
const ELEMENT_MULTIPLIER := 1.35
const ELEMENT_BEATS := {92: 93, 93: 95, 94: 92, 95: 96, 96: 94}
const SIEGE_DAMAGE_DONE := 0.5  ## Siege units do half the damage to units...
const SIEGE_DAMAGE_TAKEN := 1.25  ## ...and take more damage from units.
const HELP_RINGS := 4  ## An attacked item calls the units of its side within 4 tiles.
const FREE_TILE_RINGS := 5
## Target choice: the client prefers units, then the town hall, then
## buildings that produce, then buildings that attack. It ignores other items.
const SCORE_BASE := 1000
const SCORE_UNIT := 150
const SCORE_TOWN_HALL := 100
const SCORE_PRODUCER := 75
const SCORE_ATTACKER := 50
const NO_ATTACK_PENALTY := 10  ## Squared tiles added to the distance of items without attack.

const SUBCAT_TOWN_HALL := 135
const SUBCAT_TOWER := 211
const SUBCAT_FARM := 122
const SUBCAT_HEALING := 137
const SUBCAT_CLERIC := 72
const SUBCAT_SIEGE := 81
const RESOURCE_SUBCATS: Array[int] = [125, 126, 127]  ## Trees, stone and gold.
const CATEGORY_TERRAIN := 6
## Towers, castles, dragon killers and town halls shoot, except Town Hall I.
const SHOOTING_SUBCATS: Array[int] = [211, 231, 1711, 135]
const TOWN_HALL_I := 26
const ICE_TOWER := 384  ## Shoots only at units.
## A tower with towers on all 8 sides does not look for targets when the map
## has at least this number of towers.
const SURROUNDED_TOWER_COUNT := 100
## Units with a range of more than 1 that still fight at close range: the golem
## and yeti bosses, the juggernaut and the angel mecha.
const CLOSE_FIGHTERS: Array[int] = [538, 545, 650, 702]
## Units that keep a unit of their own side as target: healers and the engineer.
const SUPPORT_UNITS: Array[int] = [502, 570, 590, 866, 886]

var rng: RandomNumberGenerator
var frame := 0
var fighters: Array[BattleFighter] = []  ## In the order in which they act in each frame.
var projectiles: Array[BattleProjectile] = []
var _removed: Array[BattleFighter] = []  # Items that left the map; others can still target them.
var _tiles := {}  # Vector2i -> BattleFighter on the tile, like the tile array of the client.
var _blocked := {}  # Vector2i -> true for tiles that walking units go around.
var _towers := 0


func _init(random: RandomNumberGenerator) -> void:
	rng = random


## Fighters refer to each other through their targets. The battle clears these
## references when it ends, so that the fighters can be freed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for item in fighters + _removed:
			item.target = null
			item.targeted_by.clear()


## Adds an item of the map. tile is the anchor tile, as in a save.
func add_item(def: GameConfig.ItemDef, tile: Vector2i, team: BattleFighter.Team) -> BattleFighter:
	var item := BattleFighter.new()
	item.def = def
	item.team = team
	item.tile = tile
	item.position = IsoGrid.tile_to_map(tile)
	item.face_point = item.position
	item.health = def.life
	item.attack = def.attack
	item.defense = def.defense
	item.attack_interval = def.attack_interval
	item.attack_range = def.attack_range
	item.speed = def.velocity
	item.flying = def.flying
	item.attack_delay = rng.randi_range(0, MAX_ATTACK_DELAY)
	item.ability = BattleAbility.for_item(def.id)
	if item.is_unit():
		item.ai = BattleAI.new(def)
		item.origin = tile
		item.next_point = item.position
		if not _tiles.has(tile):
			_tiles[tile] = item
	elif def.category_id != CATEGORY_TERRAIN:
		var area := item.footprint()
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				_tiles[Vector2i(x, y)] = item
				if def.subcat_functional != SUBCAT_FARM:
					_blocked[Vector2i(x, y)] = true
	if def.subcat_functional == SUBCAT_TOWER:
		_towers += 1
	fighters.append(item)
	return item


## Runs one frame.
func step() -> void:
	for item: BattleFighter in fighters.duplicate():
		if item.dead and item.is_unit():
			item.remove_frames -= 1
			if item.remove_frames <= 0:
				_remove(item)
	_update_projectiles()
	for item: BattleFighter in fighters.duplicate():
		if item.is_unit():
			_update_unit(item)
		elif not item.dead:
			_update_building(item)
	frame += 1


## An order of the player: the unit walks to tile and does not attack on the way.
func order_walk(unit: BattleFighter, tile: Vector2i) -> bool:
	unit.attacking = false
	set_target(unit, null)
	unit.ai.state = BattleAI.State.FORCED_MOVE
	return walk(unit, tile)


## An order of the player to units of the player, as the client gives it when
## the player clicks tile: the units walk to tile in a formation, see
## BattleFormation. They attack an enemy on tile, and they stand around an own
## item or a tree or deposit on tile.
func order(units: Array[BattleFighter], tile: Vector2i) -> void:
	var living: Array[BattleFighter] = units.filter(func(unit: BattleFighter) -> bool: return not unit.dead)
	var item: BattleFighter = _tiles.get(tile)
	var stands := {}
	if item != null and (item.team == BattleFighter.Team.ENEMY or item.def.subcat_functional in RESOURCE_SUBCATS):
		var can_stand := func(candidate: Vector2i) -> bool: return _is_standable(candidate) or _tiles.get(candidate) in living
		stands = BattleFormation.attack_tiles(item, living, can_stand)
	else:
		var is_free := func(candidate: Vector2i) -> bool: return _on_map(candidate) and not _tiles.has(candidate)
		var tiles := BattleFormation.spiral_tiles(item.tile, living.size(), is_free) if item != null \
				else BattleFormation.square_tiles(tile, living.size(), is_free)
		for i in tiles.size():
			stands[living[i]] = tiles[i]
	for unit: BattleFighter in stands:
		if item != null and item.team == BattleFighter.Team.ENEMY:
			unit.ai.state = BattleAI.State.FORCED_MOVE
			unit.attacking = true
			set_target(unit, item)
			if not walk(unit, stands[unit]):
				set_target(unit, null)
		else:
			order_walk(unit, stands[unit])


## The unit attacks target; it walks next to it when it is out of range.
func attack(unit: BattleFighter, target: BattleFighter) -> void:
	if unit.dead:
		return
	unit.attacking = true
	set_target(unit, target)
	if distance(unit, target) <= unit.attack_range:
		return
	var stand: Variant = _formation_tile(target, unit)
	if stand != null and not walk(unit, stand):
		set_target(unit, null)


## The unit walks to tile. Returns false when it cannot get there.
func walk(unit: BattleFighter, tile: Vector2i) -> bool:
	if unit.dead:
		return false
	var nodes: Array[Vector2i] = []
	if unit.flying:
		nodes = _line(unit.tile, tile)
		if nodes.is_empty():
			return false
		nodes.append(tile)
	else:
		nodes = Pathfinder.find_route(unit.tile, tile, _is_walkable)
		if nodes.size() == 1:
			nodes.append(tile)  # The client walks to the goal twice when it is the first step.
	if nodes.is_empty():
		return false
	unit.walk_point = IsoGrid.tile_to_map(nodes.pop_front())
	unit.path = nodes
	return true


func set_target(item: BattleFighter, target: BattleFighter) -> void:
	if item.target == target:
		return
	if item.target != null:
		item.target.targeted_by.erase(item)
	item.target = target
	if target != null:
		target.targeted_by.append(item)


## The distance in tiles between the nearest tiles of two items, counting a
## diagonal step as one.
func distance(a: BattleFighter, b: BattleFighter) -> int:
	var area_a := a.footprint()
	var area_b := b.footprint()
	var gap_x := maxi(maxi(area_b.position.x - area_a.end.x + 1, area_a.position.x - area_b.end.x + 1), 0)
	var gap_y := maxi(maxi(area_b.position.y - area_a.end.y + 1, area_a.position.y - area_b.end.y + 1), 0)
	return maxi(gap_x, gap_y)


## The enemy that the client chooses for item from tile, within range tiles.
func nearest_enemy(item: BattleFighter, tile: Vector2i, range_tiles: int) -> BattleFighter:
	return nearest_target(item, tile, range_tiles, func(other: BattleFighter) -> bool: return true, false)


## The best target for item near tile that passes filter: on the side of item
## when own_side, else on the other side. See SCORE_BASE for the order.
func nearest_target(item: BattleFighter, tile: Vector2i, range_tiles: int, filter: Callable, own_team: bool) -> BattleFighter:
	var team := item.team if own_team else _opponent(item.team)
	var best: BattleFighter = null
	var best_score := -1
	for other in fighters:
		if other.team != team or other.dead:
			continue
		var offset := other.tile - tile
		var squared := offset.x * offset.x + offset.y * offset.y
		var score := _target_score(other, squared)
		if score > best_score and squared <= range_tiles * range_tiles and other.tile != tile and filter.call(other):
			best = other
			best_score = score
	return best


## Up to count units on the side of item within range tiles of it that pass
## filter, nearest first. The unit itself is not included.
func nearest_units(item: BattleFighter, range_tiles: int, count: int, filter: Callable) -> Array[BattleFighter]:
	var found: Array[BattleFighter] = []
	var squares := {}
	for other in fighters:
		var offset := other.tile - item.tile
		var squared := offset.x * offset.x + offset.y * offset.y
		if other.team == item.team and other.is_unit() and squared <= range_tiles * range_tiles and other.tile != item.tile and filter.call(other):
			found.append(other)
			squares[other] = squared
	found.sort_custom(func(a: BattleFighter, b: BattleFighter) -> bool: return squares[a] < squares[b])
	return found.slice(0, count)


func needs_healing(unit: BattleFighter) -> bool:
	return unit.is_unit() and not unit.dead and unit.health < unit.max_life() and unit.def.subcat_functional != SUBCAT_SIEGE


func is_wounded_siege(unit: BattleFighter) -> bool:
	return unit.is_unit() and not unit.dead and unit.health < unit.max_life() and unit.def.subcat_functional == SUBCAT_SIEGE


func heal(target: BattleFighter, amount: int) -> void:
	if target.dead:
		return
	target.health = mini(target.health + amount, target.max_life())
	healed.emit(target, amount)


## An attack of amount points on target. attacker can be null.
func receive_attack(target: BattleFighter, amount: int, attacker: BattleFighter) -> void:
	if amount == 0 or target.dead:
		return
	var points := float(amount)
	if attacker != null and attacker.is_unit() and target.is_unit():
		if attacker.def.subcat_functional == SUBCAT_SIEGE:
			points = ceilf(points * SIEGE_DAMAGE_DONE)
		if target.def.subcat_functional == SUBCAT_SIEGE:
			points = ceilf(points * SIEGE_DAMAGE_TAKEN)
	var critical := rng.randf() * 100 < CRITICAL_PERCENT
	var variance := rng.randf() * DAMAGE_VARIANCE - DAMAGE_VARIANCE / 2
	points = (points + absf(variance)) * CRITICAL_MULTIPLIER if critical else points + variance
	var damage := maxi(floori(points - target.defense + 0.5), 1)
	target.health -= damage
	hit.emit(target, attacker, damage, critical)
	if target.health <= 0:
		target.health = 0
		_kill(target, attacker)
		return
	if attacker == null:
		return
	if target.is_unit():
		target.ai.on_attacked(self, target, attacker)
	elif target.attack > 0 and (target.target == null or target.target.attack == 0):
		set_target(target, attacker)
	_call_for_help(target, attacker)


func _update_unit(unit: BattleFighter) -> void:
	if unit.dead:
		if frame % ANIMATION_FRAMES == 0:
			unit.animation = BattleFighter.Pose.DYING
		return
	if frame % BattleAI.UPDATE_INTERVAL == 0:
		_tidy(unit)
		unit.ai.update(self, unit)
	if unit.attacking and (frame + unit.attack_delay) % ATTACK_CHECK_FRAMES == 0:
		_update_attack(unit)
	_update_walk(unit)
	if frame % ANIMATION_FRAMES == 0:
		_update_animation(unit)
	unit.reposition_frames = maxi(unit.reposition_frames - 1, 0)
	unit.reattack_frames = maxi(unit.reattack_frames - 1, 0)


## The regular check of the client: a unit drops a dead target, takes its tile,
## and walks off a tile that another item covers.
func _tidy(unit: BattleFighter) -> void:
	if unit.target != null:
		if unit.target.team != unit.team and unit.target.team != BattleFighter.Team.NEUTRAL:
			unit.attacking = true
		if unit.target.dead:
			set_target(unit, null)
	if unit.moving:
		return
	var here: BattleFighter = _tiles.get(unit.tile)
	if here == null:
		_tiles[unit.tile] = unit
	elif here != unit and here.def.subcat_functional != SUBCAT_FARM:
		# An enemy unit stays on a tile of the player.
		if unit.team == BattleFighter.Team.ENEMY and here.team == BattleFighter.Team.PLAYER:
			return
		var free: Variant = _random_free_tile_near(unit.tile)
		if free != null:
			unit.ai.state = BattleAI.State.FORCED_MOVE
			walk(unit, free)
	var centre := IsoGrid.tile_to_map(unit.tile)
	if unit.position != centre:
		unit.walk_point = centre


func _update_attack(unit: BattleFighter) -> void:
	var target := unit.target
	if target == null:
		unit.attacking = false
		return
	if target.team == unit.team and not unit.def.id in SUPPORT_UNITS:
		set_target(unit, null)
		unit.attacking = false
		return
	if target.dead:
		return
	# A ranged unit shoots while it walks; a melee unit attacks when it stands.
	var ready := unit.next_point == unit.position or (not unit.moving and unit.attack_range <= 1) or unit.attack_range >= 2
	if distance(unit, target) <= unit.attack_range and ready:
		unit.path.clear()
		if not _tiles.has(unit.tile):
			_tiles[unit.tile] = unit
		if unit.attack_interval <= 0 or (frame + unit.attack_delay) % unit.attack_interval != 0:
			return
		if unit.ability != null and not unit.ability.on_attack(self, unit):
			return
		if unit.is_special() and unit.animation != BattleFighter.Pose.ATTACKING:
			return  # The special attacks of these units come with their abilities.
		if unit.def.subcat_functional == SUBCAT_CLERIC:
			return
		if unit.attack_range > 1 and not unit.def.id in CLOSE_FIGHTERS:
			_shoot(unit, target, BattleProjectile.STEPPED_SHOTS.has(unit.def.id))
		else:
			receive_attack(target, _attack_against(unit, target), unit)
		return
	if target.is_unit() and target.moving and unit.reposition_frames == 0:
		attack(unit, target)
		unit.reposition_frames = FOLLOW_WAIT_FRAMES
	if not unit.moving and unit.reattack_frames == 0:
		attack(unit, target)
		unit.reattack_frames = FOLLOW_WAIT_FRAMES


## The client moves a unit with IsoGrid.step_toward() in each frame, and stops
## for one frame at each tile of its path.
func _update_walk(unit: BattleFighter) -> void:
	if unit.walk_point == null or unit.speed <= 0:
		unit.moving = false
		return
	unit.moving = true
	if unit.walk_point != unit.previous_walk_point:
		unit.previous_walk_point = unit.walk_point
		unit.next_point = unit.walk_point
	elif unit.position == unit.next_point:
		if not unit.path.is_empty():
			var next_tile: Vector2i = unit.path.pop_front()
			unit.walk_point = IsoGrid.tile_to_map(next_tile)
			if not unit.flying and _blocked.has(next_tile):
				unit.walk_point = null
				unit.path.clear()
		else:
			unit.walk_point = null
			unit.moving = false
			unit.ai.on_arrived()
	if unit.position == unit.next_point:
		return
	unit.position = IsoGrid.step_toward(unit.position, unit.next_point, unit.speed)
	var tile := IsoGrid.nearest_tile(unit.position)
	if tile != unit.tile:
		if _tiles.get(unit.tile) == unit:
			_tiles.erase(unit.tile)
		if not _tiles.has(tile):
			_tiles[tile] = unit
		unit.tile = tile


func _update_animation(unit: BattleFighter) -> void:
	if unit.moving:
		unit.animation = BattleFighter.Pose.WALKING
		unit.face_point = unit.next_point
	elif unit.attacking and unit.target != null:
		if unit.is_special():
			_update_special_cycle(unit)
		else:
			unit.animation = BattleFighter.Pose.ATTACKING
		unit.face_point = unit.target.position
	else:
		unit.animation = BattleFighter.Pose.IDLE


func _update_special_cycle(unit: BattleFighter) -> void:
	var ability := unit.ability
	unit.special_frames += ANIMATION_FRAMES
	match unit.animation:
		BattleFighter.Pose.ATTACKING:
			if unit.special_frames > ability.special_intervals[unit.special_index]:
				unit.special_frames = 0
				unit.animation = BattleFighter.Pose.SPECIAL
		BattleFighter.Pose.SPECIAL:
			if unit.special_frames > ability.special_durations[unit.special_index]:
				unit.special_frames = 0
				unit.animation = BattleFighter.Pose.ATTACKING
				unit.special_index = (unit.special_index + 1) % ability.special_intervals.size()
		_:
			unit.animation = BattleFighter.Pose.ATTACKING


func _update_building(building: BattleFighter) -> void:
	var subcat := building.def.subcat_functional
	if building.attack_interval <= 0 or frame % building.attack_interval != 0:
		return
	if subcat == SUBCAT_HEALING:
		var wounded := nearest_target(building, building.tile, building.attack_range, needs_healing, true)
		if wounded != null:
			heal(wounded, building.attack)
		return
	if building.team == BattleFighter.Team.NEUTRAL or not subcat in SHOOTING_SUBCATS or building.def.id == TOWN_HALL_I:
		return
	# A tower keeps its target only within half its range.
	if building.target != null and distance(building, building.target) > building.attack_range / 2.0:
		set_target(building, null)
	if (building.target == null or building.target.dead) and not _is_surrounded_by_towers(building):
		set_target(building, nearest_enemy(building, building.tile, building.attack_range))
	if building.target == null:
		return
	if building.def.id == ICE_TOWER and not building.target.is_unit():
		return
	_shoot(building, building.target, BattleProjectile.STEPPED_SHOTS.has(building.def.id))


## stepped: the shot is one of BattleProjectile.STEPPED_SHOTS, which the client
## does not fire at a target out of range.
func _shoot(shooter: BattleFighter, target: BattleFighter, stepped: bool) -> void:
	if stepped and distance(shooter, target) > shooter.attack_range:
		return
	var shot := BattleProjectile.fire(shooter, target, rng)
	projectiles.append(shot)
	shot_fired.emit(shot)


func _update_projectiles() -> void:
	for shot: BattleProjectile in projectiles.duplicate():
		shot.frames_left -= 1
		if shot.frames_left > 0:
			continue
		projectiles.erase(shot)
		shot_landed.emit(shot)
		var target := shot.target
		if shot.kind == BattleProjectile.Kind.STEPPED:
			# The client uses the attack of the shooter when the shot lands.
			if not target.dead and shot.attacker in fighters and shot.end.distance_to(target.position) <= BattleProjectile.HIT_RADIUS:
				receive_attack(target, _attack_against(shot.attacker, target), shot.attacker)
		elif _pixel_distance(shot.aim, target) <= BattleProjectile.HIT_RADIUS:
			receive_attack(target, shot.damage, shot.attacker)


func _attack_against(attacker: BattleFighter, target: BattleFighter) -> int:
	if ELEMENT_BEATS.get(attacker.def.subcat_functional) == target.def.subcat_functional:
		return int(attacker.attack * ELEMENT_MULTIPLIER)
	return attacker.attack


func _kill(item: BattleFighter, killer: BattleFighter) -> void:
	item.dead = true
	item.attacking = false
	died.emit(item, killer)
	if item.is_unit():
		item.walk_point = null
		item.path.clear()
		item.remove_frames = DEAD_UNIT_FRAMES
	elif item.team != BattleFighter.Team.PLAYER or (item.def.cost_type != "c" and item.def.subcat_functional != SUBCAT_TOWN_HALL):
		# In battles away from the village, a destroyed building leaves the map;
		# the town hall and buildings that cost cash stay as ruins.
		_remove(item)
	for other: BattleFighter in item.targeted_by.duplicate():
		if other.is_unit() and other.target == item and not other.dead:
			other.ai.on_target_dead(self, other, item.tile)


func _remove(item: BattleFighter) -> void:
	fighters.erase(item)
	_removed.append(item)
	set_target(item, null)
	for tile: Vector2i in _tiles.keys():
		if _tiles[tile] == item:
			_tiles.erase(tile)
	if not item.is_unit():
		var area := item.footprint()
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				_blocked.erase(Vector2i(x, y))


## The client calls the units of the same side on the rings around the tile of
## an attacked item, from the nearest ring out. Corner tiles get two calls.
func _call_for_help(item: BattleFighter, attacker: BattleFighter) -> void:
	var centre := item.tile
	for ring in range(1, HELP_RINGS + 1):
		for x in range(centre.x - ring, centre.x + ring + 1):
			_ask_for_help(Vector2i(x, centre.y - ring), item, attacker)
			_ask_for_help(Vector2i(x, centre.y + ring), item, attacker)
		for y in range(centre.y - ring, centre.y + ring + 1):
			_ask_for_help(Vector2i(centre.x - ring, y), item, attacker)
			_ask_for_help(Vector2i(centre.x + ring, y), item, attacker)


func _ask_for_help(tile: Vector2i, item: BattleFighter, attacker: BattleFighter) -> void:
	var other: BattleFighter = _tiles.get(tile)
	if other != null and other.team == item.team and other.is_unit() and not other.dead:
		other.ai.on_ally_attacked(self, other, attacker)


## The tile from which unit attacks target: on the ring at the range of the
## unit around the target, the free tile nearest to the unit.
func _formation_tile(target: BattleFighter, unit: BattleFighter) -> Variant:
	var size := Vector2i(target.def.width, target.def.height)
	var centre := target.tile - size / 2
	var even := 1 if size.x % 2 == 0 else 0
	for ring in range(unit.attack_range + size.x / 2, IsoGrid.MAP_TILES):
		var best: Variant = null
		var best_squared := 0
		for tile in BattleFormation.ring_tiles(centre, ring, even):
			if not (_is_standable(tile) or _tiles.get(tile) == unit):
				continue
			var offset := tile - unit.tile
			var squared := offset.x * offset.x + offset.y * offset.y
			if best == null or squared < best_squared:
				best = tile
				best_squared = squared
		if best != null:
			return best
	return null


func _is_walkable(tile: Vector2i) -> bool:
	return _on_map(tile) and not _blocked.has(tile)


## A unit can stand on a tile without items, or on a flat item such as a road.
func _is_standable(tile: Vector2i) -> bool:
	if not _on_map(tile):
		return false
	var item: BattleFighter = _tiles.get(tile)
	return item == null or item.def.elevation == 0


func _random_free_tile_near(tile: Vector2i) -> Variant:
	for ring in range(1, FREE_TILE_RINGS + 1):
		var free: Array[Vector2i] = []
		for x in range(tile.x - ring, tile.x + ring + 1):
			for y in [tile.y + ring, tile.y - ring]:
				if _on_map(Vector2i(x, y)) and not _tiles.has(Vector2i(x, y)):
					free.append(Vector2i(x, y))
		for y in range(tile.y - ring + 1, tile.y + ring):
			for x in [tile.x - ring, tile.x + ring]:
				if _on_map(Vector2i(x, y)) and not _tiles.has(Vector2i(x, y)):
					free.append(Vector2i(x, y))
		if not free.is_empty():
			return free[rng.randi_range(0, free.size() - 1)]
	return null


func _is_surrounded_by_towers(building: BattleFighter) -> bool:
	if _towers < SURROUNDED_TOWER_COUNT:
		return false
	for x in range(building.tile.x - 1, building.tile.x + 2):
		for y in range(building.tile.y - 1, building.tile.y + 2):
			var other: BattleFighter = _tiles.get(Vector2i(x, y))
			if other == null or other.is_unit() or other.def.subcat_functional != SUBCAT_TOWER:
				return false
	return true


## The client measures a timed shot from its aim point to the tiles of the
## target, including one more row and column than the footprint.
func _pixel_distance(point: Vector2, item: BattleFighter) -> float:
	var nearest := float(IsoGrid.MAP_TILES)
	for x in range(item.tile.x - item.def.width, item.tile.x + 1):
		for y in range(item.tile.y - item.def.height, item.tile.y + 1):
			nearest = minf(nearest, point.distance_to(IsoGrid.tile_to_map(Vector2i(x, y))))
	return nearest


func _target_score(item: BattleFighter, squared: int) -> int:
	var score := SCORE_BASE - squared - (NO_ATTACK_PENALTY if item.def.attack == 0 else 0)
	if item.is_unit():
		return score + SCORE_UNIT
	if item.def.subcat_functional == SUBCAT_TOWN_HALL:
		return score + SCORE_TOWN_HALL
	if item.def.collect > 0:
		return score + SCORE_PRODUCER
	if item.attack > 0:
		return score + SCORE_ATTACKER
	return -1


## The tiles of a flying unit from start (not included) to goal: diagonal steps first.
static func _line(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var tile := start
	while tile != goal:
		tile += (goal - tile).sign()
		result.append(tile)
	return result


static func _on_map(tile: Vector2i) -> bool:
	return Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile)


static func _opponent(team: BattleFighter.Team) -> BattleFighter.Team:
	return BattleFighter.Team.ENEMY if team == BattleFighter.Team.PLAYER else BattleFighter.Team.PLAYER
