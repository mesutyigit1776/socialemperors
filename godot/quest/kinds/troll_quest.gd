class_name TrollQuest
extends QuestBattle
## The troll islands (QuestIslaTrollsGeneric of the client). All units and
## buildings are enemies; the treasure, decorations and scenery are neutral.
## When the last enemy unit is dead, the treasure opens; the player wins when
## they collect it. The treasure can drop an item of a collection.

var _treasure: BattleFighter
var _treasure_open := false


func is_treasure(item: BattleFighter) -> bool:
	return item == _treasure


func is_treasure_open() -> bool:
	return _treasure_open


func is_collectable(item: BattleFighter) -> bool:
	return item == _treasure and _treasure_open


## The player collects the open treasure and wins.
func collect(item: BattleFighter) -> bool:
	if item != _treasure or not _treasure_open or _finished:
		return false
	_treasure_open = false
	_treasure = null
	sim.remove_item(item)
	_drop(_loot_source(item.def))
	_win()
	return true


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.race == "n" or def.subcat_functional in [SUBCAT_SCENERY, SUBCAT_TREASURE, SUBCAT_DECORATION] or def.subcat_functional in island.neutral_subcats:
		return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.ENEMY


func _on_placed(item: BattleFighter) -> void:
	super(item)
	if item.def.subcat_functional == SUBCAT_TREASURE:
		_treasure = item


func _on_enemy_died(item: BattleFighter) -> void:
	if item.is_unit():
		_enemies_left -= 1
		changed.emit()
	if _enemies_left <= 0 and _treasure != null and not _treasure_open:
		_treasure_open = true
		treasure_opened.emit()
		collectable_opened.emit(_treasure)
