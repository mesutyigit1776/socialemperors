class_name OptionsPanel
extends Node
## The options of the client (options_panel of GuiMC and GuiManager): a panel
## at the right edge of the screen with the music, the sounds, the full screen
## and the pause. Only its button "bo" shows; a click on it slides the panel
## out, and after 5 seconds it slides back. The buttons bm, bs and bf show the
## options that are on, bmo, bso and bfo the ones that are off.
##
## The pause (Base.pauseGame) stops the game under a dark curtain with the
## window GamePausedMC until the player clicks its button.

## The panel is this far above the bottom bar (StateNormal.enter), and this
## far from the right edge of the screen when it is in and when it is out.
const PANEL_Y := -435.0
const IN_FROM_RIGHT := 30.0
const OUT_FROM_RIGHT := 90.0
const SLIDE_SECONDS := 0.5
const OUT_SECONDS := 5.0
## Over all the windows of the village.
const PAUSE_LAYER := 20

## The client does not pause in the tutorial.
var pause_allowed := true
var _ui: UiLibrary
var _panel: UiClip
var _gui: UiClip
var _out := false
var _slide: Tween
var _timer := Timer.new()
var _pause: CanvasLayer


## panel: options_panel of gui, the GuiMC of the HUD.
func _init(ui: UiLibrary, gui: UiClip, panel: UiClip) -> void:
	_ui = ui
	_gui = gui
	_panel = panel
	_timer.one_shot = true
	_timer.timeout.connect(_slide_to.bind(false))
	add_child(_timer)
	_button("bo", func() -> void: _slide_to(not _out))
	for name: String in ["bm", "bmo"]:
		_button(name, func() -> void:
			SoundPlayer.set_music_on(not SoundPlayer.is_music_on())
			_show_states())
	for name: String in ["bs", "bso"]:
		_button(name, func() -> void:
			SoundPlayer.set_effects_on(not SoundPlayer.are_effects_on())
			_show_states())
	for name: String in ["bf", "bfo"]:
		_button(name, _toggle_full_screen)
	_button("bp", _show_pause)
	_show_states()


## Puts the panel at the right edge of a screen of this size.
func place(size: Vector2) -> void:
	if _slide != null:
		_slide.kill()
	_panel.position = Vector2(_x(size, _out), PANEL_Y)


func _button(name: String, action: Callable) -> void:
	var button: UiButton = _panel.part(name)
	button.pressed.connect(action)


func _x(size: Vector2, out: bool) -> float:
	return size.x - _gui.position.x - (OUT_FROM_RIGHT if out else IN_FROM_RIGHT)


func _slide_to(out: bool) -> void:
	_out = out
	if out:
		_timer.start(OUT_SECONDS)
	if _slide != null:
		_slide.kill()
	_slide = create_tween()
	_slide.tween_property(_panel, "position:x", _x(_panel.get_viewport_rect().size, out), SLIDE_SECONDS).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _show_states() -> void:
	var full_screen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	for pair: Array in [["bm", SoundPlayer.is_music_on()], ["bs", SoundPlayer.are_effects_on()], ["bf", not full_screen]]:
		_panel.set_part_visible(pair[0], pair[1])
		_panel.set_part_visible(pair[0] + "o", not pair[1])


func _toggle_full_screen() -> void:
	var full_screen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full_screen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_states()


func _show_pause() -> void:
	if _pause != null or not pause_allowed:
		return
	_pause = CanvasLayer.new()
	_pause.layer = PAUSE_LAYER
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	var size := _panel.get_viewport_rect().size
	var curtain := _ui.make("CortinaMC")
	curtain.scale = size / curtain.bounds().size if curtain.bounds().size.x > 0 else Vector2.ONE
	curtain.take_mouse()
	_pause.add_child(curtain)
	var window := _ui.make("GamePausedMC")
	window.position = size / 2
	_pause.add_child(window)
	(window.part("bpo") as UiButton).pressed.connect(func() -> void:
		get_tree().paused = false
		_pause.queue_free()
		_pause = null)
	add_child(_pause)
	get_tree().paused = true
