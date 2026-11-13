class_name ShieldWindow
extends Control
## The window that sells the PvP shields (PopupBuyShields of the client),
## which the shield of the HUD opens. Each shield (ShieldItem) shows its
## picture, its time of protection, its cooldown and its price in cash; a
## shield that the player bought in the cooldown is grey and shows the text
## of an acquired shield instead of its price. The mouse over a shield that
## the player can buy makes it 1.1 times as big. During the cooldown of the
## shields (Village.shield_cooldown_active) all shields are grey, and the
## window shows the time left. A click asks the player to confirm the purchase.

signal buy_requested(shield_id: int)

const BACKGROUND := "PopupBuyShields/background.png"
const SHIELD_PICTURE := "PopupBuyShields/shield_%d.png"
## ShieldItem.WIDTH; the shields are 35 pixels apart.
const SHIELD_WIDTH := 190.0
const SHIELD_GAP := 35.0
const HOVER_SCALE := 1.1
const HOVER_IN_SECONDS := 0.3
const HOVER_OUT_SECONDS := 0.2
## A disabled shield: saturation 0, brightness 1.5 (colorMatrixFilter of TweenMax).
const DISABLED_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 colour = COLOR;
	float light = dot(colour.rgb, vec3(0.3086, 0.6094, 0.082));
	COLOR = vec4(min(vec3(light) * 1.5, vec3(1.0)), colour.a);
}
"""
const SECONDS_PER_DAY := 86400

var _ui: UiLibrary
var _config: GameConfig
var _village: Village
var _window: UiClip
var _now: Callable
var _disabled := ShaderMaterial.new()


## now: gives the time of the game in seconds, for the cooldown.
func _init(ui: UiLibrary, config: GameConfig, village: Village, now: Callable) -> void:
	_ui = ui
	_config = config
	_village = village
	_now = now
	_disabled.shader = Shader.new()
	_disabled.shader.code = DISABLED_SHADER
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupBuyShieldsMC")
	add_child(_window)
	_window.show_picture("bg/bgAnchor", ui.image(BACKGROUND), false)
	_window.set_text("popupTitle", config.text("POPUP_BUY_SHIELDS_TITLE"))
	_window.set_part_visible("popupCover", false)
	_window.button("btnHelp").pressed.connect(func() -> void:
		PvpHelp.open(self, _ui, _config, PvpHelp.SHIELD_TIPS, PvpHelp.SHIELD_PICTURES))
	_window.button("btnClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		queue_free())
	show_shields()


func _ready() -> void:
	_window.keep_centred()


func _process(_delta: float) -> void:
	if _window.part("coolDown").visible:
		_window.set_text("coolDown/remainingTime", _time_text(_village.shield_cooldown_seconds(_now.call())))


## Shows the shields as the village has them now, for example after a purchase.
func show_shields() -> void:
	var now: int = _now.call()
	var cooldown := _village.shield_cooldown_active(now)
	_window.set_text("description", _config.text("POPUP_SHIELDS_DESCRIPTION_COOLDOWN" if cooldown else "POPUP_SHIELDS_DESCRIPTION"))
	_window.set_part_visible("coolDown", cooldown)
	_window.set_text("coolDown/remainingCooldown", _config.text("POPUP_SHIELDS_COOLDOWN_ACTIVE"))
	set_process(cooldown)
	var anchor := _window.part("shieldsAnchor")
	for child in anchor.get_children():
		if child is UiClip:
			child.queue_free()
	var shields := _config.pvp_shields.duplicate()
	shields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for index in shields.size():
		var item := _make_shield(shields[index], cooldown, now)
		item.position.x = index * (SHIELD_WIDTH + SHIELD_GAP)
		anchor.add_child(item)
	if cooldown:
		_process(0)


func _make_shield(shield: Dictionary, cooldown: bool, now: int) -> UiClip:
	var item := _ui.make("PopupBuyShields.ShieldItemMC")
	var owned := not _village.can_buy_shield(shield["id"], now)
	item.show_picture("shieldAnchor", _ui.image(SHIELD_PICTURE % shield["id"]), false)
	item.set_text("protectionTime", _days(shield["protection_time"], shield["protection_time"] > SECONDS_PER_DAY))
	item.set_text("lblProtection", _config.text("POPUP_SHIELDS_PROTECTION"))
	var cooldown_days := roundi(float(shield["cooldown"]) / SECONDS_PER_DAY)
	item.set_text("lblCoolDown", "%s %d %s" % [_config.text("POPUP_SHIELDS_COOLDOWN"), cooldown_days, _config.text("AUX_DAY" if cooldown_days == 1 else "AUX_DAYS")])
	item.set_text("price/lbl", str(shield["price"]))
	item.clip("price/res").show_frame(StoreWindow.COST_FRAMES["c"])
	item.set_part_visible("price", not owned)
	item.set_part_visible("acquired", owned)
	if owned or cooldown:
		item.material = _disabled
		for child in item.find_children("*", "CanvasItem", true, false):
			(child as CanvasItem).use_parent_material = true
		return item
	item.make_button()
	item.pivot_offset = item.bounds().get_center()
	item.mouse_entered.connect(func() -> void: create_tween().tween_property(item, "scale", Vector2.ONE * HOVER_SCALE, HOVER_IN_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT))
	item.mouse_exited.connect(func() -> void: create_tween().tween_property(item, "scale", Vector2.ONE, HOVER_OUT_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT))
	item.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		var question := ConfirmWindow.new(_ui, _config, _config.text("BUY_SHIELD_CONFIRMATION").replace("#0#", _days(shield["protection_time"], shield["protection_time"] > SECONDS_PER_DAY)))
		question.confirmed.connect(func() -> void: buy_requested.emit(shield["id"]))
		add_child(question))
	return item


## The time of protection as ShieldItem shows it: whole days, "Day" or "Days".
func _days(seconds: int, plural: bool) -> String:
	return "%d %s" % [roundi(float(seconds) / SECONDS_PER_DAY), _config.text("AUX_DAYS" if plural else "AUX_DAY")]


## The time left as the client shows it: "2d 03:04:05", without days when there are none.
static func _time_text(seconds: int) -> String:
	var days := seconds / SECONDS_PER_DAY
	var rest := seconds % SECONDS_PER_DAY
	return "%s%02d:%02d:%02d" % ["%dd " % days if days > 0 else "", rest / 3600, rest % 3600 / 60, rest % 60]
