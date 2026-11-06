class_name SurvivalWindow
extends Control
## The survival window of the client (PopupSurvival): the five maps, the lives
## and the button that buys a life. A map shows its picture, its name and the
## best time. The player can choose a map that is open and can be played (the
## first two, see SurvivalMap.PLAYABLE) while they have a life; the other maps
## are white. The mouse over a map shows its rewards by time. The help button
## shows the rules.

signal map_chosen(map_id: String)
signal closed
signal village_changed  ## The player bought a life; the owner saves the village.

## The places of the maps in mcThemes, as in the client.
const MAP_PLACES: Array[Vector2] = [Vector2(0, 0), Vector2(200, 0), Vector2(400, 0), Vector2(100, 180), Vector2(300, 180)]
const HEART_FULL := 0
const HEART_EMPTY := 1
const REWARD_ROW := 70.0
const REWARD_SCALE := 0.75
const REWARDS_LEFT := -294.0
const REWARDS_RIGHT := 102.0
const LOCKED_TINT := Color(1, 1, 1, 0.35)

var _ui: UiLibrary
var _config: GameConfig
var _village: Village
var _now: Callable
var _window: UiClip
var _maps: Array[UiClip] = []
var _rewards: UiClip
var _clock := 0.0


## now returns the time in seconds.
func _init(ui: UiLibrary, config: GameConfig, village: Village, now: Callable) -> void:
	_ui = ui
	_config = config
	_village = village
	_now = now
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupSurvivalMC")
	add_child(_window)
	_window.set_text("txTitle", config.text("POPUP_SURVIVAL_SELECT_MAP"))
	_window.set_text("btBuyLives/txBuyLife", config.text("POPUP_SURVIVAL_BUY_LIFE_FOR"))
	_window.set_text("btBuyLives/txPrice", str(config.survival_life_cash))
	var buy := _window.clip("btBuyLives")
	buy.make_button()
	buy.pressed.connect(_buy_life)
	var close := _window.button("closeButt")
	close.pressed.connect(func() -> void: closed.emit())
	_rewards = _window.clip("mcWin")
	_rewards.set_text("txTitle", config.text("SURVIVAL_SURVIVE_AND_WIN"))
	_rewards.set_text("txMinutes", config.text("SURVIVAL_MINUTES"))
	_rewards.set_text("txUnit", config.text("SURVIVAL_UNIT"))
	_rewards.visible = false
	_rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var help := _window.clip("helpWindow")
	help.visible = false
	help.set_text("txTitle", config.text("POPUP_LOADING_SURVIVAL_TITLE"))
	help.set_text("txSubtitle", config.text("POPUP_LOADING_SURVIVAL_TEXT"))
	help.clip("btnOk").make_button()
	help.clip("btnOk").pressed.connect(func() -> void: help.visible = false)
	_window.button("help").pressed.connect(func() -> void: help.visible = true)
	for i in MAP_PLACES.size():
		_maps.append(_map_button(i))
	_refresh()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		_show_lives()


func _map_button(index: int) -> UiClip:
	var map := _ui.make("SurvivalMapMC")
	map.position = MAP_PLACES[index]
	_window.clip("mcThemes").add_child(map)
	map.set_text("txTheme", _config.text(SurvivalMap.NAMES[index]))
	map.set_text("txDifficult", _config.text("SURVIVAL_AVAILABLE" if index < SurvivalMap.PLAYABLE else "SURVIVAL_COMING_SOON"))
	map.set_part_visible("btUnlock", false)
	map.set_part_visible("infoTxt", index < SurvivalMap.PLAYABLE)
	map.set_part_visible("mcLock", index >= SurvivalMap.PLAYABLE)
	var picture := TextureRect.new()
	picture.texture = _ui.image(SurvivalMap.PICTURES[index])
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if picture.texture != null:
		picture.position = -picture.texture.get_size() / 2
	map.clip("image").add_child(picture)
	var image := map.clip("image")
	image.make_button()
	image.pressed.connect(func() -> void:
		if _can_play(index):
			map_chosen.emit(SurvivalMap.IDS[index]))
	image.mouse_entered.connect(_show_rewards.bind(index))
	image.mouse_exited.connect(func() -> void: _rewards.visible = false)
	return map


## A map can be played when it is one of the first maps, the save has it, and the player has a life.
func _can_play(index: int) -> bool:
	return index < SurvivalMap.PLAYABLE and _village.survival_best_time(SurvivalMap.IDS[index]) >= 0 and _village.survival_lives(_now.call()) > 0


func _refresh() -> void:
	_show_lives()
	for i in _maps.size():
		var best := _village.survival_best_time(SurvivalMap.IDS[i])
		if best >= 0:
			_maps[i].set_text("infoTxt", _config.text("SURVIVAL_BEST_TIME").replace("#0#", time_text(best)))
		_maps[i].clip("image").modulate = Color.WHITE if _can_play(i) else LOCKED_TINT


func _show_lives() -> void:
	var now: int = _now.call()
	var lives := _village.survival_lives(now)
	var many := lives > Village.SURVIVAL_LIVES
	for i in range(1, Village.SURVIVAL_LIVES + 1):
		var heart := _window.clip("life%d" % i)
		heart.visible = i == 1 or not many
		heart.show_frame(HEART_FULL if lives >= i or many else HEART_EMPTY)
	_window.set_part_visible("txLifes", many)
	_window.set_text("txLifes", "x%d" % lives)
	var wait := _village.survival_life_wait(now)
	_window.set_part_visible("txNext", wait > 0)
	if wait > 0:
		_window.set_text("txNext", _config.text("SURVIVAL_NEXT_LIFE").replace("#0#", time_text(wait)))


func _buy_life() -> void:
	if _village.buy_survival_life() != Village.Placement.OK:
		add_child(AlertWindow.new(_ui, _config, _config.text("AVISO_SUFICIENTE_CASH")))
		return
	village_changed.emit()
	_refresh()


## The rewards of the map: a row for each time, with the picture of the unit.
func _show_rewards(index: int) -> void:
	var container := _rewards.clip("mcRewardsUnitsContainer")
	for child in container.get_children():
		child.queue_free()
	var y := 0.0
	for entry: Array in SurvivalMap.REWARDS[index]:
		var row := _ui.make("SurvivalMinRewardMc")
		row.position = Vector2(0, y)
		y += REWARD_ROW
		row.set_text("txMin", _config.text("SURVIVAL_MINUTES_REWARD").replace("#0#", str(entry[1])))
		row.set_part_visible("mcItem/txUnit", false)
		var thumb := TextureRect.new()
		thumb.texture = _ui.thumb(_config.get_item(entry[0]).img_name)
		thumb.scale = Vector2.ONE * REWARD_SCALE
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.clip("mcItem/image").add_child(thumb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(row)
	_rewards.position.x = REWARDS_LEFT if MAP_PLACES[index].x >= 300 else REWARDS_RIGHT
	_rewards.visible = true


## Seconds as the client writes a time: hours, minutes and seconds with two digits.
static func time_text(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]
