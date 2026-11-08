class_name PvpWindow
extends PanelContainer
## The PvP window of the client (PopupPvp, PopupBuyShields and
## PopupAttackLog): the army, the search for an enemy for gold, the shields
## and the attack log. The ranking of the client was a web page of the
## server, so the port does not have it.

signal search_requested
signal shield_requested(shield_id: int)
signal attack_log_opened

const WIDTH := 520

var _village: Village
var _config: GameConfig
var _content := VBoxContainer.new()


func _init(village: Village, config: GameConfig) -> void:
	_village = village
	_config = config
	custom_minimum_size.x = WIDTH
	add_child(_content)


func _ready() -> void:
	position = (get_viewport_rect().size - Vector2(WIDTH, 0)) / 2 - Vector2(0, 200)


## The main view. now: for the shield times.
func show_main(now: int) -> void:
	_clear()
	_label(_config.text("PVP_ATTACK").strip_edges() + ": attack other players", true)
	var army := _village.quest_army()
	var parts: Array[String] = []
	for id: int in army:
		parts.append("%s ×%d" % [_config.get_item(id).name, army[id]])
	_label("Your army: " + (", ".join(parts) if not parts.is_empty() else "none. Train units first."))
	var cost := _village.pvp_search_cost()
	var search := _button(_content, "%s (%d gold)" % [_config.text("PVP_SEARCH_ENEMY").strip_edges(), cost], func() -> void: search_requested.emit())
	search.disabled = army.is_empty()
	var shield := _village.shield_seconds(now)
	_label("Your shield: %s." % ("protects you for " + VillageHud.duration(shield) if shield > 0 else "none") \
			+ " An attack of your own ends your shield.")
	var shields := HBoxContainer.new()
	for entry: Dictionary in _config.pvp_shields:
		var button := _button(shields, "%s (%d cash)" % [entry["name"], entry["price"]],
				func() -> void:
					SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTallResources
					shield_requested.emit(entry["id"]))
		button.disabled = not _village.can_buy_shield(entry["id"], now)
		button.tooltip_text = "Protects you for %s. Each shield once in %s." % [VillageHud.duration(entry["protection_time"]), VillageHud.duration(entry["cooldown"])]
	_content.add_child(shields)
	var buttons := HBoxContainer.new()
	_button(buttons, _config.text("PVP_ATTACK_LOG").strip_edges(), func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTall
		_show_log())
	_button(buttons, "Close", queue_free)
	_content.add_child(buttons)


func _show_log() -> void:
	attack_log_opened.emit()
	_clear()
	_label(_config.text("PVP_ATTACK_LOG").strip_edges(), true)
	var attacks := _village.attacks_received()
	if attacks.is_empty():
		_label("Nobody attacked you.")
	for attack in attacks:
		var won := str(attack.get("attackWinner")) == str(attack.get("id"))
		var lost: Variant = attack.get("attackResourcesLost")
		_label("%s (level %s) %s. %s" % [attack.get("name", "?"), str(attack.get("level", "?")), "won" if won else "lost",
				Time.get_datetime_string_from_unix_time(int(attack.get("attackTime", 0)), true)] + (" Lost: %s" % str(lost) if lost is Dictionary and not lost.is_empty() else ""))
	var buttons := HBoxContainer.new()
	_button(buttons, "Back", show_main.bind(int(Time.get_unix_time_from_system())))
	_content.add_child(buttons)


func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _label(text: String, title := false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 20
	if title:
		label.add_theme_font_size_override("font_size", 20)
	_content.add_child(label)


func _button(parent: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
