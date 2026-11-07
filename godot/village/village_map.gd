class_name VillageMap
extends RefCounted
## The lowest layer of Village, which describes the save rules and the layers.
##
## This layer: the save document, the items and the land, resources and
## experience, placement, buying, moving, turning and selling, buying land,
## the name of the map, the market, the workers of buildings, and saving. It
## also sends the events of the goals (happened, see VillageEvent).

enum QuestRole { ENEMY, NEUTRAL, OBJECTIVE }

enum Placement {
	OK,
	OUTSIDE_MAP,
	NOT_OWNED_LAND,
	OCCUPIED,
	MAX_COUNT_REACHED,
	HOUSE_LIMIT_REACHED,
	TOWER_LIMIT_REACHED,
	LAND_AREA_TOWER_LIMIT_REACHED,
	LEVEL_TOO_LOW,
	NOT_ENOUGH_RESOURCES,
	UNKNOWN_RESOURCE,
	NOT_ALLOWED,  ## The player cannot move, turn or sell this item.
	POPULATION_FULL,
	UNIT_LIMIT_REACHED,
	NEIGHBOURS_NEEDED,  ## The client asks for more neighbours.
	NO_TRADES_LEFT,
}

## What the player did, for the goals; see VillageEvent.
signal happened(kind: VillageEvent.Kind, data: Dictionary)

## Buildings for which the server's "buy" hires no workers, in addition to
## GameConfig.allies_item_ids.
const ROUND_TABLE := 389
const TROLL_ALLIES_BUILDING := 361
## The Great Church has no place for the player's own villager.
const GREAT_CHURCH := 470
## The client gives the spell book to human players at this level, and then
## also a free Wizardry Academy, from which the player opens the spell window.
const SPELL_BOOK_LEVEL := 15
const WIZARDRY := 416

## The client sells the land areas around the first area 13; the prices are
## GameConfig.land_prices, by the number of areas that the map has.
const LAND_FOR_SALE: Array[int] = [7, 8, 9, 12, 14, 17, 18, 19]
## The second town (PopupRaceSelector of the client, "buy_map" of the server):
## a troll town, map SECOND_TOWN of the save, for gold or cash from the level
## SECOND_TOWN_LEVEL of the map in which the player buys it. The client
## contains these values (TOWN_PRICE_GOLD, TOWN_PRICE_CASH,
## TROL_RACE_REQUIRED_LEVEL); the town_prices of the configuration are not used.
const SECOND_TOWN := 1
const SECOND_TOWN_RACE := "t"
const SECOND_TOWN_LEVEL := 20
const TOWN_PRICE_GOLD := 100000
const TOWN_PRICE_CASH := 22
## The first troll town, as the server's save migration makes it (fix_troll_empire): [item id, x, y].
const TROLL_TOWN_ITEMS: Array[Array] = [[289, 51, 51], [325, 45, 51], [307, 55, 50], [307, 55, 52], [291, 50, 56], [580, 53, 54], [580, 53, 55]]
const TROLL_TOWN_LAND := 13
const TROLL_TOWN_NAME := "My Empire 1"
## The market of the map trades 100, 200 or 300 of wood, stone or food for
## gold. Its price starts at MARKET_BASE_COSTS for 100 and changes by
## MARKET_INCREMENT for each trade of the resource ("resourcesTraded" of the
## map). The player has MARKET_MAX_TRADES trades; the client counts them again
## from 0 when it loads a map whose first trade was more than
## MARKET_PERIOD_HOURS ago. The client contains these values.
const MARKETS := {23: 100, 188: 200, 189: 300, 335: 100, 345: 200, 346: 300}
const MARKET_BASE_COSTS := {"w": 100, "s": 150, "f": 100}
const MARKET_INCREMENT := 0.02
const MARKET_MAX_INCREMENTS := 200
const MARKET_MAX_DECREMENTS := 25
const MARKET_SELL_SHARE := 0.75
const MARKET_MAX_TRADES := 20
const MARKET_PERIOD_HOURS := 20

## For check_limits(): the location is not known yet.
const ANY_TILE := Vector2i(-1, -1)

## Trees and stone and gold deposits. The player collects them, but cannot move or sell them.
const NEUTRAL_RESOURCE_SUBCATS: Array[int] = [125, 126, 127, 128]
const CATEGORY_TERRAIN := 6
## A sold item gives back its cost divided by this number, in the resource of
## the cost. Items that cost cash give nothing back.
const SELL_DIVISOR := 20

## Resource codes in item costs and level rewards, and where the save keeps each
## resource. "map" values are in the map, "player" values in playerInfo and
## "private" values in privateState.
const RESOURCE_KEYS := {
	"g": ["map", "coins"],
	"w": ["map", "wood"],
	"s": ["map", "stone"],
	"f": ["map", "food"],
	"c": ["player", "cash"],
	"m": ["private", "mana"],
	"p": ["private", "potion"],
}


class PlacedItem:
	var item_id: int
	var tile: Vector2i
	var frame: int  ## 0-based graphic frame; the client uses it for orientation and state.
	var _entry: Array  # The item entry in the save; move() and sell() change it.


var items: Array[PlacedItem] = []
var owned_land: PackedInt32Array = []  ## Land area numbers, see IsoGrid.land_area_number().
var skin: int = 0  ## Map style; selects the land item 1000 + skin.
var race: String  ## "h" (human) or "t" (troll).

## The ids of the player's neighbours, in the order of the server's neighbour
## list: the server hires them as workers of new buildings. The owner sets
## them from NeighbourSource; the save does not keep them.
var neighbour_ids: Array[String] = []
## The items of the quest in the town and their side, set by TownQuests; the
## save does not keep it. The player cannot move, sell or store these items.
var quest_roles := {}  # PlacedItem -> QuestRole
var _document: Dictionary  # The whole save.
var _map: Dictionary  # The map in _document that this village shows.
var _map_index: int
var _trades_done: Variant = null  # The trades that the client counts, see market_trades_left().
var _config: GameConfig
# Set when the player reaches SPELL_BOOK_LEVEL in the village; Village.add_free_buildings() then gives the Wizardry Academy.
var _wizardry_due := false
var _occupied := PackedByteArray()  # Number of items that cover each tile, row by row.
func get_level() -> int:
	return int(_map["level"])


func get_xp() -> int:
	return int(_map["xp"])


## The experience that the next level needs, or -1 at the highest level.
func get_next_level_xp() -> int:
	if get_level() >= _config.levels.size():
		return -1
	return _config.levels[get_level()].exp_required


## Returns -1 for a resource code that the save does not keep.
func get_resource(code: String) -> int:
	if not RESOURCE_KEYS.has(code):
		return -1
	return int(_resource_holder(code).get(RESOURCE_KEYS[code][1], 0))


## Checks only the location: the map edges, the owned land and the other items.
## The item ignored does not block the location; use it for the item that moves.
func check_location(item: GameConfig.ItemDef, tile: Vector2i, ignored: PlacedItem = null) -> Placement:
	var covered := footprint(item, tile)
	var ignored_tiles := _covered_tiles(ignored) if ignored != null else Rect2i()
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).encloses(covered):
		return Placement.OUTSIDE_MAP
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			var area := Vector2i(x, y) / IsoGrid.LAND_TILES
			if not IsoGrid.land_area_number(area) in owned_land:
				return Placement.NOT_OWNED_LAND
			var others := _occupied[y * IsoGrid.MAP_TILES + x] - (1 if ignored_tiles.has_point(Vector2i(x, y)) else 0)
			if others != 0:
				return Placement.OCCUPIED
	return Placement.OK


## Checks the limits on the number of buildings of a type. With ANY_TILE, it does
## not check the limit of towers in the land area of the location. The item
## ignored does not count; use it for the item that moves.
func check_limits(item: GameConfig.ItemDef, tile: Vector2i = ANY_TILE, ignored: PlacedItem = null) -> Placement:
	var same_item := 0
	var same_subcat := 0
	var houses := 0
	var towers := 0
	var townhall_id := -1
	var groups := ConstructionLimits.ONE_PER_GROUP.filter(func(group: Array) -> bool: return item.id in group)
	var in_group := 0
	for placed in items:
		var placed_item := _config.get_item(placed.item_id)
		if placed_item == null or placed == ignored:
			continue
		if placed.item_id == item.id:
			same_item += 1
		if placed_item.subcat_functional == item.subcat_functional:
			same_subcat += 1
		match placed_item.subcat_functional:
			ConstructionLimits.SUBCAT_HOUSE:
				if placed.item_id != ConstructionLimits.BATHS:
					houses += 1
			ConstructionLimits.SUBCAT_TOWER:
				towers += 1
			ConstructionLimits.SUBCAT_TOWNHALL:
				townhall_id = placed.item_id
		if not groups.is_empty() and placed.item_id in groups[0]:
			in_group += 1

	if item.subcat_functional == ConstructionLimits.SUBCAT_TOWER:
		if towers >= owned_land.size() * ConstructionLimits.MAX_TOWERS_PER_LAND_AREA:
			return Placement.TOWER_LIMIT_REACHED
		if tile != ANY_TILE and _tower_tiles_in_land_area(tile, ignored) >= ConstructionLimits.MAX_TOWERS_PER_LAND_AREA:
			return Placement.LAND_AREA_TOWER_LIMIT_REACHED
	if item.subcat_functional == ConstructionLimits.SUBCAT_HOUSE and item.id != ConstructionLimits.BATHS:
		if houses >= _config.townhall_house_limit.get(townhall_id, 0):
			return Placement.HOUSE_LIMIT_REACHED
	if item.subcat_functional in ConstructionLimits.ONE_PER_SUBCAT and same_subcat >= 1:
		return Placement.MAX_COUNT_REACHED
	if ConstructionLimits.MAX_PER_ITEM.has(item.id) and same_item >= ConstructionLimits.MAX_PER_ITEM[item.id]:
		return Placement.MAX_COUNT_REACHED
	if in_group >= 1:
		return Placement.MAX_COUNT_REACHED
	return Placement.OK


## Buys an item from the store and places it, as the server command "buy" does.
## frame is the direction, from 0 to item.max_frame - 1. Changes nothing when the result is not OK.
func buy(item: GameConfig.ItemDef, tile: Vector2i, timestamp: int, frame: int = 0) -> Placement:
	if frame < 0 or frame >= item.max_frame:
		return Placement.NOT_ALLOWED
	var location := check_location(item, tile)
	if location != Placement.OK:
		return location
	var limit := check_limits(item, tile)
	if limit != Placement.OK:
		return limit
	if get_level() < item.min_level:
		return Placement.LEVEL_TOO_LOW
	var available := get_resource(item.cost_type)
	if available < 0:
		return Placement.UNKNOWN_RESOURCE
	if available < item.cost:
		return Placement.NOT_ENOUGH_RESOURCES

	_add_resource(item.cost_type, -item.cost)
	_add_xp(item.xp)
	_register_unit(item.id)
	var placed := _add_entry(item, tile, frame, timestamp, _new_item_attributes(item))
	if not item.is_unit():
		happened.emit(VillageEvent.Kind.BUILT, {"item": item.id})
	_report_workers(placed)
	return Placement.OK


## The price of the next land area: {"coins", "cash", "neighbors"}, or {}
## when the map has all areas that the client sells.
func next_land_price() -> Dictionary:
	var index := owned_land.size() - 1
	if index < 0 or index >= _config.land_prices.size() or LAND_FOR_SALE.all(func(area: int) -> bool: return area in owned_land):
		return {}
	return _config.land_prices[index]


func can_buy_land(area: int) -> bool:
	return area in LAND_FOR_SALE and not area in owned_land and not next_land_price().is_empty()


## Buys the land area for cash or gold, as the server command "expand" does.
## For gold the client wants the number of neighbours of the price, from
## neighbours: the neighbours of the server's list, without Arthur. Changes
## nothing when the result is not OK.
func buy_land(area: int, with_cash: bool, neighbours: int) -> Placement:
	if not can_buy_land(area):
		return Placement.NOT_ALLOWED
	var price := next_land_price()
	if not with_cash and neighbours < int(price["neighbors"]):
		return Placement.NEIGHBOURS_NEEDED
	var code := "c" if with_cash else "g"
	var cost := int(price["cash"] if with_cash else price["coins"])
	if get_resource(code) < cost:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource(code, -cost)
	owned_land.append(area)
	if not _map.get("expansions") is Array:
		_map["expansions"] = []
	_map["expansions"].append(area)
	happened.emit(VillageEvent.Kind.LAND_BOUGHT, {"amount": owned_land.size()})
	return Placement.OK


## The towns that the player bought: privateState.maps of the save, one
## {"r": race} for each town. A save without the list has only the first town.
func _towns() -> Array:
	var towns: Variant = _document["privateState"].get("maps")
	return towns if towns is Array and not towns.is_empty() else [{"r": "h"}]


func has_second_town() -> bool:
	return _towns().size() > SECOND_TOWN


## OK when the player can buy the second town in this map now, for cash or gold.
func can_buy_second_town(with_cash: bool) -> Placement:
	if has_second_town():
		return Placement.NOT_ALLOWED
	if get_level() < SECOND_TOWN_LEVEL:
		return Placement.LEVEL_TOO_LOW
	if get_resource("c" if with_cash else "g") < (TOWN_PRICE_CASH if with_cash else TOWN_PRICE_GOLD):
		return Placement.NOT_ENOUGH_RESOURCES
	return Placement.OK


## Buys the troll town for cash or gold, as the server command "buy_map" does.
## A save that has no map SECOND_TOWN gets the troll town that the server's
## save migration makes. Changes nothing when the result is not OK.
func buy_second_town(with_cash: bool, now: int) -> Placement:
	var result := can_buy_second_town(with_cash)
	if result != Placement.OK:
		return result
	if with_cash:
		_add_resource("c", -TOWN_PRICE_CASH)
	else:
		_add_resource("g", -TOWN_PRICE_GOLD)
	var towns := _towns()
	towns.append({"r": SECOND_TOWN_RACE})
	_document["privateState"]["maps"] = towns
	if _document["maps"].size() <= SECOND_TOWN:
		_add_troll_town(now)
	return Placement.OK


## Map SECOND_TOWN of fix_troll_empire of the server: the Troll Hall, the
## coliseum, two houses, a tower and two villagers on land area TROLL_TOWN_LAND,
## with the values that the rest of the server's save migration adds.
func _add_troll_town(now: int) -> void:
	var entries := []
	for item: Array in TROLL_TOWN_ITEMS:
		entries.append([item[0], item[1], item[2], 0, now, 0, [], {}])
	_document["maps"].append({"id": SECOND_TOWN, "expansions": [TROLL_TOWN_LAND], "timestamp": now, "coins": 250, "xp": 4, "level": 1,
			"stone": 250, "wood": 850, "food": 700, "race": SECOND_TOWN_RACE, "skin": 0, "idCurrentTreasure": 0, "timestampLastTreasure": 0,
			"resourcesTraded": {}, "receivedAssists": {}, "increasedPopulation": 0, "expirableUnitsTime": {}, "universAttackWin": [],
			"questTimes": {}, "lastQuestTimes": [], "items": entries, "warehouseAditionalCapacitySingle": 50, "warehousedUnits": {},
			"timestampLastTrade": 0, "numTradesDone": 0, "store": {}, "resourceAlliesMarket": "n", "currentQuestVars": {}})
	var info: Dictionary = _document["playerInfo"]
	for key: String in ["map_names", "map_sizes"]:
		if not info.get(key) is Array:
			info[key] = []
		while info[key].size() <= SECOND_TOWN:
			info[key].append("" if key == "map_names" else 0)
	info["map_names"][SECOND_TOWN] = TROLL_TOWN_NAME
	info["map_sizes"][SECOND_TOWN] = 0


## The name of the map, which the player gives with rename().
func map_name() -> String:
	var names: Variant = _document["playerInfo"].get("map_names")
	return str(names[_map_index]) if names is Array and _map_index < names.size() else ""


## Names the map, as the server command "name_map" does.
func rename(new_name: String) -> Placement:
	new_name = new_name.strip_edges()
	if new_name.is_empty():
		return Placement.NOT_ALLOWED
	var names: Variant = _document["playerInfo"].get("map_names")
	if not names is Array:
		names = []
		_document["playerInfo"]["map_names"] = names
	while names.size() <= _map_index:
		names.append("")
	names[_map_index] = new_name
	happened.emit(VillageEvent.Kind.RENAMED, {})
	return Placement.OK


## The market of the map, or null. The client uses the first one, and trades
## only when its workers opened it.
func market() -> PlacedItem:
	for placed in items:
		if MARKETS.has(placed.item_id) and not is_being_built(placed):
			return placed
	return null


## The amount of one trade, from the level of the market; 0 without a market.
func market_amount() -> int:
	return MARKETS[market().item_id] if market() != null else 0


## The gold of a trade of market_amount() of the resource w, s or f, as the
## server calculates it. A sale gives MARKET_SELL_SHARE of the price.
func market_price(code: String, sell: bool) -> int:
	var traded := clampi(int(_traded().get(code, 0)), -MARKET_MAX_DECREMENTS, MARKET_MAX_INCREMENTS)
	var base: float = MARKET_BASE_COSTS[code] * (market_amount() / 100.0)
	var cost := _round_half_even(base + base * traded * MARKET_INCREMENT)
	return _round_half_even(cost * MARKET_SELL_SHARE) if sell else cost


func market_trades_left(now: int) -> int:
	if _trades_done == null:
		var last := float(_map.get("timestampLastTrade", 0))
		_trades_done = 0 if now - last > MARKET_PERIOD_HOURS * 3600 else int(_map.get("numTradesDone", 0))
	return maxi(MARKET_MAX_TRADES - int(_trades_done), 0)


## Buys or sells market_amount() of the resource w, s or f, as the server
## command "trade_resource_b" does. A sale takes the gold price of the
## resource, not the amount: the server does this, so the port does too.
func trade(code: String, sell: bool, now: int) -> Placement:
	if market() == null or not MARKET_BASE_COSTS.has(code):
		return Placement.NOT_ALLOWED
	if market_trades_left(now) == 0:
		return Placement.NO_TRADES_LEFT
	var price := market_price(code, sell)
	var amount := market_amount()
	# The client checks the amount of a sale, the server its price.
	if get_resource(code if sell else "g") < (maxi(price, amount) if sell else price):
		return Placement.NOT_ENOUGH_RESOURCES
	if sell:
		_add_resource(code, -price)
		_add_resource("g", price)
	else:
		_add_resource("g", -price)
		_add_resource(code, amount)
	_traded()[code] = int(_traded().get(code, 0)) + (-1 if sell else 1)
	if int(_map.get("numTradesDone", 0)) == 0:
		_map["timestampLastTrade"] = now
	_map["numTradesDone"] = int(_map.get("numTradesDone", 0)) + 1
	_trades_done = int(_trades_done) + 1
	happened.emit(VillageEvent.Kind.MARKET_TRADED, {"code": code, "amount": -amount if sell else amount})
	return Placement.OK


## A building with workers that the player did not open yet: it shows its
## construction, takes no units and does not produce. Allies buildings,
## which need neighbours, are not in this group.
func is_being_built(placed: PlacedItem) -> bool:
	return _config.worker_item_ids.has(placed.item_id) and placed._entry.size() > 7 and placed._entry[7] is Dictionary \
			and placed._entry[7].get("si") is Array and not _needs_neighbours(placed.item_id)


## The workers of a building with a list of them ("si"): [hired, needed].
## [0, 0] for other buildings.
func workers(placed: PlacedItem) -> Array[int]:
	var hired: Variant = _workers_list(placed)
	return [hired.size() if hired is Array else 0, int(_config.worker_item_ids.get(placed.item_id, [0, 0])[1]) if hired is Array else 0]


## Hires a worker for the worker cost in cash, as the server command
## "buy_si_help" does: for a building that waits for its workers, and for the
## allies buildings except the Round Table, which takes only neighbours.
func hire_worker(placed: PlacedItem) -> Placement:
	var hired: Variant = _workers_list(placed)
	if not hired is Array or placed.item_id == ROUND_TABLE or hired.size() >= workers(placed)[1]:
		return Placement.NOT_ALLOWED
	var cost := int(_config.worker_item_ids[placed.item_id][0])
	if get_resource("c") < cost:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", -cost)
	hired.append("0")
	_report_workers(placed)
	return Placement.OK


## Opens a building that has all its workers, as the server command
## "finish_si" does.
func open_building(placed: PlacedItem) -> Placement:
	if not is_being_built(placed) or workers(placed)[0] < workers(placed)[1]:
		return Placement.NOT_ALLOWED
	placed._entry[7].erase("si")
	happened.emit(VillageEvent.Kind.SOCIAL_BUILDING_OPENED, {"item": placed.item_id})
	return Placement.OK


func _workers_list(placed: PlacedItem) -> Variant:
	if not _config.worker_item_ids.has(placed.item_id) or placed._entry.size() <= 7 or not placed._entry[7] is Dictionary:
		return null
	return placed._entry[7].get("si")


## The client tells the goals the number of workers of a building that has a
## list of them, when it loads the map and when a worker comes.
func _report_workers(placed: PlacedItem) -> void:
	if _workers_list(placed) is Array:
		happened.emit(VillageEvent.Kind.WORKERS_HIRED, {"item": placed.item_id, "amount": _workers_list(placed).size()})


## Sends WORKERS_HIRED for each building with workers, as the client does when it loads the map.
func report_all_workers() -> void:
	for placed in items:
		_report_workers(placed)


func _needs_neighbours(item_id: int) -> bool:
	return item_id == ROUND_TABLE or item_id == TROLL_ALLIES_BUILDING or item_id in _config.allies_item_ids


func _traded() -> Dictionary:
	if not _map.get("resourcesTraded") is Dictionary:
		_map["resourcesTraded"] = {}
	return _map["resourcesTraded"]


## Python's round(), which the server uses: a half goes to the even number.
static func _round_half_even(value: float) -> int:
	var lower := floori(value)
	var rest := value - lower
	if is_equal_approx(rest, 0.5):
		return lower if lower % 2 == 0 else lower + 1
	return roundi(value)


## The item that covers the tile, or null. When items overlap, the item added last.
func item_at(tile: Vector2i) -> PlacedItem:
	for i in range(items.size() - 1, -1, -1):
		if _config.get_item(items[i].item_id) != null and _covered_tiles(items[i]).has_point(tile):
			return items[i]
	return null


## Reads map map_index of the save at path. Returns false and reports an error
## when the file is missing or not a valid save. Village.load_from_file() calls it.
func _read(path: String, config: GameConfig, map_index: int) -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read village '%s' (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary and data.get("maps") is Array and data.get("playerInfo") is Dictionary and data.get("privateState") is Dictionary):
		push_error("Village '%s' is not a save: it has no maps, playerInfo or privateState." % path)
		return false
	var maps: Array = data["maps"]
	if map_index < 0 or map_index >= maps.size() or not maps[map_index] is Dictionary:
		push_error("Village '%s' has no map %d." % [path, map_index])
		return false
	var game_map: Dictionary = maps[map_index]
	if not game_map.get("items") is Array:
		push_error("Map %d of village '%s' has no item list." % [map_index, path])
		return false
	# Two quest maps of the server store the level as text, for example "50".
	# The client reads it as a number, so the port does too.
	for key in ["level", "xp", "coins", "wood", "stone", "food"]:
		var number: Variant = game_map.get(key)
		if number is String:
			number = GameConfig.to_int(number)
		if not (number is float or number is int):
			push_error("Map %d of village '%s' has no number '%s'." % [map_index, path, key])
			return false
		game_map[key] = number
	if int(game_map["level"]) < 1:
		push_error("Map %d of village '%s' has level %d. The lowest level is 1." % [map_index, path, int(game_map["level"])])
		return false

	if not game_map.get("race") in ["h", "t"]:
		push_error("Map %d of village '%s' has no race \"h\" or \"t\"." % [map_index, path])
		return false

	_document = data
	_map = game_map
	_map_index = map_index
	_config = config
	_occupied.resize(IsoGrid.MAP_TILES * IsoGrid.MAP_TILES)
	skin = int(game_map.get("skin", 0))
	race = game_map["race"]
	for area: Variant in game_map.get("expansions", []):
		if (area is int or area is float) and int(area) >= 1 and int(area) <= IsoGrid.LAND_AREAS * IsoGrid.LAND_AREAS:
			owned_land.append(int(area))
	for entry: Variant in game_map["items"]:
		var placed := _parse_item(entry)
		if placed == null:
			push_warning("Ignored an incorrect item in '%s': %s" % [path, str(entry).left(200)])
			continue
		_add(placed)
	return true


## The player can move the own buildings and decorations, also the town hall.
func can_move(placed: PlacedItem) -> bool:
	var item := _config.get_item(placed.item_id)
	return item != null and not item.is_unit() and item.category_id != CATEGORY_TERRAIN \
			and not item.subcat_functional in NEUTRAL_RESOURCE_SUBCATS and not quest_roles.has(placed)


## The player can sell the items that they can move, except the town hall.
func can_sell(placed: PlacedItem) -> bool:
	return can_move(placed) and _config.get_item(placed.item_id).subcat_functional != ConstructionLimits.SUBCAT_TOWNHALL


## The amount that selling the item gives back, in the resource of its cost.
static func sell_refund(item: GameConfig.ItemDef) -> int:
	return 0 if item.cost_type == "c" else item.cost / SELL_DIVISOR


## Checks a move of the item to the tile. The client removes the item from the
## map while it moves, so the item does not block its own location or count for the limits.
func check_move(placed: PlacedItem, tile: Vector2i) -> Placement:
	if not can_move(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var location := check_location(item, tile, placed)
	if location != Placement.OK:
		return location
	return check_limits(item, tile, placed)


## Moves the item and gives it the direction frame, as the server command "move"
## does. frame -1 keeps the direction. Changes nothing when the result is not OK.
func move(placed: PlacedItem, tile: Vector2i, frame: int = -1) -> Placement:
	var result := check_move(placed, tile)
	if result != Placement.OK:
		return result
	if frame == -1:
		frame = placed.frame
	elif frame < 0 or frame >= _config.get_item(placed.item_id).max_frame:
		return Placement.NOT_ALLOWED
	_mark_occupied(placed, -1)
	placed.tile = tile
	placed._entry[1] = tile.x
	placed._entry[2] = tile.y
	_set_frame(placed, frame)
	_mark_occupied(placed, 1)
	if not _config.get_item(placed.item_id).is_unit():
		happened.emit(VillageEvent.Kind.MOVED, {"item": placed.item_id})
	return Placement.OK


## The player can turn the items that they can move and that have more than one direction.
func can_rotate(placed: PlacedItem) -> bool:
	return can_move(placed) and _config.get_item(placed.item_id).max_frame > 1


## Turns the item to its next direction, as the server command "orient" does.
func rotate(placed: PlacedItem) -> Placement:
	if not can_rotate(placed):
		return Placement.NOT_ALLOWED
	_set_frame(placed, (placed.frame + 1) % _config.get_item(placed.item_id).max_frame)
	return Placement.OK


## Sells the item, as the server command "sell" does. VillageUnits first takes
## the units out of the building. Changes nothing when the result is not OK.
func sell(placed: PlacedItem, now: int) -> Placement:
	if not can_sell(placed):
		return Placement.NOT_ALLOWED
	var item := _config.get_item(placed.item_id)
	var refund := sell_refund(item)
	if refund > 0:
		_add_resource(item.cost_type, refund)
	_remove(placed)
	return Placement.OK


## A tile that a unit can stand on: in the map and with no other item on it.
func is_free(tile: Vector2i, ignored: PlacedItem = null) -> bool:
	if not Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(tile):
		return false
	var others := _occupied[tile.y * IsoGrid.MAP_TILES + tile.x]
	if ignored != null and _covered_tiles(ignored).has_point(tile):
		others -= 1
	return others == 0


## The free tile nearest to the area, in rings around it, or ANY_TILE.
func free_tile_around(area: Rect2i) -> Vector2i:
	for ring in range(1, IsoGrid.MAP_TILES):
		var tiles := _free_tiles_in_ring(area, ring)
		if not tiles.is_empty():
			return tiles[0]
	return ANY_TILE


## A free tile at random from the nearest ring around the tile that has one,
## or ANY_TILE when the first max_rings rings have none.
func random_free_tile_near(tile: Vector2i, max_rings: int, rng: RandomNumberGenerator) -> Vector2i:
	for ring in range(1, max_rings + 1):
		var tiles := _free_tiles_in_ring(Rect2i(tile, Vector2i.ONE), ring)
		if not tiles.is_empty():
			return tiles[rng.randi_range(0, tiles.size() - 1)]
	return ANY_TILE


## The free tiles on the ring around the area, row by row.
func _free_tiles_in_ring(area: Rect2i, ring: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var around := area.grow(ring)
	for y in range(around.position.y, around.end.y):
		for x in range(around.position.x, around.end.x):
			var on_edge := x == around.position.x or x == around.end.x - 1 or y == around.position.y or y == around.end.y - 1
			if on_edge and is_free(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	return tiles


## The free place for the item nearest to the tile, in rings around it, as the
## client finds a place for a free building, or ANY_TILE.
func _free_place_near(item: GameConfig.ItemDef, center: Vector2i) -> Vector2i:
	for ring in IsoGrid.MAP_TILES:
		var best := ANY_TILE
		var around := Rect2i(center, Vector2i.ONE).grow(ring)
		for y in range(around.position.y, around.end.y):
			for x in range(around.position.x, around.end.x):
				var on_edge := x == around.position.x or x == around.end.x - 1 or y == around.position.y or y == around.end.y - 1
				var tile := Vector2i(x, y)
				if on_edge and check_location(item, tile) == Placement.OK \
						and (best == ANY_TILE or (tile - center).length_squared() < (best - center).length_squared()):
					best = tile
		if best != ANY_TILE:
			return best
	return ANY_TILE


func _private_int(key: String) -> int:
	var value: Variant = _document["privateState"].get(key, 0)
	return int(value) if value is int or value is float else 0


func _set_private(keys: Array, values: Array) -> void:
	for i in keys.size():
		_document["privateState"][keys[i]] = values[i]


## Writes the save to a temporary file, keeps the old file as <path>.bak, then
## puts the new file in its place, as the server does.
func save_to_file(save_path: String) -> Error:
	var path := ProjectSettings.globalize_path(save_path)
	var temp_path := path.get_base_dir().path_join(".%s.tmp" % path.get_file())
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_whole_numbers_as_int(_document), "\t", false))
	file.close()
	var error := file.get_error()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp_path, path)


## Raises the level while the experience reaches the next level, one level at a
## time, as the client does when the player gets experience. The client then
## sends "rt_level_up" for each level, and the server gives the reward of that
## level and, from a configured level, mana. The client does not check the level
## when it loads a save, so a save can keep more experience than its level needs.
## The client gives the Wizardry Academy only at a level that the player
## reaches in the own village: in_village is false for the experience of a quest.
func _add_xp(amount: int, in_village: bool = true) -> void:
	_map["xp"] = get_xp() + amount
	while get_next_level_xp() >= 0 and get_xp() >= get_next_level_xp():
		var new_level := get_level() + 1
		var reached := _config.levels[new_level - 1]
		_add_resource(reached.reward_type, reached.reward_amount)
		if new_level >= _config.start_level_mana_reward:
			_add_resource("m", _config.mana_reward_per_level)
		_map["level"] = new_level
		if new_level == SPELL_BOOK_LEVEL and in_village:
			_wizardry_due = true


func _add_resource(code: String, amount: int) -> void:
	if not RESOURCE_KEYS.has(code):
		# The levels in the configuration give only g, w, s, f and c. The server
		# also knows "all"; the port does not need it yet.
		push_warning("Ignored a reward of %d with the unknown resource code '%s'." % [amount, code])
		return
	var key: String = RESOURCE_KEYS[code][1]
	var holder := _resource_holder(code)
	holder[key] = int(holder.get(key, 0)) + amount
	if amount != 0:
		happened.emit(VillageEvent.Kind.RESOURCE_CHANGED, {"code": code, "amount": amount})


func _resource_holder(code: String) -> Dictionary:
	match RESOURCE_KEYS[code][0]:
		"map":
			return _map
		"player":
			return _document["playerInfo"]
		_:
			return _document["privateState"]


## The server's "buy" gives a building that needs workers a list of hired
## workers ("si"): the player's own villager ("0"), except in the Great
## Church, then the neighbours in the order of neighbour_ids, until the
## building has its workers (hire_friends of the server). The buildings of
## the allies and the Round Table hire no one.
func _new_item_attributes(item: GameConfig.ItemDef) -> Dictionary:
	if not _config.worker_item_ids.has(item.id):
		return {}
	if item.id == ROUND_TABLE:
		return {"si": [], "sif": {}}
	if _needs_neighbours(item.id):
		return {"si": []}
	var hired: Array = [] if item.id == GREAT_CHURCH else ["0"]
	for pid in neighbour_ids:
		if hired.size() >= int(_config.worker_item_ids[item.id][1]):
			break
		hired.append(pid)
	return {"si": hired}


## The client counts each tile that a tower covers, not each tower.
func _tower_tiles_in_land_area(tile: Vector2i, ignored: PlacedItem) -> int:
	var area := Rect2i(tile / IsoGrid.LAND_TILES * IsoGrid.LAND_TILES, Vector2i.ONE * IsoGrid.LAND_TILES)
	var count := 0
	for placed in items:
		var placed_item := _config.get_item(placed.item_id)
		if placed_item != null and placed != ignored and placed_item.subcat_functional == ConstructionLimits.SUBCAT_TOWER:
			count += footprint(placed_item, placed.tile).intersection(area).get_area()
	return count


## The server keeps a list of the units of the player's race that the player
## had. It ignores buildings, which collection rewards and stored items can be.
func _register_unit(unit_id: int) -> void:
	var item := _config.get_item(unit_id)
	if not item.is_unit() or item.race == ("h" if race == "t" else "t"):
		return
	if not _document["privateState"].get("boughtUnits") is Array:
		_document["privateState"]["boughtUnits"] = []
	var bought: Array = _document["privateState"]["boughtUnits"]
	if not bought.has(unit_id) and not bought.has(float(unit_id)):
		bought.append(unit_id)


## Adds an item entry in the server format and puts the item on the map.
func _add_entry(item: GameConfig.ItemDef, tile: Vector2i, frame: int, timestamp: int, attributes: Dictionary) -> PlacedItem:
	# Entry format of the server: [item_id, x, y, orientation, timestamp, level, units, attributes].
	var entry := [item.id, tile.x, tile.y, frame, timestamp, 0, [], attributes]
	_map["items"].append(entry)
	var placed := PlacedItem.new()
	placed.item_id = item.id
	placed.tile = tile
	placed.frame = frame
	placed._entry = entry
	_add(placed)
	return placed


func _set_frame(placed: PlacedItem, frame: int) -> void:
	placed.frame = frame
	placed._entry[3] = frame


func _remove(placed: PlacedItem) -> void:
	quest_roles.erase(placed)
	_mark_occupied(placed, -1)
	items.erase(placed)
	_map["items"].erase(placed._entry)


func _add(placed: PlacedItem) -> void:
	items.append(placed)
	if _config.get_item(placed.item_id) == null:
		push_warning("The village contains item %d, which is not in the configuration." % placed.item_id)
		return
	_mark_occupied(placed, 1)


## change is 1 when the item comes on the map and -1 when it goes away.
## Units also occupy their tile in the client.
func _mark_occupied(placed: PlacedItem, change: int) -> void:
	var covered := _covered_tiles(placed)
	for y in range(covered.position.y, covered.end.y):
		for x in range(covered.position.x, covered.end.x):
			_occupied[y * IsoGrid.MAP_TILES + x] += change


## The tiles of the map that a placed item covers.
func _covered_tiles(placed: PlacedItem) -> Rect2i:
	return footprint(_config.get_item(placed.item_id), placed.tile).intersection(Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES))


## The tiles that an item covers. tile is the front tile; the item extends up and to the left of it.
static func footprint(item: GameConfig.ItemDef, tile: Vector2i) -> Rect2i:
	return Rect2i(tile.x - item.width + 1, tile.y - item.height + 1, item.width, item.height)


## An item entry is [item_id, x, y, frame, timestamp, level, units, attributes].
static func _parse_item(entry: Variant) -> PlacedItem:
	if not (entry is Array and entry.size() >= 8 and entry[6] is Array and entry[7] is Dictionary):
		return null
	for i in 5:
		if not (entry[i] is int or entry[i] is float):
			return null
	var placed := PlacedItem.new()
	placed.item_id = int(entry[0])
	placed.tile = Vector2i(int(entry[1]), int(entry[2]))
	placed.frame = int(entry[3])
	placed._entry = entry
	var inside := Rect2i(0, 0, IsoGrid.MAP_TILES, IsoGrid.MAP_TILES).has_point(placed.tile)
	if not inside or placed.frame < 0:
		return null
	return placed


## Godot reads every JSON number as a float and writes it with ".0". The server
## uses some numbers as list indexes, which must be integers. Saves contain
## whole numbers, except some timestamps with a fraction.
static func _whole_numbers_as_int(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Array:
		var result := []
		for element: Variant in value:
			result.append(_whole_numbers_as_int(element))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _whole_numbers_as_int(value[key])
		return result
	return value
