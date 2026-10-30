class_name QuestHud
extends Control
## The screen of the client during a quest: the bar at the top with the name of
## the island and the gold and experience that the quest gave so far, the
## counter of the enemies or town halls that are left, and the Withdraw button.
##
## The client builds the screen for a stage 760 pixels wide and places it from
## the bottom-left corner. The port keeps the bar at the same distance from the
## top centre and the button at the same distance from the bottom right. The
## client also builds the counter in its code; its place on the screen is not
## clear from the code, so the port shows it at the top right.

signal withdraw_requested

const BAR_FRAME := 2  ## Frame 3 of the bar is the bar of the quests.
const STAGE_WIDTH := 760.0
const BAR_POSITION := Vector2(295.9, 50.1)  ## From the top-left of the stage.
const EXIT_FROM_BOTTOM_RIGHT := Vector2(83.5, 98.0)
const EXIT_SCALE := Vector2(0.73, 0.75)
const COUNTER_MARGIN := Vector2(20, 12)
const COUNTER_FONT := 7  ## Arial Rounded MT Bold.

var _quest: QuestBattle
var _config: GameConfig
var _bar: UiClip
var _exit: UiClip
var _counter_title := Label.new()
var _counter := Label.new()


func _init(ui: UiLibrary, config: GameConfig, quest: QuestBattle) -> void:
	_quest = quest
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ui.make("GuiMC/barraAttackArriba")
	_bar.show_frame(BAR_FRAME)
	_bar.set_text("nameText", config.text(quest.island.title_text))
	add_child(_bar)
	_exit = ui.make("GuiMC/bgBar/btnExit")
	_exit.scale = EXIT_SCALE
	_exit.set_text("lbl", config.text("AUX_WITHDRAW"))
	_exit.make_button(true)
	_exit.pressed.connect(func() -> void: withdraw_requested.emit())
	add_child(_exit)
	for pair: Array in [[_counter_title, 14], [_counter, 20]]:
		var label: Label = pair[0]
		label.add_theme_font_override("font", ui.font(COUNTER_FONT))
		label.add_theme_font_size_override("font_size", pair[1])
		label.add_theme_color_override("font_color", Color.BLACK)
		# The client draws the counter with a white glow.
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_counter_title.text = config.text("QUEST_CIVILIZACION_ENEMIGOS" if quest.counts_town_halls() else "TIMER_EJERCITO_ENEMIGO")
	quest.changed.connect(_update)
	_update()


func _ready() -> void:
	var screen := get_viewport_rect().size
	_bar.position = Vector2(screen.x / 2 - STAGE_WIDTH / 2, 0) + BAR_POSITION
	_exit.position = screen - EXIT_FROM_BOTTOM_RIGHT
	_counter_title.position = Vector2(screen.x - COUNTER_MARGIN.x - 300, COUNTER_MARGIN.y)
	_counter_title.size.x = 300
	_counter.position = _counter_title.position + Vector2(0, 16)
	_counter.size.x = 300


func _update() -> void:
	_bar.set_text("goldGained", str(_quest.gold))
	_bar.set_text("xpGained", str(_quest.xp))
	var left := _quest.enemies_left()
	if _quest.counts_town_halls():
		_counter.text = _config.text("QUEST_CIVILIZACION_HQ_SINGULAR") if left == 1 else _config.text("QUEST_CIVILIZACION_HQ_PLURAL").replace("#0#", str(left))
	else:
		_counter.text = _config.text("QUEST_ENEMIES_ALIVE_SINGULAR") if left == 1 else _config.text("QUEST_ENEMIES_ALIVE_PLURAL").replace("#0#", str(left))
