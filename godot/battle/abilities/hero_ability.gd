class_name HeroAbility
extends BattleAbility
## The special attacks that the client writes in IsoUnit itself
## (checkUnitSpecial and updateAttack), not in a delegate. These units repeat
## a cycle of a normal attack and one or two special attacks. While a special
## animation plays, each attack is the special attack instead of the normal one.

## Item id -> [kind, intervals, durations].
const UNITS := {
	603: ["wave_15", [105], [70]], 643: ["wave_15", [105], [70]],  # Elephants
	644: ["wave_25", [105], [70]], 673: ["wave_25", [105], [70]],  # Hell warriors
	648: ["wave_whirl", [105], [70]], 677: ["wave_whirl", [105], [70]],  # Hell halberdiers
	645: ["whirl", [105], [70]], 674: ["whirl", [105], [70]],  # Hell warriors II
	533: ["whirl", [60], [60]],  # Xena
	629: ["whirl", [120], [60]],  # Elf tiger
	632: ["whirl", [120], [30]],  # Elf royal
	646: ["hell_archer", [100], [60]], 675: ["hell_archer", [100], [60]],
	647: ["fire_stream", [105], [70]], 676: ["fire_stream", [105], [70]],  # Hell knights
	650: ["juggernaut", [105, 105], [45, 70]],
	534: ["stream", [60], [60]],  # Arthur
	618: ["king", [60], [60]],
	628: ["druid", [0], [30]],
	554: ["valkyrie", [70], [70]],
	555: ["wallace", [140], [100]],
	556: ["thor", [105], [140]],
	557: ["duplicate", [210], [70]],  # High elf
	612: ["duplicate", [210], [30]], 670: ["duplicate", [210], [30]],  # Anubis warriors
	608: ["hit", [120], [30]], 610: ["hit", [120], [30]],  # Footman and horseman level 5
	609: ["shoot", [120], [30]],  # Archer level 5
	652: ["merlin", [140], [100]], 691: ["merlin", [140], [100]],  # Red Merlins
}
## The units that the auras of the Valkyrie and of Wallace help: peasants,
## clerics, footmen, horsemen and archers.
const AURA_SUBCATS: Array[int] = [71, 72, 78, 79, 80]
const SUBCAT_EAGLE := 86
const WALLACE_AURA_FRAMES := 140
const DUPLICATE_FRAMES := 600
const MERLIN_SPELL_FRAME := 1

var _kind := ""
var _duplicating := false  # specialStatus of the client.


func configure(item_id: int) -> void:
	var data: Array = UNITS[item_id]
	_kind = data[0]
	special_intervals.assign(data[1])
	special_durations.assign(data[2])
	ranged_melee = _kind == "juggernaut"


func on_attack(sim: BattleSim, fighter: BattleFighter) -> bool:
	if in_special(fighter, 0):
		_special(sim, fighter)
		return true
	if in_special(fighter, 1):
		# Only the Juggernaut has a second special attack.
		arrow_storm(sim, fighter, MagicParticles.FIRE_METEOR, 20)
		return true
	if _kind == "thor" and fighter.target.is_unit() and fighter.attack_range <= 1:
		sim.push_in_air(fighter.target, fighter, 2)
	return true


func _special(sim: BattleSim, fighter: BattleFighter) -> void:
	match _kind:
		"wave_15":
			_wave(sim, fighter, 15)
		"wave_25":
			_wave(sim, fighter, 25)
		"wave_whirl":
			_wave(sim, fighter, 25)
			_whirl(sim, fighter)
		"whirl":
			_whirl(sim, fighter)
		"juggernaut":
			_wave(sim, fighter, 10)
			_whirl(sim, fighter)
		"hell_archer":
			arrow_storm(sim, fighter, MagicParticles.FIRE_ARROW, 10)
		"fire_stream":
			_stream(sim, fighter, MagicParticles.FIRE_RED, 4)
		"stream":
			_stream(sim, fighter, MagicParticles.FIRE_BLUE, 4)
		"king":
			_stream(sim, fighter, MagicParticles.FIRE_RED, 5)
		"druid":
			sim.particle(fighter, fighter.target.tile, MagicParticles.ROOT, fighter.attack, 0)
		"valkyrie":
			for unit in _aura_units(sim, fighter, 2):
				sim.heal(unit, fighter.attack, fighter)
				sim.particle(fighter, unit.tile, MagicParticles.STARS, 0, 0, func(_a: BattleFighter, _t: BattleFighter, _v: int) -> void: pass)
		"wallace":
			wallace_aura(sim, fighter)
		"thor":
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var chance := sim.rng.randf()
					if chance < 0.3:
						sim.particle(fighter, fighter.tile + Vector2i(dx, dy), MagicParticles.LIGHTNING, fighter.attack, roundi(chance * 120))
		"duplicate":
			_duplicate(sim, fighter)
		"hit":
			sim.receive_attack(fighter.target, fighter.attack, fighter)
		"shoot":
			sim.shoot(fighter, fighter.target, "", fighter.attack)
		"merlin":
			var tile := fighter.target.tile
			var damage := int(fighter.def.attack * 1.5)
			sim.after(MERLIN_SPELL_FRAME, func() -> void:
				for item in enemies_near(sim, fighter, tile, 0, 1):
					sim.receive_attack(item, damage, fighter if not fighter.dead else null))


## An expansive wave on the tile of the fighter after delay frames: the units
## of the other side within 2 tiles (not bosses or eagles) are stunned and take
## half its attack (attackSpecialElephant).
func _wave(sim: BattleSim, fighter: BattleFighter, delay: int) -> void:
	var damage := fighter.attack / 2
	sim.particle(fighter, fighter.tile, MagicParticles.EXPANSIVE_WAVE, damage, delay, func(_a: BattleFighter, _t: BattleFighter, value: int) -> void:
		if fighter.dead:
			return
		for unit in enemy_units_near(sim, fighter, fighter.tile, 2, 20):
			if unit.def.subcat_functional in [BattleSim.SUBCAT_BOSS, SUBCAT_EAGLE]:
				continue
			sim.stun(unit)
			sim.receive_attack(unit, value, fighter), true)


## The items of the other side on the four diagonal tiles next to the fighter
## take its attack (attackSpecialWhirlwind).
func _whirl(sim: BattleSim, fighter: BattleFighter) -> void:
	for step in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		for item in enemies_near(sim, fighter, fighter.tile + step, 0, 1):
			if item.is_valid_target():
				sim.receive_attack(item, fighter.attack, fighter)


## count magic particles of type in a line in front of the fighter, 10 frames
## one after the other, each with its attack (attackSpecialStream).
func _stream(sim: BattleSim, fighter: BattleFighter, type: int, count: int) -> void:
	var step: Vector2i = TILE_STEPS[direction(fighter)]
	for i in count:
		sim.particle(fighter, fighter.tile + step * (i + 1), type, fighter.attack, 10 * i)


## The own units of AURA_SUBCATS within range tiles.
static func _aura_units(sim: BattleSim, fighter: BattleFighter, range_tiles: int) -> Array[BattleFighter]:
	return sim.items_near(fighter.tile, range_tiles, 20, fighter.team, true, func(item: BattleFighter) -> bool:
		return item.is_unit() and not item.dead and item.def.subcat_functional in AURA_SUBCATS)


## Up to 10 own units within 2 tiles attack 10 frames faster (at most every
## 10 frames) for frames frames (MAGIC_TYPE_AURA_WALLACE; the Archangel aura
## is the same for 220 frames).
static func wallace_aura(sim: BattleSim, fighter: BattleFighter, frames := WALLACE_AURA_FRAMES) -> void:
	var units := _aura_units(sim, fighter, 2).slice(0, 10)
	for unit in units:
		if unit != fighter:
			unit.attack_interval = maxi(10, unit.def.attack_interval - 10)
	sim.after(frames, func() -> void:
		for unit in units:
			if not unit.dead:
				unit.attack_interval = unit.def.attack_interval)


## Two copies of the fighter come next to it for 600 frames, once at a time
## (MAGIC_TYPE_DUPLICATE). The copies do not make copies.
func _duplicate(sim: BattleSim, fighter: BattleFighter) -> void:
	if _duplicating:
		return
	_duplicating = true
	var copies: Array[BattleFighter] = []
	for i in 2:
		var copy := sim.spawn(fighter.def, fighter.tile, fighter.team)
		if copy != null:
			if copy.ability is HeroAbility:
				copy.ability._duplicating = true
			copies.append(copy)
	sim.after(DUPLICATE_FRAMES, func() -> void:
		for copy in copies:
			if not copy.dead:
				sim.remove_item(copy)
		_duplicating = false)
