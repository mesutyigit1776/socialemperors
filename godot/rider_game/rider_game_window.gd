class_name RiderGameWindow
extends Control
## The window of the client around the mini-game (WindowMiniGameDragonRiderMC):
## the game in its frame, and a close button, which loses the game.
## `finished` reports the result once; the window then closes.

signal finished(won: bool)

var _window: UiClip
var _done := false


## Null, with an error, when the import has no mini-game; see RiderArt.
static func open(data_dir: String, ui: UiLibrary, frames: FrameCache, level: int, rider_type: int) -> RiderGameWindow:
	var art := RiderArt.load_from(data_dir, frames)
	var game_ui := UiLibrary.load_from(data_dir, frames, "rider_game/ui")
	if art == null or game_ui == null or not ui.has_symbol("WindowMiniGameDragonRiderMC"):
		return null
	var window := RiderGameWindow.new()
	window._build(ui, RiderGame.new(art, game_ui, data_dir, level, rider_type))
	return window


func _build(ui: UiLibrary, game: RiderGame) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(GuiCover.new())
	_window = ui.make("WindowMiniGameDragonRiderMC")
	add_child(_window)
	_window.set_part_visible("help", false)
	# The client shows 650 x 500 pixels of the game at gameBeacon (a scrollRect).
	var beacon := _window.part("gameBeacon")
	var screen := Control.new()
	screen.clip_contents = true
	screen.position = beacon.position
	screen.size = RiderGame.SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_window.add_child(screen)
	screen.add_child(game)
	game.finished.connect(_finish)
	_window.button("closeButt").pressed.connect(func() -> void: _finish(false))


func _ready() -> void:
	_window.keep_centred()


func _finish(won: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(won)
	queue_free()
