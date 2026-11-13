class_name AttackLogWindow
extends Control
## The attack log of the client (PopupAttackLog): the attacks on the player,
## newest first, 4 on a page (AttackLogItem). Each shows the name and the level
## of the attacker, the resources that it took, the time since the attack,
## whether the attacker won (btnWinLose), and a button to attack the attacker
## while the player has not answered the attack: "Take Revenge!!" after a
## lost defence, else "Attack". After the last attacks of the list comes the
## end of the log (AttackLogEndItemMC). The client shows the Facebook picture
## of the attacker; the port has none.

signal revenge_requested(attack: Dictionary)
signal closed

const BACKGROUND := "popup_elements/popup_attack_log/attack_log_bg.png"
const PER_PAGE := 4
const GAP := Vector2(8, 6)
## The client shows the end of the log when the last page has fewer than 3 attacks.
const END_LIMIT := 3
## The text of an empty log, in the code of the client (not in the texts).
const EMPTY_TEXT := "You haven't received any attack"
const EMPTY_FONT := "Eras Bold ITC"
const EMPTY_FONT_SIZE := 24
## GameStatic.dhms: the two largest units of the time.
const TIME_UNITS := [[86400, "d"], [3600, "h"], [60, "m"], [1, "s"]]
const TIME_PARTS := 2
const RESOURCE_FIELDS := {"g": "lblGold", "w": "lblWood", "f": "lblFood", "s": "lblStone"}

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip


## now: the time of the game in seconds.
func _init(ui: UiLibrary, config: GameConfig, attacks: Array[Dictionary], player_id: String, now: int) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupAttackLogMC")
	add_child(_window)
	_window.show_picture("bg/bgAnchor", ui.image(BACKGROUND), false)
	_window.button("butClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		closed.emit()
		queue_free())
	var pages := Paginator.new(_window.clip("AttackContainer"), _window.clip("bPrevButton"), _window.clip("bNextButton"), 1, PER_PAGE, GAP)
	pages.set_closing(ui.make("AttackLogEndItemMC"), END_LIMIT)
	var items: Array[Control] = []
	var newest_first := attacks.duplicate()
	newest_first.reverse()
	for attack: Dictionary in newest_first:
		items.append(_make_item(attack, player_id, now))
	var empty: Label = null
	if attacks.is_empty():
		empty = Label.new()
		empty.text = EMPTY_TEXT
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.size.x = ui.make("AttackLogItemMC").bounds().size.x + GAP.x
		empty.add_theme_font_override("font", ui.named_font(EMPTY_FONT))
		empty.add_theme_font_size_override("font_size", EMPTY_FONT_SIZE)
		empty.add_theme_color_override("font_color", Color.BLACK)
	pages.show_list(items, empty)


func _ready() -> void:
	_window.keep_centred()


func _make_item(attack: Dictionary, player_id: String, now: int) -> UiClip:
	var item := _ui.make("AttackLogItemMC")
	item.set_text("lblPlayerName", str(attack.get("name", "")))
	item.set_text("lblLevel", str(attack.get("level", "")))
	var lost: Variant = attack.get("attackResourcesLost")
	for code: String in RESOURCE_FIELDS:
		item.set_text(RESOURCE_FIELDS[code], str(roundi(float(lost.get(code, 0)))) if lost is Dictionary else "0")
	item.set_text("lblStolenResources", _config.text("ATTACK_LOG_STOLEN_RESOURCES"))
	item.set_text("lblTime", AttackLogWindow.time_text(now - int(attack.get("attackTime", now))) + " ago")
	item.set_part_visible("photo/qty", false)
	var attacker_won := str(attack.get("attackWinner")) == str(attack.get("id"))
	item.clip("btnWinLose").show_frame(1 if attacker_won else 0)
	var revenge := item.clip("btnRevenge")
	if int(attack.get("reply", 0)) == 0:
		revenge.fit_text("lbl", _config.text("BUTTON_REVENGE" if attacker_won else "POPOVER_FRIEND_BUTTON_ATTACK"))
		revenge.make_button(true)
		revenge.pressed.connect(func() -> void:
			SoundPlayer.play(SoundEffect.BUTTON_CLICK)
			revenge_requested.emit(attack))
	else:
		revenge.visible = false
	return item


## A time as GameStatic.dhms of the client writes it, for example "2 d 3 h".
static func time_text(seconds: int) -> String:
	var parts: Array[String] = []
	var rest := absi(seconds)
	for unit: Array in TIME_UNITS:
		var count: int = rest / unit[0]
		if count > 0:
			parts.append("%d %s" % [count, unit[1]])
		rest %= unit[0]
	return ("-" if seconds < 0 else "") + " ".join(parts.slice(0, TIME_PARTS))
