class_name AssetImport
extends RefCounted
## Converts the user's original Social Empires files into data for the port.
##
## The port does not contain Social Point files. The import reads them from a
## socialemperors folder that the player selects (a clone or a release
## download). It reads only data: assets/, config/ with config/patch/, mods/,
## villages/, server_config.json and templates/img/profile/. It writes:
##
##   <out>/config.json                  game configuration, as the server sends it (GameConfigBuilder)
##   <out>/shop.json                    item groups of the "New" store rotation and the shop settings of the server
##   <out>/sprites/<img_name>/graphic.swf  copy of the SWF file of the item graphic; the port draws its frames
##   <out>/sprites/<img_name>/meta.json  record of the import, see below
##   <out>/fx/<name>/...                shots, effects and spells of battles, in the same form as the units
##   <out>/villages/<name>.json         village saves to display
##   <out>/neighbours/<kind>/<file>     the neighbours, see _import_neighbours()
##   <out>/quests/<id>.save.json        maps of the quest islands
##   <out>/fx/fire_flames.json          the flames of the fire of damaged buildings (FireMC of the client):
##                                      for each frame, the matrix [a, b, c, d, x, y] (pixels) of each flame
##   <out>/spells.json                  how the spell graphics play: img_name -> {"labels": {label: frame},
##                                      "loop_from": frame where the graphic goes on after its last frame, or null}
##   <out>/ui/...                       windows of the client, see UiImport
##   <out>/ui/images/profile/...        the player pictures of the server (templates/img/profile)
##   <out>/sound/...                    music and sound effects of the client, see _import_sounds()
##   <out>/rider_game/...               the mini-game of the Dragon Riding and the Rider Academy, see _import_rider_game()
##
## The import continues after a stop: run it again with the same output
## folder. A graphic is done when its meta.json is written; meta.json also
## records the code of the import and the SWF file that made it. The next run
## skips each graphic whose record still matches, and imports the others
## again. The windows, the sounds and the mini-game have such a record in the
## import.json of their folder.
##
## run() does the whole import; the first-run screen (ImportScreen) calls
## begin(), then step() in each frame, then finish(), and shows the progress.

const TERRAIN_ITEM_IDS := [1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009]  # 1000 + map skin; see the land graphic in the client
const NEUTRAL_RESOURCE_SUBCATS := ["125", "126", "127", "128"]  # trees, stone, gold and their regrowth
## The units that footmen and archers become in the training stables; see Village.MOUNTED_UNITS.
const MOUNTED_UNIT_IDS := [512, 513, 514, 541, 572, 515, 573, 574]
## The units of the dragon and monster nests, the riders of the Rider Academy and
## the free dragon nest and Soul Mixer; see Village.NESTS, RIDER_UNITS and FREE_BUILDING_TILES.
const SPECIAL_BUILDING_ITEM_IDS := [638, 649, 651, 684, 698, 695, 717, 713, 742, 653, 822, 823, 824, 1233, 1529]
## The Huge Egg that the second dragon island lays during the battle; see quest/kinds/dragon_2_quest.gd.
const BATTLE_BUILDING_IDS := [434]
## The treasures and activators of the quests in the town (TownQuestBook).
const TOWN_QUEST_SUBCATS := ["811", "812"]
## The code that decides the content of the graphics, the windows, the sounds
## and the mini-game. A part from other code is imported again.
const IMPORT_CODE := ["res://importer/asset_import.gd", "res://importer/ui_import.gd", "res://importer/import_files.gd"]
const MOCK_CODE := ["res://importer/mock_villages.gd"]
## The kinds of neighbours: neighbour folder -> folders of the socialemperors folder.
## The server also loads villages from its folders friend/ and enemy/, which
## it makes while it runs; the import reads only villages/ (decision 9 in
## docs/PORT_STATUS.md).
const NEIGHBOUR_FOLDERS := {
	"static": ["villages"],  # Arthur and Guinevere, and other fixed villages
	"friend": ["villages/friend_static"],
	"enemy": [],
}
## The copy of the SWF file in the folder of a graphic, from which the port draws it.
const GRAPHIC_FILE := "graphic.swf"
const SPRITE_DIR := "assets/buildingsprites"
## The fire of damaged buildings, in the client file. Its frames 1 to 4 place
## 1 to 4 copies of one animated flame; the port plays a flame at each place.
const FIRE_SYMBOL := "FireMC"
## The scaffolds of a new building for its time of construction
## (IsoElement.setGraphicConstruction), by its size, race and kind.
const CONSTRUCTION_SWF := "assets/swf/120608_dynamic.swf"
const CONSTRUCTION_SYMBOLS := ["Construction1x1", "Construction2x2", "Construction3x3", "Construction4x4", "Construction2x2Trol",
		"Construction3x3Trol", "Construction4x4Trol", "ConstructionGranja", "ConstructionRancho"]
## The hosts of the goal box (MissionPopup) and of the tutorial (TutorialMain),
## male and female (see godot/host/host.gd).
const HOST_SYMBOLS := ["GameShowHostMissionMC", "GameShowFemaleMissionMC", "GameShowHostMC", "GameShowFemaleHostMC"]
const SHIELD_SYMBOLS := ["shieldEnabled", "shieldDisabled"]
## The library of magic particles that the client loads (ExternalClass.LIB_MAGICPARTICLES).
const MAGIC_PARTICLES_SWF := "assets/swf/20131010_magicParticles.swf"
const MAGIC_PARTICLES_SYMBOL := "MagicParticleMC"
## The music of the client (SoundManager.MUSIC), and the library from which the
## client loads its sounds by the name of their class (ExternalClass).
const MUSIC_DIR := "assets/music"
const SOUND_LIBRARY := "assets/swf/120608_dynamic.swf"
## The mini-game: the client plays this file in its window WindowMiniGameDragonRiderMC.
const GAME_SWF := "assets/swf/minigames/SagaOTDC.swf"
const GAME_FILE := "game.swf"
## The parts of the screen of the mini-game that have buttons and text fields.
const GAME_UI_SYMBOLS := ["main.control_board", "main.heroHealthBar", "main.game_won", "main.game_over", "main.game_complete"]
## A file in the output folder while an import runs, with the path of the
## socialemperors folder. A stopped import leaves it, so that the port knows
## that the data folder is not complete (ImportScreen).
const UNFINISHED_FILE := "unfinished_import.txt"
## The folders and files that a socialemperors folder must have.
const REQUIRED := ["assets/buildingsprites", "assets/flash", "config/main.json", "server_config.json", "villages/initial.json"]

## The socialemperors folder and the output folder, as absolute paths.
var source: String
var out_dir: String
## The village saves to import; default villages/initial.json of the source.
var village_paths := PackedStringArray()
## Import the graphics of all items, not only those that the game needs.
var export_all := false
## The time of the start of the server (Unix time) for the configuration, see GameConfigBuilder.
var now := int(Time.get_unix_time_from_system())
## Called with (done, total, text) after each step of step().
var on_progress := func(_done: int, _total: int, _text: String) -> void: pass
## Set to true to stop the import: step() then does nothing more.
var stop_requested := false
## What the import reports: the messages of the configuration, and each part
## that it could not import with the reason.
var messages := PackedStringArray()
var failed := PackedStringArray()
## The number of graphics that an earlier run imported.
var skipped := 0
## The steps of step() that are done, and all steps: the graphics, then the
## other parts (_parts).
var done := 0
var total := 0

var _version: String
var _graphics := []  # The graphics to import, see _jobs().
## The parts after the graphics, in this order: [name, Callable]. The flames,
## the windows, the pictures of the players (after the windows, which can
## remove the ui folder), the sounds and the mini-game.
var _parts := []


func _init(p_source: String, p_out_dir: String) -> void:
	source = ProjectSettings.globalize_path(p_source).simplify_path()
	out_dir = ProjectSettings.globalize_path(p_out_dir).simplify_path()


## Whether the data folder needs an import: it has no configuration, or an import into it did not finish.
static func needs_import(data_dir: String) -> bool:
	return not FileAccess.file_exists(data_dir.path_join("config.json")) or FileAccess.file_exists(data_dir.path_join(UNFINISHED_FILE))


## The socialemperors folder of an import into the data folder that did not finish, or "".
static func unfinished_source(data_dir: String) -> String:
	return FileAccess.get_file_as_string(data_dir.path_join(UNFINISHED_FILE)).strip_edges()


## An error text when the folder is not a socialemperors folder with the game files, or "".
static func check_source(folder: String) -> String:
	for path: String in REQUIRED:
		if not FileAccess.file_exists(folder.path_join(path)) and not DirAccess.dir_exists_absolute(folder.path_join(path)):
			return "%s has no %s. Select the socialemperors folder (a clone or a release download)." % [folder, path]
	return ""


## Runs the whole import. Returns "" when it is done (failed lists the parts
## that it could not import), "stopped" after stop_requested, else the error
## that stopped it.
func run() -> String:
	var error := begin()
	if not error.is_empty():
		return error
	while step():
		pass
	return finish()


## The first part of the import, which takes about a second: the
## configuration, the villages, the neighbours, the quest maps and the spells.
## It finds the graphics and the parts that step() then imports one at a
## time, so that a window can show the progress between them. The extension
## flash_art accepts calls on the main thread only, so the import cannot run
## on a thread of its own. Returns an error text or "".
func begin() -> String:
	var error := check_source(source)
	if error.is_empty():
		error = ImportFiles.make_dir(out_dir)
	if error.is_empty():
		error = ImportFiles.write_bytes(out_dir.path_join(UNFINISHED_FILE), source.to_utf8_buffer())
	if not error.is_empty():
		return error
	if village_paths.is_empty():
		village_paths = PackedStringArray([source.path_join("villages/initial.json")])
	var villages := []
	for path in village_paths:
		var village := _load_village(path)
		if village.has("error"):
			return village["error"]
		villages.append(village["value"])
	# The graphics also cover the quest maps, on which the battles of the quests are.
	for name in ImportFiles.files_in(source.path_join("villages/quests"), "json"):
		var path := source.path_join("villages/quests").path_join(name)
		if name.ends_with(".save.json") and not path in village_paths:
			var village := _load_village(path)
			if village.has("error"):
				return village["error"]
			villages.append(village["value"])

	var builder := GameConfigBuilder.new()
	var built := builder.build(source, now)
	messages.append_array(builder.messages)
	if built.has("error"):
		return built["error"]
	var config: Dictionary = built["config"]
	var shop := _load_shop()
	if shop.has("error"):
		return shop["error"]
	for folder: String in ["villages", "quests"]:
		error = ImportFiles.make_dir(out_dir.path_join(folder))
		if not error.is_empty():
			return error
	for write: Array in [["config.json", config, false], ["shop.json", shop, true]]:
		error = ImportFiles.write_json(out_dir.path_join(write[0]), write[1], write[2])
		if not error.is_empty():
			return error
	for path in village_paths:
		error = ImportFiles.copy(path, out_dir.path_join("villages").path_join(path.get_file()))
		if not error.is_empty():
			return error
	var neighbours := _import_neighbours(config)
	if neighbours.has("error"):
		return neighbours["error"]
	villages.append_array(neighbours["value"])
	for name in ImportFiles.files_in(source.path_join("villages/quests"), "json"):
		if name.ends_with(".save.json"):
			error = ImportFiles.copy(source.path_join("villages/quests").path_join(name), out_dir.path_join("quests").path_join(name))
			if not error.is_empty():
				return error

	# A spell hurts at the frame of its graphic with the label "attack".
	var spells := {}
	for spell: Dictionary in config.get("magics", []):
		var graphic: Dictionary = SwfImport.spell_graphic(source.path_join(SPRITE_DIR).path_join("%s.swf" % spell["img_name"]), spell["img_name"])
		if graphic.has("error"):
			failed.append("labels of %s: %s" % [spell["img_name"], graphic["error"]])
			continue
		spells[spell["img_name"]] = graphic["value"]
	error = ImportFiles.write_json(out_dir.path_join("spells.json"), spells, true)
	if not error.is_empty():
		return error

	_version = _code_hash(IMPORT_CODE) + SwfImport.version()
	_graphics = _jobs(_needed_items(config, villages, shop, export_all), spells.keys())
	var music := ImportFiles.files_in(source.path_join(MUSIC_DIR), "mp3")
	var sound_sources := Array(music).map(func(name: String) -> String: return source.path_join(MUSIC_DIR).path_join(name)) + [source.path_join(SOUND_LIBRARY)]
	_parts = [
		["fx/fire_flames.json", _write_fire_flames],
		["windows", _import_part.bind("ui", _import_windows.bind(config, spells.keys()), _windows_record(config, spells.keys()))],
		["player pictures", func() -> void:
			var picture_error := _copy_profile_pictures()
			if not picture_error.is_empty():
				failed.append("player pictures: %s" % picture_error)],
		["sounds", _import_part.bind("sound", _import_sounds.bind(music), {"importer": _version, "sources": sound_sources.map(ImportFiles.stamp)})],
		["mini-game", _import_part.bind("rider_game", _import_rider_game, {"importer": _version, "sources": [ImportFiles.stamp(source.path_join(GAME_SWF))]})],
	]
	total = _graphics.size() + _parts.size()
	return ""


## Imports the next graphic or part. Returns false when there is nothing more
## to do: all is done, or stop_requested is true.
func step() -> bool:
	if stop_requested or done >= total:
		return false
	var text: String
	if done < _graphics.size():
		var job: Array = _graphics[done]
		var result := _import_graphic(job)
		text = job[0]
		if result == "done before":
			skipped += 1
			text += " (done before)"
		elif not result.is_empty():
			failed.append("%s: %s" % [job[0], result])
	else:
		var part: Array = _parts[done - _graphics.size()]
		text = part[0]
		(part[1] as Callable).call()
	done += 1
	on_progress.call(done, total, text)
	return done < total


## Ends the import after step(). Returns "" when it is done, or "stopped".
## A stopped import continues when it runs again into the same folder.
func finish() -> String:
	if done < total:
		return "stopped"
	DirAccess.remove_absolute(out_dir.path_join(UNFINISHED_FILE))
	return ""


## The number of graphics.
func graphic_count() -> int:
	return _graphics.size()


## Writes the places of the flames in each frame of FireMC, see FIRE_SYMBOL.
func _write_fire_flames() -> void:
	var flames: Dictionary = SwfImport.frame_matrices(source.path_join(UiImport.CLIENT_SWF), FIRE_SYMBOL)
	var error: String = flames.get("error", "")
	if error.is_empty():
		error = ImportFiles.write_json_last(out_dir.path_join("fx/fire_flames.json"), {"frames": flames["value"]})
	if not error.is_empty():
		failed.append("fx/fire_flames.json: %s" % error)


## {"value": the save} or {"error": text}.
func _load_village(path: String) -> Dictionary:
	var read := ImportFiles.read_json(path)
	if read.has("error"):
		return read
	var village: Variant = read["value"]
	if not village is Dictionary or not village.get("maps") is Array or village["maps"].is_empty():
		return {"error": "%s: village has no maps" % path}
	return read


## The store rotation: {"factions": {name: [item ids]}, "settings": shop settings}.
## The server offers some of these item groups at a time (GameConfigBuilder);
## the port chooses the groups itself, with the same settings.
func _load_shop() -> Dictionary:
	var rotation := ImportFiles.read_json(source.path_join("config/shop_rotation.json"))
	var server := ImportFiles.read_json(source.path_join("server_config.json"))
	for read in [rotation, server]:
		if read.has("error"):
			return read
	return {"factions": rotation["value"]["factions"], "settings": server["value"]["shop"]}


## int() of Python for an id of the configuration or of a save.
static func _id(value: Variant) -> int:
	return value if value is int else int(value)


## The ids of the items that a save has on its maps, in buildings, in the unit
## warehouse, in training queues, in the item store, in the gifts and in the
## graveyards. The game can put each of them on the map.
static func _save_item_ids(village: Dictionary, ids: Dictionary) -> void:
	var private: Dictionary = village.get("privateState", {})
	for game_map: Dictionary in village["maps"]:
		for entry: Array in game_map["items"]:
			ids[_id(entry[0])] = true
			for unit_id: Variant in entry[6]:
				ids[_id(unit_id)] = true
		for key: String in ["warehousedUnits", "store"]:
			for item_id: Variant in game_map.get(key) if game_map.get(key) else {}:
				ids[_id(item_id)] = true
	var queues: Variant = private.get("barracksQueues")
	for queue: Dictionary in (queues.values() if queues else []):
		if queue.has("unit"):
			ids[_id(queue["unit"])] = true
	for key: String in ["gifts", "deadHeroes", "resurrectableUnits"]:
		for item_id: Variant in private.get(key) if private.get(key) else []:
			ids[_id(item_id)] = true


## The ids of the items that the quests in the town put on the map or give:
## the "legend" and "rewards" of TownQuestBook.QUESTS, and ENEMY_BUILDINGS.
static func _town_quest_item_ids() -> Array:
	var ids := []
	for quest: Dictionary in TownQuestBook.QUESTS.values():
		ids.append_array(quest.get("legend", {}).values())
		ids.append_array(quest.get("rewards", []))
	for buildings: Dictionary in TownQuestBook.ENEMY_BUILDINGS.values():
		ids.append_array(buildings.values())
	return ids


## {img_name: item} for the items whose graphics the import copies.
##
## By default these are the land, the store buildings, all items of the store
## rotation, the units that these buildings train, the trees and deposits, the
## wild animals, the mounted units of the training stables, the items that the
## special buildings and the collections give, the forge island, the items in
## the villages and on the quest maps, the items of the quests in the town, all
## units (bosses and abilities call units that are on no map) and the buildings
## that battles make (BATTLE_BUILDING_IDS).
static func _needed_items(config: Dictionary, villages: Array, shop: Dictionary, all: bool) -> Dictionary:
	var items := {}
	for item: Dictionary in config["items"]:
		items[_id(item["id"])] = item
	var ids := {}
	if all:
		for item_id: int in items:
			ids[item_id] = true
	else:
		for item_id: int in TERRAIN_ITEM_IDS + BATTLE_BUILDING_IDS + MOUNTED_UNIT_IDS + SPECIAL_BUILDING_ITEM_IDS:
			ids[item_id] = true
		for item_id: int in items:
			var item: Dictionary = items[item_id]
			var subcat := GameConfigBuilder.python_str(item["subcat_functional"])
			if (item["type"] == "b" and GameConfigBuilder.python_str(item["in_store"]) != "0") or item["type"] == "u" \
					or subcat in NEUTRAL_RESOURCE_SUBCATS or subcat in TOWN_QUEST_SUBCATS \
					or _id(item.get("breeding_order") if item.get("breeding_order") else 0) > 0:
				ids[item_id] = true
		var cfg_globals: Dictionary = config["globals"]
		for dragon_id: String in cfg_globals["DRAGONS"]:
			ids[_id(dragon_id)] = true
			ids[_id(cfg_globals["DRAGONS"][dragon_id]["tamedId"])] = true
		for item_id: Variant in cfg_globals["COLLECTION_REWARDS"]:
			ids[_id(item_id)] = true
		# The island of the Island Forge (collect_game); its prizes are units.
		var games: Variant = config.get("collect_game")
		for game: Dictionary in (games.values() if games else []):
			ids[_id(game["building_id"])] = true
		for group: Array in shop["factions"].values():
			for item_id: Variant in group:
				ids[_id(item_id)] = true
		for village: Dictionary in villages:
			_save_item_ids(village, ids)
		for item_id: Variant in _town_quest_item_ids():
			ids[_id(item_id)] = true
		for item_id: int in ids.keys():
			if items.has(item_id) and GameConfigBuilder.python_str(items[item_id]["trains"]) != "0":
				ids[_id(items[item_id]["trains"])] = true
	var result := {}
	for item_id: int in ids:
		var item: Variant = items.get(item_id)
		if item != null and item.get("img_name"):
			result[item["img_name"]] = item
	return result


## The graphics to import: [name shown in the progress, SWF file, symbol, output folder, animated].
func _jobs(items: Dictionary, spell_names: Array) -> Array:
	var jobs := []
	var sprite_dir := source.path_join(SPRITE_DIR)
	var names := items.keys()
	names.sort()
	for img_name: String in names:
		jobs.append([img_name, sprite_dir.path_join(img_name + ".swf"), img_name, out_dir.path_join("sprites").path_join(img_name), items[img_name]["type"] == "u"])
	# Each file in assets/fx has one symbol with the name of the file. The
	# client loads them by name; the port maps the shooters to the names.
	for file_name in ImportFiles.files_in(source.path_join("assets/fx"), "swf"):
		jobs.append(_fx_job(source.path_join("assets/fx").path_join(file_name), file_name.get_basename()))
	# The magic particles of the abilities: one frame for each type of particle
	# (MagicParticle of the client), with the clip that plays.
	jobs.append(_fx_job(source.path_join(MAGIC_PARTICLES_SWF), MAGIC_PARTICLES_SYMBOL))
	jobs.append(_fx_job(source.path_join(UiImport.CLIENT_SWF), FIRE_SYMBOL))
	for name: String in CONSTRUCTION_SYMBOLS:
		jobs.append(_fx_job(source.path_join(CONSTRUCTION_SWF), name))
	# The shield of the HUD, in files of their own.
	for name: String in SHIELD_SYMBOLS:
		jobs.append(_fx_job(source.path_join("assets/swf").path_join(name + ".swf"), name))
	for name: String in HOST_SYMBOLS:
		jobs.append(_fx_job(source.path_join(UiImport.CLIENT_SWF), name))
	# The graphics of the spells, which the battles show like the effects.
	var spells := spell_names.duplicate()
	spells.sort()
	for name: String in spells:
		jobs.append(_fx_job(sprite_dir.path_join(name + ".swf"), name))
	return jobs


func _fx_job(swf_path: String, symbol: String) -> Array:
	return ["fx/" + symbol, swf_path, symbol, out_dir.path_join("fx").path_join(symbol), true]


## Copies the SWF file of a graphic to its folder (graphic.swf); the port draws
## the frames from it and reads their bounds, shot points and clips.
## animated: the frames contain clips that play, as in units and in the
## graphics of shots; the client shows nested sprites of buildings on their
## first frame. Returns "" when the graphic is imported, "done before" when
## an earlier run did it, else the error.
func _import_graphic(job: Array) -> String:
	var swf_path: String = job[1]
	var folder: String = job[3]
	if not FileAccess.file_exists(swf_path):
		return "no SWF file"
	var record := {"importer": _version, "source": ImportFiles.stamp(swf_path), "animated": job[4]}
	if ImportFiles.is_done(folder.path_join("meta.json"), "import", record):
		return "done before"
	# Frames of a stopped or older import must not stay next to the new ones.
	ImportFiles.remove_dir(folder)
	var check: Dictionary = SwfImport.check_sprite(swf_path, job[2])
	if check.has("error"):
		return check["error"]
	var error := ImportFiles.make_dir(folder)
	if error.is_empty():
		error = ImportFiles.copy(swf_path, folder.path_join(GRAPHIC_FILE))
	if error.is_empty():
		error = ImportFiles.write_json_last(folder.path_join("meta.json"), {"animated": job[4], "import": record})
	return error


## Imports a part with a record in <out>/<folder>/import.json, when the
## record of an earlier run does not match. work returns an error text or "".
func _import_part(folder: String, work: Callable, record: Dictionary) -> void:
	var record_path := out_dir.path_join(folder).path_join("import.json")
	var key: String = {"ui": "windows", "sound": "sounds", "rider_game": "rider_game"}[folder]
	if ImportFiles.is_done(record_path, key, record):
		messages.append("%s: done before" % folder)
		return
	ImportFiles.remove_dir(out_dir.path_join(folder))
	var error: String = work.call()
	if error.is_empty():
		error = ImportFiles.write_json_last(record_path, {key: record})
	if not error.is_empty():
		failed.append("%s: %s" % [folder, error])


## The record of the windows: the code, the client files and the pictures.
func _windows_record(config: Dictionary, spell_names: Array) -> Dictionary:
	var pictures := _window_pictures(config, spell_names)
	return {"importer": _version, "sources": [ImportFiles.stamp(source.path_join(UiImport.CLIENT_SWF)), ImportFiles.stamp(source.path_join(UiImport.CAST_SWF))],
			"pictures": Array(pictures[0]) + Array(pictures[1])}


## [the pictures of buildingthumbs, the other pictures of images_new] that the windows show.
func _window_pictures(config: Dictionary, spell_names: Array) -> Array:
	# All pictures of buildingthumbs: the windows show the units, and the
	# portrait buttons of the special units show pictures of their attacks.
	var thumbs := ImportFiles.files_in(source.path_join("assets/buildingthumbs"), "jpg")
	var images := PackedStringArray()
	for name: String in spell_names:
		images.append_array([name + ".jpg", "prev_%s.jpg" % name])
	# The goal window shows a picture and a character for each goal.
	var goal_images := {}
	for goal: Dictionary in config.get("goals", []):
		for key: String in ["image", "characters"]:
			var image: Variant = goal.get(key)
			if image is String and not image in ["", "none"] and FileAccess.file_exists(source.path_join("assets/images_new").path_join(image)):
				goal_images[image] = true
	var sorted_goals := PackedStringArray(goal_images.keys())
	sorted_goals.sort()
	images.append_array(sorted_goals)
	images.append_array(_town_quest_pictures())
	images.append_array(_news_pictures(config))
	return [thumbs, images]


func _import_windows(config: Dictionary, spell_names: Array) -> String:
	var pictures := _window_pictures(config, spell_names)
	var result := UiImport.import_ui(source, out_dir, pictures[0], pictures[1])
	if result.has("error"):
		return result["error"]
	messages.append("windows: %d sprites" % result["count"])
	return ""


## The pictures of the window of the quests in the town: the file names in
## TownQuestBook.PICTURES that assets/images_new has.
func _town_quest_pictures() -> PackedStringArray:
	var names := {}
	for race_pictures: Array in TownQuestBook.PICTURES.values():
		for name: String in race_pictures:
			names[name] = true
	var result := PackedStringArray()
	for name: String in names:
		if FileAccess.file_exists(source.path_join("assets/images_new").path_join(name)):
			result.append(name)
	result.sort()
	return result


## The pictures of the news window and of its promotion packs, as paths in
## assets/images_new: the client loads them from the folder that the "images"
## table of the configuration names for each picture.
func _news_pictures(config: Dictionary) -> PackedStringArray:
	var folders: Dictionary = config["images"] if config.get("images") is Dictionary else {}
	var news: Variant = config.get("globals", {}).get("NEWS_ITEM", [])
	var names := {}
	for entry: Variant in (news if news is Array else []):
		if entry is Dictionary and entry.get("news_image") is String:
			names[entry["news_image"]] = true
	for pack: Variant in config.get("offer_packs", []):
		if pack is Dictionary:
			names["offer_pack_%s.png" % GameConfigBuilder.python_str(pack.get("id"))] = true
	var sorted_names := PackedStringArray(names.keys())
	sorted_names.sort()
	var paths := PackedStringArray()
	for name in sorted_names:
		var path: String = "%s/%s" % [folders[name], name] if folders.get(name) else name
		if FileAccess.file_exists(source.path_join("assets/images_new").path_join(path)):
			paths.append(path)
	return paths


## Copies the default player picture and the avatars of the server
## (templates/img/profile/) to <out>/ui/images/profile/. The server sends them
## to the client for the neighbour bar and the attack log
## (NeighbourSource.picture_image()).
func _copy_profile_pictures() -> String:
	return _copy_tree(source.path_join("templates/img/profile"), out_dir.path_join("ui/images/profile"))


## Copies the files of a folder and its subfolders; nothing when it is not there.
static func _copy_tree(from: String, to: String) -> String:
	for name in DirAccess.get_directories_at(from):
		var error := _copy_tree(from.path_join(name), to.path_join(name))
		if not error.is_empty():
			return error
	for name in DirAccess.get_files_at(from):
		var error := ImportFiles.make_dir(to)
		if error.is_empty():
			error = ImportFiles.copy(from.path_join(name), to.path_join(name))
		if not error.is_empty():
			return error
	return ""


## Copies the neighbour villages to <out>/neighbours/<kind>/, and writes the
## mock neighbours (MockVillages) to <out>/neighbours/mock/. As the server
## does with villages/friend_static, a file that is already there stays: the
## port writes the shields and the attack logs of the neighbours that the
## player attacks into these files. The mock villages are made again when
## mock_villages.gd changes (neighbours/mock_generator.json). Returns
## {"value": the saves, whose items need graphics} or {"error": text}.
func _import_neighbours(config: Dictionary) -> Dictionary:
	for kind: String in NEIGHBOUR_FOLDERS:
		var target := out_dir.path_join("neighbours").path_join(kind)
		var error := ImportFiles.make_dir(target)
		if not error.is_empty():
			return {"error": error}
		for folder: String in NEIGHBOUR_FOLDERS[kind]:
			for name in ImportFiles.files_in(source.path_join(folder), "json"):
				if not name.begins_with("initial") and not FileAccess.file_exists(target.path_join(name)):
					error = ImportFiles.copy(source.path_join(folder).path_join(name), target.path_join(name))
					if not error.is_empty():
						return {"error": error}
	var template := ImportFiles.read_json(source.path_join("villages/initial.json"))
	if template.has("error"):
		return template
	var target := out_dir.path_join("neighbours/mock")
	# The mock villages of another version of the generator go away.
	var generator := _code_hash(MOCK_CODE)
	var marker := out_dir.path_join("neighbours/mock_generator.json")
	if not ImportFiles.is_done(marker, "generator", generator):
		ImportFiles.remove_dir(target)
	var error := ImportFiles.make_dir(target)
	if not error.is_empty():
		return {"error": error}
	var mocks := MockVillages.make(config, template["value"])
	if mocks.has("error"):
		return mocks
	for name: String in mocks:
		if not FileAccess.file_exists(target.path_join(name)):
			error = ImportFiles.write_json_last(target.path_join(name), mocks[name])
			if not error.is_empty():
				return {"error": error}
	error = ImportFiles.write_json_last(marker, {"generator": generator})
	if not error.is_empty():
		return {"error": error}
	var saves := []
	var kinds := Array(DirAccess.get_directories_at(out_dir.path_join("neighbours")))
	kinds.sort()
	for kind: String in kinds:
		for name in ImportFiles.files_in(out_dir.path_join("neighbours").path_join(kind), "json"):
			var village := _load_village(out_dir.path_join("neighbours").path_join(kind).path_join(name))
			if village.has("error"):
				return village
			saves.append(village["value"])
	return {"value": saves}


## Copies the music of the client and writes each sound of the library as an MP3 file:
##   <out>/sound/music/<file>.mp3   the music of the client (SoundManager.MUSIC), as it is
##   <out>/sound/sfx/<class>.mp3    each sound of the library, with the name of its class
##                                  (for example ButtonClickSound)
## The library stores the sounds as MP3 frames, which an MP3 file can hold as they are.
func _import_sounds(music: PackedStringArray) -> String:
	var music_dir := out_dir.path_join("sound/music")
	var error := ImportFiles.make_dir(music_dir)
	for name in music:
		if error.is_empty():
			error = ImportFiles.copy(source.path_join(MUSIC_DIR).path_join(name), music_dir.path_join(name))
	if error.is_empty():
		error = _write_sounds(source.path_join(SOUND_LIBRARY), out_dir.path_join("sound/sfx"))
	if error.is_empty():
		messages.append("sounds: %d music files" % music.size())
	return error


## Imports the mini-game of the Dragon Riding and the Rider Academy:
##   <out>/rider_game/game.swf          a copy of the SWF file; the port draws the
##                                      hero, the enemies and the levels from it
##   <out>/rider_game/sounds/<class>.mp3  each sound of the file, with the name of its class
##   <out>/rider_game/ui/...            the skill bar, the health bar and the result
##                                      screens, in the form of UiImport
func _import_rider_game() -> String:
	var game_dir := out_dir.path_join("rider_game")
	var swf_path := source.path_join(GAME_SWF)
	var error := ImportFiles.make_dir(game_dir)
	if error.is_empty():
		error = ImportFiles.copy(swf_path, game_dir.path_join(GAME_FILE))
	if error.is_empty():
		error = _write_sounds(swf_path, game_dir.path_join("sounds"))
	if error.is_empty():
		error = UiImport.import_windows(swf_path, PackedStringArray(GAME_UI_SYMBOLS), game_dir.path_join("ui")).get("error", "")
	return error


## Writes each sound with a class name of a SWF file to <folder>/<class>.mp3.
static func _write_sounds(swf_path: String, folder: String) -> String:
	var sounds: Dictionary = SwfImport.sounds(swf_path)
	if sounds.has("error"):
		return "%s: %s" % [swf_path, sounds["error"]]
	var error := ImportFiles.make_dir(folder)
	for name: String in sounds["value"]:
		if error.is_empty():
			error = ImportFiles.write_bytes(folder.path_join(name + ".mp3"), sounds["value"][name])
	return error


## A hash of the code of the scripts. It leaves out the lines that are only
## comments, so that a change of them alone does not start the import again.
## An exported game can keep its scripts as tokens without the source; then
## the hash is of the tokens.
static func _code_hash(paths: Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		var code := (load(path) as GDScript).source_code
		if code.is_empty():
			context.update(FileAccess.get_file_as_bytes(path.get_basename() + ".gdc"))
		for line in code.split("\n"):
			if not line.strip_edges().begins_with("#"):
				context.update((line + "\n").to_utf8_buffer())
	return context.finish().hex_encode().substr(0, 16)
