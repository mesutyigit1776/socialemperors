class_name PvpHelp
## The help window of the PvP windows (PopupPvpHelp with TipsWithImagesParams
## of the client): four tips, each a picture with its text above it, over the
## background of the generic windows. A cover under it takes the clicks.

const BACKGROUND := "generic_bg.png"
## The tips of an attack (PopupPvp, popupLoadingAssault) and of the shields (PopupBuyShields).
const ATTACK_TIPS: Array[String] = ["PVP_HELP_TIP_1", "PVP_HELP_TIP_2", "PVP_HELP_TIP_3", "PVP_HELP_TIP_4"]
const ATTACK_PICTURES := "popup_elements/popup_pvp_help/tip_%d.png"
const SHIELD_TIPS: Array[String] = ["PVP_SHIELDS_HELP_TIP_1", "PVP_SHIELDS_HELP_TIP_2", "PVP_SHIELDS_HELP_TIP_3", "PVP_SHIELDS_HELP_TIP_4"]
const SHIELD_PICTURES := "popup_elements/popup_pvp_shields_help/tip_%d.png"
## The client puts the text of a tip this many pixels above its picture.
const TEXT_GAP := 3.0


## Opens the help over parent; closed runs when the player closes it.
## pictures: the path of the picture of tip n, with %d for n (from 1).
static func open(parent: Node, ui: UiLibrary, config: GameConfig, tips: Array[String], pictures: String, closed := Callable()) -> void:
	SoundPlayer.play(SoundEffect.BUTTON_CLICK)
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var help := ui.make("PopupPvpHelpMC")
	help.keep_centred()
	help.show_picture("bg/bgAnchor", ui.image(BACKGROUND), false)
	help.button("btnClose").pressed.connect(func() -> void:
		SoundPlayer.play(SoundEffect.BUTTON_CLICK)
		cover.queue_free()
		if closed.is_valid():
			closed.call())
	cover.add_child(help)
	parent.add_child(cover)
	# A Label counts its lines only inside the tree.
	for index in tips.size():
		var tip := "tip%d" % (index + 1)
		var label := "lblTip%d" % (index + 1)
		help.show_picture(tip, ui.image(pictures % (index + 1)), false)
		help.set_text(label, config.text(tips[index]))
		var field: Label = help.part(label)
		var text_height := field.get_line_count() * field.get_line_height()
		# The client moves the field (its y in Flash); the port keeps the offset of the text in the field.
		var offset: Vector2 = field.get_meta("offset", Vector2.ZERO) * field.scale
		field.position.y = help.part(tip).position.y - (text_height + TEXT_GAP) + offset.y
