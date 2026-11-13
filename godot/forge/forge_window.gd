class_name ForgeWindow
extends Control
## The window of the Island Forge (PopupIslandForge of the client): the six
## forge items with their counters, buttons and waits, the two dragons of the
## prizes, the progress bar with the hammer, the time that is left, and the
## button that buys all missing items. The window does the actions with
## IslandForge; the owner saves the village on changed and opens the other
## screens on the request signals. The window closes when the event ends.

signal changed  ## The forge or the cash changed.
signal pvp_requested
signal islands_requested
signal closed

const PRIZES := 2
## The items in the places item1 to item6 of the window. The client fills the
## places in the order in which it reads its dictionary of the items; in
## Ruffle this order is 4, 5, 6, 1, 2, 3. The picture of a place comes from
## the number of the place (IslandForge/<n>.jpg), not from the item, so the
## client shows, for example, the picture of the copper above the name Skull.
## The order of Flash Player is not known.
const SLOT_ITEMS: Array[int] = [4, 5, 6, 1, 2, 3]
## The client makes a button smaller when the mouse leaves it.
const BUTTON_OUT_SCALE := 0.86
## The box in which the client fits the dragon of a prize (AnimatedUnit).
const DRAGON_BOX := Vector2(400, 300)
## The client calls a page of its own for the invitations; the port cannot invite.
const NO_INVITE := "The port cannot invite friends. You can buy the horns."
const HAMMER_FPS := 30.0

var _forge: IslandForge
var _config: GameConfig
var _ui: UiLibrary
var _window: UiClip
var _items: Dictionary = {}  # Item id -> its place (item1 to item6).
var _bar: UiClip
var _hammer: UiClip
var _clock: Callable


## bar_ui and hammer_ui: the progress bar and the hammer (ui/forge_bar and
## ui/forge_hammer), or null. clock returns the time now.
func _init(ui: UiLibrary, bar_ui: UiLibrary, hammer_ui: UiLibrary, config: GameConfig, sprites: SpriteLibrary, forge: IslandForge, clock: Callable) -> void:
	_forge = forge
	_config = config
	_ui = ui
	_clock = clock
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PoupIslandForgeMC")
	add_child(_window)
	_window.set_part_visible("popupCover", false)
	var background := ui.image("IslandForge/bg.jpg")
	if background != null:
		var picture := TextureRect.new()
		picture.texture = background
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.clip("bg").add_child(picture)
	_window.set_text("popupTitle", config.text("ISLAND_FORGE_TITLE"))
	_window.set_text("lblDescription", config.text("ISLAND_FORGE_DESCRIPTION"))
	_window.set_text("lblRemainingTimeTitle", config.text("ISLAND_FORGE_TIME_REMAINING"))
	_window.button("btnHelp").pressed.connect(func() -> void: _alert(config.text("ISLAND_FORGE_HELP_POPOUP")))
	_window.button("btnClose").pressed.connect(_close)
	for index in mini(PRIZES, forge.prizes().size()):
		_add_prize(index, sprites)
	var buy_all := _window.clip("btnBuyAll")
	buy_all.clip("res").show_frame(StoreWindow.COST_FRAMES["c"])
	_scaled_button(buy_all, _buy_all)
	for index in SLOT_ITEMS.size():
		var entry := forge.item(SLOT_ITEMS[index])
		if not entry.is_empty():
			_items[entry["id"]] = _add_item(_window.clip("item%d" % (index + 1)), entry, index + 1)
	if bar_ui != null and bar_ui.has_symbol("island_progressbar"):
		_bar = bar_ui.make("island_progressbar")
		_window.clip("progressbarAnchor").add_child(_bar)
	if hammer_ui != null and hammer_ui.has_symbol("forge_hammer"):
		_hammer = hammer_ui.make("forge_hammer")
		_hammer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.clip("hammerAnchor").add_child(_hammer)
	_update()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _process(_delta: float) -> void:
	_update()


## The dragon of a prize: its button, and its card, which shows while the
## mouse is over the place of the prize.
func _add_prize(index: int, sprites: SpriteLibrary) -> void:
	var prize: Array = _forge.prizes()[index]
	var unit := _config.get_item(prize[1])
	var area := _window.clip("reward%d" % (index + 1))
	var card := _window.clip("rewardAnchor%d" % (index + 1))
	var get_button := _window.clip("btnGetReward%d" % (index + 1))
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_button.set_text("lbl", _config.text("ISLAND_FORGE_GET_DRAGON"))
	if unit != null:
		card.set_text("lblDragonName", unit.name)
		card.set_text("lblAttack", str(unit.attack))
		card.set_text("lblLife", str(unit.life))
		card.show_picture("anchor", _ui.image("IslandForge/dragonBG.png"))
		var sprite := sprites.get_sprite(unit.img_name)
		if sprite != null:
			card.clip("anchor").add_child(_dragon(sprite))
	area.make_button()
	area.mouse_entered.connect(func() -> void: card.visible = true)
	area.mouse_exited.connect(func() -> void: card.visible = false)
	_scaled_button(get_button, func() -> void:
		if _forge.take_prize(prize[1]) != Village.Placement.OK:
			return
		changed.emit()
		_alert(_config.text("ISLAND_FORGE_REWARD_GIVEN").replace("#0#", unit.name if unit != null else "")))


## The walking dragon, made smaller when it is larger than DRAGON_BOX and
## centred on the anchor.
func _dragon(sprite: SpriteLibrary.ItemSprite) -> UnitSprite:
	var frame := UnitSprite.frame_of(UnitSprite.Action.WALKING, UnitCard.DIRECTION)
	var unit := UnitSprite.new(sprite)
	unit.show_action(UnitSprite.Action.WALKING, UnitCard.DIRECTION)
	var size: Vector2 = sprite.frame_sizes[frame] if frame < sprite.frame_sizes.size() else DRAGON_BOX
	var origin: Vector2 = sprite.frame_origins[frame] if frame < sprite.frame_origins.size() else Vector2.ZERO
	var ratio := maxf(maxf(size.x / DRAGON_BOX.x, size.y / DRAGON_BOX.y), 1.0)
	unit.scale = Vector2.ONE / ratio
	unit.position = -size / ratio / 2 - origin / ratio
	return unit


func _add_item(clip: UiClip, entry: Dictionary, number: int) -> UiClip:
	var item_id: int = entry["id"]
	# The client splits the name at a space of its text key, which has none,
	# so the name has one line at the place of the second line.
	clip.set_text("lblName1", _config.text(entry["name"]))
	clip.set_part_visible("lblName2", false)
	clip.part("lblName1").position.y = clip.part("lblName2").position.y
	clip.show_picture("thumb", _ui.image("IslandForge/%d.jpg" % number), false)
	clip.set_part_visible("btn/res", false)
	for path: String in ["btnBuy/res", "btnSpeedup/res"]:
		clip.clip(path).show_frame(StoreWindow.COST_FRAMES["c"])
	if entry["action"] != "":
		clip.set_text("btn/lbl", _config.text(entry["action"]))
	if entry["action"] == "" and entry["cooldown"] == 0:
		clip.set_part_visible("btn", false)
		clip.part("btnBuy").position.y = clip.part("btn").position.y
	clip.clip("tooltip").show_label("hidden")
	var area := clip.clip("tooltipArea")
	area.make_button()
	area.mouse_entered.connect(func() -> void:
		var tooltip := clip.clip("tooltip")
		tooltip.show_label("right" if area.get_global_rect().position.x < get_viewport_rect().size.x / 2 else "left")
		tooltip.set_text("txtInfo", _config.text(entry["tooltip"])))
	area.mouse_exited.connect(func() -> void: clip.clip("tooltip").show_label("hidden"))
	_scaled_button(clip.clip("btnBuy"), func() -> void: _result(_forge.buy(item_id, _clock.call())))
	_scaled_button(clip.clip("btnSpeedup"), func() -> void: _result(_forge.speed_up(item_id, _clock.call())))
	_scaled_button(clip.clip("btn"), _action.bind(item_id))
	return clip


func _action(item_id: int) -> void:
	match item_id:
		IslandForge.DAILY:
			if _forge.hammer(_clock.call()):
				changed.emit()
				_play_hammer()
		IslandForge.PVP:
			pvp_requested.emit()
		IslandForge.QUEST:
			islands_requested.emit()
		IslandForge.INVITE:
			_alert(NO_INVITE)


## The hammer moves to the end of the progress bar and plays once.
func _play_hammer() -> void:
	if _hammer == null:
		return
	if _bar != null and _bar.clip("anchor") != null:
		_window.clip("hammerAnchor").global_position = _bar.clip("anchor").global_position
	var frames := _hammer.frame_count()
	var tween := create_tween()
	tween.tween_method(func(frame: float) -> void: _hammer.show_frame(int(frame)), 0.0, float(frames - 1), frames / HAMMER_FPS)
	tween.tween_callback(_hammer.show_frame.bind(0))


func _buy_all() -> void:
	if _forge.progress() >= _forge.total():
		return
	if _forge.buy_all().is_empty():
		_no_cash()
		return
	changed.emit()
	_alert(_config.text("ISLAND_FORGE_REWARDS_GIVEN"))


func _result(result: Village.Placement) -> void:
	if result == Village.Placement.NOT_ENOUGH_RESOURCES:
		_no_cash()
	elif result == Village.Placement.OK:
		changed.emit()


## The client offers its cash shop; the port has none.
func _no_cash() -> void:
	_alert(_config.text("AVISO_SUFICIENTE_CASH") + "\n" + VillageHud.NO_CASH_SHOP)


func _alert(text: String) -> void:
	add_child(AlertWindow.new(_ui, _config, text))


## The client makes these buttons BUTTON_OUT_SCALE times smaller while the
## mouse is not over them.
func _scaled_button(clip: UiClip, action: Callable) -> void:
	clip.make_button()
	clip.scale = Vector2.ONE * BUTTON_OUT_SCALE
	clip.pressed.connect(action)
	clip.mouse_entered.connect(func() -> void: clip.scale = Vector2.ONE)
	clip.mouse_exited.connect(func() -> void: clip.scale = Vector2.ONE * BUTTON_OUT_SCALE)


func _update() -> void:
	var now: int = _clock.call()
	var left := maxi(_forge.end - now, 0)
	if left == 0 or not _forge.running(now):
		_close()
		return
	_window.set_text("lblRemainingTimeValue", time_text(left))
	var progress := _forge.progress()
	if _bar != null:
		_bar.show_frame(mini(progress / 10, _bar.frame_count() - 1))
	_window.set_text("lblProgress", "%d/%d" % [progress, _forge.total()])
	var buy_all := _window.clip("btnBuyAll")
	buy_all.set_text("lbl", _config.text("AUX_BUY_NOW").replace("#0#", str(_forge.pack_price())))
	buy_all.visible = progress < _forge.total()
	for index in mini(PRIZES, _forge.prizes().size()):
		var prize: Array = _forge.prizes()[index]
		var given := _forge.prize_given(prize[1])
		_window.set_part_visible("reward%d" % (index + 1), not given)
		_window.set_part_visible("btnGetReward%d" % (index + 1), not given and prize[0] <= progress)
	for item_id: int in _items:
		_update_item(_items[item_id], _forge.item(item_id), now)


func _update_item(clip: UiClip, entry: Dictionary, now: int) -> void:
	var item_id: int = entry["id"]
	var amount := _forge.amount(item_id)
	clip.set_text("counter/lbl", "%d/%d" % [mini(amount, entry["required"]), entry["required"]])
	if amount >= entry["required"]:
		for path: String in ["btnBuy", "btn", "btnSpeedup", "cooldown"]:
			clip.set_part_visible(path, false)
		return
	var price := _forge.price(item_id)
	var wait := _forge.wait_left(item_id, now)
	clip.set_text("btnBuy/lbl", "%s %d" % [_config.text("AUX_COMPRAR"), price])
	clip.set_part_visible("btnBuy", _forge.running(now) and price > 0 and wait == 0)
	clip.set_part_visible("cooldown", wait > 0)
	clip.set_part_visible("btnSpeedup", wait > 0)
	if wait > 0:
		clip.set_part_visible("btn", false)
		clip.set_text("cooldown/lblCooldown", SurvivalWindow.time_text(wait))
		clip.set_text("btnSpeedup/lbl", "%s: %d" % [_config.text("AUX_SPEEDUP"), entry["speedup_cost"]])
	else:
		clip.set_part_visible("btn", entry["action"] != "")


## A time as the client writes it in this window (GameStatic.dhms): the two
## largest of days, hours, minutes and seconds, for example "6 d 23 h".
static func time_text(seconds: int) -> String:
	var parts: Array[String] = []
	for unit: Array in [[86400, "d"], [3600, "h"], [60, "m"], [1, "s"]]:
		var count: int = seconds / unit[0]
		if count > 0:
			parts.append("%d %s" % [count, unit[1]])
		seconds %= unit[0]
	return " ".join(parts.slice(0, 2))


func _close() -> void:
	if is_queued_for_deletion():
		return
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit()
	queue_free()
