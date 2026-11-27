class_name ImportFiles
## Reads and writes the files of the import. The JSON files are read and
## written as Python's json module does (see SwfImport.parse_json() and
## to_json() of the extension flash_art), so that the files are equal to
## those of the server code.


## {"value": the JSON value of the file} or {"error": text}.
static func read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return {"error": "%s: %s" % [path, error_string(FileAccess.get_open_error())]}
	var result: Dictionary = SwfImport.parse_json(text)
	if result.has("error"):
		return {"error": "%s: %s" % [path, result["error"]]}
	return result


## Writes value as json.dump(value) or, with indent, json.dump(value, indent="\t").
## Returns an error text, or "".
static func write_json(path: String, value: Variant, indent: bool) -> String:
	var json: Dictionary = SwfImport.to_json(value, indent)
	if json.has("error"):
		return "%s: %s" % [path, json["error"]]
	return write_bytes(path, (json["value"] as String).to_utf8_buffer())


## Writes the JSON file that marks a part of the import as done. It is
## written last and replaced in one step, so that a stop never leaves a part
## marked done that is not.
static func write_json_last(path: String, value: Variant) -> String:
	var error := write_json(path + ".tmp", value, true)
	if not error.is_empty():
		return error
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	return "" if result == OK else "%s: %s" % [path, error_string(result)]


static func write_bytes(path: String, data: PackedByteArray) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "%s: %s" % [path, error_string(FileAccess.get_open_error())]
	file.store_buffer(data)
	file.close()
	return "" if file.get_error() == OK else "%s: %s" % [path, error_string(file.get_error())]


static func copy(from: String, to: String) -> String:
	var result := DirAccess.copy_absolute(from, to)
	return "" if result == OK else "%s: %s" % [from, error_string(result)]


static func make_dir(path: String) -> String:
	var result := DirAccess.make_dir_recursive_absolute(path)
	return "" if result == OK else "%s: %s" % [path, error_string(result)]


## Removes a folder with its content; nothing when it is not there.
static func remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_directories():
		remove_dir(path.path_join(name))
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(path)


## The size and the change time of a source file; a changed file is imported again.
static func stamp(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	var size := file.get_length() if file != null else -1
	return [size, FileAccess.get_modified_time(path)]


## True when the JSON file at record_path has record under key, from an earlier run.
static func is_done(record_path: String, key: String, record: Variant) -> bool:
	if not FileAccess.file_exists(record_path):
		return false
	var done := read_json(record_path)
	if not done.has("value") or not done["value"] is Dictionary or not (done["value"] as Dictionary).has(key):
		return false
	return SwfImport.to_json(done["value"][key], false).get("value") == SwfImport.to_json(record, false).get("value")


## The files with the extension in a folder, sorted by name; [] when the folder is not there.
static func files_in(path: String, extension: String) -> PackedStringArray:
	var names := PackedStringArray()
	for name in DirAccess.get_files_at(path):
		if name.get_extension() == extension:
			names.append(name)
	names.sort()
	return names
