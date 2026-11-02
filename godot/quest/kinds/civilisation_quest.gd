class_name CivilisationQuest
extends QuestBattle
## The civilisation islands (QuestIslaCivilizacion of the client). Only the
## scenery (and on Atlantis also walls and decorations) is neutral. The player
## wins when the last town hall falls. The units of the map do not join the
## player, but the client counts QuestIsland.free_units as units of the
## player. Copies for more stars are not made of animals.


func counts_town_halls() -> bool:
	return true


func counter_texts() -> Array[String]:
	var left := enemies_left()
	var text := _config.text("QUEST_CIVILIZACION_HQ_SINGULAR") if left == 1 else _config.text("QUEST_CIVILIZACION_HQ_PLURAL").replace("#0#", str(left))
	return [_config.text("QUEST_CIVILIZACION_ENEMIGOS"), text]


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.race == "n" or def.subcat_functional == SUBCAT_SCENERY or def.subcat_functional in island.neutral_subcats:
		return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.ENEMY


func _gives_map_units() -> bool:
	return false


func _on_placed(item: BattleFighter) -> void:
	if item.team == BattleFighter.Team.ENEMY and item.def.subcat_functional == SUBCAT_TOWN_HALL:
		_enemies_left += 1


func _copies(enemy: BattleFighter) -> bool:
	return not enemy.def.subcat_functional in NOT_COPIED_SUBCATS


func _on_copied(original: BattleFighter, _copy: BattleFighter) -> void:
	if _pays_gold(original):
		_gold_units += 1


func _on_enemy_died(item: BattleFighter) -> void:
	if item.def.subcat_functional != SUBCAT_TOWN_HALL:
		return
	_enemies_left -= 1
	changed.emit()
	if _enemies_left <= 0:
		_win()
