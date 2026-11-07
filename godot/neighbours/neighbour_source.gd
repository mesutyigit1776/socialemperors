class_name NeighbourSource
extends RefCounted
## The other players: the neighbours of the player and the enemies of PvP.
##
## The port has no server. It reads the saves of the other players from the
## folders that the importer writes (<data>/neighbours/), and keeps the rules
## of the server (sessions.py) for them:
## - "static": fixed villages, as villages/*.json of the server. Arthur and
##   Guinevere (ARTHUR_IDS) are here; the server leaves them out of the
##   neighbour list and of PvP, and the client visits them as its host.
## - "friend": as the friend/ folder of the server, with villages/friend_static.
## - "enemy": as the enemy/ folder of the server; only for PvP.
## - "mock": the mock neighbours of the port (importer/mock_villages.py). They
##   count as friends. Delete the folder to remove them.
##
## This class is the only part of the port that knows where the other
## players come from. A version for a server would answer the same calls with
## the server's requests: neighbours() with the "neighbors" of
## get_player_info, load_village() with get_player_info for the user,
## find_enemy() with the "pvp/enemy" service, and record_attack() with the
## "pvp/attack/end" service. The saves have the format of the server, so they
## can come from a server without a change.

enum Kind { STATIC, FRIEND, ENEMY }

const ARTHUR_IDS: Array[String] = ["100000030", "100000031", "100000032"]
const FOLDERS := {"static": Kind.STATIC, "friend": Kind.FRIEND, "mock": Kind.FRIEND, "enemy": Kind.ENEMY}
## The server's search for an enemy (server_config.json "pvp" "search").
const SEARCH_TRIES := 2200
const SEARCH_TRIES_BEFORE_WIDER := 200
const SEARCH_LEVEL_RANGE := 10
## The server makes the resources of friend and enemy villages grow again
## over this time after their shield ends (resource_regeneration_hours).
const LOOT_REGROWTH_HOURS := 48
const LOOT_MIN_SHARE := 0.125

var _config: GameConfig
var _entries: Dictionary = {}  # pid -> {"path", "kind", "name", "level", "xp", "world_id", "pic", "shield"}
var _order: Array[String] = []  # The pids in the order of the server's lists.


## Reads the saves in the folders of dir. A missing folder has no neighbours.
static func load_from(dir: String, config: GameConfig) -> NeighbourSource:
	var source := NeighbourSource.new()
	source._config = config
	for folder: String in FOLDERS:
		var path := dir.path_join(folder)
		var files := DirAccess.get_files_at(path) if DirAccess.dir_exists_absolute(path) else PackedStringArray()
		files.sort()
		for file in files:
			if file.ends_with(".json"):
				source._read(path.path_join(file), FOLDERS[folder])
	return source


## The neighbours of the player, as the server lists them: the fixed villages
## without Arthur, then the friends. Each entry: {"pid", "name", "level",
## "xp", "world_id", "pic"}.
func neighbours(own_pid: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind in [Kind.STATIC, Kind.FRIEND]:
		for pid in _order:
			var entry: Dictionary = _entries[pid]
			if entry["kind"] == kind and pid != own_pid and not pid in ARTHUR_IDS:
				result.append({"pid": pid, "name": entry["name"], "level": entry["level"], "xp": entry["xp"], "world_id": entry["world_id"], "pic": entry["pic"]})
	return result


func has(pid: String) -> bool:
	return _entries.has(pid)


## The map of the player with the id, or null. The resources of a friend or
## enemy village are smaller after an attack and grow again, as the server
## shows them; the file does not change.
func load_village(pid: String, now: int) -> Village:
	if not _entries.has(pid):
		return null
	var village := Village.load_from_file(_entries[pid]["path"], _config)
	if village != null and _entries[pid]["kind"] != Kind.STATIC:
		var hours := int((now - _entries[pid]["shield"]) / 3600)
		village.scale_loot(clampf(float(hours) / LOOT_REGROWTH_HOURS, LOOT_MIN_SHARE, 1.0))
	return village


## An enemy for an attack of a player of the level, as the server's search
## does it: random players of the pool without a shield, at most
## SEARCH_LEVEL_RANGE levels from the level; the range grows after each
## SEARCH_TRIES_BEFORE_WIDER tries. The server only takes enemies from level
## 8; the owner of the port decided that the port takes all levels. Returns
## "" when it finds no enemy.
func find_enemy(own_pid: String, level: int, now: int, rng: RandomNumberGenerator) -> String:
	var pool := _order.filter(func(pid: String) -> bool: return not pid in ARTHUR_IDS and pid != own_pid)
	if pool.is_empty():
		return ""
	var low := level - SEARCH_LEVEL_RANGE
	var high := level + SEARCH_LEVEL_RANGE
	for i in SEARCH_TRIES:
		if i > 0 and i % SEARCH_TRIES_BEFORE_WIDER == 0:
			low -= SEARCH_LEVEL_RANGE
			high += SEARCH_LEVEL_RANGE
		var pid: String = pool[rng.randi_range(0, pool.size() - 1)]
		var entry: Dictionary = _entries[pid]
		if now >= entry["shield"] and entry["level"] >= low and entry["level"] <= high:
			return pid
	return ""


## The player attacked the village of pid, as the service "pvp/attack/end"
## tells the server: a friend or enemy village gets a shield and an entry in
## its attack log, see Village.receive_attack(). Fixed villages do not change.
## attacker: {"name", "level", "id"}. Returns false when the file cannot be written.
func record_attack(pid: String, attacker: Dictionary, attacker_won: bool, loot: Dictionary, now: int) -> bool:
	if not _entries.has(pid) or _entries[pid]["kind"] == Kind.STATIC:
		return true
	var village := Village.load_from_file(_entries[pid]["path"], _config)
	if village == null:
		return false
	village.receive_attack(attacker, attacker_won, loot, now)
	if village.save_to_file(_entries[pid]["path"]) != OK:
		return false
	_entries[pid]["shield"] = now + VillageSocial.PVP_VICTIM_SHIELD_SECONDS
	return true


func _read(path: String, kind: Kind) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary and data.get("playerInfo") is Dictionary and data.get("maps") is Array and not data["maps"].is_empty() \
			and data["maps"][0] is Dictionary and data.get("privateState") is Dictionary):
		push_warning("Ignored neighbour '%s': it is not a save." % path)
		return
	var info: Dictionary = data["playerInfo"]
	var pid := str(info.get("pid", ""))
	if pid.is_empty() or _entries.has(pid):
		push_warning("Ignored neighbour '%s': no player id, or the id of another neighbour." % path)
		return
	var game_map: Dictionary = data["maps"][0]
	var level: Variant = GameConfig.to_int(game_map.get("level"))
	var shield: Variant = data["privateState"].get("shieldEndTime", 0)
	_entries[pid] = {"path": path, "kind": kind, "name": str(info.get("name", "")), "level": level if level != null else 1,
			"xp": int(game_map.get("xp", 0)), "world_id": info.get("world_id"), "pic": str(info.get("pic", "")),
			"shield": float(shield) if shield is int or shield is float else 0.0}
	_order.append(pid)
