class_name HardQuest
extends QuestBattle
## The hard islands (QuestIslaHardGeneric of the client) and the god islands
## (QuestIslaGodGeneric).
##
## - Decorations, treasures and scenery are neutral; all other items are
##   enemies, also trees and rocks.
## - The player wins when the last enemy unit is dead.
## - Hard islands: each enemy that dies can drop an item of the Bahamut
##   collections (the HARDCORE source).
## - God islands: the experience can be higher (GameConfig.quest_max_xp_god).
##   The client counts the enemies that pay gold only among the copies for the
##   stars, so with 1 star the enemies pay no gold, and with more stars every
##   enemy that pays gold gets the share of a copy. The port does the same.
## - Some of these islands take a team, see QuestIsland.team.


func recovered_percent() -> int:
	return _config.quest_units_back_hardcore


func max_xp() -> int:
	return _config.quest_max_xp_god if island.family == QuestIsland.Family.GOD else _config.quest_max_xp


func _team_of(def: GameConfig.ItemDef, _tile: Vector2i) -> BattleFighter.Team:
	if def.subcat_functional in [SUBCAT_DECORATION, SUBCAT_TREASURE, SUBCAT_SCENERY]:
		return BattleFighter.Team.NEUTRAL
	return BattleFighter.Team.ENEMY


func _place_map(map: Village) -> void:
	super(map)
	if island.family == QuestIsland.Family.GOD:
		_gold_units = 0


## The client uses the HARDCORE source for all drops on these islands. A boss
## drops as in all quests; on a hard island every enemy also drops, so a boss
## there has two chances.
func _drop_source(item: BattleFighter) -> int:
	return Collections.Source.HARDCORE if item.def.subcat_functional == SUBCAT_BOSS else -1


func _on_enemy_died(item: BattleFighter) -> void:
	if island.family == QuestIsland.Family.HARD:
		_drop(Collections.Source.HARDCORE)
	super(item)
