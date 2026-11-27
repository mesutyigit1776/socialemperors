class_name GameConfigBuilder
## Builds the game configuration from the data of a socialemperors folder,
## as the server does when it starts: get_game_config.py with mods.py,
## event_system.py and darts.py.
##
## This is a second copy of the rules of these Python files. It must stay
## equal to them: the same patches, mods, goal pictures, removal of duplicate
## items and unit pack entries, shop rotation, darts dates, events and PvP
## settings, in the same order. After a change of one of these files, change
## this file in the same way, and compare the config.json of the two (see
## "Import the game files" in godot/README.md).
##
## One difference stays: darts.py uses the local time zone of the computer,
## with the offset of each date. This file uses the present offset of the
## time zone for all dates, so in a zone with summer time the darts dates can
## differ by one hour. The port has no darts (decision 2 in docs/PORT_STATUS.md).

## The old patches that the mega patch replaces; get_game_config.patch_ignore.
const PATCH_IGNORE := ["dragon_boss_fix", "graveyard", "level_up_tips", "mission_goals", "missions_0_1", "new_daily_bonus",
		"soulmixer_temp", "unit_patch", "viral_offers", "viral_icons", "unit_collections",
		"soulmixer_powerup_incremented_modified", "soulmixer_items_data", "soulmixer_item", "3-unit_fusion", "fusion_output"]
## The fields that a mod must have, with their types; mods._required_fields.
const MOD_FIELDS := {"name": TYPE_STRING, "author": TYPE_STRING, "description": TYPE_STRING, "game": TYPE_STRING,
		"supports": TYPE_ARRAY, "data": TYPE_ARRAY}
const MOD_GAME := "Social Empires"
const MOD_VERSION := "rewrite"  ## mods._supported_mod_versions
## The item fields that a mod cannot leave out of a unit; mods.check_item_mod().
const NEW_UNIT_FIELDS := ["pack_num", "pack_category", "pack_chance", "training_time"]
const KEPT_UNIT_FIELDS := ["pack_num", "pack_category", "pack_chance", "training_time", "sm_training_time", "breeding_order"]
## The events of server_config.json: event name -> [collect_game id or 0, viral offer id]; event_system._events.
const EVENTS := {
	"EASTER_DRAGON": [0, 1],
	"HELL_FORGE_ISLAND": [1, 2],
	"IVORY_CHALLENGE": [0, 3],
	"IVORY_CHALLENGE_DUPLICATE": [0, 4],
	"NIGHT_FORGE": [0, 5],
}
const MAX_EVENTS := 3  ## The client cannot show more active events.
const DAY := 86400
const WEEK := 604800
const HOUR := 3600
const HALLOWEEN := "Halloween"

## The messages of the server log about the patches, the mods and the events.
var messages := PackedStringArray()
var _source: String
var _config: Dictionary
var _server: Dictionary
var _rotation: Dictionary


## {"config": the configuration, "server": server_config.json} or {"error": text}.
## now: the time of the start of the server (Unix time), which sets the shop
## rotation, the darts dates and the expiry date of the limited items.
func build(source: String, now: int) -> Dictionary:
	_source = source
	var files := {}
	for name: String in ["server_config.json", "config/main.json", "config/shop_rotation.json", "config/goals.json"]:
		var read := ImportFiles.read_json(source.path_join(name))
		if read.has("error"):
			return read
		files[name] = read["value"]
	_server = files["server_config.json"]
	_config = files["config/main.json"]
	_rotation = files["config/shop_rotation.json"]
	for step: Callable in [_apply_patches.bind(files["config/goals.json"]), _apply_mods, _check_unit_packs,
			_apply_shop_rotation.bind(now), _refresh_darts.bind(now), _apply_events, _apply_server_config]:
		var error: String = step.call()
		if not error.is_empty():
			return {"error": error}
	return {"config": _config, "server": _server}


func _apply_patches(goals: Variant) -> String:
	var folder := _source.path_join("config/patch")
	for file_name in ImportFiles.files_in(folder, "json"):
		var name := file_name.get_file().split(".")[0]
		if name.to_lower() in PATCH_IGNORE:
			continue
		var patch := ImportFiles.read_json(folder.path_join(file_name))
		if patch.has("error"):
			return patch["error"]
		var result := JsonPatch.apply(_config, patch["value"])
		if result.has("error"):
			return "%s: %s" % [file_name, result["error"]]
		_config = result["value"]
		messages.append("Patch applied: %s" % name)
	# apply_goals(): the client loads the pictures of the goals that the "images" table names.
	_config["goals"] = goals
	var images: Dictionary = _config["images"]
	for goal: Dictionary in goals:
		for key: String in ["image", "characters"]:
			if goal[key] != "none" and not images.has(goal[key]):
				images[goal[key]] = ""
	return ""


func _apply_mods() -> String:
	var list := _source.path_join("mods/mods.txt")
	if FileAccess.file_exists(list):
		for line in FileAccess.get_file_as_string(list).split("\n"):
			var mod := line.strip_edges()
			if mod.begins_with("#") or mod.is_empty():
				continue
			# As in the server, the file name is the line with ".json" added.
			var path := _source.path_join("mods/%s.json" % mod)
			if FileAccess.file_exists(path):
				var error := _apply_mod(path, mod)
				if not error.is_empty():
					return error
	_remove_duplicate_items()
	return ""


## mods.apply_user_mod(). A mod that breaks a rule is left out; an error only
## when its patch does not apply, which stops the server too.
func _apply_mod(path: String, mod_name: String) -> String:
	var read := ImportFiles.read_json(path)
	if read.has("error"):
		return read["error"]
	var mod: Variant = read["value"]
	if not mod is Dictionary:
		messages.append("[%s] Wrong mod format!" % mod_name)
		return ""
	for key: String in MOD_FIELDS:
		if not mod.has(key) or typeof(mod[key]) != MOD_FIELDS[key]:
			messages.append("[%s] Incorrect mod structure!" % mod_name)
			return ""
	if mod["game"] != MOD_GAME:
		messages.append("[%s] Mod does not support this game!" % mod_name)
		return ""
	if not MOD_VERSION in mod["supports"]:
		messages.append("[%s] Mod does not support this version!" % mod_name)
		return ""
	if not _mod_is_allowed(mod["data"], mod_name):
		messages.append("[%s] %s by %s -> FAILED!" % [mod_name, mod["name"], mod["author"]])
		return ""
	var result := JsonPatch.apply(_config, mod["data"])
	if result.has("error"):
		return "mod %s: %s" % [mod_name, result["error"]]
	_config = result["value"]
	messages.append("[%s] %s by %s -> MOD ACTIVE!" % [mod_name, mod["name"], mod["author"]])
	return ""


## mods.try_apply_mod(): a mod cannot replace items or remove anything, and
## a unit that it adds or changes keeps the fields that the game needs.
func _mod_is_allowed(data: Array, mod_name: String) -> bool:
	var allowed := true
	for operation: Dictionary in data:
		var path: String = str(operation.get("path", "")).to_lower()
		match operation.get("op"):
			"replace":
				if path.begins_with("/items"):
					messages.append("[%s] Replace operation on items is not allowed!" % mod_name)
					allowed = false
			"add":
				var item: Variant = operation.get("value")
				if path == "/items/-" and item is Dictionary and item.get("type") == "u" and not _unit_mod_is_valid(item):
					messages.append("[%s] Invalid item modification: [%s] %s!" % [mod_name, item.get("id"), item.get("name")])
					allowed = false
			"remove":
				messages.append("[%s] Remove operation is not allowed!" % mod_name)
				allowed = false
	return allowed


func _unit_mod_is_valid(item: Dictionary) -> bool:
	var id := int(item["id"])
	var original: Variant = null
	for other: Dictionary in _config["items"]:
		if int(other["id"]) == id:
			original = other
			break
	if original == null:
		return NEW_UNIT_FIELDS.all(func(field: String) -> bool: return item.has(field))
	return KEPT_UNIT_FIELDS.all(func(field: String) -> bool: return item.has(field) or not original.has(field))


## remove_duplicate_items(): of the items with the same id, the last one stays.
func _remove_duplicate_items() -> void:
	var items: Array = _config["items"]
	var last := {}
	for index in items.size():
		last[items[index]["id"]] = index
	var kept := []
	for index in items.size():
		if last[items[index]["id"]] == index:
			kept.append(items[index])
	if kept.size() != items.size():
		messages.append("Removed %d duplicate items from config patches" % (items.size() - kept.size()))
		items.assign(kept)


## check_unit_packs(): the first entry of each unit in a pack stays.
func _check_unit_packs() -> String:
	for pack: Dictionary in _config["unit_packs"]:
		if not pack.has("custom"):
			continue
		var seen := []
		var kept := []
		for entry: Dictionary in pack["custom"]:
			if seen.any(func(id: Variant) -> bool: return JsonPatch.equal(id, entry["id"])):
				messages.append("Duplicate found: id=%s in pack id=%s" % [entry["id"], pack["id"]])
				continue
			seen.append(entry["id"])
			kept.append(entry)
		(pack["custom"] as Array).assign(kept)
	return ""


## apply_shop_rotation(): the store sells the items of some factions of
## config/shop_rotation.json. The factions change every rotation_hours; the
## random generator of Python, seeded with the number of the period, chooses them.
func _apply_shop_rotation(now: int) -> String:
	var settings: Dictionary = _server["shop"]
	var factions: Dictionary = _rotation["factions"]
	var by_id := {}
	for item: Dictionary in _config["items"]:
		if not by_id.has(item["id"]):
			by_id[item["id"]] = item
	var set_in_store := func(item_ids: Array, value: String) -> void:
		for item_id: Variant in item_ids:
			var item: Variant = by_id.get(python_str(item_id))
			if item != null:
				item["in_store"] = value
	for faction: String in factions:
		set_in_store.call(factions[faction], "0")
	var interval := int(settings["rotation_hours"] * HOUR)
	var period := now / interval
	_config["globals"]["LIMITED_EDITION_EXPIRATION"] = Time.get_date_string_from_unix_time((period + 1) * interval)
	var random := PythonRandom.from_int(period)
	var spooktober: bool = settings["spooktober"]
	var today := Time.get_date_dict_from_system()
	var is_halloween: bool = today["month"] == 10 and today["day"] == 31
	if settings["full_random"]:
		var all_items := []
		for faction: String in factions:
			if not (spooktober and faction == HALLOWEEN):
				all_items.append_array(factions[faction])
		random.shuffle(all_items)
		set_in_store.call(all_items.slice(0, mini(all_items.size(), int(settings["max_items_full_random"]))), "1")
		if spooktober and is_halloween:
			set_in_store.call(factions[HALLOWEEN], "1")
	else:
		var names := factions.keys()
		random.shuffle(names)
		if spooktober:
			# The Halloween faction comes only on Halloween.
			if not HALLOWEEN in names:
				return "config/shop_rotation.json has no faction %s" % HALLOWEEN
			names.erase(HALLOWEEN)
		var count := mini(int(settings["max_factions"]), names.size())
		var chosen := []
		if spooktober and is_halloween:
			count -= 1
			chosen.append(HALLOWEEN)
		chosen.append_array(names.slice(0, maxi(count, 0)))
		for faction: String in chosen:
			set_in_store.call(factions[faction], "1")
	for faction: Variant in settings.get("always_enabled", []):
		if factions.has(faction):
			set_in_store.call(factions[faction], "1")
	return ""


## refresh_darts(): the darts games start on Mondays, one each week from
## the start date of the last game, and wrap around until now.
func _refresh_darts(now: int) -> String:
	if not _config.has("darts_items"):
		return ""
	var games: Array = _config["darts_items"]
	var last_start: Variant = _local_unix_time(games[-1]["start_date"])
	if last_start == null:
		return "darts_items: wrong start_date %s" % games[-1]["start_date"]
	while now >= last_start:
		last_start = _update_darts(games, last_start)
	return ""


## _update_darts() of darts.py: the new start dates from first, and the start of the last game.
func _update_darts(games: Array, first: int) -> int:
	var shift := 0
	var last_start := 0
	for game: Dictionary in games:
		var date := _local_date(first + shift)
		# The change of summer time moves the dates by one hour.
		if date["hour"] == 23:
			shift += HOUR
		elif date["hour"] == 1:
			shift -= HOUR
		date = _local_date(first + shift)
		# To the nearest Monday: Tuesday to Thursday back, Friday to Sunday on.
		var weekday: int = 7 if date["weekday"] == 0 else date["weekday"]
		shift += [0, 0, -1, -2, -3, 3, 2, 1][weekday] * DAY
		date = _local_date(first + shift)
		game["start_date"] = "%04d-%02d-%02d %02d:%02d:%02d" % [date["year"], date["month"], date["day"], date["hour"], date["minute"], date["second"]]
		last_start = first + shift
		shift += WEEK
	return last_start


## time.mktime() of a local date "YYYY-MM-DD hh:mm:ss", or null.
func _local_unix_time(text: Variant) -> Variant:
	var parts := str(text).split(" ")
	if parts.size() != 2 or parts[0].split("-").size() != 3 or parts[1].split(":").size() != 3:
		return null
	var date := parts[0].split("-")
	var time := parts[1].split(":")
	var dict := {"year": date[0].to_int(), "month": date[1].to_int(), "day": date[2].to_int(),
			"hour": time[0].to_int(), "minute": time[1].to_int(), "second": time[2].to_int()}
	return Time.get_unix_time_from_datetime_dict(dict) - _zone_offset()


func _local_date(unix_time: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix_time + _zone_offset())


func _zone_offset() -> int:
	return int(Time.get_time_zone_from_system()["bias"]) * 60


## apply_events(): the events of server_config.json switch the viral offers
## and the events of the Island Forge on or off. At most MAX_EVENTS are on.
## An event with wrong data is left out, as the server does.
func _apply_events() -> String:
	if not _server.has("events"):
		return ""
	var active := 0
	for event: Variant in _server["events"]:
		if not event is Dictionary or not EVENTS.has(event.get("event")):
			messages.append("Unknown event %s" % str(event.get("event") if event is Dictionary else event))
			continue
		active += _apply_event(event, EVENTS[event["event"]], active)
	return ""


## event_basic(): sets the start and the duration of the viral offer and of
## its Island Forge event, or 0 and 0 when the event is off. Returns 1 when
## the event is on.
func _apply_event(event: Dictionary, ids: Array, active: int) -> int:
	var forge: Variant = _find_by_id(_config["collect_game"], ids[0]) if ids[0] else null
	var offer: Variant = _find_by_id(_config["viral_offers"], ids[1])
	if offer == null or not event.has("active"):
		messages.append("[%s] FAILED to activate event! -> Event data not found!" % event["event"])
		return 0
	var on: bool = event["active"] and active < MAX_EVENTS
	if event["active"] and not on:
		messages.append("[%s] FAILED to activate event! -> Too many active events!" % event["event"])
	var starts_at: Variant = 0
	var duration: Variant = 0
	if on:
		starts_at = _utc_date(event.get("date"))
		if not (event.get("days") is int or event.get("days") is float) or starts_at == null:
			messages.append("[%s] wrong date or days" % event["event"])
			return 0
		duration = event["days"] * DAY
		messages.append("[%s] Event active! -> %s - %s" % [event["event"], Time.get_date_string_from_unix_time(starts_at),
				Time.get_date_string_from_unix_time(starts_at + duration)])
	for target: Variant in [offer, forge]:
		if target != null:
			target["starts_at"] = starts_at
			target["duration"] = duration
	return 1 if on else 0


## date_to_ts() of get_game_config.py: the Unix time of a date "MM-DD-YYYY" at 0:00 UTC, or null.
func _utc_date(text: Variant) -> Variant:
	var parts := str(text).split("-")
	if not text is String or parts.size() != 3 or not Array(parts).all(func(p: String) -> bool: return p.is_valid_int()):
		return null
	var date := {"year": parts[2].to_int(), "month": parts[0].to_int(), "day": parts[1].to_int(), "hour": 0, "minute": 0, "second": 0}
	if date["month"] < 1 or date["month"] > 12 or date["day"] < 1 or date["day"] > 31:
		return null
	return Time.get_unix_time_from_datetime_dict(date)


func _find_by_id(table: Dictionary, id: int) -> Variant:
	for key: String in table:
		if JsonPatch.equal(table[key].get("id"), id):
			return table[key]
	return null


## apply_server_config(): the time limit of a PvP attack and the resources
## that an attack can take.
func _apply_server_config() -> String:
	var pvp: Dictionary = _server["pvp"]
	_config["globals"]["PVP_TIMER_SECONDS"] = int(pvp["time_limit_minutes"] * 60)
	var multiplier := clampi(int(pvp["resource_cap_multiplier"]), 1, 10000)
	var limits: Dictionary = _config["globals"]["PVP_MAX_RESOURCES"]
	for key: String in limits:
		limits[key]["g"] = str(int(limits[key]["g"]) * multiplier)
	return ""


## str() of Python for a value of the configuration: an int, a float or a str.
static func python_str(value: Variant) -> String:
	if value is bool:
		return "True" if value else "False"
	if value is float:
		return SwfImport.to_json(value, false)["value"]
	return str(value)
