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
## spells.json.

const DEFAULT_ATTACK_FRAME := 10
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


## The spell for one battle, or null when the port does not have it. The
## configuration has 15 spells; the client also has Thunder (1), which the
## configuration does not list.
## labels: the frame labels of the graphic of the spell, from spells.json.
static func create(spell: GameConfig.SpellDef, config: GameConfig, labels: Dictionary) -> BattleSpell:
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
	result._attack_frame = int(labels.get("attack", DEFAULT_ATTACK_FRAME))
	return result


## Reads spells.json of the importer: img_name of a spell -> {label: frame}.
## Returns null and reports an error when the file is missing or not valid.
static func read_labels(path: String) -> Variant:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Cannot read the frame labels of the spells in '%s'. Import the files again." % path)
		return null
	for img_name: Variant in data:
		if not data[img_name] is Dictionary or data[img_name].values().any(func(frame: Variant) -> bool: return GameConfig.to_int(frame) == null):
			push_error("The frame labels of '%s' in '%s' are not correct." % [img_name, path])
			return null
	return data


## The spell book shows the other spells with the sign "Not in the port yet".
static func is_in_port(spell_id: int) -> bool:
	return not spell_id in NOT_IN_PORT


## Casts the spell on tile with level, the level that Village.use_spell() gives.
func cast(_sim: BattleSim, _tile: Vector2i, _level: int) -> void:
	pass


## The side of the square that the spell marks at this level.
func area(level: int) -> int:
	return def.areas[level - 1]


## Runs action like a particle of the client: the particle appears after delay
## frames (at least 1, as it counts from the next frame) and acts attack_frame
## frames later.
func _particle(sim: BattleSim, delay: float, attack_frame: int, action: Callable) -> void:
	sim.after(maxi(ceili(delay), 1) + attack_frame, action)


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
