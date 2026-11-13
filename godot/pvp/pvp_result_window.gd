class_name PvpResultWindow
extends Control
## The result window of an attack on another player (PopupPVPFinished of the
## client): the flags, the names and levels of the attacker (the player, on
## the right) and of the defender, the animation of a won or lost attack and
## then the result text, the loot that the player took, its percentage, the
## experience, the honour, and the units that did not come back, on pages of
## 9 × 2 (ArmyUnitCell at 0.9 of its size). The client sends the result to
## the server while the window shows "Saving Results ..." and shows the close
## button after; the port saves when the player closes the window, so it
## shows the close button at once.

signal closed

const BACKGROUND := "popup_elements/popup_end_battle/end_pvp_bg.jpg"
const UNITS_BACKGROUND := "popup_elements/popup_end_battle/bg_units_container.png"
const BLUE_FLAG := "PopupPVPFinished/blue_flag.png"
const RED_FLAG := "PopupPVPFinished/red_flag.png"
const RESOURCE_FIELDS := {"g": "PVPResults/lblGold", "w": "PVPResults/lblWood", "s": "PVPResults/lblStone", "f": "PVPResults/lblFood"}
const MAX_UNITS := 30
const UNITS_PER_ROW := 9
const UNIT_ROWS := 2
const UNIT_GAP := Vector2(9, 3)
const UNIT_SCALE := 0.9
const FRAME_SECONDS := 1.0 / 30.0
## The result text appears 5 frames before the end of the animation, from 0.2
## of its size to its size in 0.3 seconds (Back.easeOut).
const TEXT_FRAMES_BEFORE_END := 5
const TEXT_START_SCALE := 0.2
const TEXT_SECONDS := 0.3

var _window: UiClip
var _animation: UiClip
var _time := 0.0


## result: see PvpBattle.result(). lost: item id -> units that did not come back.
func _init(ui: UiLibrary, config: GameConfig, result: Dictionary, timed_out: bool, lost: Dictionary, honour: int,
		player: Dictionary, enemy: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupPVPFInishedMC")
	add_child(_window)
	_window.set_text("popupTitle", config.text("POPUP_ATAQUE_ACABADO_TITULO"))
	_window.set_part_visible("savingResults", false)
	var won: bool = result["won"]
	var text := won or timed_out
	_window.clip("lblWin").show_frame(1 if text else 0)
	_window.set_text("lblWin/lbl", config.text("POPUP_ATAQUE_ACABADO_RESULTADOS_GANAS" if won else ("POPUP_ATAQUE_ACABADO_RESULTADOS_TIME_EXCEEDED" if timed_out else "POPUP_ATAQUE_ACABADO_RESULTADOS_PIERDES")))
	_window.part("lblWin").visible = false
	_window.set_text("levelText2", str(player["level"]))
	_window.set_text("exp2", str(player["name"]))
	_window.set_text("levelText1", str(enemy["level"]))
	_window.set_text("exp1", str(enemy["name"]))
	_window.set_text("honorPoints", str(honour))
	for code: String in RESOURCE_FIELDS:
		_window.set_text(RESOURCE_FIELDS[code], str(roundi(float(result["loot"][code]))))
	_window.set_text("lblPercentage", "%d%%" % roundi(minf(result["percentage"] * 100, 100)))
	_window.set_text("lblXP", "+%d" % result["xp"])
	_window.show_picture("bg/bgAnchor", ui.image(BACKGROUND), false)
	_window.show_picture("blueFlag", ui.image(BLUE_FLAG), false)
	_window.show_picture("redFlag", ui.image(RED_FLAG), false)
	_window.show_picture("bg_units_container", ui.image(UNITS_BACKGROUND))
	var pages := Paginator.new(_window.clip("UnitsContainer"), _window.clip("bPrevButton"), _window.clip("bNextButton"), UNITS_PER_ROW, UNIT_ROWS, UNIT_GAP)
	var cells: Array[Control] = []
	for id: int in lost:
		if cells.size() >= MAX_UNITS:
			break
		var cell := PvpWindow.army_cell(ui, config.get_item(id), lost[id])
		cell.scale = Vector2.ONE * UNIT_SCALE
		cells.append(cell)
	pages.show_list(cells)
	_window.button("btnClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		closed.emit())
	var animations := ui.other("ui/anim_win" if won else "ui/anim_lose")
	var symbol := "anim_win" if won else "anim_lose"
	if animations != null and animations.has_symbol(symbol):
		_animation = animations.make(symbol)
		_window.part("animation").add_child(_animation)
	set_process(_animation != null)


func _ready() -> void:
	_window.keep_centred()
	if _animation == null:
		_show_text()


func _process(delta: float) -> void:
	_time += delta
	while _time >= FRAME_SECONDS:
		_time -= FRAME_SECONDS
		if _animation.frame + 1 >= _animation.frame_count():
			set_process(false)
			return
		_animation.show_frame(_animation.frame + 1)
		if _animation.frame == _animation.frame_count() - 1 - TEXT_FRAMES_BEFORE_END:
			_show_text()


func _show_text() -> void:
	var text := _window.part("lblWin")
	text.visible = true
	var full := text.scale
	text.scale = full * TEXT_START_SCALE
	create_tween().tween_property(text, "scale", full, TEXT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
