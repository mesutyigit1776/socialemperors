class_name SurvivalScreen
extends Node2D
## A survival map on the screen (SurvivalBattle), with the windows of the
## client:
##
## 1. The map shows with the army on it, under the start window
##    (PopupLoadingSurvival) with the rules. The start button uses a life
##    (started) and starts the waves.
## 2. The bar at the top (frame 5 of the bar of the client) shows the time, the
##    enemies killed, the life of the relic and the text of the next wave. The
##    player controls the units as in other battles, uses their portrait
##    buttons and casts spells. Survival has no Withdraw button.
## 3. When the relic is destroyed, the result window shows the time and the
##    reward unit; its OK button gives the result (closed).

signal started
signal closed(seconds: int, reward: int)
signal village_changed  ## A spell changed the mana or the spells; the owner saves the village.

const BAR_FRAME := 4
const STAGE_WIDTH := 760.0
const BAR_POSITION := Vector2(295.9, 50.1)
const ATTACKED_FRAMES := 150  ## The client shows that the relic is attacked for 5 seconds.
const INFO_BLINK_SECONDS := 4.8
const RELIC_BAR := "mcVida/barVida/barraRoja"
const LOST_PICTURE_SCALE := 0.7

var battle: SurvivalBattle
var _village_color: Color  # The colour around the map before this screen.
var _village: Village
var _ui: UiLibrary
var _config: GameConfig
var _view := BattleView.new()
var _camera := MapCamera.new()
var _screen: BattleScreen
var _windows := CanvasLayer.new()
var _bar: UiClip
var _relic_bar_width := 0.0
var _attacked_until := -1
var _shown_info := ""
var _cast_ui: UiLibrary
var _spell_graphics: Dictionary
var _spells := {}


func _init(survival: SurvivalBattle, village: Village, ui: UiLibrary, cast_ui: UiLibrary, spell_graphics: Dictionary, config: GameConfig, sprites: SpriteLibrary, effects: SpriteLibrary) -> void:
	battle = survival
	_village = village
	_ui = ui
	_config = config
	_cast_ui = cast_ui
	_spell_graphics = spell_graphics
	battle.sim.spell_graphics = spell_graphics
	battle.sim.spell_uses = village.spell_uses()
	add_child(_view)
	_view.show_battle(battle.sim, config, sprites, effects, SurvivalMap.LANDS[battle.map.index], battle.map.land_frames())
	_camera.position = IsoGrid.tile_to_map(SurvivalMap.START_TILE)
	add_child(_camera)
	_screen = BattleScreen.new(battle.sim, _view)
	_screen.paused = true
	add_child(_screen)
	_screen.stepped.connect(battle.update)
	battle.changed.connect(_update_bar)
	battle.ended.connect(_show_result)
	battle.sim.hit.connect(func(target: BattleFighter, _attacker: BattleFighter, _damage: int, _critical: bool) -> void:
		if target == battle.relic:
			_attacked_until = battle.sim.frame + ATTACKED_FRAMES
			_update_bar())
	add_child(_windows)


func _ready() -> void:
	_add_start_window()


func _enter_tree() -> void:
	_village_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(QuestScreen.SEA_COLOR)


## The village has the colour of its map style, see VillageView.
func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(_village_color)


func _add_start_window() -> void:
	var cover := _cover()
	var window := _ui.make("PopupLoadingSurvivalMC")
	cover.add_child(window)
	window.position = _screen_size() / 2
	window.set_text("title", _config.text("POPUP_LOADING_SURVIVAL_TITLE"))
	window.set_text("helpText", _config.text("POPUP_LOADING_SURVIVAL_TEXT"))
	var start := window.clip("btnStartBattle")
	start.make_button(true)
	start.pressed.connect(func() -> void:
		cover.queue_free()
		_start())


func _start() -> void:
	started.emit()
	battle.start()
	_bar = _ui.make("GuiMC/barraAttackArriba")
	_bar.show_frame(BAR_FRAME)
	_bar.position = Vector2(_screen_size().x / 2 - STAGE_WIDTH / 2, 0) + BAR_POSITION
	_bar.set_part_visible("nameText", false)
	_bar.set_part_visible("attackedTxt", false)
	_bar.set_text("infoTxt", "")
	var relic_part := _bar.part(RELIC_BAR)
	if relic_part != null:
		_relic_bar_width = relic_part.scale.x
	var picture := TextureRect.new()
	picture.texture = _ui.thumb(battle.relic.def.img_name)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.clip("mcImageSelected").add_child(picture)
	_windows.add_child(_bar)
	var buttons := UnitButtonPanel.new(battle.sim, _ui, _config)
	_screen.selection_changed.connect(buttons.show_selection)
	_windows.add_child(buttons)
	if SpellBook.is_shown(_village):
		var book := SpellBook.new(_ui, _cast_ui, _config, _village, _windows)
		book.cast_on = _cast
		book.marker_layer = _view.under_items()
		book.changed.connect(func() -> void: village_changed.emit())
		add_child(book)
	_screen.paused = false
	_update_bar()


func _process(_delta: float) -> void:
	if _bar != null and _attacked_until >= 0 and battle.sim.frame >= _attacked_until and not battle.relic.dead:
		_attacked_until = -1
		_bar.set_part_visible("attackedTxt", false)


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_text("goldGained", SurvivalWindow.time_text(battle.seconds()))
	_bar.set_text("xpGained", str(battle.kills))
	var relic := battle.relic
	_bar.set_text("mcVida/txVida", "%d/%d" % [maxi(relic.health, 0), relic.max_life()])
	var red := _bar.part(RELIC_BAR)
	if red != null:
		# The client widens the red part of the bar as the relic loses life.
		red.scale.x = _relic_bar_width * (1.0 - float(maxi(relic.health, 0)) / relic.max_life())
	if relic.dead or _attacked_until >= 0:
		_bar.set_part_visible("attackedTxt", true)
		_bar.set_text("attackedTxt", _config.text("SURVIVAL_BEEN_DESTROYED" if relic.dead else "SURVIVAL_BEEN_ATTACKED"))
	if battle.info_text != _shown_info:
		_shown_info = battle.info_text
		_bar.set_text("infoTxt", _shown_info)
		_blink(_bar.part("infoTxt"))


## The client blinks the text of a new wave for a few seconds.
func _blink(part: Control) -> void:
	if part == null:
		return
	var tween := create_tween()
	for i in 3:
		tween.tween_property(part, "modulate:a", 0.8, INFO_BLINK_SECONDS / 6)
		tween.tween_property(part, "modulate:a", 0.2 if i < 2 else 0.0, INFO_BLINK_SECONDS / 6)


func _show_result() -> void:
	_screen.paused = true
	var seconds := battle.seconds()
	var reward := battle.reward()
	var cover := _cover()
	var window := _ui.make("PopupSurvivalResultsMC")
	cover.add_child(window)
	window.position = _screen_size() / 2
	var picture := TextureRect.new()
	picture.texture = _ui.image("aldeana-regalos.png" if reward != 0 else "ataque_perdido.jpg")
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reward == 0:
		picture.scale = Vector2.ONE * LOST_PICTURE_SCALE
	_centre(picture)
	window.clip("foto").add_child(picture)
	window.set_text("txTitle", _config.text("SURVIVAL_RESULT_WIN_TITLE" if reward != 0 else "SURVIVAL_RESULT_LOOSE_TITLE"))
	window.set_text("txInfo", _config.text("SURVIVAL_RESULT_WIN_TEXT" if reward != 0 else "SURVIVAL_RESULT_LOOSE_TEXT"))
	window.set_text("txInfoTime", SurvivalWindow.time_text(seconds))
	window.set_part_visible("t1", false)
	if reward != 0:
		var thumb := TextureRect.new()
		thumb.texture = _ui.thumb(_config.get_item(reward).img_name)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_centre(thumb)
		window.clip("m1").add_child(thumb)
	var ok := window.clip("btnOk")
	ok.set_text("lbl", _config.text("AUX_OK"))
	ok.make_button(true)
	ok.pressed.connect(func() -> void: closed.emit(seconds, reward))


## The client centres the pictures of its windows on their container.
static func _centre(picture: TextureRect) -> void:
	if picture.texture != null:
		picture.position = -picture.texture.get_size() * picture.scale / 2


func _cover() -> ColorRect:
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.size = _screen_size()
	_windows.add_child(cover)
	return cover


func _screen_size() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))


func _cast(spell: GameConfig.SpellDef, tile: Vector2i, level: int) -> void:
	if not _spells.has(spell.id):
		var created := BattleSpell.create(spell, _config, _spell_graphics.get(spell.img_name, {}))
		if created == null:
			return
		_spells[spell.id] = created
		_view.show_spell(created)
	_spells[spell.id].cast(battle.sim, tile, level)
