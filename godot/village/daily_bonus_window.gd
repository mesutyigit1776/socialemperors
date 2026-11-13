class_name DailyBonusWindow
extends Control
## The window of the login bonus (PopupNewDailyBonus of the client): the five
## days of the bonus, the days that are over in grey, today with a tick, and
## "Get Reward!" when the reward of today is new, else "Close". The client
## adds the unit of a day to the item store when it opens this window, see
## Village.add_daily_bonus_unit(); the server gave the other rewards.

## The player closed the window. reward is the reward of today when it is new,
## else empty: resource code or "u" -> amount or unit id.
signal closed(reward: Dictionary)

const DAYS_SHOWN := 5
## The client fades the days that are not reached yet and paints the days that
## are over in light grey (colorize 0xEEEEEE).
const UNACTIVE_ALPHA := 0.6
const OLD_COLOUR := Color("eeeeee")
## Frame (from 0) of the background of the Close button (frame 11 of the client).
const CLOSE_BUTTON_FRAME := 10
## The picture of a day fills the loader of the client, 100 x 100 before its
## scale. The parts of the item frame go over it when the frame changes.
const PICTURE_SIZE := Vector2(100, 100)
const GREY_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
void fragment() {
	vec4 colour = texture(TEXTURE, UV);
	float light = dot(colour.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(light * tint.rgb, colour.a);
}
"""

var _window: UiClip
var _reward: Dictionary = {}


## state: Village.start_daily_bonus().
func _init(ui: UiLibrary, config: GameConfig, state: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupNewDailyBonusMC")
	add_child(_window)
	var background := ui.image("DailyBonus/bg.png")
	if background != null:
		var picture := TextureRect.new()
		picture.texture = background
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.clip("bg").add_child(picture)
	var logged: int = state["days_logged"]
	var rewarded: int = state["last_rewarded"]
	var next_day := 1
	for day_reward: Dictionary in config.daily_bonus:
		if day_reward["day"] > rewarded:
			next_day = day_reward["day"]
			break
	var grey := ShaderMaterial.new()
	grey.shader = Shader.new()
	grey.shader.code = GREY_SHADER
	grey.set_shader_parameter("tint", OLD_COLOUR)
	for index in DAYS_SHOWN:
		var item := _window.clip("item%d" % (index + 1))
		if index >= config.daily_bonus.size():
			item.visible = false
			continue
		var day_reward: Dictionary = config.daily_bonus[index]
		var day: int = day_reward["day"]
		var other_day := config.text("POPUP_DAILYBONUS_TOMORROW") if day == logged + 1 else "%s %d" % [config.text("AUX_DAY"), day]
		var picture := _add_picture(ui, item, day_reward["img"])
		if day < logged:
			item.show_label("old")
			item.set_text("lblTitle", "%s %d" % [config.text("POPUP_NEW_DAILY_BONUS_DAY"), day])
			if picture != null:
				picture.material = grey
		elif day == logged:
			item.show_label("today")
			item.set_text("lblTitle", config.text("POPUP_DAILYBONUS_TODAY"))
		elif day == next_day:
			item.show_label("today")
			item.set_part_visible("tick", false)
			item.set_text("lblTitle", other_day)
		else:
			item.show_label("unactive")
			item.set_text("lblTitle", other_day)
			if picture != null:
				picture.modulate.a = UNACTIVE_ALPHA
		if day == logged and logged != rewarded:
			_reward = day_reward["reward"]
	_window.set_part_visible("unitReward", false)
	var get_button := _window.clip("btnGet")
	if _reward.is_empty():
		get_button.set_text("lbl", config.text("AUX_CLOSE"))
		get_button.clip("animatedBg").show_frame(CLOSE_BUTTON_FRAME)
	else:
		get_button.set_text("lbl", config.text("POPUP_NEW_DAILY_BONUS_GET"))
	get_button.make_button()
	get_button.pressed.connect(_close)
	_window.button("btnClose").pressed.connect(_close)
	_window.button("btnHelp").pressed.connect(func() -> void: add_child(AlertWindow.new(ui, config, config.text("POPUP_NEW_DAILY_BONUS_HELP"))))


func _ready() -> void:
	_window.keep_centred()


## The new reward of today, or empty.
func reward() -> Dictionary:
	return _reward


func _add_picture(ui: UiLibrary, item: UiClip, image: String) -> TextureRect:
	var texture := ui.image("DailyBonus/imgs/" + image)
	if texture == null:
		return null
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	picture.size = PICTURE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The loader of the client draws nothing at run time; its image in the
	# SWF file is the white box of the component.
	var anchor := item.clip("img_anchor")
	anchor.visible = false
	picture.position = anchor.position
	picture.scale = anchor.scale
	item.add_child(picture)
	return picture


func _close() -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	closed.emit(_reward)
	queue_free()
