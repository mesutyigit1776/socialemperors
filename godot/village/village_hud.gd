class_name VillageHud
extends CanvasLayer
## The HUD of the village with the art of the client (GuiMC and GuiManager):
## the resources, the experience bar, the cash, the name of the empire, the
## population and the shield at the top; the bottom bar with the neighbours
## (see NeighbourBar) or the panel of the selected item (SelectionPanel), and
## the tools: the normal mouse, the store, the square tool, the World menu
## and the Gift menu. The goal box (GoalBox) is at the left.
##
## The client puts its HUD of 760 pixels in the middle of a full screen, with
## the bottom bar at the bottom and the bars of the top at the top
## (StateNormal.setFullScreen); the port does the same in its window.

signal collections_requested
signal stored_items_requested
signal units_requested
signal news_requested
signal quests_requested
signal survival_requested
signal tournament_requested
signal pvp_requested
## The player opens the town window (the town selector of the client).
signal towns_requested
signal packs_requested
## The player gave the map a new name.
signal rename_requested(new_name: String)
## The next drag on the map selects the units in a box.
signal selection_tool_requested
## The player clicked the normal mouse: the current tool stops.
signal tool_cancelled
## The player clicked a goal of the goal box: its id, or 0 for the goal list.
signal goal_requested(goal_id: int)
## The player used the zoom slider: the zoom of MapCamera that it asks for.
signal zoom_requested(level: float)
## The player clicked the icon of the first purchase offer.
signal first_offer_requested

## The buttons of the client that open the cash shop show this message.
const NO_CASH_SHOP := "The port has no cash shop."
const CLIENT_WIDTH := 760
## The height of the bottom bar, and the y of the HUD in the 600-pixel stage of the client.
const BAR_HEIGHT := 125
## TutorialMain puts its host at this place from the top-left of the stage.
const TUTORIAL_HOST_PLACE := Vector2(0, -190)
const CLIENT_Y := 525
## The parts at the top, which the client moves to the top of a full screen.
const TOP_PARTS := ["experienceBar", "topLeft", "topRight", "barraAttackArriba", "cash", "addCashButton"]
## The parts that the village does not show (StateNormal.enter and
## GuiManager.createButtonsHerramientas); the port has no collection panel,
## map button, fast collect, remove tool or darts.
const HIDDEN := ["barraAttackArriba", "questProgressButton", "panelCollection", "bgBar/btnExit", "bgBar/returnHome",
		"bgBar/iconMenu", "bgBar/iconMenuGift", "bgBar/iconMenuWorld", "bgBar/iconMenuGames", "bgBar/btnSelectAll", "bgBar/btnSelectSpecials",
		"bgBar/bulldozer", "bgBar/recolectaRapido", "bgBar/mcTrolls", "bgBar/giftCounter", "bgBar/normalMouse/btnNoArrow"]
## The y of the panel of the selected item over the neighbours, and below the screen (GuiManager.showRecuadro).
const PANEL_SHOWN_Y := -9.5
const PANEL_HIDDEN_Y := 123.0
const PANEL_SLIDE_SECONDS := 0.2
## The zoom slider is 24 pixels from the right edge of the screen and 200
## pixels above the bottom of the 600-pixel stage of the client (ZoomSlider).
const ZOOM_FROM_RIGHT := 24.0
const ZOOM_FROM_BOTTOM := 200.0
## The icon panel at the right edge (IconPanel of GuiManager.createViralButtons):
## 360 pixels above the HUD of the client, which is BAR_HEIGHT - 75 pixels
## lower than the HUD of the port. Its first icon is at ICON_OFFSET, and the
## mouse over an icon makes it ICON_HOVER_SCALE times larger in 0.2 seconds.
const ICON_PANEL_Y := -360.0 + BAR_HEIGHT - 75.0
const ICON_OFFSET := Vector2(-10, -45)
const ICON_HOVER_SCALE := 1.1
const ICON_FADE_SECONDS := 0.5
## The client shows the shield from level 6 (StateNormal.enter).
const SHIELD_LEVEL := 6
const POPULATION_FULL_COLOUR := Color(0, 0, 1)
const POPULATION_OVER_COLOUR := Color(1, 0, 0)
const MESSAGE_SECONDS := 8.0
## The windows of the HUD are over the spell book of the village (layer 5), as
## the popups of the client are over its magic box, and under the windows of
## the quests (layer 10).
const WINDOW_LAYER := 7
const RESOURCE_NAMES := {"g": "gold", "w": "wood", "s": "stone", "f": "food", "c": "cash", "p": "potions"}
const RESOURCE_FIELDS := [["topLeft/coinText", "g"], ["topLeft/woodText", "w"], ["topLeft/stoneText", "s"], ["topLeft/foodText", "f"], ["cash/dollarText", "c"]]
const PLACEMENT_MESSAGES := {
	Village.Placement.OUTSIDE_MAP: "The item does not fit on the map.",
	Village.Placement.NOT_OWNED_LAND: "You can build only on your own land.",
	Village.Placement.OCCUPIED: "Something is already on this place.",
	Village.Placement.MAX_COUNT_REACHED: "You cannot build more of this building.",
	Village.Placement.HOUSE_LIMIT_REACHED: "Your town hall allows no more houses. Upgrade the town hall to build more.",
	Village.Placement.TOWER_LIMIT_REACHED: "You can build only %d towers for each land area that you own." % ConstructionLimits.MAX_TOWERS_PER_LAND_AREA,
	Village.Placement.LAND_AREA_TOWER_LIMIT_REACHED: "This land area has the maximum number of towers.",
	Village.Placement.LEVEL_TOO_LOW: "Your level is too low for this item.",
	Village.Placement.NOT_ENOUGH_RESOURCES: "You do not have enough resources.",
	Village.Placement.UNKNOWN_RESOURCE: "This item has a cost type that the port does not support yet.",
	Village.Placement.NOT_ALLOWED: "You cannot do this with this item.",
	Village.Placement.POPULATION_FULL: "The population is full. Build houses for more population.",
	Village.Placement.UNIT_LIMIT_REACHED: "You have the maximum number of this unit.",
	Village.Placement.NEIGHBOURS_NEEDED: "This needs more neighbours.",
	Village.Placement.NO_TRADES_LEFT: "The market has no trades left.",
}

var store: StoreWindow
var selection: SelectionPanel
var _goal_box: GoalBox
var _tutorial_host: HostSprite
var _shield_graphics: Array = []  # [shieldEnabled, shieldDisabled], see set_shield_graphics().
var _shield: ShieldSprite
var _shield_enabled := false
var _ui: UiLibrary
var _config: GameConfig
var _gui: UiClip
var _top_y: Dictionary = {}  # Part of TOP_PARTS -> its y in GuiMC.
var _message := Label.new()
var _message_timer := Timer.new()
var _town_quest := Label.new()  # The quest in the town, or the time until the next one.
var _rename_dialog := AcceptDialog.new()
var _rename_edit := LineEdit.new()
var _windows := Control.new()  # The windows of the HUD, see WINDOW_LAYER.
var _menus: Array[String] = ["bgBar/iconMenuWorld", "bgBar/iconMenuGift", "bgBar/iconMenuGames"]
var _locked := false
var _zoom: UiClip
var _zoom_level := 1.0
var _zoom_dragging := false
var _panel_tween: Tween
var _options: OptionsPanel
var _offer_icon: UiClip


func _init(ui: UiLibrary, config: GameConfig) -> void:
	_ui = ui
	_config = config
	_gui = ui.make("GuiMC")
	add_child(_gui)
	_top_y = top_positions(_gui)
	for path: String in HIDDEN:
		_gui.set_part_visible(path, false)
	# The bars take the clicks, so that a click on them does not reach the map.
	for path: String in ["bgBar", "topLeft", "topRight", "experienceBar", "cash"]:
		_gui.clip(path).take_mouse()
	_gui.set_text("bgBar/herramientaCuadrado/cuadradoText", config.text("ICON_SQUARE_TOOL"))
	_gui.set_part_visible("bgBar/herramientaCuadrado/spaceKeyText", false)
	_clip_button("bgBar/normalMouse/btnArrow", func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # GuiManager.returnMouse
		_close_menus()
		tool_cancelled.emit())
	_clip_button("bgBar/storeButton", _open_store)
	_clip_button("bgBar/herramientaCuadrado", func() -> void:
		_close_menus()
		if not _locked:
			selection_tool_requested.emit())
	_clip_button("bgBar/achievementsButton", _toggle_menu.bind("bgBar/iconMenuWorld"))
	_clip_button("bgBar/giftButton", _toggle_menu.bind("bgBar/iconMenuGift"))
	_clip_button("bgBar/gamesButton", _toggle_menu.bind("bgBar/iconMenuGames"))
	# The World menu; the client of 1.4.07 hides survival, which the port has.
	for entry: Array in [["questButton", "questText", "ICON_MENU_WORLD_QUEST", quests_requested], ["pvpButton", "#text", "", pvp_requested],
			["tournamentButton", "tournamentText", "ICON_MENU_WORLD_TOURNEY", tournament_requested], ["survivalButton", "survivalText", "ICON_MENU_WORLD_SURVIVAL", survival_requested]]:
		_menu_entry("bgBar/iconMenuWorld", entry)
	# The Gift menu: the item store, the collections, the unit list and the news.
	for entry: Array in [["giftButton", "giftsText", "ICON_MENU_GIFT_GIFTS", stored_items_requested], ["colButton", "colText", "ICON_MENU_GIFT_COLLECTIONS", collections_requested],
			["unitsButton", "unitsText", "ICON_MENU_GIFT_UNITS", units_requested], ["newsButton", "newsText", "ICON_MENU_GIFT_NEWS", news_requested]]:
		_menu_entry("bgBar/iconMenuGift", entry)
	# The town selector of the client is in the menu of the games, without the darts.
	_menu_entry("bgBar/iconMenuGames", ["herramientaSelectorMundo", "txtSelectorMundo", "", towns_requested])
	for path: String in ["bgBar/iconMenuGames/herramientaDarts", "bgBar/iconMenuGames/dartsText"]:
		_gui.set_part_visible(path, false)
	_clip_button("addCashButton", func() -> void: show_message(NO_CASH_SHOP))
	var name_field := _gui.part("topRight/nameText")
	name_field.mouse_filter = Control.MOUSE_FILTER_STOP
	name_field.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _locked:
			open_rename())
	_clip_button("topRight/hudShield", func() -> void: pvp_requested.emit())
	_options = OptionsPanel.new(ui, _gui, _gui.clip("options_panel"))
	add_child(_options)
	# The client puts the zoom slider under the bottom bar.
	_zoom = ui.make("ZoomSliderMC")
	_gui.add_child(_zoom)
	_gui.move_child(_zoom, _gui.part("bgBar").get_index())
	for pair: Array in [["zoomIn", MapCamera.ZOOM_STEP], ["zoomOut", 1.0 / MapCamera.ZOOM_STEP]]:
		var step: float = pair[1]
		var button := _zoom.clip(pair[0])
		button.make_button()
		button.pressed.connect(func() -> void:
			if not _locked:
				zoom_requested.emit(_zoom_level * step))
	_zoom.clip("slider").make_button()
	_zoom.clip("slider").gui_input.connect(_on_zoom_drag)
	selection = SelectionPanel.new(ui, config, _windows)
	_gui.clip("bgBar/recuadroInfo").add_child(selection)
	_gui.clip("bgBar/recuadroInfo").position.y = PANEL_HIDDEN_Y
	_gui.clip("bgBar/recuadroInfo").take_mouse()
	# The town quest uses the troll timer of the client (trollTimerMC), which
	# 1.4.07 does not show; see TownQuests.
	_town_quest.add_theme_font_override("font", ui.named_font(ClientTheme.BODY_FONT))
	_town_quest.add_theme_font_size_override("font_size", 12)
	_town_quest.add_theme_color_override("font_color", Color.WHITE)
	_town_quest.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0, 1))
	_town_quest.add_theme_constant_override("outline_size", 4)
	_town_quest.position = Vector2(-2, -24)
	_town_quest.custom_minimum_size.x = 150
	_town_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gui.clip("bgBar/mcTrolls").add_child(_town_quest)
	_gui.set_part_visible("bgBar/mcTrolls/buf", false)
	_goal_box = GoalBox.new(ui, config)
	_goal_box.goal_requested.connect(func(id: int) -> void: goal_requested.emit(id))
	_goal_box.list_requested.connect(func() -> void: goal_requested.emit(0))
	add_child(_goal_box)
	move_child(_goal_box, 0)
	_message.add_theme_font_override("font", ui.named_font(ClientTheme.BODY_FONT))
	_message.add_theme_font_size_override("font_size", 15)
	_message.add_theme_color_override("font_color", Color.WHITE)
	_message.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0, 1))
	_message.add_theme_constant_override("outline_size", 5)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func() -> void: _message.visible = false)
	add_child(_message_timer)
	store = StoreWindow.new(ui, config)
	store.blocked.connect(show_placement_result)
	store.packs_requested.connect(func() -> void: packs_requested.emit())
	store.stored_items_requested.connect(func() -> void: stored_items_requested.emit())
	_windows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var window_layer := CanvasLayer.new()
	window_layer.layer = WINDOW_LAYER
	window_layer.add_child(_windows)
	add_child(window_layer)
	visibility_changed.connect(func() -> void: window_layer.visible = visible)
	_windows.add_child(store)
	_rename_dialog.title = "Name of your empire"
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.confirmed.connect(func() -> void: rename_requested.emit(_rename_edit.text))
	add_child(_rename_dialog)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


## The node of the bottom bar in which the neighbour bar goes (mcFriends of the client).
func neighbour_anchor() -> Control:
	return _gui.part("bgBar/mcFriends")


## The node for the windows that belong to the HUD, over its bars.
func windows() -> Control:
	return _windows


## The y of the parts of TOP_PARTS in a new GuiMC, for place_gui().
static func top_positions(gui: UiClip) -> Dictionary:
	var result := {}
	for name: String in TOP_PARTS:
		result[name] = gui.part(name).position.y
	return result


## Puts GuiMC where the client puts it on a full screen of this size: the
## bottom bar at the bottom and the parts of TOP_PARTS at the top.
static func place_gui(gui: UiClip, top_y: Dictionary, size: Vector2) -> void:
	gui.position = Vector2(roundf(size.x / 2 - CLIENT_WIDTH / 2.0), size.y - BAR_HEIGHT)
	var shift := CLIENT_Y - gui.position.y
	for name: String in TOP_PARTS:
		gui.part(name).position.y = top_y[name] + shift
	gui.part("bgBar").position.y = 0


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	place_gui(_gui, _top_y, size)
	_options.place(size)
	_zoom.position = Vector2(size.x - ZOOM_FROM_RIGHT, size.y - ZOOM_FROM_BOTTOM) - _gui.position
	if _offer_icon != null:
		_offer_icon.position = Vector2(size.x - _gui.position.x, ICON_PANEL_Y) + ICON_OFFSET
	_message.position = Vector2(_gui.position.x + 60, size.y - BAR_HEIGHT - 70)
	_message.size = Vector2(CLIENT_WIDTH - 120, 60)
	if _tutorial_host != null:
		_tutorial_host.position = Vector2(_gui.position.x, 0) + TUTORIAL_HOST_PLACE


## Shows the icon of the first purchase offer (viralFirstOffer) in the icon
## panel, under the other parts of the HUD as in the client.
func show_first_offer(icon: UiClip) -> void:
	_offer_icon = icon
	# The SWF file of the icon has only the letters of its sample text; the
	# client writes the text with the font of its own file (TextFieldUtil.setHTML).
	var timer := icon.part("timer")
	if timer != null:
		timer.add_theme_font_override("font", _ui.named_font(ClientTheme.BODY_FONT))
	_gui.add_child(icon)
	_gui.move_child(icon, 0)
	icon.make_button()
	icon.pressed.connect(func() -> void:
		if not _locked:
			first_offer_requested.emit())
	for pair: Array in [["mouse_entered", ICON_HOVER_SCALE], ["mouse_exited", 1.0]]:
		var target: float = pair[1]
		icon.connect(pair[0], func() -> void: create_tween().tween_property(icon, "scale", Vector2(target, target), 0.2))
	_layout()


## The text of the icon: "open me" or the time that is left.
func set_first_offer_text(text: String) -> void:
	if _offer_icon != null:
		_offer_icon.set_text("timer", text)


## The client fades the icon out after the purchase (IconPanel.removeIcon).
func remove_first_offer() -> void:
	if _offer_icon == null:
		return
	var icon := _offer_icon
	_offer_icon = null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(icon, "modulate:a", 0.0, ICON_FADE_SECONDS).finished.connect(icon.queue_free)


func _clip_button(path: String, action: Callable) -> void:
	var node := _gui.part(path)
	if node is UiButton:
		node.pressed.connect(action)
	elif node is UiClip:
		node.make_button()
		node.pressed.connect(action)


## [button, text field, text name or "", signal] of a menu of the bar.
func _menu_entry(menu: String, entry: Array) -> void:
	var requested: Signal = entry[3]
	_clip_button("%s/%s" % [menu, entry[0]], func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # GuiManager.returnMouse
		_close_menus()
		if not _locked:
			requested.emit())
	if not (entry[2] as String).is_empty():
		_gui.set_text("%s/%s" % [menu, entry[1]], _config.text(entry[2]))


func _toggle_menu(menu: String) -> void:
	var shown := not _gui.part(menu).visible
	if not shown:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)  # The client clicks when its button closes a menu.
	_close_menus()
	_gui.set_part_visible(menu, shown and not _locked)


func _close_menus() -> void:
	for menu in _menus:
		_gui.set_part_visible(menu, false)


## The store opens also in the tutorial, whose steps build; main.gd allows only the items of the step.
func _open_store() -> void:
	_close_menus()
	store.open()


## Updates the resources, the experience, the population and the store.
func refresh(village: Village) -> void:
	for field: Array in RESOURCE_FIELDS:
		_gui.set_text(field[0], formatted(village.get_resource(field[1])))
	var level := village.get_level()
	var next_xp := village.get_next_level_xp()
	var start_xp := _config.levels[level - 1].exp_required if level >= 1 and level - 1 < _config.levels.size() else 0
	_gui.set_text("experienceBar/levelText", str(level))
	_gui.set_text("experienceBar/exp", "%d/%d" % [village.get_xp(), next_xp] if next_xp >= 0 else str(village.get_xp()))
	var bar := _gui.clip("experienceBar/expMask")
	bar.scale.x = 1.0 if next_xp <= start_xp else clampf(float(village.get_xp() - start_xp) / (next_xp - start_xp), 0.0, 1.0)
	var population := village.population()
	var maximum := village.max_population()
	_gui.set_text("topRight/visitorsText", "%d/%d" % [population, maximum])
	var colour := POPULATION_OVER_COLOUR if population > maximum else (POPULATION_FULL_COLOUR if village.is_population_capped() else Color.BLACK)
	_gui.part("topRight/visitorsText").add_theme_color_override("font_color", colour)
	_gui.set_text("topRight/nameText", village.map_name())
	_rename_edit.text = village.map_name()
	var stored := 0
	for count: int in village.stored_items().values():
		stored += count
	_gui.set_part_visible("bgBar/giftCounter", stored > 0)
	_gui.set_text("bgBar/giftCounter/count", str(stored))
	store.refresh(village)


## The shield of the player: the time that it lasts, or no shield.
func show_shield(level: int, seconds: int) -> void:
	_gui.set_part_visible("topRight/hudShield", level >= SHIELD_LEVEL)
	var enabled := seconds > 0
	var graphic: SpriteLibrary.ItemSprite = _shield_graphics[0 if enabled else 1] if _shield_graphics.size() == 2 else null
	if graphic != null and (_shield == null or _shield_enabled != enabled):
		if _shield != null:
			_shield.queue_free()
		_shield = ShieldSprite.new(graphic, enabled)
		_shield_enabled = enabled
		_gui.part("topRight/hudShield/shieldAnchor").add_child(_shield)
	var days := seconds / 86400
	var rest := seconds % 86400
	_gui.set_text("topRight/hudShield/timer/time", "No shield" if seconds <= 0 else "%s%02d:%02d:%02d" % ["%dd " % days if days > 0 else "", rest / 3600, rest % 3600 / 60, rest % 60])


## Writes numbers as the client does, with a comma between groups of three digits.
static func formatted(value: int) -> String:
	var digits := str(absi(value))
	var groups: Array[String] = []
	while digits.length() > 3:
		groups.push_front(digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.push_front(digits)
	return ("-" if value < 0 else "") + ",".join(groups)


static func duration(seconds: float) -> String:
	var total := ceili(seconds)
	if total >= 3600:
		return "%dh %02dm" % [total / 3600, total % 3600 / 60]
	if total >= 60:
		return "%dm %02ds" % [total / 60, total % 60]
	return "%ds" % total


## Shows the panel of the selected item over the neighbours, or hides it.
func show_panel(shown: bool) -> void:
	var panel := _gui.clip("bgBar/recuadroInfo")
	var target := PANEL_SHOWN_Y if shown else PANEL_HIDDEN_Y
	if is_equal_approx(panel.position.y, target):
		return
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "position:y", target, PANEL_SLIDE_SECONDS)


## Moves the knob of the zoom slider to the zoom of the camera, from the
## top for ZOOM_MAX to the bottom for ZOOM_MIN.
func show_zoom(level: float) -> void:
	_zoom_level = level
	var height := _zoom.clip("slideBar").bounds().size.y
	_zoom.clip("slider").position.y = height * (1.0 - inverse_lerp(MapCamera.ZOOM_MIN, MapCamera.ZOOM_MAX, level))


func _on_zoom_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_zoom_dragging = event.pressed and not _locked
	elif event is InputEventMouseMotion and _zoom_dragging:
		var height := _zoom.clip("slideBar").bounds().size.y
		var place := clampf(_zoom.get_local_mouse_position().y, 0.0, height)
		zoom_requested.emit(lerpf(MapCamera.ZOOM_MAX, MapCamera.ZOOM_MIN, place / height))


## Opens the store at the page of the item, as the client does for a goal.
func show_build_item(item: GameConfig.ItemDef) -> void:
	store.open_at(item)


## During the tutorial, the client blocks the menus and the tools of the selected item.
func set_locked(locked: bool) -> void:
	_locked = locked
	selection.set_locked(locked)
	_options.pause_allowed = not locked
	_goal_box.marks_allowed = not locked
	if locked:
		_close_menus()


## The town selector: from level 20 in the human town, always in the troll town.
func show_world_button(shown: bool) -> void:
	_gui.set_part_visible("bgBar/gamesButton", shown)
	if not shown:
		_gui.set_part_visible("bgBar/iconMenuGames", false)


func open_rename() -> void:
	_rename_dialog.popup_centered(Vector2i(320, 0))


## The host of the goal box: graphic is the imported Host.goal_symbol(), or null.
func show_goal_host(graphic: SpriteLibrary.ItemSprite, host: Host) -> void:
	_goal_box.show_host(graphic, host)


## The host of the tutorial (TutorialMain), under the bars of the HUD as in
## the client; the client hides the host of the goal box while it shows.
## graphic: the imported Host.tutorial_symbol(), or null.
func show_tutorial_host(graphic: SpriteLibrary.ItemSprite, host: Host) -> void:
	if graphic == null:
		return
	_tutorial_host = HostSprite.new(graphic, host)
	add_child(_tutorial_host)
	move_child(_tutorial_host, 0)
	_goal_box.set_host_visible(false)
	_layout()


## The client plays "bien1" at each new step of the tutorial while its host
## shows; it removes the host when the tutorial no longer needs it, and shows
## the host of the goal box again.
func tutorial_step(host_shown: bool) -> void:
	if _tutorial_host == null:
		return
	if host_shown:
		_tutorial_host.well_done()
		return
	_tutorial_host.queue_free()
	_tutorial_host = null
	_goal_box.set_host_visible(true)


## The graphics shieldEnabled and shieldDisabled of the shield (ShieldSprite); without them the shield has no picture.
func set_shield_graphics(enabled: SpriteLibrary.ItemSprite, disabled: SpriteLibrary.ItemSprite) -> void:
	if enabled != null and disabled != null:
		_shield_graphics = [enabled, disabled]


## goals: [id, title, progress] of the goals of the goal box.
func show_goals(goals: Array) -> void:
	_goal_box.show_goals(goals.map(func(entry: Array) -> Array: return [entry[0], "%s  %s" % [entry[1], entry[2]]]))


## The quest in the town (TownQuests), or the time until the next one; an
## empty text hides it.
func show_town_quest(text: String, troll: bool) -> void:
	_town_quest.text = text
	_gui.set_part_visible("bgBar/mcTrolls", not text.is_empty())
	_gui.clip("bgBar/mcTrolls/cara").show_frame(1 if troll else 0)


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()
	if not text.is_empty():
		_message_timer.start(MESSAGE_SECONDS)


func show_placement_result(result: Village.Placement) -> void:
	show_message(PLACEMENT_MESSAGES.get(result, ""))
