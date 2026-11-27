class_name JsonPatch
## Applies a JSON patch (RFC 6902) to a value, as the Python package
## jsonpatch does for the server (jsonpatch.apply_patch(doc, patch,
## in_place=True)): the patches of config/patch/ and the mods.

## The end of a list in a path ("-").
const END := "-"


## Applies the operations in order. Returns {"value": the changed document}
## (a new value only when an operation replaces the whole document) or
## {"error": text}; after an error, the operations before it stay applied.
static func apply(document: Variant, patch: Variant) -> Dictionary:
	if not patch is Array:
		return {"error": "a patch must be a list of operations"}
	for operation: Variant in patch:
		var result := _apply_one(document, operation)
		if result.has("error"):
			return result
		document = result["value"]
	return {"value": document}


static func _apply_one(document: Variant, operation: Variant) -> Dictionary:
	if not operation is Dictionary or not operation.has("op") or not operation.has("path") or not operation["path"] is String:
		return {"error": "an operation needs \"op\" and \"path\": %s" % str(operation)}
	var op: Variant = operation["op"]
	var path: String = operation["path"]
	match op:
		"add", "replace", "test":
			if not operation.has("value"):
				return {"error": "the operation %s of %s is missing a value" % [op, path]}
		"move", "copy":
			if not operation.has("from") or not operation["from"] is String:
				return {"error": "the operation %s of %s is missing \"from\"" % [op, path]}
		"remove":
			pass
		_:
			return {"error": "unknown operation %s" % str(op)}
	match op:
		"add":
			return _add(document, path, operation["value"])
		"remove":
			return _remove(document, path)
		"replace":
			return _replace(document, path, operation["value"])
		"test":
			var found := _resolve(document, path)
			if found.has("error"):
				return found
			if not equal(found["value"], operation["value"]):
				return {"error": "the test of %s failed" % path}
			return {"value": document}
	var from: String = operation["from"]
	var value := _resolve(document, from)
	if value.has("error"):
		return value
	if op == "copy":
		return _add(document, path, _copy(value["value"]))
	if from == path:
		return {"value": document}
	if path.begins_with(from + "/"):
		return {"error": "cannot move %s into its own child %s" % [from, path]}
	var removed := _remove(document, from)
	if removed.has("error"):
		return removed
	return _add(removed["value"], path, value["value"])


## {"parent": container of the last token, "key": the last token} or {"error"};
## {"parent": null} for the whole document.
static func _parent(document: Variant, path: String) -> Dictionary:
	var tokens: Variant = _tokens(path)
	if tokens == null:
		return {"error": "the path %s does not start with /" % path}
	if tokens.is_empty():
		return {"parent": null, "key": null}
	var target: Variant = document
	for token: String in tokens.slice(0, tokens.size() - 1):
		var step := _step(target, token, path)
		if step.has("error"):
			return step
		target = step["value"]
	return {"parent": target, "key": tokens[-1]}


static func _resolve(document: Variant, path: String) -> Dictionary:
	var tokens: Variant = _tokens(path)
	if tokens == null:
		return {"error": "the path %s does not start with /" % path}
	var target: Variant = document
	for token: String in tokens:
		var step := _step(target, token, path)
		if step.has("error"):
			return step
		target = step["value"]
	return {"value": target}


static func _step(target: Variant, token: String, path: String) -> Dictionary:
	if target is Dictionary:
		if not target.has(token):
			return {"error": "%s: no member %s" % [path, token]}
		return {"value": target[token]}
	if target is Array:
		var index := _index(token)
		if index < 0 or index >= target.size():
			return {"error": "%s: no index %s" % [path, token]}
		return {"value": target[index]}
	return {"error": "%s: %s is not a list or an object" % [path, token]}


static func _add(document: Variant, path: String, value: Variant) -> Dictionary:
	var place := _parent(document, path)
	if place.has("error"):
		return place
	var parent: Variant = place["parent"]
	if place["key"] == null:
		return {"value": value}
	var key: String = place["key"]
	if parent is Dictionary:
		parent[key] = value
	elif parent is Array:
		if key == END:
			parent.append(value)
		else:
			var index := _index(key)
			if index < 0 or index > parent.size():
				return {"error": "%s: cannot insert outside of the list" % path}
			parent.insert(index, value)
	else:
		return {"error": "%s: the parent is not a list or an object" % path}
	return {"value": document}


static func _remove(document: Variant, path: String) -> Dictionary:
	var place := _parent(document, path)
	if place.has("error"):
		return place
	var parent: Variant = place["parent"]
	if place["key"] == null:
		return {"error": "cannot remove the whole document"}
	var key: String = place["key"]
	if parent is Dictionary and parent.has(key):
		parent.erase(key)
	elif parent is Array and _index(key) >= 0 and _index(key) < parent.size():
		parent.remove_at(_index(key))
	else:
		return {"error": "%s: there is nothing to remove" % path}
	return {"value": document}


static func _replace(document: Variant, path: String, value: Variant) -> Dictionary:
	var place := _parent(document, path)
	if place.has("error"):
		return place
	var parent: Variant = place["parent"]
	if place["key"] == null:
		return {"value": value}
	var key: String = place["key"]
	if parent is Dictionary and parent.has(key):
		parent[key] = value
	elif parent is Array and _index(key) >= 0 and _index(key) < parent.size():
		parent[_index(key)] = value
	else:
		return {"error": "%s: cannot replace a value that is not there" % path}
	return {"value": document}


## The tokens of a JSON pointer, or null when it is not one.
static func _tokens(path: String) -> Variant:
	if path.is_empty():
		return PackedStringArray()
	if not path.begins_with("/"):
		return null
	var tokens := PackedStringArray()
	for token in path.substr(1).split("/"):
		tokens.append(token.replace("~1", "/").replace("~0", "~"))
	return tokens


## The index of a list token, or -1 when it is not one ("0", or a number without a leading zero).
static func _index(token: String) -> int:
	if token == "0" or (token.is_valid_int() and not token.begins_with("0") and not token.begins_with("-") and not token.begins_with("+")):
		return token.to_int()
	return -1


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


## Equality as Python has it for JSON values: 1 == 1.0, and lists and
## objects are equal when their members are.
static func equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float) and not a is bool and not b is bool:
		return a == b
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not equal(a[key], b[key]):
				return false
		return true
	return a == b
