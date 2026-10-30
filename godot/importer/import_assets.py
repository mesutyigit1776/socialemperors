"""Converts the user's original Social Empires files into data for the Godot port.

The port does not contain Social Point files. This tool reads them from a
socialemperors server folder that the user supplies and writes:

  <out>/config.json                  game configuration, as the server sends it
  <out>/shop.json                    item groups of the "New" store rotation and the shop settings of the server
  <out>/sprites/<img_name>/<n>.png   frame n of the item graphic (1-based)
  <out>/sprites/<img_name>/meta.json registration offset and frame count
  <out>/villages/<name>.json         village saves to display

It needs Java and the JPEXS decompiler (ffdec-cli.jar) to render SWF frames.
"""

import argparse
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import tempfile

from swf_bounds import SwfError, SwfFile

TERRAIN_ITEM_IDS = range(1000, 1010)  # 1000 + map skin; see the land graphic in the client
NEUTRAL_RESOURCE_SUBCATS = {"125", "126", "127", "128"}  # trees, stone, gold and their regrowth


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


def needed_items(config, villages, shop, export_all):
	"""Returns {img_name: item} for the items whose graphics must be exported.

	By default these are the land, the store buildings, all items of the store
	rotation, the units that these buildings train, the trees and deposits, and
	the items in the villages.
	"""
	items = {int(item["id"]): item for item in config["items"]}
	if export_all:
		ids = items.keys()
	else:
		ids = set(TERRAIN_ITEM_IDS)
		ids.update(item_id for item_id, item in items.items() if item["type"] == "b" and str(item["in_store"]) != "0")
		ids.update(item_id for item_id, item in items.items() if str(item["subcat_functional"]) in NEUTRAL_RESOURCE_SUBCATS)
		for group in shop["factions"].values():
			ids.update(int(item_id) for item_id in group)
		for village in villages:
			for game_map in village["maps"]:
				ids.update(int(entry[0]) for entry in game_map["items"])
				ids.update(int(unit_id) for entry in game_map["items"] for unit_id in entry[6])
		ids.update(int(items[item_id]["trains"]) for item_id in list(ids) if item_id in items and str(items[item_id]["trains"]) != "0")
	result = {}
	for item_id in ids:
		item = items.get(item_id)
		if item is not None and item.get("img_name"):
			result[item["img_name"]] = item
	return result


def export_frames(jpexs, swf_path, class_name, work_dir):
	"Renders every frame of the exported symbol to PNG. Returns the frame file paths in order."
	command = ["java", "-jar", jpexs] if jpexs.endswith(".jar") else [jpexs]
	command += ["-selectclass", class_name, "-format", "sprite:png", "-export", "sprite", work_dir, swf_path]
	result = subprocess.run(command, capture_output=True, text=True)
	if result.returncode != 0:
		raise RuntimeError(f"JPEXS failed for {swf_path}: {result.stdout[-500:]}{result.stderr[-500:]}")
	suffix = f"_{class_name}"
	folders = [d for d in os.listdir(work_dir) if d.endswith(suffix)]
	if len(folders) != 1:
		raise RuntimeError(f"JPEXS did not export symbol '{class_name}' from {swf_path}")
	folder = os.path.join(work_dir, folders[0])
	frames = sorted((f for f in os.listdir(folder) if f.endswith(".png")), key=lambda f: int(f[:-4]))
	return [os.path.join(folder, f) for f in frames]


def import_sprite(jpexs, swf_path, img_name, out_dir):
	swf = SwfFile(swf_path)
	offset_x, offset_y, _, _ = swf.symbol_offset(img_name)
	frame_sizes = swf.symbol_frame_sizes(img_name)
	with tempfile.TemporaryDirectory() as work_dir:
		frames = export_frames(jpexs, swf_path, img_name, work_dir)
		sprite_dir = os.path.join(out_dir, "sprites", img_name)
		os.makedirs(sprite_dir, exist_ok=True)
		for index, frame in enumerate(frames, start=1):
			shutil.copyfile(frame, os.path.join(sprite_dir, f"{index}.png"))
	if len(frame_sizes) != len(frames):
		raise RuntimeError(f"{swf_path}: JPEXS exported {len(frames)} frames, the SWF has {len(frame_sizes)}")
	meta = {
		"origin_x": offset_x,   # top-left of every PNG relative to the symbol registration point
		"origin_y": offset_y,
		"frame_sizes": frame_sizes,   # [width, height] of each frame as Flash measures it; the client places graphics by it
	}
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

	config = load_game_config(source)
	shop = load_shop(source)
	os.makedirs(os.path.join(out_dir, "villages"), exist_ok=True)
	with open(os.path.join(out_dir, "config.json"), 'w', encoding='utf-8') as f:
		json.dump(config, f)
	with open(os.path.join(out_dir, "shop.json"), 'w', encoding='utf-8') as f:
		json.dump(shop, f, indent='\t')
	for path in village_paths:
		shutil.copyfile(path, os.path.join(out_dir, "villages", os.path.basename(path)))

	sprite_dir = os.path.join(source, "assets", "buildingsprites")
	failed = []
	items = needed_items(config, villages, shop, args.all)

	def import_one(img_name):
		swf_path = os.path.join(sprite_dir, f"{img_name}.swf")
		if not os.path.exists(swf_path):
			return "no SWF file"
		try:
			import_sprite(args.jpexs, swf_path, img_name, out_dir)
		except (SwfError, RuntimeError) as e:
			return str(e)
		return None

	with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
		results = pool.map(import_one, sorted(items))
		for count, (img_name, error) in enumerate(zip(sorted(items), results), start=1):
			if error is not None:
				failed.append((img_name, error))
			print(f"[{count}/{len(items)}] {img_name}", flush=True)

	for img_name, reason in failed:
		print(f"not imported: {img_name}: {reason}", file=sys.stderr)
	print(f"done: {len(items) - len(failed)} sprites in {out_dir}")


if __name__ == "__main__":
	main()
