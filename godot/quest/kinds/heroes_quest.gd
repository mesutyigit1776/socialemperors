class_name HeroesQuest
extends QuestBattle
## The Heroes island (QuestIslaHeroes of the client). The enemy units stand
## behind walls in AREAS areas, each with a door. The walls and the doors are
## neutral; the towers are enemies. When the last unit of an area is dead, its
## door opens. The player wins when all enemy units are dead.
##
## The copies for more stars, and the units of the player that the monks of
## the island convert, are in no area. The client then counts their death in
## area 0, so the door of area 0 can open before its own units are dead; the
## port does the same.

## The areas: [left, top, right, bottom] tiles, included.
const AREAS: Array[Rect2i] = [
	Rect2i(54, 75, 18, 22), Rect2i(19, 74, 18, 22), Rect2i(19, 50, 19, 16), Rect2i(54, 50, 20, 16),
	Rect2i(54, 24, 18, 17), Rect2i(19, 24, 17, 17), Rect2i(30, 1, 31, 16),
]
const SUBCAT_TOWER := 211
const SUBCAT_DOOR := 222

var _doors: Array = [null, null, null, null, null, null, null]
var _area_units: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var _area_of := {}  # Enemy unit -> its area.


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.is_unit() or def.subcat_functional == SUBCAT_TOWER:
		return BattleFighter.Team.ENEMY
	return BattleFighter.Team.NEUTRAL


func _on_placed(item: BattleFighter) -> void:
	var area := _area(item.tile)
	if item.is_unit():
		_enemies_left += 1
		if area >= 0:
			_area_units[area] += 1
			_area_of[item] = area
	elif item.def.subcat_functional == SUBCAT_DOOR and area >= 0:
		_doors[area] = item


func _on_enemy_died(item: BattleFighter) -> void:
	var area: int = _area_of.get(item, 0)
	_area_units[area] -= 1
	if _area_units[area] == 0 and _doors[area] != null:
		sim.open_door(_doors[area])
	# A unit of the player that a monk converted does not count as an enemy.
	if item.is_unit() and not item.converted:
		_enemies_left -= 1
		changed.emit()
	if _enemies_left <= 0:
		_win()


## The area that contains tile, or -1.
func _area(tile: Vector2i) -> int:
	for i in AREAS.size():
		if AREAS[i].has_point(tile):
			return i
	return -1


func _end_soon(seconds := 1) -> void:
	# The client waits 3 seconds after a loss on this island.
	super(3 if _player_units == 0 and not _won else seconds)
