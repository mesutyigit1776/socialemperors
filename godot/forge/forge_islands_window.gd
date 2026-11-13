class_name ForgeIslandsWindow
extends Control
## The window of the forge islands (PopupIslandQuestsManager of the client):
## the island window of the campaign with one picture and a button for each
## island of IslandForge.QUEST_IDS. The first island is open; each other one
## opens after a win on the one before it. The text at the top shows the
## wait of the quest item. The client does not set the count of the stars,
## so the window shows the text of the graphic, "10/100".

signal island_chosen(quest_id: String)
signal closed

const PICTURE := "quests_island_manager_img_1.jpg"
const BUTTON_PLACES: Array[Vector2] = [Vector2(298, 236), Vector2(571, 272), Vector2(558, 450), Vector2(380, 553), Vector2(157, 460)]

var _forge: IslandForge
var _window: UiClip
var _clock: Callable


func _init(ui: UiLibrary, config: GameConfig, forge: IslandForge, village: Village, clock: Callable) -> void:
	_forge = forge
	_clock = clock
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	_window = ui.make("PopupQuestsManagerMC")
	add_child(_window)
	var mask := Control.new()
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask_part := _window.clip("mcMask")
	mask.position = mask_part.position
	mask.size = mask_part.bounds().size
	_window.add_child(mask)
	_window.move_child(mask, _window.part("bgContent").get_index())
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(page)
	var picture := TextureRect.new()
	picture.texture = ui.image(PICTURE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(picture)
	for index in IslandForge.QUEST_IDS.size():
		var quest_id := IslandForge.QUEST_IDS[index]
		var button := ui.make("NewQuestIslandButtonMC")
		button.position = BUTTON_PLACES[index]
		button.set_text("nombreIsla", QuestIsland.name_of(quest_id, config))
		button.clip("stars").show_frame(village.quest_rank(quest_id))
		button.set_part_visible("mcLevelLock", false)
		var locked := index > 0 and village.quest_rank(IslandForge.QUEST_IDS[index - 1]) == 0
		button.set_part_visible("lock", locked)
		button.set_part_visible("enterQuestButton", not locked)
		button.make_button()
		button.pressed.connect(func() -> void: island_chosen.emit(quest_id))
		page.add_child(button)
	# The client also writes a red "NEW!" on the picture with a font that it
	# does not have under that name, so Ruffle shows no text there; the port
	# leaves it out. The arrows have nothing to scroll, but they do not look
	# disabled in Ruffle.
	_window.set_part_visible("btnHelp", false)
	var close := _window.clip("btnClose")
	close.make_button()
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	_update_timer()


func _ready() -> void:
	_window.position = get_viewport_rect().size / 2


func _process(_delta: float) -> void:
	_update_timer()


func _update_timer() -> void:
	var wait := _forge.wait_left(IslandForge.QUEST, _clock.call())
	_window.set_text("txtQuestTimer", "Play now" if wait == 0 else "NEXT QUEST IN \n" + ForgeWindow.time_text(wait))
