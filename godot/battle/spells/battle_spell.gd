class_name BattleSpell
extends RefCounted
## A spell of the spell book in a battle, as the spell classes of the client
## cast it. Each battle makes its own spells with create(), because some
## spells keep data between casts.
##
## The player casts a spell on a tile. For the client this is the corner of
## the marked square with the largest x and y: the square covers area tiles to
## the left and up from it. Each spell uses the tile in its own way, see the
## subclasses.
##
## The client shows each effect of a spell as a particle: a graphic that comes
## after a delay and acts at the frame of its graphic with the label "attack"
## (DEFAULT_ATTACK_FRAME without a label). The importer writes these labels to
## spells.json. The spell tells a view about each particle, see particle_shown.

## A particle of the spell appears. look: "scale" and "alpha" of the graphic,
## "frames": the frames until it fades out for FADE_FRAMES, or -1 when it
## stays, "depth": "below" the items, "mixed" with them or "above" them, and
## "loop_from": see read_graphics(). The view plays the graphic; it does not
## change the battle.
signal particle_shown(graphic: String, tile: Vector2i, look: Dictionary)

const DEFAULT_ATTACK_FRAME := 10
## The client fades a particle out in 1 second, by default 1 second after it acts.
const FADE_FRAMES := 30
const DEFAULT_STAY_FRAMES := 30
## Spells that the port does not have yet. Instant Limit fills the limit bars
## of units, which come with their special abilities (battle stages 5 and 6).
const NOT_IN_PORT: Array[int] = [INSTANT_LIMIT]
const INSTANT_LIMIT := 13
## Items that the client protects from most spells.
const SUBCAT_TOWN_HALL := 135
const SUBCAT_TREASURE := 811
const SUBCAT_ACTIVATOR := 812

var def: GameConfig.SpellDef
var _config: GameConfig
var _attack_frame: int  # The frame of the graphic with the label "attack".
var _loop_from: Variant  # See read_graphics().


## The spell for one battle, or null when the port does not have it. The
## configuration has 15 spells; the client also has Thunder (1), which the
## configuration does not list.
## graphic: how the graphic of the spell plays, from spells.json, see read_graphics().
static func create(spell: GameConfig.SpellDef, config: GameConfig, graphic: Dictionary) -> BattleSpell:
	var result: BattleSpell
	match spell.id:
		2:
			result = FireHavocSpell.new()
		3:
			result = HailSpell.new()
		4:
			result = FrostbiteSpell.new()
		5:
			result = SacredRainSpell.new()
		6:
			result = SummonSpell.new(SummonSpell.GOLEM)
		7:
			result = HellAbyssSpell.new()
		8:
			result = PoisonFloodSpell.new()
		9:
			result = EtherShieldSpell.new()
		10:
			result = SummonSpell.new(SummonSpell.YETI)
		11:
			result = ColossusSpell.new()
		12:
			result = DragonSpell.new()
		14:
			result = DoubleStatSpell.new(DoubleStatSpell.Stat.SPEED)
		15:
			result = DoubleStatSpell.new(DoubleStatSpell.Stat.RANGE)
		16:
			result = BlackHoleSpell.new()
		_:
			return null
	result.def = spell
	result._config = config
	result._attack_frame = int(graphic.get("labels", {}).get("attack", DEFAULT_ATTACK_FRAME))
	result._loop_from = graphic.get("loop_from")
	return result


## Reads spells.json of the importer: img_name of a spell -> {"labels": {label:
## frame}, "loop_from": frame or null}. Returns null and reports an error when
## the file is missing or not valid.
static func read_graphics(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Cannot read how the spell graphics play from '%s'. Import the files again." % path)
		return null
	for img_name: Variant in data:
		var entry: Variant = data[img_name]
		var valid: bool = entry is Dictionary and entry.get("labels") is Dictionary \
				and entry["labels"].values().all(func(frame: Variant) -> bool: return GameConfig.to_int(frame) != null) \
				and (entry.get("loop_from") == null or GameConfig.to_int(entry["loop_from"]) != null)
		if not valid:
			push_error("The graphic of '%s' in '%s' is not correct. Import the files again." % [img_name, path])
			return null
	return data


## The spell book shows the other spells with the sign "Not in the port yet".
static func is_in_port(spell_id: int) -> bool:
	return not spell_id in NOT_IN_PORT


## The texts of the spell book for the levels 1 to 3 of spell, as the client
## builds them from its numbers.
static func describe(spell: GameConfig.SpellDef, config: GameConfig) -> Array[String]:
	var created := create(spell, config, {})
	if created != null:
		return created.descriptions(config)
	var texts: Array[String] = []
	for level in range(1, GameConfig.SPELL_LEVELS + 1):
		texts.append(_fill(config, "SPELL_FULL_LIMIT_DESCRIPTION" if spell.id == INSTANT_LIMIT else "", [spell.areas[level - 1], spell.areas[level - 1]]))
	return texts


## See describe().
func descriptions(_config: GameConfig) -> Array[String]:
	return ["", "", ""]


## A text of the client with its places #0#, #1# and so on filled.
static func _fill(config: GameConfig, key: String, values: Array) -> String:
	if key.is_empty():
		return ""
	var text := config.text(key)
	for i in values.size():
		text = text.replace("#%d#" % i, str(values[i]))
	return text


## The descriptions of a spell whose text has the area and one number for each level.
func _area_texts(config: GameConfig, key: String, numbers: Array) -> Array[String]:
	var texts: Array[String] = []
	for level in range(1, GameConfig.SPELL_LEVELS + 1):
		var values := [area(level), area(level)]
		if not numbers.is_empty():
			values.append(numbers[level - 1])
		texts.append(_fill(config, key, values))
	return texts


## Casts the spell on tile with level, the level that Village.use_spell() gives.
func cast(_sim: BattleSim, _tile: Vector2i, _level: int) -> void:
	pass


## The side of the square that the spell marks at this level.
func area(level: int) -> int:
	return def.areas[level - 1]


## Runs action like a particle of the client: the particle appears on tile
## after delay frames (at least 1, as it counts from the next frame) and acts
## attack_frame frames later. look: see particle_shown; without "frames" the
## particle fades DEFAULT_STAY_FRAMES after it acts.
func _particle(sim: BattleSim, tile: Vector2i, delay: float, attack_frame: int, action: Callable, look: Dictionary = {}) -> void:
	var spawn := maxi(ceili(delay), 1)
	var shown := look.duplicate()
	if not shown.has("frames"):
		shown["frames"] = attack_frame + DEFAULT_STAY_FRAMES
	if not shown.has("depth"):
		shown["depth"] = "below"
	shown["loop_from"] = _loop_from
	sim.after(spawn, func() -> void: particle_shown.emit(def.img_name, tile, shown))
	sim.after(spawn + attack_frame, action)


## Bosses, town halls, treasures and activators are safe from most spells.
static func _is_protected(item: BattleFighter) -> bool:
	return item.def.subcat_functional in [BattleSim.SUBCAT_BOSS, SUBCAT_TOWN_HALL, SUBCAT_TREASURE, SUBCAT_ACTIVATOR]


## The tiles of the client loops "from tile - area to tile": area + 1 tiles on each side.
static func _square_from_corner(tile: Vector2i, area_tiles: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(tile.y - area_tiles, tile.y + 1):
		for x in range(tile.x - area_tiles, tile.x + 1):
			tiles.append(Vector2i(x, y))
	return tiles


## The item on tile when it is on team, else null.
static func _item_of(sim: BattleSim, tile: Vector2i, team: BattleFighter.Team) -> BattleFighter:
	var item := sim.fighter_at(tile)
	return item if item != null and item.team == team else null
