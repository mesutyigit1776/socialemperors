extends SceneTree
## Imports the game files from the command line (AssetImport):
##
##   godot --headless --path godot --script res://importer/import_cli.gd -- --source <socialemperors folder> --out <data folder>
##
## Options after "--":
##   --source <folder>   the socialemperors folder (default: the folder above godot/)
##   --out <folder>      the data folder that the port reads (required)
##   --village <file>    a village save to import; can be given more than once
##                       (default: villages/initial.json of the source)
##   --all               import the graphics of all items
##   --time <unix time>  build the configuration for this time, not for now;
##                       the shop rotation and the darts dates depend on it
## The exit code is 0 when the import is done, also when some parts failed
## (the output lists them), and 1 when it stopped with an error.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {"source": ProjectSettings.globalize_path("res://").path_join(".."), "village": PackedStringArray()}
	var index := 0
	while index < args.size():
		var key := args[index].trim_prefix("--")
		if key == "all":
			options["all"] = true
		elif key in ["source", "out", "village", "time"] and index + 1 < args.size():
			index += 1
			if key == "village":
				options["village"].append(args[index])
			else:
				options[key] = args[index]
		else:
			printerr("Unknown option %s; see the top of importer/import_cli.gd." % args[index])
			quit(1)
			return
		index += 1
	if not options.has("out"):
		printerr("Give the data folder: -- --out <folder>")
		quit(1)
		return
	var work := AssetImport.new(options["source"], options["out"])
	work.export_all = options.has("all")
	if options.has("time"):
		work.now = int(options["time"])
	for path: String in options["village"]:
		work.village_paths.append(ProjectSettings.globalize_path(path).simplify_path())
	work.on_progress = func(done: int, total: int, text: String) -> void: print("[%d/%d] %s" % [done, total, text])
	var error := work.run()
	for message in work.messages:
		print(message)
	for failure in work.failed:
		printerr("not imported: %s" % failure)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	print("done: %d graphics in %s, %d of them from an earlier run" % [work.graphic_count(), work.out_dir, work.skipped])
	quit(0)
