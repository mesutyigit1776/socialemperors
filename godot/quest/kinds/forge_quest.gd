class_name ForgeQuest
extends QuestBattle
## The forge islands of the Island Forge (QuestCollectable1 to 5 of the
## client). The rules of QuestBattle apply, with these differences:
## - The quest has no gold of its own. Each enemy that dies (a unit or a
##   building) gives gold and experience by its price (_kill_reward()), except
##   on the first forge island, which gives nothing.
## - The counter shows the skeletons that are alive.
## - The quest ends 7 seconds after a win and 3 seconds after a loss.
## - The win does not open the next island of the campaign.
## A win with more stars than before gives a forge item (IslandForge.quest_won()).

const FIRST_ISLAND := "100000055"
const SUBCAT_WALL := 221
const WIN_SECONDS := 7
const LOSS_SECONDS := 3


func counter_texts() -> Array[String]:
	var left := enemies_left()
	var text := _config.text("QUEST_ESQUELETOS_VIVOS_SINGULAR") if left == 1 else _config.text("QUEST_ESQUELETOS_VIVOS_PLURAL").replace("#0#", str(left))
	return [_config.text("QUEST_ESQUELETOS_VIVOS"), text]


func result() -> Dictionary:
	var data := super()
	data["set_unlocked_index"] = 0
	return data


## [gold, experience] of an enemy that dies: half of half its gold price, or
## of a quarter of its stone price, for an enemy that attacks; 2 for other
## enemies. The experience is 5 % of the gold, rounded up, and at least 1
## except for walls.
static func kill_reward(def: GameConfig.ItemDef) -> Vector2i:
	var value := 0
	if def.attack > 0 and def.cost_type == "g":
		value = def.cost / 2
	elif def.attack > 0 and def.cost_type == "s":
		value = def.cost / 4
	if value == 0:
		value = 5
	var gold := int(value * 0.5)
	var xp := ceili(gold * 0.05)
	if xp == 0 and def.subcat_functional != SUBCAT_WALL:
		xp = 1
	return Vector2i(gold, xp)


func _divide_reward() -> void:
	_gold_per_kill = 0
	_gold_on_win = 0


func _gives_reward(_item: BattleFighter) -> bool:
	return false


func _on_enemy_died(item: BattleFighter) -> void:
	if island.id != FIRST_ISLAND:
		var reward := kill_reward(item.def)
		gold += reward.x
		xp += reward.y
		changed.emit()
	super(item)


func _end_soon(_seconds := 1) -> void:
	super(WIN_SECONDS if _won else LOSS_SECONDS)
