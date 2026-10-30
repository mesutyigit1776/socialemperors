class_name QuestBook
extends RefCounted
## The quest islands of a village and the rules for starting a quest, as the
## island window and the start window of the client apply them.
##
## - The islands open one after the other in GameConfig.quest_order: the
##   player can start the islands up to Village.unlocked_quest_index(). Some
##   islands also need a level (GameConfig.quest_min_levels), and some are
##   always open (GameConfig.quests_always_open).
## - An island that the port does not have yet (see QuestIsland) cannot start,
##   also when it is open.
## - The player chooses 1 to 3 stars: at most one star more than they won on
##   the island before.
## - The army is all fighting units on the map (Village.quest_army()).

## THE QUEST LIMIT. This is a change from the original game.
##
## The player can start QUESTS_PER_WINDOW quests in a row, or
## QUESTS_PER_WINDOW_ODIN when the Odin statue (item ODIN_STATUE) is on the
## map. A start counts while it is less than QUEST_WINDOW_SECONDS before the
## next newer start (or before now, for the newest start). So after
## QUEST_WINDOW_SECONDS without a new start, the player can again start the
## full number of quests.
##
## The original game waits 6 hours (6 * 3600 seconds). The owner of the port
## chose 2 hours.
## - To make the wait longer or shorter, change QUEST_WINDOW_SECONDS.
## - To remove the limit, set QUEST_LIMIT_ENABLED to false.
## The save keeps the start times either way (Village.start_quest()), so a
## change here also applies to the quests that the player already started.
const QUEST_LIMIT_ENABLED := true
const QUEST_WINDOW_SECONDS := 2 * 3600
const QUESTS_PER_WINDOW := 3
const QUESTS_PER_WINDOW_ODIN := 4
const ODIN_STATUE := 366

const MAX_STARS := 3

## Why a quest cannot start.
enum Refusal { NONE, LOCKED, NOT_IN_PORT, NO_ARMY, LIMIT_REACHED }

var _village: Village
var _config: GameConfig


func _init(village: Village, config: GameConfig) -> void:
	_village = village
	_config = config


## The quest ids of the islands, in the order of the island list.
func islands() -> Array[String]:
	return _config.quest_order


## The island is open in the game: the player reached it and has its level.
func is_open(quest_id: String) -> bool:
	if quest_id in _config.quests_always_open:
		return true
	var index := _config.quest_order.find(quest_id)
	return index >= 0 and index <= _village.unlocked_quest_index() and not is_level_locked(quest_id)


## The island needs a higher level than the player has.
func is_level_locked(quest_id: String) -> bool:
	return _village.get_level() < int(_config.quest_min_levels.get(quest_id, 0))


func min_level(quest_id: String) -> int:
	return int(_config.quest_min_levels.get(quest_id, 0))


## The stars that the player won on the island: 0 to MAX_STARS.
func stars(quest_id: String) -> int:
	return _village.quest_rank(quest_id)


## The place in islands() of the last island that the player reached.
func current_island() -> int:
	return _village.unlocked_quest_index()


## All stars that the player won on the islands of the list.
func won_stars() -> int:
	var total := 0
	for quest_id in islands():
		total += _village.quest_rank(quest_id)
	return total


## The most stars that the player can choose for the island.
func max_stars(quest_id: String) -> int:
	return mini(_village.quest_rank(quest_id) + 1, MAX_STARS)


func refusal(quest_id: String, now: int) -> Refusal:
	if not is_open(quest_id):
		return Refusal.LOCKED
	if not QuestIsland.is_in_port(quest_id):
		return Refusal.NOT_IN_PORT
	if _village.quest_army().is_empty():
		return Refusal.NO_ARMY
	if quests_left(now) <= 0:
		return Refusal.LIMIT_REACHED
	return Refusal.NONE


## The number of quests that the player can start now, see QUEST_LIMIT_ENABLED.
func quests_left(now: int) -> int:
	if not QUEST_LIMIT_ENABLED:
		return quests_per_window()
	var times := _village.quest_start_times()
	times.sort()
	times.reverse()
	var counted := 0
	var later := now
	for time in times:
		if later - time >= QUEST_WINDOW_SECONDS:
			break
		counted += 1
		later = time
	return maxi(quests_per_window() - counted, 0)


func quests_per_window() -> int:
	var has_statue := _village.items.any(func(placed: Village.PlacedItem) -> bool: return placed.item_id == ODIN_STATUE)
	return QUESTS_PER_WINDOW_ODIN if has_statue else QUESTS_PER_WINDOW


## The seconds until the player can start quests again, when quests_left() is 0.
func seconds_to_next_quest(now: int) -> int:
	var times := _village.quest_start_times()
	if times.is_empty():
		return 0
	return maxi(times.max() + QUEST_WINDOW_SECONDS - now, 0)
