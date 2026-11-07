class_name VillageSocial
extends VillageUnits
## The save changes that come from neighbours and from attacks on other
## players (PvP). The layer between VillageUnits and Village; see Village.
##
## The server commands that are the reference: "assist_neighbor_new" (the
## player helps a neighbour), "assist_receive" and "clean_received_assists" (the
## player takes the help of a neighbour), "get_enemy_new" (the search for an
## enemy), "reset_shield" and "buy_shield", "end_attack" and "end_attack_new"
## (the end of an attack), and the service "pvp/attack/end", which changes the
## save of the attacked player (receive_attack()).
##
## Who the neighbours are, and where their saves are, is not part of the save:
## see NeighbourSource.

## A visit can help at most this number of buildings (NUM_CLICKS_ASSIST).
const ASSIST_CLICKS := 5
## The client lets the player help a neighbour again after this time.
const ASSIST_WAIT_SECONDS := 86400
## The buildings that a visitor can help (isFriendAsistable of the client):
## farms, mills, collect buildings, mines, ranches and wonders without
## population, but not the Treasure Mine, the Sacrifice Altar, the Nursery
## and the Training Stables. the other constants are
## in VillageUnits.
const SUBCAT_MILL := 121
const SUBCAT_COLLECT := 138
const SUBCAT_MINE := 124
## The help of a neighbour gives this part of the collect amount of the
## building, and this experience (FRIENDS_ASSIST_DIVISOR and
## FRIENDS_ASSIST_EXPERIENCE of the client and the server).
const RECEIVED_ASSIST_SHARE := 0.25
const RECEIVED_ASSIST_XP := 10
## The client opens PvP from this level (MIN_LEVEL_PVP).
const PVP_LEVEL := 8
## The server gives the attacked player a shield for this time
## (shield_hours_after_attack_pve and _pvp in server_config.json).
const PVP_VICTIM_SHIELD_SECONDS := 12 * 3600
## The server gives back twice the price of a shield (the option
## shield_allow_original_bug, which is on by default): an error of the
## original game that the server keeps on purpose.
const SHIELD_REFUND_FACTOR := 2


## True when a visitor can help this building.
static func is_assistable(item: GameConfig.ItemDef) -> bool:
	if item == null or item.id in [TREASURE_MINE, SACRIFICE_ALTAR, NURSERY, TRAINING_STABLES]:
		return false
	return item.subcat_functional in [SUBCAT_FARM, SUBCAT_MILL, SUBCAT_COLLECT, SUBCAT_MINE, SUBCAT_RANCH] \
			or (item.subcat_functional == SUBCAT_WONDER and item.population <= 0)


## True when the player can help the neighbour now: the last help, which the
## save keeps in privateState "neighborAssists", is more than a day ago.
func can_assist(pid: String, now: int) -> bool:
	var assists: Variant = _document["privateState"].get("neighborAssists")
	if not assists is Dictionary:
		return true
	var last: Variant = assists.get("u" + pid, assists.get(pid, 0))
	return now - (float(last) if last is int or last is float else 0.0) > ASSIST_WAIT_SECONDS


## The player helped clicks buildings of the neighbour in one visit. The
## client sends the help only when there is at least one; five give honour.
func assist_neighbour(pid: String, clicks: int, now: int) -> void:
	if clicks <= 0:
		return
	if not _document["privateState"].get("neighborAssists") is Dictionary:
		_document["privateState"]["neighborAssists"] = {}
	_document["privateState"]["neighborAssists"][pid] = now
	if clicks >= ASSIST_CLICKS:
		_add_honour(_config.honour_help_friend)


## The help that neighbours gave to this map: neighbour id -> the helped
## buildings, as [x, y, item id] entries.
func received_assists() -> Dictionary:
	var result := {}
	var assists: Variant = _map.get("receivedAssists")
	for pid: Variant in assists if assists is Dictionary else {}:
		if assists[pid] is Array:
			result[str(pid)] = assists[pid].filter(func(entry: Variant) -> bool: return entry is Array and entry.size() >= 3)
	return result


## The player accepts the help of the neighbour. As the cart of the client
## does, each helped building that is still at its place gives its part of
## the collect amount and experience. Returns the buildings that gave something.
func accept_assist(pid: String) -> Array[PlacedItem]:
	var helped: Array[PlacedItem] = []
	for entry: Array in received_assists().get(pid, []):
		var placed := item_at(Vector2i(int(entry[0]), int(entry[1])))
		var item := _config.get_item(int(entry[2]))
		if placed == null or placed.item_id != int(entry[2]) or placed.tile != Vector2i(int(entry[0]), int(entry[1])) or not is_assistable(item):
			continue
		_add_resource(item.collect_type, floori(item.collect * RECEIVED_ASSIST_SHARE))
		_add_xp(RECEIVED_ASSIST_XP)
		helped.append(placed)
	decline_assist(pid)
	return helped


## The help of the neighbour leaves the save without effect.
func decline_assist(pid: String) -> void:
	var assists: Variant = _map.get("receivedAssists")
	if assists is Dictionary:
		assists.erase(pid)


## The gold of one search for an enemy.
func pvp_search_cost() -> int:
	return GameConfig.value_for_level(_config.pvp_search_costs, get_level())


func pay_pvp_search() -> Placement:
	var cost := pvp_search_cost()
	if get_resource("g") < cost:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("g", -cost)
	return Placement.OK


## The seconds that the shield of the player still protects, or 0.
func shield_seconds(now: int) -> int:
	return maxi(_private_int("shieldEndTime") - now, 0)


## The seconds until the player can buy shields again, or 0.
func shield_cooldown_seconds(now: int) -> int:
	return maxi(_private_int("shieldCooldown") - now, 0)


## True when the player can buy the shield now: each shield once in its cooldown.
func can_buy_shield(shield_id: int, now: int) -> bool:
	return not shield_id in _bought_shields(now)


## Buys a shield, as the server command "buy_shield" does: the shield adds its
## time, also to a shield that still runs when other shields of the cooldown
## were bought, and starts its cooldown. The server gives back
## SHIELD_REFUND_FACTOR times the price.
func buy_shield(shield_id: int, now: int) -> Placement:
	var shields := _config.pvp_shields.filter(func(entry: Dictionary) -> bool: return entry["id"] == shield_id)
	if shields.is_empty() or shields[0]["price_type"] != "c" or not can_buy_shield(shield_id, now):
		return Placement.NOT_ALLOWED
	var shield: Dictionary = shields[0]
	if get_resource("c") < shield["price"]:
		return Placement.NOT_ENOUGH_RESOURCES
	_add_resource("c", shield["price"] * (SHIELD_REFUND_FACTOR - 1))
	var bought := _bought_shields(now)
	bought.append(shield_id)
	var end_time := _private_int("shieldEndTime")
	if _private_int("shieldCooldown") < now and bought.size() == 1:
		end_time = 0
	end_time = (now if now >= end_time else end_time) + int(shield["protection_time"])
	_set_private(["shieldEndTime", "shieldCooldown", "purchasedShields"], [end_time, now + int(shield["cooldown"]), bought])
	return Placement.OK


## The player starts an attack: the own shield ends, as the client's
## "reset_shield" does. The cooldown stays.
func drop_shield() -> void:
	_set_private(["shieldEndTime"], [0])


## The resources, experience, honour and counts of the end of an attack of
## the player on another player; Village.end_pvp_attack() also takes the dead
## units. result:
## - "loot": {"g", "w", "s", "f"}, the resources that the attack took, and
##   "xp", which "end_attack_new" adds.
## - "won" and "percentage" (0 to 1, the part of the loot that the attack
##   took): the service "pvp/attack/end" gives honour for them and counts the
##   attack as won or lost.
func _count_pvp_result(result: Dictionary) -> void:
	for code: String in ["g", "f", "w", "s"]:
		_add_resource(code, int(result["loot"].get(code, 0)))
	_add_xp(int(result["xp"]))
	var won: bool = result["won"]
	_add_honour(pvp_honour(won, float(result["percentage"])))
	var player: Dictionary = _document["playerInfo"]
	var key := "attacks_won" if won else "attacks_lost"
	player[key] = int(player.get(key, 0)) + 1
	var private_key := "attacksWon" if won else "attacksLost"
	_set_private([private_key], [_private_int(private_key) + 1])


## The honour of an attack, as the server gives it: a win gives a fixed
## amount; a loss gives an amount for each tenth of the loot that the attack
## did not take.
func pvp_honour(won: bool, percentage: float) -> int:
	return _config.honour_pvp_win if won else roundi(100 * (1.0 - percentage) / 10) * _config.honour_pvp_lost


## Attacks that the player won and lost, which the PvP goals count.
func attacks_won() -> int:
	return _private_int("attacksWon")


func attacks_lost() -> int:
	return _private_int("attacksLost")


## The attacks on this player: the entries of privateState
## "PVPattacksReceived", newest last.
func attacks_received() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var log: Variant = _document["privateState"].get("PVPattacksReceived")
	for key: Variant in log if log is Dictionary else {}:
		if log[key] is Dictionary:
			result.append(log[key])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("attackTime", 0)) < float(b.get("attackTime", 0)))
	return result


## Another player attacked this one, as the server's "pvp/attack/end" changes
## the save of a neighbour: the attacked player gets a shield, and the attack
## goes into the attack log. The server takes resources only from the saves
## of real players, not from the neighbour villages; the port has only the
## neighbour villages. attacker: {"name", "level", "id"}.
func receive_attack(attacker: Dictionary, attacker_won: bool, loot: Dictionary, now: int) -> void:
	_set_private(["shieldEndTime"], [maxi(_private_int("shieldEndTime"), now + PVP_VICTIM_SHIELD_SECONDS)])
	if not _document["privateState"].get("PVPattacksReceived") is Dictionary:
		_document["privateState"]["PVPattacksReceived"] = {}
	var log: Dictionary = _document["privateState"]["PVPattacksReceived"]
	var next_id := log.size()
	while log.has(str(next_id)):
		next_id += 1
	log[str(next_id)] = {"name": attacker["name"], "level": attacker["level"], "id": attacker["id"],
			"attackWinner": attacker["id"] if attacker_won else player_id(), "reply": 1, "attackResourcesLost": loot, "attackTime": now}
	_document["playerInfo"]["_pvp_alert"] = true


## The resources of the village of another player times share, as the server
## shows them some time after an attack. For a village that the player only
## visits or attacks; it must not be saved.
func scale_loot(share: float) -> void:
	for key: String in ["coins", "food", "wood", "stone"]:
		_map[key] = maxi(0, int(float(_map[key]) * share))


## The resources that the village shows to an attacker: {"g", "w", "s", "f"}.
func loot_resources() -> Dictionary:
	return {"g": int(_map["coins"]), "w": int(_map["wood"]), "s": int(_map["stone"]), "f": int(_map["food"])}


func player_id() -> String:
	return str(_document["playerInfo"].get("pid", ""))


func honour() -> int:
	return int(_document["playerInfo"].get("honor_points", 0))


func _add_honour(amount: int) -> void:
	_document["playerInfo"]["honor_points"] = honour() + amount


## The shields bought in the cooldown. The server forgets them when the
## cooldown is over, at the next load of the save.
func _bought_shields(now: int) -> Array:
	var bought: Variant = _document["privateState"].get("purchasedShields")
	if now >= _private_int("shieldCooldown") or not bought is Array:
		return []
	return bought.duplicate()
