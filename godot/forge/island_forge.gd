class_name IslandForge
extends RefCounted
## The Island Forge, a timed event of the client (CollectGameManager,
## PopupIslandForge). While the event runs, the forge island (building 1530)
## stands in the village of the player, and the player collects six forge
## items. At the item counts of GameConfig.collect_game "prizes" the player
## can take a dragon. After the last prize, or at the end of the event, the
## island goes away.
##
## The items come from these places, or the player buys them for cash:
## - QUEST: a win with more stars on one of the five forge islands (QUEST_IDS).
## - TROLLS: by chance, when an enemy unit dies in the village.
## - COLLECT: by chance, when the player collects a mill or mine; the chance
##   grows with its work time.
## - PVP: by chance, when an enemy unit dies in an attack on another player.
## - INVITE: friends that accept an invitation. The port cannot invite, so the
##   player buys these, as on the server. The number is the number of friends
##   of the viral offer "2", not the counter of the item.
## - DAILY: the hammer button of the window, after the wait of the item.
##
## The event time: the server writes the date of server_config.json into the
## configuration ("starts_at" and "duration"). The setting SETTING_DATE
## ("YYYY-MM-DD", UTC) and SETTING_DAYS of the settings file replace them, so
## that a player can start the event without a new import. The event runs
## after the start and before the end, as in the client.
##
## Village keeps the save values; this class has the rules and the prices.

## The item ids of the client, which are also the types of the items.
const QUEST := 1
const TROLLS := 2
const COLLECT := 3
const PVP := 4
const INVITE := 5
const DAILY := 6
## The forge islands, in the order in which they open (CollectGameManager.questsIDs).
const QUEST_IDS: Array[String] = ["100000055", "100000054", "100000053", "100000052", "100000051"]
const SETTING_SECTION := "events"
const SETTING_DATE := "island_forge_date"
const SETTING_DAYS := "island_forge_days"
const DEFAULT_DAYS := 7
## The client finds no items before this level.
const MIN_LEVEL := 2
## The chances of the client in percent, before the factor of missing items
## (see roll()). A collect gives work seconds / COLLECT_SECONDS.
const TROLLS_CHANCE := 0.25
const PVP_CHANCE := 0.333
const COLLECT_SECONDS := 8 * 3600

var start: int
var end: int
var _game: Dictionary
var _village: Village


## game: GameConfig.collect_game, not empty.
func _init(game: Dictionary, village: Village, start_time: int, end_time: int) -> void:
	_game = game
	_village = village
	start = start_time
	end = end_time


## The forge of the village with the event time of the settings file, or
## null when the configuration has no collect game.
static func from_settings(config: GameConfig, village: Village, settings_path: String) -> IslandForge:
	if config.collect_game.is_empty():
		return null
	var time := event_time(config.collect_game, settings_path)
	return IslandForge.new(config.collect_game, village, time.x, time.y)


## [start, end] of the event.
static func event_time(game: Dictionary, settings_path: String) -> Vector2i:
	var settings := ConfigFile.new()
	var date := ""
	var days: Variant = DEFAULT_DAYS
	if settings.load(settings_path) == OK:
		date = str(settings.get_value(SETTING_SECTION, SETTING_DATE, ""))
		days = settings.get_value(SETTING_SECTION, SETTING_DAYS, DEFAULT_DAYS)
	if date.is_empty():
		return Vector2i(game["start"], game["start"] + game["duration"])
	var begin := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	if begin <= 0 or not (days is int or days is float):
		push_error("Settings file '%s': [%s] %s must be a date YYYY-MM-DD and %s a number of days." % [settings_path, SETTING_SECTION, SETTING_DATE, SETTING_DAYS])
		return Vector2i(game["start"], game["start"] + game["duration"])
	return Vector2i(begin, begin + int(days) * 86400)


func running(now: int) -> bool:
	return now > start and now < end


## The event runs and has prizes ("active" of the client).
func active(now: int) -> bool:
	return running(now) and not _game["prizes"].is_empty()


## The island stands in the village, and the window and its icon show.
func island_shown(now: int) -> bool:
	return active(now) and prizes_left()


func items() -> Array:
	return _game["items"]


func item(item_id: int) -> Dictionary:
	for entry: Dictionary in _game["items"]:
		if entry["id"] == item_id:
			return entry
	return {}


func amount(item_id: int) -> int:
	if item_id == INVITE:
		return mini(_village.forge_friends(), item(item_id)["required"])
	return _village.forge_item(item_id)["counter"]


func complete(item_id: int) -> bool:
	return item(item_id)["required"] > 0 and amount(item_id) >= item(item_id)["required"]


func progress() -> int:
	var sum := 0
	for entry: Dictionary in _game["items"]:
		sum += amount(entry["id"])
	return sum


func total() -> int:
	var sum := 0
	for entry: Dictionary in _game["items"]:
		sum += entry["required"]
	return sum


## Seconds until the item can come again, or 0. The time of an item is the
## time when the player last found it (or started a forge island).
func wait_left(item_id: int, now: int) -> int:
	var cooldown: int = item(item_id)["cooldown"]
	var last: int = _village.forge_item(item_id)["timestamp"]
	if cooldown == 0 or now - last >= cooldown:
		return 0
	return last + cooldown - now


## The cash for one more of the item: "cost", but "last_cost" for the last one.
func price(item_id: int) -> int:
	var entry := item(item_id)
	if entry["cost"] == entry["last_cost"] or amount(item_id) < entry["required"] - 1:
		return entry["cost"]
	return entry["last_cost"]


## The price of all missing items, with a discount by the part that is
## missing. The formula is the one of the client and of the server (event_system.py
## hellforge_buy_all_price). The test for the last item in it is never true
## there either, so each item adds its "last_cost" once.
func pack_price() -> int:
	var sum := 0
	for entry: Dictionary in _game["items"]:
		var cost: int = entry["cost"] if entry["cost"] != 0 else entry["speedup_cost"]
		var last: int = entry["last_cost"] if entry["last_cost"] != 0 else entry["speedup_cost"]
		var have := amount(entry["id"])
		sum += (entry["required"] - have - 1) * cost + (0 if entry["required"] == have - 1 else last)
	var missing := float(total() - progress()) / total()
	return ceili(sum - sum * (_game["discount"] / 100.0) * missing)


## [items needed, unit id] of each prize.
func prizes() -> Array:
	return _game["prizes"]


func prize_given(unit_id: int) -> bool:
	return unit_id in _village.forge_prizes_given()


func prizes_left() -> bool:
	return _game["prizes"].any(func(prize: Array) -> bool: return not prize_given(prize[1]))


## A prize that the player can take now. The client then opens the window.
func prize_ready() -> bool:
	return _game["prizes"].any(func(prize: Array) -> bool: return progress() >= prize[0] and not prize_given(prize[1]))


## The chance of the client (CollectGameManager.generate): a roll from 0 to 100
## against chance * 3 ^ (missing / 7) + bonus. QUEST and DAILY do not roll.
func roll(item_id: int, now: int, rng: RandomNumberGenerator, chance: float, bonus: float = 0.0) -> bool:
	if not active(now) or _village.get_level() < MIN_LEVEL or complete(item_id):
		return false
	var limit := pow(3.0, float(item(item_id)["required"] - amount(item_id)) / 7.0) * chance + bonus
	return rng.randf() * 100.0 <= limit and limit > 0


## One more of the item, found (not bought). False when the item is complete.
func add(item_id: int, now: int) -> bool:
	if amount(item_id) >= item(item_id)["required"]:
		return false
	_village.add_forge_item(item_id, 0, now)
	return true


## An enemy unit died: in the village (pvp false) or in an attack on another
## player. The item comes by chance after the wait of the event setting.
func enemy_killed(unit: GameConfig.ItemDef, pvp: bool, now: int, rng: RandomNumberGenerator) -> bool:
	if unit == null or not unit.is_unit():
		return false
	var item_id := PVP if pvp else TROLLS
	var cooldown: int = _game["pvp_cooldown"] if pvp else _game["trolls_cooldown"]
	if now - _village.forge_item(item_id)["timestamp"] <= cooldown:
		return false
	var bonus := 0.0
	if pvp:
		bonus = floorf(unit.life / 1000.0) * _game["pvp_life_multiplier"]
	return roll(item_id, now, rng, PVP_CHANCE if pvp else TROLLS_CHANCE, bonus) and add(item_id, now)


## The player collected a mill or mine with this work time.
func collected(work_minutes: int, now: int, rng: RandomNumberGenerator) -> bool:
	return work_minutes > 0 and roll(COLLECT, now, rng, work_minutes * 60.0 / COLLECT_SECONDS) and add(COLLECT, now)


## The player won a forge island with these stars; old_stars is the rank
## before the win.
func quest_won(quest_id: String, stars: int, old_stars: int, now: int) -> bool:
	return quest_id in QUEST_IDS and stars > old_stars and add(QUEST, now)


## The first forge island is always open; each other one opens after a win
## on the one before it. All are closed when the event does not run.
func quest_open(quest_id: String, now: int) -> bool:
	var index := QUEST_IDS.find(quest_id)
	if index < 0 or not active(now):
		return false
	return index == 0 or _village.quest_rank(QUEST_IDS[index - 1]) > 0


## The start of a forge island starts the wait of QUEST.
func quest_started(now: int) -> void:
	_village.start_forge_wait(QUEST, now)


## The hammer button. The client does not test the event time or the level
## here; the window shows only while the event runs.
func hammer(now: int) -> bool:
	return wait_left(DAILY, now) == 0 and add(DAILY, now)


func buy(item_id: int, now: int) -> Village.Placement:
	if complete(item_id) or not running(now) or price(item_id) <= 0:
		return Village.Placement.NOT_ALLOWED
	var result := _village.add_forge_item(item_id, price(item_id), now)
	if result == Village.Placement.OK and item_id == INVITE:
		_village.add_forge_friend()
	return result


func speed_up(item_id: int, now: int) -> Village.Placement:
	if complete(item_id) or wait_left(item_id, now) == 0:
		return Village.Placement.NOT_ALLOWED
	return _village.end_forge_wait(item_id, item(item_id)["speedup_cost"])


## Buys all missing items and gives every prize that is left. Returns the units.
func buy_all() -> Array[int]:
	var given: Array[int] = []
	if progress() >= total():
		return given
	var required := {}
	for entry: Dictionary in _game["items"]:
		required[entry["id"]] = entry["required"]
	if _village.complete_forge(required, INVITE, pack_price()) != Village.Placement.OK:
		return given
	for prize: Array in _game["prizes"]:
		if take_prize(prize[1]) == Village.Placement.OK:
			given.append(prize[1])
	return given


## Gives the prize unit when the player has enough items. After the last
## prize the event ends for the player.
func take_prize(unit_id: int) -> Village.Placement:
	var index: int = _game["prizes"].find_custom(func(prize: Array) -> bool: return prize[1] == unit_id)
	if index < 0 or progress() < _game["prizes"][index][0]:
		return Village.Placement.NOT_ALLOWED
	var result := _village.give_forge_prize(unit_id)
	if result == Village.Placement.OK and not prizes_left():
		_village.end_forge_offer()
	return result
