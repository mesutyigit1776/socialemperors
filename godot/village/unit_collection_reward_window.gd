class_name UnitCollectionRewardWindow
extends Control
## The window after the player takes the reward of a unit collection
## (PopupNextIslandAttack of the client, without the island rewards): the
## title, the text, the picture of the villager with gifts and the cash of
## the reward. The client does not show the reward unit of the configuration
## and does not give it.

signal closed

const PICTURE := "aldeana-regalos.png"
const PICTURE_SCALE := 0.7
## With one reward and no picture of it, the client moves the cash this far to the right.
const CASH_SHIFT := 100.0


func _init(ui: UiLibrary, config: GameConfig, cash: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0.5)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var window := ui.make("PopupNextIslandAttackMC")
	add_child(window)
	window.name = "window"
	window.set_text("txTitle", config.text("POPUP_UNIT_COLLECTION_COMPLETE_TITLE"))
	window.set_text("txInfo", config.text("POPUP_UNIT_COLLECTION_COMPLETE_TEXT"))
	window.set_text("txCash", str(cash))
	window.set_part_visible("t1", false)
	window.set_part_visible("t2", false)
	for part_name in ["txCash", "iconResources", "m1", "t1"]:
		window.part(part_name).position.x += CASH_SHIFT
	var picture := TextureRect.new()
	picture.texture = ui.image(PICTURE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.scale = Vector2.ONE * PICTURE_SCALE
	# The client centres the picture on its anchor.
	if picture.texture != null:
		picture.position = -picture.texture.get_size() * PICTURE_SCALE / 2
	window.clip("foto").add_child(picture)
	var ok := window.clip("btnOk")
	ok.set_text("lbl", config.text("AUX_OK"))
	ok.make_button(true)
	ok.pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		closed.emit()
		queue_free())


func _ready() -> void:
	(get_node("window") as UiClip).keep_centred()
