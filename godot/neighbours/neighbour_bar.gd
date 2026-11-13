class_name NeighbourBar
extends Control
## The neighbour bar of the client (FriendsWindow and FriendButton) in the
## bottom bar of the HUD: the neighbours sorted by experience, then the host
## of the tutorial, Arthur or Guinevere (Host). It shows SHOWN
## neighbours; the arrows move the list by one or by SHOWN. A click on a
## neighbour opens the menu with "Visit" (PopOverVisit). A neighbour whose
## buildings the player can help has the mark of the client.

signal visit_requested(entry: Dictionary)

const SHOWN := 6
## FriendsWindow: the window is at (-10, -12) in mcFriends, and its buttons are
## 88 pixels apart from x = 29.
const WINDOW_POSITION := Vector2(-10, -12)
const BUTTON_X := 29.0
const BUTTON_Y := 11.0
const BUTTON_STEP := 88.0
## FriendButton grows by 10 % under the mouse.
const HOVER_SCALE := 1.1
const HOVER_SHIFT := Vector2(-4, -5.4)

var _ui: UiLibrary
var _config: GameConfig
var _host: Host
var _window: UiClip
var _buttons: Array[UiClip] = []
var _entries: Array[Dictionary] = []
var _start := 0
var _popover: UiClip


func _init(ui: UiLibrary, config: GameConfig, host: Host) -> void:
	_ui = ui
	_config = config
	_host = host
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window = ui.make("MenuTabFriendsMC")
	_window.position = WINDOW_POSITION
	add_child(_window)
	for pair: Array in [["shiftLeft", -SHOWN], ["oneLeft", -1], ["oneRight", 1], ["shiftRight", SHOWN]]:
		var arrow := _window.clip(pair[0])
		arrow.make_button()
		var step: int = pair[1]
		arrow.pressed.connect(func() -> void:
			_start = clampi(_start + step, 0, maxi(_entries.size() - SHOWN, 0))
			_refresh())
	for index in SHOWN:
		var button := ui.make("FriendButtonMC")
		var place := Vector2(BUTTON_X + BUTTON_STEP * index, BUTTON_Y)
		button.position = place
		button.make_button()
		button.pressed.connect(_open_popover.bind(index))
		button.mouse_entered.connect(func() -> void:
			button.scale = Vector2.ONE * HOVER_SCALE
			button.position = place + HOVER_SHIFT)
		button.mouse_exited.connect(func() -> void:
			button.scale = Vector2.ONE
			button.position = place)
		button.set_part_visible("mcworld", false)
		var picture := TextureRect.new()
		picture.name = "picture"
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.clip("holder").add_child(picture)
		_window.add_child(button)
		_buttons.append(button)


## The entries of the bar, as the client builds them: neighbours (see
## NeighbourSource.neighbours()) sorted by experience, then the host at
## round(1.2 × the level of the player). can_assist(pid) tells whether the
## player can help the neighbour now. Each entry: {"pid", "name", "level",
## "xp", "host", "assist"}.
static func entries(neighbours: Array[Dictionary], village: Village, config: GameConfig, host: Host, now: int, helped: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for neighbour in neighbours:
		result.append({"pid": neighbour["pid"], "name": neighbour["name"], "level": neighbour["level"], "xp": neighbour["xp"], "host": false,
				"assist": village.can_assist(neighbour["pid"], now) and not neighbour["pid"] in helped})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["xp"] < b["xp"])
	var host_level := mini(roundi(village.get_level() * 1.2), config.levels.size() - 1)
	result.append({"pid": host_pid(village.get_level()), "name": host.name(config), "level": host_level,
			"xp": config.levels[host_level].exp_required, "host": true, "assist": false})
	return result


## The client visits one of the three villages of Arthur and Guinevere, by the level of the player.
static func host_pid(level: int) -> String:
	return NeighbourSource.ARTHUR_IDS[0 if level <= 10 else (1 if level <= 20 else 2)]


func show_entries(new_entries: Array[Dictionary]) -> void:
	_entries = new_entries
	_start = clampi(_start, 0, maxi(_entries.size() - SHOWN, 0))
	_refresh()


func _refresh() -> void:
	_close_popover()
	for index in SHOWN:
		var button := _buttons[index]
		var has_entry := _start + index < _entries.size()
		var entry: Dictionary = _entries[_start + index] if has_entry else {}
		button.set_text("friendName", entry.get("name", ""))
		button.set_text("exp", _config.text("AUX_EXP").replace("#0#", str(entry["xp"])) if has_entry else "")
		button.set_text("townSize", "")
		button.set_text("levelStar/levelText", str(entry.get("level", "")))
		button.set_part_visible("levelStar", has_entry)
		button.set_part_visible("mcassist", entry.get("assist", false))
		# The client centres the picture of the host on the holder.
		var picture: TextureRect = button.clip("holder").get_node("picture")
		picture.texture = _ui.image(_host.picture()) if entry.get("host", false) else null
		picture.position = -picture.texture.get_size() / 2 if picture.texture != null else Vector2.ZERO
		button.mouse_filter = Control.MOUSE_FILTER_STOP if has_entry else Control.MOUSE_FILTER_IGNORE
	_set_arrows("shiftLeft", "oneLeft", _start > 0)
	_set_arrows("shiftRight", "oneRight", _start + SHOWN < _entries.size())


## FriendsWindow.disableButton2 shows an arrow that leads nowhere at half alpha.
func _set_arrows(shift: String, one: String, enabled: bool) -> void:
	for name in [shift, one]:
		var arrow := _window.clip(name)
		arrow.modulate.a = 1.0 if enabled else 0.5
		arrow.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


## PopOverVisit at the mouse, with the Visit button; it closes when the mouse leaves it.
func _open_popover(index: int) -> void:
	_close_popover()
	var entry := _entries[_start + index]
	_popover = _ui.make("PopOverVisitMC")
	_popover.position = get_global_mouse_position()
	_popover.set_part_visible("buttonAttack", false)
	_popover.set_part_visible("buttonSendGift", false)
	_popover.set_text("buttonVisit/lbl", _config.text("POPOVER_FRIEND_BUTTON_VISIT"))
	var visit := _popover.clip("buttonVisit")
	visit.make_button(true)
	visit.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # PopOverVisit.visitFriend
		_close_popover()
		visit_requested.emit(entry))
	visit.mouse_exited.connect(_close_popover)
	# Over the HUD, at the place of the mouse on the screen.
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(_popover)
	add_child(layer)


func _close_popover() -> void:
	if _popover != null:
		_popover.get_parent().queue_free()
		_popover = null
