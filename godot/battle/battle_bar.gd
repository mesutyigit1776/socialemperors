class_name BattleBar
extends Control
## The bottom bar of the client in battles (StateAssault and
## StateTournament): the bar of the village with the neighbour bar, the
## pointer, the square tool, Select All and Select Specials, and the zoom
## slider. The store, World and Gift buttons are hidden. The client shows it
## in the quests, survival, the tournament and the PvP attacks, also under
## the start windows.
##
## The bar of the client also holds the panel of the selected units
## (RecuadroInfoNew); the port does not have that panel, see
## docs/PORT_GAPS.md. The quests and the tournament show the Withdraw button
## of the bar (show_withdraw()); the PvP attacks have their own in the attack bar.

## The parts of GuiMC other than the bottom bar, which the battles show in
## their own way or not at all.
const HIDDEN_PARTS := ["topLeft", "topRight", "experienceBar", "cash", "addCashButton", "barraAttackArriba", "questProgressButton",
		"panelCollection", "options_panel"]
## The parts of the bottom bar that StateAssault and StateTournament hide,
## and the parts that the port does not show in the village either (see VillageHud.HIDDEN).
const HIDDEN_BAR_PARTS := ["storeButton", "achievementsButton", "giftButton", "gamesButton", "normalMouse/btnArrow", "btnExit", "returnHome",
		"iconMenu", "iconMenuGift", "iconMenuWorld", "iconMenuGames", "bulldozer", "recolectaRapido", "mcTrolls", "giftCounter", "recuadroInfo"]
## GuiManager.btnMouseOverScale: Select All and Select Specials grow by 5 % under the mouse.
const HOVER_SCALE := 1.05
## The size of the Withdraw label that the client shows in Ruffle
## (SpyScreen.grow_label), before the scale of the button in the art.
const WITHDRAW_FONT_SIZE := 21

var _config: GameConfig
var _gui: UiClip
var _bar: UiClip
var _top_y: Dictionary
var _zoom: ZoomSlider


## neighbours: the neighbour bar, which shows the neighbours of the village
## and opens no menu (NeighbourBar.visits is false).
func _init(ui: UiLibrary, config: GameConfig, neighbours: NeighbourBar, screen: BattleScreen, camera: MapCamera) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_config = config
	_gui = ui.make("GuiMC")
	_top_y = VillageHud.top_positions(_gui)
	for path: String in HIDDEN_PARTS:
		_gui.set_part_visible(path, false)
	var bar := _gui.clip("bgBar")
	_bar = bar
	for path: String in HIDDEN_BAR_PARTS:
		bar.set_part_visible(path, false)
	# The bar takes the clicks, so that a click on it does not reach the map.
	bar.take_mouse()
	bar.set_text("herramientaCuadrado/cuadradoText", config.text("ICON_SQUARE_TOOL"))
	bar.set_part_visible("herramientaCuadrado/spaceKeyText", false)
	_button(bar, "normalMouse/btnNoArrow", func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # GuiManager.returnMouse
		screen.stop_selection_tool())
	_button(bar, "herramientaCuadrado", screen.start_selection_tool)
	for pair: Array in [["btnSelectAll", screen.select_all], ["btnSelectSpecials", screen.select_specials]]:
		var button := bar.part(pair[0])
		_button(bar, pair[0], pair[1])
		button.mouse_entered.connect(func() -> void: button.scale = Vector2.ONE * HOVER_SCALE)
		button.mouse_exited.connect(func() -> void: button.scale = Vector2.ONE)
	bar.part("mcFriends").add_child(neighbours)
	add_child(_gui)
	# The client puts the zoom slider under the bottom bar.
	_zoom = ZoomSlider.new(ui)
	_gui.add_child(_zoom)
	_gui.move_child(_zoom, bar.get_index())
	_zoom.follow(camera)


## Shows the Withdraw button of the bar (bgBar/btnExit) and returns it; its
## pressed signal is the click.
func show_withdraw() -> UiClip:
	var exit := _bar.clip("btnExit")
	exit.visible = true
	exit.set_text("lbl", _config.text("AUX_WITHDRAW"))
	SpyScreen.grow_label(exit, WITHDRAW_FONT_SIZE)
	exit.make_button(true)
	return exit


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport_rect().size
	VillageHud.place_gui(_gui, _top_y, size)
	_zoom.place(size)


func _button(bar: UiClip, path: String, action: Callable) -> void:
	var node := bar.part(path)
	if node is UiButton:
		node.pressed.connect(action)
	elif node is UiClip:
		node.make_button()
		node.pressed.connect(action)
