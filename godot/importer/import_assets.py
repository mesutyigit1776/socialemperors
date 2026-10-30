"""Converts the user's original Social Empires files into data for the Godot port.

The port does not contain Social Point files. This tool reads them from a
socialemperors server folder that the user supplies and writes:

  <out>/config.json                  game configuration, as the server sends it
  <out>/shop.json                    item groups of the "New" store rotation and the shop settings of the server
  <out>/sprites/<img_name>/<n>.png   frame n of the item graphic (1-based)
  <out>/sprites/<img_name>/meta.json registration offset and frame count
  <out>/sprites/<img_name>/clips/<id>/<n>.png  frame n of an animation of a unit
  <out>/fx/<name>/...                shots and effects of battles, in the same form as the units
  <out>/villages/<name>.json         village saves to display
  <out>/quests/<id>.save.json        maps of the quest islands
  <out>/spells.json                  frame labels of the spell graphics: img_name -> {label: frame}
  <out>/ui/...                       windows of the client, see ui_import.py

It needs Java and the JPEXS decompiler (ffdec-cli.jar) to render SWF frames.
"""

import argparse
import concurrent.futures
import glob
import json
import os
import shutil
import sys
import tempfile

from jpexs import copy_frames, exported_frames, run_jpexs
from swf_bounds import SwfError, SwfFile
from ui_import import import_ui

TERRAIN_ITEM_IDS = range(1000, 1010)  # 1000 + map skin; see the land graphic in the client
NEUTRAL_RESOURCE_SUBCATS = {"125", "126", "127", "128"}  # trees, stone, gold and their regrowth
WILD_ANIMAL_SUBCATS = {"74", "75", "88", "90"}  # cow, sheep, horse and boar; see Village.WILD_ANIMALS
# The units that footmen and archers become in the training stables; see Village.MOUNTED_UNITS.
MOUNTED_UNIT_IDS = {512, 513, 514, 541, 572, 515, 573, 574}
# The units of the dragon and monster nests, the riders of the Rider Academy and
# the free dragon nest and Soul Mixer; see Village.NESTS, RIDER_UNITS and FREE_BUILDING_TILES.
SPECIAL_BUILDING_ITEM_IDS = {638, 649, 651, 684, 698, 695, 717, 713, 742, 653, 822, 823, 824, 1233, 1529}


def load_game_config(source):
	"Returns the game configuration that the server in source sends to the client."
	# get_game_config applies patches, mods and events when it is imported and
	# reads files relative to the working directory. Using it keeps one source
	# of truth for the configuration.
	previous_dir = os.getcwd()
	os.chdir(source)
	sys.path.insert(0, source)
	try:
		import get_game_config
		return get_game_config.get_game_config()
	finally:
		sys.path.remove(source)
		os.chdir(previous_dir)


def load_shop(source):
	"""Returns the store rotation: {"factions": {name: [item ids]}, "settings": shop settings}.

	The server offers some of these item groups at a time (get_game_config.apply_shop_rotation).
	The port chooses the groups itself, with the same settings.
	"""
	with open(os.path.join(source, "config", "shop_rotation.json"), encoding='utf-8') as f:
		factions = json.load(f)["factions"]
	with open(os.path.join(source, "server_config.json"), encoding='utf-8') as f:
		settings = json.load(f)["shop"]
	return {"factions": factions, "settings": settings}


def load_village(path):
	with open(path, encoding='utf-8') as f:
		village = json.load(f)
	if not isinstance(village.get("maps"), list) or not village["maps"]:
		raise ValueError(f"{path}: village has no maps")
	return village


def save_item_ids(village):
	"""Returns the ids of the items that a save has on its maps, in buildings,
	in the unit warehouse, in training queues, in the item store, in the gifts
	and in the graveyards. The game can put each of them on the map."""
	ids = set()
	private = village.get("privateState", {})
	for game_map in village["maps"]:
		ids.update(int(entry[0]) for entry in game_map["items"])
		ids.update(int(unit_id) for entry in game_map["items"] for unit_id in entry[6])
		for key in ("warehousedUnits", "store"):
			ids.update(int(item_id) for item_id in game_map.get(key) or {})
	ids.update(int(queue["unit"]) for queue in (private.get("barracksQueues") or {}).values() if "unit" in queue)
	for key in ("gifts", "deadHeroes"):
		ids.update(int(item_id) for item_id in private.get(key) or {})
	ids.update(int(item_id) for item_id in private.get("resurrectableUnits") or [])
	return ids


def needed_items(config, villages, shop, export_all):
	"""Returns {img_name: item} for the items whose graphics must be exported.

	By default these are the land, the store buildings, all items of the store
	rotation, the units that these buildings train, the trees and deposits, the
	wild animals, the mounted units of the training stables, the items that the
	special buildings and the collections give, and the items in the villages
	and on the quest maps.
	"""
	items = {int(item["id"]): item for item in config["items"]}
	if export_all:
		ids = items.keys()
	else:
		ids = set(TERRAIN_ITEM_IDS)
		ids.update(item_id for item_id, item in items.items() if item["type"] == "b" and str(item["in_store"]) != "0")
		ids.update(item_id for item_id, item in items.items() if str(item["subcat_functional"]) in NEUTRAL_RESOURCE_SUBCATS)
		ids.update(item_id for item_id, item in items.items() if item["type"] == "u" and str(item["subcat_functional"]) in WILD_ANIMAL_SUBCATS)
		ids.update(MOUNTED_UNIT_IDS)
		ids.update(SPECIAL_BUILDING_ITEM_IDS)
		cfg_globals = config["globals"]
		for dragon_id, dragon in cfg_globals["DRAGONS"].items():
			ids.update((int(dragon_id), int(dragon["tamedId"])))
		ids.update(int(item_id) for item_id in cfg_globals["COLLECTION_REWARDS"])
		ids.update(item_id for item_id, item in items.items() if int(item.get("breeding_order") or 0) > 0)
		for group in shop["factions"].values():
			ids.update(int(item_id) for item_id in group)
		for village in villages:
			ids.update(save_item_ids(village))
		ids.update(int(items[item_id]["trains"]) for item_id in list(ids) if item_id in items and str(items[item_id]["trains"]) != "0")
	result = {}
	for item_id in ids:
		item = items.get(item_id)
		if item is not None and item.get("img_name"):
			result[item["img_name"]] = item
	return result


def import_clips(jpexs, swf, swf_path, symbol, sprite_dir):
	"""Exports the clips of a graphic. Returns the meta entries "clips" and "frame_clips"."""
	frame_clips = swf.symbol_frame_clips(symbol)
	clip_ids = sorted({clip[0] for clip in frame_clips if clip is not None})
	clips = {}
	if clip_ids:
		with tempfile.TemporaryDirectory() as work_dir:
			run_jpexs(jpexs, swf_path, ["-selectid", ",".join(map(str, clip_ids))], work_dir)
			for clip_id in clip_ids:
				name = f"DefineSprite_{clip_id}"
				frames = exported_frames(work_dir, lambda d: d == name or d.startswith(name + "_"), f"sprite {clip_id} of {swf_path}")
				copy_frames(frames, os.path.join(sprite_dir, "clips", str(clip_id)))
				offset_x, offset_y = swf.sprite_offset(clip_id)
				clips[str(clip_id)] = {"origin_x": offset_x, "origin_y": offset_y, "frames": len(frames)}
	# The matrix places the clip in the graphic: [a, b, c, d] and the translation in pixels.
	entries = [None if clip is None else [clip[0], *clip[1][:4], clip[1][4] / 20, clip[1][5] / 20] for clip in frame_clips]
	return clips, entries


def import_sprite(jpexs, swf_path, symbol, sprite_dir, animated):
	"""Exports the frames of a symbol to sprite_dir. animated: the frames contain
	clips that play, as in units and in the graphics of shots."""
	swf = SwfFile(swf_path)
	offset_x, offset_y, _, _ = swf.symbol_offset(symbol)
	frame_rects = swf.symbol_frame_rects(symbol)
	with tempfile.TemporaryDirectory() as work_dir:
		run_jpexs(jpexs, swf_path, ["-selectclass", symbol], work_dir)
		frames = exported_frames(work_dir, lambda d: d.endswith(f"_{symbol}"), f"symbol '{symbol}' from {swf_path}")
		copy_frames(frames, sprite_dir)
	if len(frame_rects) != len(frames):
		raise RuntimeError(f"{swf_path}: JPEXS exported {len(frames)} frames, the SWF has {len(frame_rects)}")
	meta = {
		"origin_x": offset_x,   # top-left of every PNG relative to the symbol registration point
		"origin_y": offset_y,
		# The bounds of each frame as Flash measures them: [width, height], and
		# [x, y] of the top-left relative to the registration point. The client
		# places graphics and aims shots by them.
		"frame_sizes": [rect[2:] for rect in frame_rects],
		"frame_origins": [rect[:2] for rect in frame_rects],
		"shot_points": swf.symbol_shot_points(symbol),   # [x, y] where the shots of the frame start, or null
	}
	if animated:
		meta["clips"], meta["frame_clips"] = import_clips(jpexs, swf, swf_path, symbol, sprite_dir)
	with open(os.path.join(sprite_dir, "meta.json"), 'w', encoding='utf-8') as f:
		json.dump(meta, f, indent='\t')


def main():
	repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--source", default=repo_root, help="socialemperors server folder with assets/ and config/")
	parser.add_argument("--out", required=True, help="output folder that the Godot port reads")
	parser.add_argument("--jpexs", required=True, help="path to ffdec-cli.jar or the ffdec start script")
	parser.add_argument("--village", action="append", default=[], help="village save to import (repeatable); default villages/initial.json")
	parser.add_argument("--all", action="store_true", help="export the graphics of every item, not only the land, the store buildings and the items in the villages")
	parser.add_argument("--jobs", type=int, default=4, help="number of JPEXS processes that run at the same time (default 4)")
	args = parser.parse_args()

	source = os.path.abspath(args.source)
	out_dir = os.path.abspath(args.out)
	village_paths = args.village or [os.path.join(source, "villages", "initial.json")]
	villages = [load_village(path) for path in village_paths]
	# The graphics also cover the player saves of the server, so that the port can
	# open each of them, and the quest maps, on which the battles of the quests are.
	other_saves = sorted(glob.glob(os.path.join(source, "saves", "*.save.json")) + glob.glob(os.path.join(source, "villages", "quests", "*.save.json")))
	villages += [load_village(path) for path in other_saves if os.path.abspath(path) not in map(os.path.abspath, village_paths)]

	config = load_game_config(source)
	shop = load_shop(source)
	os.makedirs(os.path.join(out_dir, "villages"), exist_ok=True)
	with open(os.path.join(out_dir, "config.json"), 'w', encoding='utf-8') as f:
		json.dump(config, f)
	with open(os.path.join(out_dir, "shop.json"), 'w', encoding='utf-8') as f:
		json.dump(shop, f, indent='\t')
	for path in village_paths:
		shutil.copyfile(path, os.path.join(out_dir, "villages", os.path.basename(path)))
	os.makedirs(os.path.join(out_dir, "quests"), exist_ok=True)
	for path in glob.glob(os.path.join(source, "villages", "quests", "*.save.json")):
		shutil.copyfile(path, os.path.join(out_dir, "quests", os.path.basename(path)))

	sprite_dir = os.path.join(source, "assets", "buildingsprites")
	# A spell hurts at the frame of its graphic with the label "attack".
	spell_labels = {}
	for spell in config.get("magics", []):
		swf_path = os.path.join(sprite_dir, f"{spell['img_name']}.swf")
		try:
			spell_labels[spell["img_name"]] = SwfFile(swf_path).symbol_frame_labels(spell["img_name"])
		except (SwfError, OSError) as e:
			print(f"not imported: labels of {spell['img_name']}: {e}", file=sys.stderr)
	with open(os.path.join(out_dir, "spells.json"), 'w', encoding='utf-8') as f:
		json.dump(spell_labels, f, indent='\t')
	items = needed_items(config, villages, shop, args.all)
	# Each file in assets/fx has one symbol with the name of the file. The
	# client loads them by name; the port maps the shooters to the names.
	fx_names = sorted(os.path.basename(path)[:-4] for path in glob.glob(os.path.join(source, "assets", "fx", "*.swf")))
	# (name shown in the progress, SWF file, symbol, output folder, animated)
	jobs = [(img_name, os.path.join(sprite_dir, f"{img_name}.swf"), img_name, os.path.join(out_dir, "sprites", img_name), items[img_name]["type"] == "u") for img_name in sorted(items)]
	jobs += [(f"fx/{name}", os.path.join(source, "assets", "fx", f"{name}.swf"), name, os.path.join(out_dir, "fx", name), True) for name in fx_names]

	def import_one(job):
		_, swf_path, symbol, folder, animated = job
		if not os.path.exists(swf_path):
			return "no SWF file"
		try:
			import_sprite(args.jpexs, swf_path, symbol, folder, animated)
		except (SwfError, RuntimeError) as e:
			return str(e)
		return None

	failed = []
	with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
		for count, (job, error) in enumerate(zip(jobs, pool.map(import_one, jobs)), start=1):
			if error is not None:
				failed.append((job[0], error))
			print(f"[{count}/{len(jobs)}] {job[0]}", flush=True)

	unit_thumbs = [f"{img_name}.jpg" for img_name, item in items.items() if item["type"] == "u"]
	try:
		print(f"windows: {import_ui(args.jpexs, source, out_dir, unit_thumbs)} sprites", flush=True)
	except (SwfError, RuntimeError, OSError) as e:
		failed.append(("windows of the client", str(e)))

	for name, reason in failed:
		print(f"not imported: {name}: {reason}", file=sys.stderr)
	print(f"done: {len(jobs) - len(failed)} graphics in {out_dir}")


if __name__ == "__main__":
	main()
