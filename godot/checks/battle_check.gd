extends SceneTree
## Checks the battle rules without a window, with fixed random seeds.
##
##   godot --headless --path godot --script res://checks/battle_check.gd -- --data <data folder>
##
## It needs config.json from an import of the unchanged socialemperors files:
## the stats of the units and buildings below come from it. The exit code is
## the number of failed checks.

const VILLAGER := 500  # survives: runs away when attacked
const HEALER := 502  # life 25, heals 15, range 5, every 120 frames
const SPEARMAN := 509  # life 40, attack 8, defense 1, range 1, every 35 frames, speed 3
const LIGHT_ARCHER := 516  # life 30, attack 5, range 5: arrows of 30 pixels per frame
const CATAPULT := 521  # siege unit: half damage to units
const GIANT_YETI := 545  # large unit (size 2), range 2
const TOWER_I := 29  # life 300, attack 4, range 7, every 35 frames
const LIGHTNING_TOWER := 214  # timed shots that fly straight, every 15 frames
const HOUSE := 1  # 2x2, no attack: not a target
const MILL := 300  # 2x2, produces: a target
const TOWN_HALL := 26  # 4x4, no attack
const WAR_TROLL := 529  # population 4, life 200
const STONE_GOLEM := 538  # boss, life 6500
const PLAYER := BattleFighter.Team.PLAYER
const ENEMY := BattleFighter.Team.ENEMY

var _config: GameConfig
var _failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--data")
	if index < 0 or index + 1 >= args.size():
		push_error("Give the data folder: -- --data <folder>")
		quit(1)
		return
	_config = GameConfig.load_from_file(args[index + 1].path_join("config.json"))
	if _config == null:
		push_error("Cannot read the imported data in '%s'." % args[index + 1])
		quit(1)
		return
	# A script error stops only the function in which it occurs, so a scenario
	# that does not return true has stopped before its end.
	for scenario: Callable in [_check_damage, _check_siege_and_elements, _check_attack_timing, _check_walk, _check_route, _check_target_choice, _check_formation, _check_group_orders, _check_shots, _check_shot_points, _check_tower, _check_healer, _check_help_and_flight, _check_fights, _check_stun_and_freeze, _check_poison, _check_enlarge_and_shield, _check_swallow_and_summon]:
		_check(scenario.call() == true, "%s runs to its end" % scenario.get_method())
	print("%d failed" % _failures if _failures > 0 else "all passed")
	quit(_failures)


## The damage of one attack: the attack plus a random value from -4 to 4, or
## a critical hit of 1.5 times the attack plus up to 4, minus the defense,
## rounded, at least 1.
func _check_damage() -> bool:
	var sim := _sim(1)
	var target := sim.add_item(_config.get_item(TOWER_I), Vector2i(50, 50), ENEMY)  # defense 1
	var damages: Array[int] = []
	sim.hit.connect(func(_target: BattleFighter, _attacker: BattleFighter, damage: int, _critical: bool) -> void: damages.append(damage))
	for i in 2000:
		target.health = 100000
		sim.receive_attack(target, 10, null)
	var normal := damages.filter(func(d: int) -> bool: return d <= 13)
	_check(normal.min() == 5 and normal.max() == 13, "normal damage of an attack of 10 against defense 1 goes from 5 to 13")
	var criticals := damages.filter(func(d: int) -> bool: return d >= 14)
	_check(criticals.min() >= 14 and criticals.max() >= 19 and criticals.max() <= 20, "critical damage goes from 14 to 20")
	_check(criticals.size() > 150 and criticals.size() < 250, "about one attack in 10 is critical (%d of 2000)" % criticals.size())

	# The same draws as the battle, computed by hand.
	var copy := RandomNumberGenerator.new()
	copy.seed = 7
	sim.rng.seed = 7
	var expected := []
	for i in 5:
		var critical := copy.randf() * 100 < 10
		var variance := copy.randf() * 8 - 4
		var points := (7 + absf(variance)) * 1.5 if critical else 7 + variance
		expected.append(maxi(floori(points - 1 + 0.5), 1))
	damages.clear()
	for i in 5:
		sim.receive_attack(target, 7, null)
	_check(damages == expected, "the damage follows the formula: %s" % [damages])

	damages.clear()
	var strong := sim.add_item(_config.get_item(TOWER_I), Vector2i(60, 60), ENEMY)
	strong.defense = 50
	sim.receive_attack(strong, 10, null)
	_check(damages == [1], "an attack does at least 1 damage")
	return true


## Siege units do half the damage to units and take a quarter more from them.
## Units of an element do 1.35 times the damage to the element that they beat.
func _check_siege_and_elements() -> bool:
	var sim := _sim(2)
	var catapult := sim.add_item(_config.get_item(CATAPULT), Vector2i(40, 40), PLAYER)
	var spearman := sim.add_item(_config.get_item(SPEARMAN), Vector2i(41, 40), ENEMY)
	var damages: Array[int] = []
	sim.hit.connect(func(_t: BattleFighter, _a: BattleFighter, damage: int, _c: bool) -> void: damages.append(damage))
	var copy := RandomNumberGenerator.new()
	copy.seed = 11
	sim.rng.seed = 11
	spearman.health = 1000
	sim.receive_attack(spearman, 31, catapult)
	_check(damages[0] == _expected_damage(copy, 16, spearman.defense), "a catapult does half its attack (rounded up) to a unit")
	catapult.health = 1000
	sim.receive_attack(catapult, 8, spearman)
	_check(damages[1] == _expected_damage(copy, 10, catapult.defense), "a catapult takes 1.25 times the attack of a unit (rounded up)")
	var white := _unit_with_subcat(92)
	var blue := _unit_with_subcat(93)
	if white == null or blue == null:
		_check(false, "the configuration has units of the white and blue elements")
		return true
	var attacker := sim.add_item(white, Vector2i(10, 10), PLAYER)
	var victim := sim.add_item(blue, Vector2i(11, 10), ENEMY)
	_check(sim._attack_against(attacker, victim) == int(white.attack * 1.35), "a white element unit does 1.35 times its attack to a blue one")
	_check(sim._attack_against(victim, attacker) == blue.attack, "a blue element unit does its normal attack to a white one")
	return true


## A unit checks its attack every 5 frames and attacks when the frame plus its
## delay is a multiple of its attack interval.
func _check_attack_timing() -> bool:
	var sim := _sim(3)
	var attacker := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30, 30), PLAYER)
	var target := sim.add_item(_config.get_item(MILL), Vector2i(32, 31), ENEMY)  # 2x2: tiles 31..32
	target.health = 100000
	var frames: Array[int] = []
	sim.hit.connect(func(_t: BattleFighter, a: BattleFighter, _d: int, _c: bool) -> void:
		if a == attacker:
			frames.append(sim.frame))
	for i in 400:
		sim.step()
	_check(attacker.target == target, "an aggressive unit takes the nearest enemy that it can attack")
	_check(frames.size() >= 9, "the spearman attacks the mill (%d attacks in 400 frames)" % frames.size())
	var regular := true
	for i in range(1, frames.size()):
		regular = regular and frames[i] - frames[i - 1] == 35
	_check(regular, "the attacks come every 35 frames")
	_check(frames.all(func(f: int) -> bool: return (f + attacker.attack_delay) % 35 == 0), "the attack frames plus the delay of the unit are multiples of its interval")
	_check(attacker.animation == BattleFighter.Pose.ATTACKING, "the unit shows its attack animation")
	return true


## A unit moves its speed in pixels per frame on the longer axis and stops for
## one frame at each tile.
func _check_walk() -> bool:
	var sim := _sim(4)
	var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(20, 20), PLAYER)
	sim.step()  # The first frame runs the AI.
	_check(sim.order_walk(unit, Vector2i(21, 20)), "a unit can walk to the next tile")
	var frames := 0
	while frames < 100:
		sim.step()
		frames += 1
		if not unit.moving:
			break
	# 54 pixels at 3 pixels per frame, then 2 frames at the tile.
	_check(frames == 20, "one step to the side takes 20 frames (%d)" % frames)
	_check(unit.tile == Vector2i(21, 20) and unit.position == IsoGrid.tile_to_map(Vector2i(21, 20)), "the unit stands on the new tile")
	_check(unit.ai.state == BattleAI.State.IDLE, "the forced move ends on arrival")

	sim.order_walk(unit, Vector2i(21, 30))
	var tiles := {}
	frames = 0
	while frames < 600:
		sim.step()
		frames += 1
		tiles[unit.tile] = true
		if not unit.moving:
			break
	_check(unit.tile == Vector2i(21, 30), "the unit walks 10 tiles")
	_check(tiles.size() == 11, "it passes the 11 tiles of its way (%d)" % tiles.size())
	# 18 frames for the first tile, 19 for each further tile with the stop, and 1 to arrive.
	_check(frames == 190, "the walk takes 190 frames (%d)" % frames)
	return true


## The client's A* search goes around buildings and does not cut corners.
func _check_route() -> bool:
	var blocked := {}
	for y in range(5, 15):
		blocked[Vector2i(10, y)] = true
	var is_free := func(tile: Vector2i) -> bool: return Rect2i(0, 0, 100, 100).has_point(tile) and not blocked.has(tile)
	var route := Pathfinder.find_route(Vector2i(8, 10), Vector2i(12, 10), is_free)
	_check(not route.is_empty() and route.back() == Vector2i(12, 10), "a route goes around a wall")
	_check(route.all(func(t: Vector2i) -> bool: return not blocked.has(t)), "the route does not cross the wall")
	var corner_cut := false
	var cost := 0
	var previous := Vector2i(8, 10)
	for tile in route:
		var step := tile - previous
		corner_cut = corner_cut or (step.x != 0 and step.y != 0 and (blocked.has(previous + Vector2i(step.x, 0)) or blocked.has(previous + Vector2i(0, step.y))))
		cost += 14 if step.x != 0 and step.y != 0 else 10
		previous = tile
	_check(not corner_cut, "the route does not cut the corner of the wall")
	# A separate search gives 128 as the lowest cost (10 for a straight step, 14 for a diagonal one).
	_check(cost == 128, "the route is a cheapest one around the wall (cost %d, %d tiles)" % [cost, route.size()])
	_check(Pathfinder.find_route(Vector2i(8, 10), Vector2i(10, 10), is_free).is_empty(), "no route to a blocked tile")
	_check(Pathfinder.find_route(Vector2i(30, 30), Vector2i(33, 31), is_free).size() == 3, "on open ground a route takes a diagonal step (3 tiles to 3 across and 1 down)")
	_check(Pathfinder.find_route(Vector2i(8, 10), Vector2i(8, 10), is_free) == [Vector2i(8, 10)], "a route to the start tile is the start tile, as in the client")
	return true


## The client prefers units, then the town hall, then producers, then towers,
## and ignores other buildings.
func _check_target_choice() -> bool:
	var sim := _sim(5)
	var seeker := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 50), PLAYER)
	var house := sim.add_item(_config.get_item(HOUSE), Vector2i(47, 47), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == null, "a house is not a target")
	var tower := sim.add_item(_config.get_item(TOWER_I), Vector2i(50, 54), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == tower, "a tower is a target")
	var mill := sim.add_item(_config.get_item(MILL), Vector2i(55, 50), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == mill, "a producer 5 tiles away comes before a tower 4 tiles away")
	var town_hall := sim.add_item(_config.get_item(TOWN_HALL), Vector2i(54, 55), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == town_hall, "the town hall comes before a producer")
	var far_unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 59), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == far_unit, "a unit 9 tiles away comes before the town hall")
	var near_unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(47, 50), ENEMY)
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == near_unit, "the nearer of two units comes first")
	_check(sim.nearest_enemy(seeker, seeker.tile, 2) == null, "nothing within 2 tiles")
	near_unit.dead = true
	_check(sim.nearest_enemy(seeker, seeker.tile, 10) == far_unit, "a dead unit is not a target")
	return house != null


## A unit that attacks a building walks to a free tile at its range next to it.
func _check_formation() -> bool:
	var sim := _sim(6)
	var mill := sim.add_item(_config.get_item(MILL), Vector2i(40, 40), ENEMY)  # tiles 39..40
	mill.health = 100000
	var melee := sim.add_item(_config.get_item(SPEARMAN), Vector2i(40, 46), PLAYER)
	var archer := sim.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(30, 40), PLAYER)
	for i in 300:
		sim.step()
	_check(sim.distance(melee, mill) == 1 and not melee.moving, "the spearman stands next to the mill")
	_check(sim.distance(archer, archer.target) <= 5 and archer.target == mill, "the archer stands within its range of the mill")
	_check(mill.health < 100000, "both attack the mill")
	return true


## Orders of the player to a group, as in the client: a square on free ground,
## the rings around an own unit, and the rings at the range around an enemy.
func _check_group_orders() -> bool:
	var sim := _sim(13)
	var units: Array[BattleFighter] = []
	for i in 8:
		units.append(sim.add_item(_config.get_item(SPEARMAN), Vector2i(20 + i, 20), PLAYER))
	var own := sim.add_item(_config.get_item(SPEARMAN), Vector2i(41, 30), PLAYER)
	sim.order(units, Vector2i(40, 30))
	var square := [Vector2i(40, 30), Vector2i(41, 31), Vector2i(40, 31), Vector2i(42, 30), Vector2i(42, 31), Vector2i(42, 32), Vector2i(41, 32), Vector2i(40, 32)]
	_check(units.map(_goal) == square, "on free ground the group fills a square that grows to the right and down, around a taken tile")
	_check(units.all(func(unit: BattleFighter) -> bool: return unit.ai.state == BattleAI.State.FORCED_MOVE and unit.target == null), "the units only walk")
	sim.order(units.slice(0, 3), own.tile)
	_check(units.slice(0, 3).map(_goal) == [Vector2i(41, 31), Vector2i(40, 31), Vector2i(40, 29)], "around an own unit the group takes the first free tiles of the ring, nearest first")

	sim = _sim(14)
	var tower := sim.add_item(_config.get_item(TOWER_I), Vector2i(50, 50), ENEMY)
	tower.health = 100000
	var spearman := sim.add_item(_config.get_item(SPEARMAN), Vector2i(60, 54), PLAYER)
	var archers: Array[BattleFighter] = [sim.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(60, 50), PLAYER), sim.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(60, 52), PLAYER)]
	var group: Array[BattleFighter] = [spearman, archers[0], archers[1]]
	for unit in group:
		unit.health = 100000
	sim.order(group, tower.tile)
	_check(group.map(_goal) == [Vector2i(51, 51), Vector2i(55, 50), Vector2i(55, 52)], "around an enemy each unit takes the tile nearest to it at its range: %s" % [group.map(_goal)])
	_check(group.all(func(unit: BattleFighter) -> bool: return unit.target == tower and unit.attacking and unit.ai.state == BattleAI.State.FORCED_MOVE), "the units attack the enemy after the walk")
	var attackers := {}
	sim.hit.connect(func(target: BattleFighter, attacker: BattleFighter, _d: int, _c: bool) -> void:
		if target == tower:
			attackers[attacker] = true)
	_run_until(sim, func() -> bool: return attackers.size() == 3, 600)
	_check(attackers.size() == 3, "all three attack the tower")

	sim = _sim(15)
	tower = sim.add_item(_config.get_item(TOWER_I), Vector2i(50, 50), ENEMY)
	spearman = sim.add_item(_config.get_item(SPEARMAN), Vector2i(61, 50), PLAYER)
	var yetis: Array[BattleFighter] = [sim.add_item(_config.get_item(GIANT_YETI), Vector2i(60, 50), PLAYER), sim.add_item(_config.get_item(GIANT_YETI), Vector2i(60, 51), PLAYER)]
	group = [spearman, yetis[0], yetis[1]]
	sim.order(group, tower.tile)
	_check(yetis.map(_goal) == [Vector2i(52, 50), Vector2i(52, 52)], "a large unit keeps the tiles around its tile free: %s" % [yetis.map(_goal)])
	# The yetis (range 2) choose before the spearman (range 1). The tiles (50, 51)
	# and (50, 49) are equally near to the spearman; it takes the first one.
	_check(_goal(spearman) == Vector2i(50, 51), "the units with the longest range choose first: the spearman gets %s" % _goal(spearman))
	return true


## The last tile of the walk of a unit.
func _goal(unit: BattleFighter) -> Vector2i:
	return unit.path.back() if not unit.path.is_empty() else IsoGrid.nearest_tile(unit.walk_point)


## Arrows fly 30 pixels per frame and hurt when they land, not when they leave.
func _check_shots() -> bool:
	var sim := _sim(7)
	var archer := sim.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(30, 30), PLAYER)
	var target := sim.add_item(_config.get_item(SPEARMAN), Vector2i(34, 30), ENEMY)
	target.health = 100000
	target.ai.condition = BattleAI.Condition.PASSIVE
	var fired: Array[int] = []
	var landed: Array[int] = []
	var hits: Array[int] = []
	sim.shot_fired.connect(func(shot: BattleProjectile) -> void:
		if shot.attacker == archer:
			fired.append(sim.frame))
	sim.shot_landed.connect(func(shot: BattleProjectile) -> void:
		if shot.attacker == archer:
			landed.append(sim.frame))
	sim.hit.connect(func(_t: BattleFighter, a: BattleFighter, _d: int, _c: bool) -> void:
		if a == archer:
			hits.append(sim.frame))
	for i in 200:
		sim.step()
	_check(not archer.moving and sim.distance(archer, target) == 4, "the archer shoots from where it stands")
	_check(fired.size() >= 4 and landed.size() >= 3, "the archer shoots arrows (%d)" % fired.size())
	# 4 tiles: about 216 pixels, so 7 or 8 frames.
	var flight := landed[0] - fired[0] if not landed.is_empty() else -1
	_check(flight >= 6 and flight <= 8, "an arrow flies for 6 to 8 frames over 4 tiles (%d)" % flight)
	_check(hits == landed, "the damage comes when an arrow lands")

	# A timed shot of the lightning tower flies 1000 pixels in a second.
	var tower := sim.add_item(_config.get_item(LIGHTNING_TOWER), Vector2i(60, 60), ENEMY)
	var victim := sim.add_item(_config.get_item(SPEARMAN), Vector2i(60, 66), PLAYER)
	var shot := BattleProjectile.fire(tower, victim, sim.rng)
	var pixels := shot.start.distance_to(shot.end)
	_check(shot.kind == BattleProjectile.Kind.TIMED and absi(shot.frames_left - roundi(pixels / 1000.0 * 30)) <= 1, "a lightning bolt flies %.0f pixels in %d frames" % [pixels, shot.frames_left])
	return true


## Shots start at the shot point of the graphic, else at a part of its height,
## and aim at a part of the height of the target; see BattleGraphic. The
## graphics here are made up, so that the check does not need imported graphics.
func _check_shot_points() -> bool:
	var sim := _sim(9)
	var archer := sim.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(50, 50), PLAYER)
	archer.graphic = BattleGraphic.of(_made_up_sprite(Vector2(40, 80), Vector2(-20, -75), null), true, 0)
	var target := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 54), ENEMY)
	target.graphic = BattleGraphic.of(_made_up_sprite(Vector2(30, 60), Vector2(-15, -58), null), true, 0)
	var arrow := BattleProjectile.fire(archer, target, sim.rng)
	_check(arrow.start - archer.position == Vector2(0, -48), "an arrow starts at 0.6 of the height of the archer: %s" % [arrow.start - archer.position])
	# The bottom of the target is 2 pixels below its position; an arrow aims at half its height.
	_check(arrow.aim - target.position == Vector2(0, -28), "an arrow aims at half the height of the target: %s" % [arrow.aim - target.position])

	# The registration point of a building graphic is half its width left of
	# the position and its height above it.
	var tower := sim.add_item(_config.get_item(TOWER_I), Vector2i(60, 50), ENEMY)
	tower.graphic = BattleGraphic.of(_made_up_sprite(Vector2(100, 200), Vector2(-50, -190), Vector2(10, -150)), false, 0)
	var tower_arrow := BattleProjectile.fire(tower, target, sim.rng)
	_check(tower_arrow.start - tower.position == Vector2(-40, -350), "a tower arrow starts at the shot point: %s" % [tower_arrow.start - tower.position])
	var lightning := sim.add_item(_config.get_item(LIGHTNING_TOWER), Vector2i(70, 50), ENEMY)
	lightning.graphic = tower.graphic
	var bolt := BattleProjectile.fire(lightning, target, sim.rng)
	_check(bolt.start - lightning.position == Vector2(0, -150), "a timed shot of a building starts at 0.75 of its height: %s" % [bolt.start - lightning.position])
	_check(bolt.aim - target.position == Vector2(0, -45), "a timed shot aims at 0.75 of the height of the target: %s" % [bolt.aim - target.position])

	# Directions 6 to 8 mirror the graphic, and its shot point.
	var thrower := sim.add_item(_config.get_item(SPEARMAN), Vector2i(80, 80), PLAYER)
	thrower.graphic = BattleGraphic.of(_made_up_sprite(Vector2(40, 80), Vector2(-20, -75), Vector2(12, -40)), true, 0)
	var right := sim.add_item(_config.get_item(SPEARMAN), Vector2i(84, 80), ENEMY)
	var left := sim.add_item(_config.get_item(SPEARMAN), Vector2i(76, 80), ENEMY)
	var to_right := BattleProjectile.fire(thrower, right, sim.rng).start - thrower.position
	var to_left := BattleProjectile.fire(thrower, left, sim.rng).start - thrower.position
	_check(right.position.x > thrower.position.x and to_right == Vector2(12, -40), "a shot to the right starts at the shot point: %s" % [to_right])
	_check(left.position.x < thrower.position.x and to_left == Vector2(-12, -40), "a shot to the left starts at the mirrored shot point: %s" % [to_left])
	return true


## A graphic of 35 frames (all actions of a unit) of the same size, top-left and shot point.
func _made_up_sprite(size: Vector2, top_left: Vector2, shot_point: Variant) -> SpriteLibrary.ItemSprite:
	var sprite := SpriteLibrary.ItemSprite.new()
	for i in 35:
		sprite.frame_sizes.append(size)
		sprite.frame_origins.append(top_left)
		sprite.shot_points.append(shot_point)
	return sprite


## A tower shoots at enemies within its range and keeps a target only within
## half its range. Destroyed buildings of the enemy leave the map.
func _check_tower() -> bool:
	var sim := _sim(8)
	var tower := sim.add_item(_config.get_item(TOWER_I), Vector2i(50, 50), ENEMY)  # range 7
	var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 56), PLAYER)
	unit.ai.condition = BattleAI.Condition.PASSIVE
	unit.health = 100000
	var shots: Array[int] = []
	sim.shot_fired.connect(func(shot: BattleProjectile) -> void:
		if shot.attacker == tower:
			shots.append(sim.frame))
	sim.step()
	_check(tower.target == unit and shots.size() == 1, "the tower shoots at a unit 6 tiles away")
	for i in 35:
		sim.step()
	_check(tower.target == unit and shots == [0, 35], "the tower shoots again after 35 frames")
	_check(sim.distance(tower, unit) > 3, "the unit is more than half the range away")
	var near := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 52), PLAYER)
	near.ai.condition = BattleAI.Condition.PASSIVE
	for i in 35:
		sim.step()
	_check(tower.target == near, "the tower changes to a unit within half its range")

	var deaths: Array[BattleFighter] = []
	sim.died.connect(func(fighter: BattleFighter, _killer: BattleFighter) -> void: deaths.append(fighter))
	tower.health = 1
	sim.receive_attack(tower, 10, near)
	_check(tower.dead and deaths == [tower] and not tower in sim.fighters, "a destroyed enemy tower leaves the map")
	_check(sim._is_walkable(Vector2i(50, 50)), "units can walk where the tower was")
	return true


## A healer heals the wounded unit of its side with the least life, up to its
## full life, during its special animation.
func _check_healer() -> bool:
	var sim := _sim(9)
	var healer := sim.add_item(_config.get_item(HEALER), Vector2i(30, 30), PLAYER)
	var wounded := sim.add_item(_config.get_item(SPEARMAN), Vector2i(32, 30), PLAYER)
	var hurt_less := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30, 32), PLAYER)
	wounded.health = 12
	hurt_less.health = 30
	var heals: Array[int] = []
	sim.healed.connect(func(target: BattleFighter, amount: int) -> void:
		if target == wounded:
			heals.append(amount))
	for i in 62:
		sim.step()
	_check(healer.target == wounded, "the healer chooses the unit with the least life")
	for i in 400:
		sim.step()
	_check(heals.size() >= 2 and heals[0] == 15, "the healer heals 15 life points at a time (%s)" % [heals])
	_check(wounded.health == 40, "a unit gets no more than its full life")
	return true


## An attacked unit calls the units of its side within 4 tiles. A villager runs
## toward the centre of the map.
func _check_help_and_flight() -> bool:
	var sim := _sim(10)
	var victim := sim.add_item(_config.get_item(SPEARMAN), Vector2i(20, 20), PLAYER)
	var friend := sim.add_item(_config.get_item(SPEARMAN), Vector2i(23, 22), PLAYER)
	var stranger := sim.add_item(_config.get_item(SPEARMAN), Vector2i(26, 20), PLAYER)
	var enemy := sim.add_item(_config.get_item(SPEARMAN), Vector2i(10, 10), ENEMY)
	sim.receive_attack(victim, 8, enemy)
	_check(victim.target == enemy and victim.attacking, "an attacked unit fights back")
	_check(friend.target == enemy, "a unit 3 tiles away comes to help")
	_check(stranger.target == null, "a unit 6 tiles away does not")

	var villager := sim.add_item(_config.get_item(VILLAGER), Vector2i(10, 20), PLAYER)
	sim.receive_attack(villager, 1, enemy)
	_check(villager.target == null and villager.walk_point != null and villager.path.back() == Vector2i(14, 23), "an attacked villager runs 5 tiles toward the centre of the map")
	return true


## Small fights end as expected with the same seed.
func _check_fights() -> bool:
	var results := []
	for seed in [21, 22, 23]:
		var sim := _sim(seed)
		var players: Array[BattleFighter] = []
		for i in 3:
			players.append(sim.add_item(_config.get_item(SPEARMAN), Vector2i(40 + i, 40), PLAYER))
		var enemy := sim.add_item(_config.get_item(SPEARMAN), Vector2i(41, 46), ENEMY)
		var frames := _run_until(sim, func() -> bool: return enemy.dead, 3000)
		results.append([frames, players.filter(func(p: BattleFighter) -> bool: return not p.dead).size()])
	_check(results.all(func(r: Array) -> bool: return r[0] > 0 and r[1] == 3), "three spearmen beat one without losses: %s" % [results])

	var sim := _sim(30)
	var tower := sim.add_item(_config.get_item(TOWER_I), Vector2i(60, 60), ENEMY)
	var lone := sim.add_item(_config.get_item(SPEARMAN), Vector2i(60, 66), PLAYER)
	var frames := _run_until(sim, func() -> bool: return lone.dead or tower.dead, 9000)
	_check(lone.dead and not tower.dead, "Tower I kills one spearman (%d frames)" % frames)
	for i in 119:
		sim.step()
	_check(lone in sim.fighters and sim._tiles.get(lone.tile) == lone, "a dead unit stays on its tile for 4 seconds")
	sim.step()
	_check(not lone in sim.fighters and sim._tiles.get(lone.tile) != lone, "then it leaves the map")

	var replay := []
	for run in 2:
		var again := _sim(31)
		var a := again.add_item(_config.get_item(SPEARMAN), Vector2i(10, 10), PLAYER)
		var b := again.add_item(_config.get_item(LIGHT_ARCHER), Vector2i(15, 12), ENEMY)
		_run_until(again, func() -> bool: return a.dead or b.dead, 5000)
		replay.append([again.frame, a.health, b.health])
	_check(replay[0] == replay[1], "the same seed gives the same battle: %s" % [replay[0]])
	return true


## A stunned unit cannot walk or attack for 75 frames and then drops its
## target. Frozen units stop at once. Stun and freeze share one state.
func _check_stun_and_freeze() -> bool:
	var sim := _sim(21)
	var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30, 30), PLAYER)
	var enemy := sim.add_item(_config.get_item(SPEARMAN), Vector2i(31, 30), ENEMY)
	enemy.health = 100000
	sim.attack(unit, enemy)
	var attacks := [0]
	sim.hit.connect(func(_t: BattleFighter, a: BattleFighter, _d: int, _c: bool) -> void:
		if a == unit:
			attacks[0] += 1)
	sim.stun(unit)
	_check(unit.incapacitated and unit.stunned and unit.animation == BattleFighter.Pose.DYING, "a stunned unit falls down")
	_check(not sim.walk(unit, Vector2i(35, 35)), "a stunned unit refuses to walk")
	for i in 75:
		sim.step()
	_check(attacks[0] == 0 and unit.incapacitated, "a stunned unit does not attack for 75 frames")
	sim.step()
	_check(not unit.incapacitated and not unit.stunned and unit.target == null, "after the stun the unit can act and has no target")
	var troll := sim.add_item(_config.get_item(WAR_TROLL), Vector2i(40, 40), ENEMY)
	var golem := sim.add_item(_config.get_item(STONE_GOLEM), Vector2i(45, 45), ENEMY)
	sim.stun(troll)
	sim.stun(golem)
	_check(not troll.incapacitated and not golem.incapacitated, "units with a population of 4 and bosses are not stunned")
	sim.enlarge(unit, 300)
	sim.stun(unit)
	_check(not unit.incapacitated, "an enlarged unit is not stunned")

	var walker := sim.add_item(_config.get_item(SPEARMAN), Vector2i(20, 20), PLAYER)
	sim.walk(walker, Vector2i(26, 20))
	for i in 10:
		sim.step()
	sim.freeze(walker, 450)
	var position := walker.position
	for i in 100:
		sim.step()
	_check(walker.frozen and walker.position == position and walker.path.is_empty(), "a frozen unit stops at once and stays")
	sim.stun(walker)
	_check(not walker.stunned, "a frozen unit is not stunned")
	for i in 351:
		sim.step()
	_check(not walker.frozen and not walker.incapacitated, "the freeze ends after its frames")
	var both := sim.add_item(_config.get_item(SPEARMAN), Vector2i(60, 60), PLAYER)
	sim.stun(both)
	sim.freeze(both, 450)
	for i in 76:
		sim.step()
	_check(both.frozen and not both.incapacitated, "as in the client, the end of a stun also ends a freeze")
	return true


## Poison hurts every 90 frames. With infects 2 it passes to the nearest other
## unit within 1 tile (the first on the map among equal ones), with one tick
## less; with infects 1 to no other unit.
func _check_poison() -> bool:
	var sim := _sim(22)
	var units: Array[BattleFighter] = []
	for x in 3:
		var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30 + x, 30), ENEMY)
		unit.health = 100000
		unit.ai.condition = BattleAI.Condition.PASSIVE
		units.append(unit)
	var hits := {}
	sim.hit.connect(func(t: BattleFighter, _a: BattleFighter, _d: int, _c: bool) -> void:
		hits[t] = hits.get(t, []) + [sim.frame])
	sim.poison(units[0], 20, 5, 1, null)
	for i in 1000:
		sim.step()
	_check(hits.get(units[0]) == [90, 180, 270, 360, 450], "poison hurts 5 times, every 90 frames: %s" % [hits.get(units[0])])
	_check(not hits.has(units[1]) and not units[0].poisoned, "with infects 1 the poison does not pass on, and it ends")
	hits.clear()
	var start := sim.frame
	sim.poison(units[1], 20, 3, 2, null)
	for i in 91:
		sim.step()
	# The units draw random numbers while they wait, so the check takes the range of an attack of 20.
	var lost: int = 100000 - units[1].health
	_check(lost >= 16 - units[1].defense and lost <= 36 - units[1].defense, "a tick is an attack of the poison damage (%d)" % lost)
	for i in 1000:
		sim.step()
	_check(hits[units[1]].slice(0, 3) == [start + 90, start + 180, start + 270], "the first unit gets its ticks")
	_check(hits.has(units[0]) and hits[units[0]][0] == start + 180 and not hits.has(units[2]), "the poison passes to one neighbour at the next tick")
	var endless := sim.add_item(_config.get_item(SPEARMAN), Vector2i(50, 50), ENEMY)
	endless.health = 100000
	endless.ai.condition = BattleAI.Condition.PASSIVE
	hits.clear()
	sim.poison(endless, 20, 0, 0, null)
	for i in 1800:
		sim.step()
	_check(hits[endless].size() == 19 and endless.poisoned, "as in the client, a poison without ticks does not end")
	return true


## An enlarged unit does 1.5 times its damage. A shield lets only its factor
## of the damage through on its tiles, on both sides; shields do not add up.
func _check_enlarge_and_shield() -> bool:
	var sim := _sim(23)
	var attacker := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30, 30), PLAYER)
	var target := sim.add_item(_config.get_item(SPEARMAN), Vector2i(31, 30), ENEMY)
	target.health = 100000
	var damages: Array[int] = []
	sim.hit.connect(func(_t: BattleFighter, _a: BattleFighter, damage: int, _c: bool) -> void: damages.append(damage))
	var copy := RandomNumberGenerator.new()
	copy.seed = 5
	sim.rng.seed = 5
	sim.enlarge(attacker, 60)
	sim.receive_attack(target, 8, attacker)
	_check(damages[0] == _expected_damage(copy, 12, target.defense), "an enlarged unit does 1.5 times its attack")
	for i in 61:
		sim.step()
	_check(not attacker.enlarged, "the unit gets its normal size after its frames")

	var shield := sim.add_shield(Vector2i(31, 30), 7, 0.7)
	_check(sim.shield_factor(Vector2i(31, 30)) == 0.7 and sim.shield_factor(Vector2i(25, 24)) == 0.7, "the shield covers 7 tiles up to its corner")
	_check(sim.shield_factor(Vector2i(32, 30)) == 1.0 and sim.shield_factor(Vector2i(24, 30)) == 1.0, "the shield ends at its area")
	sim.add_shield(Vector2i(31, 30), 5, 0.4)
	_check(sim.shield_factor(Vector2i(31, 30)) == 0.7, "the first shield counts; shields do not add up")
	damages.clear()
	copy.seed = 6
	sim.rng.seed = 6
	sim.receive_attack(target, 40, null)
	var critical := copy.randf() * 100 < 10
	var variance := copy.randf() * 8 - 4
	var points := (40 + absf(variance)) * 1.5 if critical else 40 + variance
	points -= floorf(points - points * 0.7 + 0.5)
	_check(damages[0] == maxi(floori(points - target.defense + 0.5), 1), "an enemy on the shield also takes less damage")
	sim.remove_shield(shield)
	_check(sim.shield_factor(Vector2i(25, 24)) == 1.0, "a removed shield protects no more")
	sim.add_shield(Vector2i(10, 10), 0, 0.4)
	_check(sim.shield_factor(Vector2i(10, 10)) == 1.0, "a shield with an area of 0 protects no tile")
	return true


## A swallowed item dies after 15 frames, without a killer. Units with 500
## life or more cannot be swallowed. A summoned unit has the life of the spell.
func _check_swallow_and_summon() -> bool:
	var sim := _sim(24)
	var unit := sim.add_item(_config.get_item(SPEARMAN), Vector2i(30, 30), ENEMY)
	var house := sim.add_item(_config.get_item(MILL), Vector2i(40, 40), ENEMY)
	var golem := sim.add_item(_config.get_item(STONE_GOLEM), Vector2i(50, 50), ENEMY)
	var deaths := {}
	sim.died.connect(func(item: BattleFighter, killer: BattleFighter) -> void: deaths[item] = [sim.frame, killer])
	sim.swallow(unit)
	sim.swallow(house)
	sim.swallow(golem)
	_check(unit.swallowed and not golem.swallowed, "a unit with 6500 life cannot be swallowed")
	for i in 16:
		sim.step()
	_check(deaths.has(unit) and deaths[unit][0] == 15 and deaths[unit][1] == null, "a swallowed unit dies after 15 frames, without a killer")
	_check(deaths.has(house) and not house in sim.fighters, "a swallowed building is destroyed")
	var summoned := sim.summon(_config.get_item(630), Vector2i(60, 60), PLAYER, 5000)
	_check(summoned.summoned and summoned.health == 5000 and summoned.max_life() == 5000, "a summoned golem has the life of the spell")
	return true


## Runs the battle until done returns true. Returns the frame, or -1 after limit frames.
func _run_until(sim: BattleSim, done: Callable, limit: int) -> int:
	for i in limit:
		sim.step()
		if done.call():
			return sim.frame
	return -1


func _sim(seed: int) -> BattleSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return BattleSim.new(rng)


func _expected_damage(copy: RandomNumberGenerator, points: float, defense: int) -> int:
	var critical := copy.randf() * 100 < 10
	var variance := copy.randf() * 8 - 4
	var total := (points + absf(variance)) * 1.5 if critical else points + variance
	return maxi(floori(total - defense + 0.5), 1)


func _unit_with_subcat(subcat: int) -> GameConfig.ItemDef:
	for item in _config.items():
		if item.is_unit() and item.subcat_functional == subcat and item.attack > 0:
			return item
	return null


func _check(passed: bool, description: String) -> void:
	if not passed:
		_failures += 1
	print("%s  %s" % ["ok  " if passed else "FAIL", description])
