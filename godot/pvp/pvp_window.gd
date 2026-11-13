class_name PvpWindow
extends Control
## The PvP window of the client (PopupPvp): the army of the player on pages of
## 4 × 4 places (ArmyUnitCell, the picture of a unit and its count), the
## search for an enemy with its cost in gold, the attack log and the help of
## an attack. The ranking of the client was a web page of the server, so the
## port hides its button. The shields have a window of their own
## (ShieldWindow), which the shield of the HUD opens.

signal search_requested
signal attack_log_requested
signal closed

const BACKGROUND := "popup_elements/popup_pvp/pvp_bg.png"
const SHIELD_PICTURE := "popup_elements/popup_pvp/red_shield.png"
const UNITS_FRAME := "popup_elements/popup_pvp/units_frame.png"
const ARMY_COLUMNS := 4
const ARMY_ROWS := 4
const ARMY_GAP := Vector2(8, 4)
## The size of the Attack Log label that the client shows in Ruffle
## (SpyScreen.grow_label), before the scale of the button in the art (0.86).
const LOG_FONT_SIZE := 19

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip


func _init(ui: UiLibrary, config: GameConfig, village: Village) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupPvpMC")
	add_child(_window)
	_window.show_picture("bg/bgAnchor", ui.image(BACKGROUND), false)
	_window.show_picture("shieldAnchor", ui.image(SHIELD_PICTURE), false)
	_window.show_picture("unitFrameAnchor", ui.image(UNITS_FRAME), false)
	_window.set_part_visible("loadingAnim", false)
	_window.set_part_visible("btnRanking", false)
	var search := _window.clip("btnGetEnemy")
	search.set_text("lbl", config.text("PVP_SEARCH_ENEMY"))
	search.set_text("cost", str(village.pvp_search_cost()))
	search.clip("icon").show_frame(StoreWindow.COST_FRAMES["g"])
	search.make_button(true)
	search.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		search_requested.emit())
	var log_button := _window.clip("btnAttackLog")
	log_button.set_text("lbl", config.text("PVP_ATTACK_LOG"))
	SpyScreen.grow_label(log_button, LOG_FONT_SIZE)
	log_button.make_button(true)
	log_button.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # ButtonGenericTall
		attack_log_requested.emit())
	_window.button("btnHelp").pressed.connect(func() -> void:
		PvpHelp.open(self, _ui, _config, PvpHelp.ATTACK_TIPS, PvpHelp.ATTACK_PICTURES))
	_window.button("btnClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		closed.emit()
		queue_free())
	var pages := Paginator.new(_window.clip("armyAnchor"), _window.clip("butPrev"), _window.clip("butNext"), ARMY_COLUMNS, ARMY_ROWS, ARMY_GAP)
	var cells: Array[Control] = []
	var army := village.quest_army()
	# The client lists the units in the order of their item ids (IsoEngine.getCurrentArmy).
	var ids := army.keys()
	ids.sort()
	for id: int in ids:
		cells.append(PvpWindow.army_cell(ui, config.get_item(id), army[id]))
	pages.show_list(cells)


func _ready() -> void:
	_window.keep_centred()


## The place of a unit in an army (ArmyUnitCell): its picture, 66 pixels
## square, and its count ("x3"), or no count when count is -1.
static func army_cell(ui: UiLibrary, item: GameConfig.ItemDef, count: int) -> UiClip:
	const THUMB_SIZE := 66.0
	var cell := ui.make("ArmyUnitCellMC")
	cell.set_part_visible("qty", count != -1)
	cell.set_text("qty", "x%d" % count)
	var thumb := ui.thumb(item.img_name) if item != null else null
	if thumb != null:
		var picture := cell.show_picture("thumb", thumb, false)
		picture.scale = Vector2(THUMB_SIZE, THUMB_SIZE) / thumb.get_size()
	return cell
