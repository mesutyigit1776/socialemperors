class_name StoreWindow
extends Control
## The store of the client (StoreMC with Tab, BuildingWindow, SubCategory and
## ItemButtonLarge): a tab for each category, the subcategories of the
## category, and 8 item buttons on a page with arrows to the other pages. The
## tabs of the unit packs and of the item store open the windows of the port
## for them. A click on an item closes the store and emits item_selected.

signal item_selected(item: GameConfig.ItemDef)
signal packs_requested
signal stored_items_requested
## The player clicked an item that the limits of the village do not allow.
signal blocked(result: Village.Placement)

## The tabs of the client: [menu number, category id], see GuiManager.setMenu.
## Menu 5 is the unit packs and menu 6 the storage, which have no category.
const TABS := [[12, Store.CATEGORY_NEW], [1, 1], [2, 4], [3, 2], [4, 3], [5, 0], [6, 0], [7, 5]]
const PACKS_MENU := 5
const STORAGE_MENU := 6
## The labels of the tabs (Language.storeIcons); a menu above 8 uses the last.
const TAB_LABELS := ["STORE_ICON_BUILDINGS", "STORE_ICON_DECORATIONS", "STORE_ICON_DEFENSE", "STORE_ICON_ATTACK", "STORE_ICON_UNIT_PACKS", "STORE_ICON_STORAGE", "STORE_ICON_WONDERS", "STORE_ICON_NEWS"]
const PAGE_SIZE := 8
const COLUMNS := 4
const BUTTON_STEP := Vector2(144, 180)
const BUTTON_ORIGIN := Vector2(30, -15)
const ITEMS_POSITION := Vector2(73, 170)
const SUBCATEGORY_Y := -44.0
const SUBCATEGORY_X := 92.0
const SUBCATEGORY_GAP := 4.0
const SUBCATEGORY_FONT := "Arial Rounded MT Bold"
const SUBCATEGORY_COLOUR := Color8(0x99, 0x83, 0x63)
const SUBCATEGORY_CHOSEN_COLOUR := Color8(0x25, 0x25, 0x25)
## The client sorts the locked items after the others (BuildingWindow.createButtons).
const LOCKED_ORDER := 10000
## The item subcategory of the limited items (Subcat.LIMITED_EDITION).
const LIMITED_SUBCATEGORY := 121
## The frames of iconResources for the cost types (GameStatic.typeCostToFrame).
const COST_FRAMES := {"c": 0, "g": 1, "f": 2, "w": 3, "s": 4, "p": 5}

var _ui: UiLibrary
var _config: GameConfig
var _window: UiClip
var _items_clip: UiClip
var _tabs: Dictionary = {}  # Menu number -> UiClip.
var _items: Dictionary = {}  # Category id -> Array[GameConfig.ItemDef] that the store offers.
var _menu := 1
var _subcategory := 0
var _start := 0
var _shown: Array[GameConfig.ItemDef] = []
var _level := 1
var _limits: Dictionary = {}  # ItemDef -> Village.Placement.
var _rotation_days := 0
var _subcategory_buttons: Array[Control] = []
var _item_buttons: Array[UiClip] = []


func _init(ui: UiLibrary, config: GameConfig) -> void:
	_ui = ui
	_config = config
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("StoreMC")
	add_child(_window)
	_window.button("closeButt").pressed.connect(hide)
	_window.set_part_visible("txtFilter", false)
	# The port has no cash shop.
	_window.set_part_visible("btnCash", false)
	_items_clip = ui.make("MenuTabMC")
	_items_clip.position = ITEMS_POSITION
	_window.add_child(_items_clip)
	for arrow in ["shiftLeft", "shiftRight"]:
		var clip := _items_clip.clip(arrow)
		clip.make_button()
		clip.pressed.connect(func() -> void: SoundPlayer.play(SoundEffect.BUTTON_CLICK))
		clip.pressed.connect(_turn_page.bind(-1 if arrow == "shiftLeft" else 1))
	for tab: Array in TABS:
		var clip := ui.make("TabMC")
		var menu: int = tab[0]
		# GuiManager.createStore: the new items first, then the menus from 1.
		clip.position = Vector2(130, 60) if menu == 12 else Vector2(135 + menu * 65, 60)
		clip.clip("icon").show_frame(menu - 1)
		clip.set_text("icon/iconLbl", config.text(TAB_LABELS[mini(menu, TAB_LABELS.size()) - 1]))
		clip.set_part_visible("tabColor", false)
		clip.make_button()
		clip.pressed.connect(func() -> void: SoundPlayer.play(SoundEffect.BUTTON_CLICK))  # Tab.mouseUsed
		clip.pressed.connect(_open_menu.bind(menu))
		_window.add_child(clip)
		_tabs[menu] = clip
	for index in PAGE_SIZE:
		var button := ui.make("BuildButtonLargeMC")
		button.position = BUTTON_ORIGIN + Vector2(BUTTON_STEP.x * (index % COLUMNS), BUTTON_STEP.y * (index / COLUMNS))
		button.make_button()
		# ItemButtonLarge clicks when the mouse comes over an item and when the player chooses it.
		button.mouse_entered.connect(func() -> void: SoundPlayer.play(SoundEffect.BUTTON_CLICK))
		button.pressed.connect(_choose.bind(index))
		_items_clip.add_child(button)
		_item_buttons.append(button)
	visible = false
	resized.connect(_place)


## The client puts the store at the left edge of its HUD and 275 pixels above
## the middle of the screen (StateNormal.setFullScreen).
func _place() -> void:
	_window.position = Vector2(roundf(size.x / 2 - VillageHud.CLIENT_WIDTH / 2.0), roundf(size.y / 2 - 275))


## The items of each category that the store offers, see Store.items().
func set_items(items: Dictionary, rotation_days: int) -> void:
	_items = items
	_rotation_days = rotation_days
	if visible:
		_show_items()


## Updates the resources, the locks and the limits of the items.
func refresh(village: Village) -> void:
	_level = village.get_level()
	for field: Array in [["coinText", "g"], ["dollarText", "c"], ["woodText", "w"], ["stoneText", "s"], ["foodText", "f"]]:
		_window.set_text(field[0], VillageHud.formatted(village.get_resource(field[1])))
	_limits.clear()
	for list: Array in _items.values():
		for item: GameConfig.ItemDef in list:
			_limits[item] = village.check_limits(item)
	if visible:
		_show_page()


## Opens the store at the tab that the player used last.
func open() -> void:
	_open_menu(_menu)


## Opens the store at the page with the item, as the client does for a goal.
func open_at(item: GameConfig.ItemDef) -> void:
	for tab: Array in TABS:
		if _items.get(tab[1], []).has(item):
			_open_menu(tab[0])
			_start = _shown.find(item) / PAGE_SIZE * PAGE_SIZE
			_show_page()
			return
	open()


## Opens the store at a tab and subcategory, as the links of the news window
## do (GuiManager.openStore).
func open_link(menu: int, subcategory: int) -> void:
	_open_menu(menu)
	if visible and subcategory != 0:
		_subcategory = subcategory
		_show_items()


func _open_menu(menu: int) -> void:
	if menu == PACKS_MENU or menu == STORAGE_MENU:
		hide()
		(packs_requested if menu == PACKS_MENU else stored_items_requested).emit()
		return
	_menu = menu
	_subcategory = 0
	_start = 0
	for key: int in _tabs:
		_tabs[key].set_part_visible("tabColor", key == menu)
	show()
	_place()
	_show_subcategories()
	_show_items()


func _category() -> int:
	for tab: Array in TABS:
		if tab[0] == _menu:
			return tab[1]
	return 0


func _show_subcategories() -> void:
	for button in _subcategory_buttons:
		button.queue_free()
	_subcategory_buttons.clear()
	var subcategories: Array = [[0, _config.text("AUX_ALL")]]
	subcategories.append_array(_config.subcategories.get(_category(), []))
	var x := SUBCATEGORY_X
	for entry: Array in subcategories:
		var button := _subcategory_button(entry[1])
		button.position = Vector2(x, SUBCATEGORY_Y)
		var id: int = entry[0]
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				SoundPlayer.play(SoundEffect.BUTTON_CLICK)
				_subcategory = id
				_start = 0
				_show_items())
		button.set_meta("subcategory", id)
		_items_clip.add_child(button)
		_subcategory_buttons.append(button)
		x += button.size.x + SUBCATEGORY_GAP


## A subcategory of the client (SubCategory): a text on a pill that is 4
## pixels wider than the text and 10 pixels wider than its field.
func _subcategory_button(text: String) -> Control:
	var font := _ui.named_font(SUBCATEGORY_FONT)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10
	var button := Control.new()
	button.size = Vector2(width + 4, 20)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pill := _ui.make("PastillaSubcategoriaMC")
	pill.show_frame(0 if width < 33 else 1 if width < 57 else 2 if width < 78 else 3 if width < 92 else 4)
	var natural := pill.bounds().size.x
	if natural > 0:
		pill.scale.x = (width + 4) / natural
		pill.position.x = -pill.bounds().position.x * pill.scale.x
	button.add_child(pill)
	var label := Label.new()
	label.text = text
	label.position = Vector2(2, 2)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.name = "text"
	button.add_child(label)
	return button


func _show_items() -> void:
	for button in _subcategory_buttons:
		var label: Label = button.get_node("text")
		label.add_theme_color_override("font_color", SUBCATEGORY_CHOSEN_COLOUR if button.get_meta("subcategory") == _subcategory else SUBCATEGORY_COLOUR)
	var order := {}
	var list: Array = _items.get(_category(), [])
	for index in list.size():
		order[list[index]] = index
	_shown.clear()
	for item: GameConfig.ItemDef in list:
		if _subcategory == 0 or item.subcategory_id == _subcategory:
			_shown.append(item)
	_shown.sort_custom(func(a: GameConfig.ItemDef, b: GameConfig.ItemDef) -> bool:
		var key_a := _sort_key(a)
		var key_b := _sort_key(b)
		return key_a < key_b if key_a != key_b else order[a] < order[b])
	_show_page()


func _sort_key(item: GameConfig.ItemDef) -> int:
	return item.min_level + LOCKED_ORDER if item.min_level > _level else item.display_order


func _turn_page(direction: int) -> void:
	_start = clampi(_start + direction * PAGE_SIZE, 0, maxi(_shown.size() - PAGE_SIZE, 0))
	_show_page()


func _show_page() -> void:
	_start = clampi(_start, 0, maxi(_shown.size() - PAGE_SIZE, 0))
	for index in PAGE_SIZE:
		var button := _item_buttons[index]
		var item: GameConfig.ItemDef = _shown[_start + index] if _start + index < _shown.size() else null
		button.visible = item != null
		if item != null:
			_show_item(button, item)
	_set_arrow("shiftLeft", _start > 0)
	_set_arrow("shiftRight", _start + PAGE_SIZE < _shown.size())


## BuildingWindow.disableButton2 shows an arrow that leads nowhere at half alpha.
func _set_arrow(name: String, enabled: bool) -> void:
	var arrow := _items_clip.clip(name)
	arrow.modulate.a = 1.0 if enabled else 0.5
	arrow.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _show_item(button: UiClip, item: GameConfig.ItemDef) -> void:
	button.set_text("itemName", item.name)
	# The client makes the font of a long name smaller.
	var name_label := button.part("itemName") as Label
	if name_label != null:
		if not name_label.has_meta("font_size"):
			name_label.set_meta("font_size", name_label.get_theme_font_size("font_size"))
		name_label.add_theme_font_size_override("font_size", 11 if item.name.length() > 11 else int(name_label.get_meta("font_size")))
	button.set_text("cost", str(item.cost))
	button.clip("iconResources").show_frame(COST_FRAMES.get(item.cost_type, 1))
	button.set_text("xpgained", _config.text("STORE_EDIFICIO_EXP").replace("#0#", str(item.xp)))
	var locked := item.min_level > _level
	button.set_part_visible("unlockAt", locked)
	button.set_text("unlockAt/levelText", _config.text("STORE_EDIFICIO_NIVEL").replace("#0#", str(item.min_level)))
	button.set_part_visible("newIcon", item.new_item and item.subcategory_id != LIMITED_SUBCATEGORY)
	button.set_part_visible("limited_mc", item.subcategory_id == LIMITED_SUBCATEGORY)
	button.set_text("limited_mc/textLimited", _config.text("STORE_EDIFICIO_LIMITE").replace("#0#", str(_rotation_days)))
	var holder := button.clip("holder")
	var picture: TextureRect = holder.get_node_or_null("picture")
	if picture == null:
		picture = TextureRect.new()
		picture.name = "picture"
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(picture)
	picture.texture = _ui.thumb(item.img_name)
	# An item that the limits do not allow is shown at half alpha.
	button.modulate.a = 1.0 if locked or _limits.get(item, Village.Placement.OK) == Village.Placement.OK else 0.5


func _choose(index: int) -> void:
	var item := _shown[_start + index]
	if item.min_level > _level:
		return
	var result: Village.Placement = _limits.get(item, Village.Placement.OK)
	if result != Village.Placement.OK:
		blocked.emit(result)
		return
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	hide()
	item_selected.emit(item)
