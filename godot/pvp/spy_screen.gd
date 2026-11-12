class_name SpyScreen
extends Node2D
## The village of an enemy that the search found (GameMode.SPY of the
## client). StateSpy shows the spy frame of the attack bar (HudSpyEnemy): the
## name and level of the enemy, the loot, and the buttons My town, Find next
## with its cost in gold, and Attack. Attack emits attack_requested; the owner
## asks about the shield and then opens AssaultStartWindow, as the client does.

signal attack_requested
signal next_requested
signal home_requested

## The client shows the village of the enemy at this zoom (Base.UpdateGame3).
const SPY_ZOOM := 0.5
const BAR_FRAME := 6  ## Frame 7 of the bar (GameMode.SPY) holds hudSpy.
const STAGE_WIDTH := 760.0
## From the top-left of the stage: the bar is at y -489.85 in GuiMC, which
## the client puts at y 475 (600 - 125), and StateNormal moves the top parts
## of the HUD 50 pixels down.
const BAR_POSITION := Vector2(295.95, 35.15)
## StateSpy.adjustScreen puts the three buttons 50 pixels above the bottom of the screen.
const BUTTONS_FROM_BOTTOM := 50.0
const BUTTONS := ["btnAttack", "btnFindNext", "btnMyTown"]
const RESOURCE_FIELDS := {"g": "lblGold", "f": "lblFood", "w": "lblWood", "s": "lblStone"}
## ButtonGenericTall makes the Attack button 0.05 bigger under the mouse.
const ATTACK_HOVER_GROWTH := 0.05
const HOVER_SECONDS := 0.1
const ATTACK_FONT_SIZE := 34
const LABEL_RISE := 5.0

var _view := VillageView.new()
var _camera := MapCamera.new()
var _layer := CanvasLayer.new()
var _bar: UiClip
var _hud: UiClip


## loot: see PvpBattle.loot_of(). next_cost: the gold of the next search.
func _init(enemy: Village, enemy_name: String, loot: Dictionary, next_cost: int, config: GameConfig, ui: UiLibrary, sprites: SpriteLibrary, start_position: Vector2) -> void:
	add_child(_view)
	_view.show_village(enemy, config, sprites)
	_camera.position = start_position
	_camera.set_mode_zoom(SPY_ZOOM)
	add_child(_camera)
	add_child(_layer)
	_layer.add_child(OptionsPanel.for_battle(ui))
	_bar = ui.make("GuiMC/barraAttackArriba")
	_bar.show_frame(BAR_FRAME)
	_layer.add_child(_bar)
	_hud = _bar.clip("hudSpy")
	_hud.set_text("enemyName", enemy_name)
	_hud.set_text("lblDefenderLevel", str(enemy.get_level()))
	for code: String in RESOURCE_FIELDS:
		_hud.set_text("EnemyResources/" + RESOURCE_FIELDS[code], str(loot[code]))
	_hud.set_part_visible("loadingAnim", false)
	var attack := _hud.clip("btnAttack")
	attack.set_text("lbl", config.text("PVP_ATTACK").strip_edges())
	_grow_label(attack)
	attack.make_button()
	attack.pivot_offset = attack.bounds().get_center()
	var normal := attack.scale
	attack.mouse_entered.connect(func() -> void: create_tween().tween_property(attack, "scale", normal + Vector2.ONE * ATTACK_HOVER_GROWTH, HOVER_SECONDS))
	attack.mouse_exited.connect(func() -> void: create_tween().tween_property(attack, "scale", normal, HOVER_SECONDS))
	attack.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		attack_requested.emit())
	var find_next := _hud.clip("btnFindNext")
	find_next.set_text("lbl", config.text("PVP_FIND_NEXT").strip_edges())
	find_next.set_text("cost", str(next_cost))
	find_next.clip("icon").show_frame(StoreWindow.COST_FRAMES["g"])
	find_next.make_button(true)
	find_next.pressed.connect(func() -> void: next_requested.emit())
	var home := _hud.clip("btnMyTown")
	home.make_button()
	home.pressed.connect(func() -> void: home_requested.emit())


func _ready() -> void:
	var screen := get_viewport_rect().size
	_bar.position = Vector2(screen.x / 2 - STAGE_WIDTH / 2, 0) + BAR_POSITION
	for name: String in BUTTONS:
		_hud.part(name).position.y = screen.y - BUTTONS_FROM_BOTTOM - _bar.position.y - _hud.position.y


## ButtonGenericTall.setTextSize makes the font of the label grow until the
## text nearly fills the button; then the label is in the middle, 5 pixels
## higher. The port does not measure text as Flash does, so it uses the size
## that the client shows in Ruffle (ATTACK_FONT_SIZE).
static func _grow_label(button: UiClip) -> void:
	var label: Label = button.part("lbl")
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", ATTACK_FONT_SIZE)
	var font := label.get_theme_font("font")
	# The field of the client grows to both sides of its middle; a Label grows to the right.
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ATTACK_FONT_SIZE).x
	if width > label.size.x:
		label.position.x -= (width - label.size.x) / 2
		label.size.x = width
	var offset: Vector2 = label.get_meta("offset", Vector2.ZERO) * label.scale
	label.position.y = -font.get_height(ATTACK_FONT_SIZE) / 2 - LABEL_RISE + offset.y


## The client changes the bar for the attack when the start window opens.
func hide_bar() -> void:
	_bar.visible = false
