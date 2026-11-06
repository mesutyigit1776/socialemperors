class_name TournamentAlert
extends ColorRect
## The alert of the team window and the tournament (Alert of the client,
## AlertTournamentMC): a text with OK, or with Yes and No. It covers the
## screen until the player answers.


## A new alert at position (the centre of the window) with OK, or with Yes and
## No when on_yes is given: Yes calls on_yes.
func _init(ui: UiLibrary, config: GameConfig, text: String, position_in_parent: Vector2, on_yes := Callable()) -> void:
	color = Color(0, 0, 0, 0.3)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var alert := ui.make("AlertTournamentMC")
	alert.position = position_in_parent
	add_child(alert)
	alert.set_text("msg_txt", text)
	var asks := on_yes.is_valid()
	alert.set_part_visible("ok_btn", not asks)
	alert.set_part_visible("yes_btn", asks)
	alert.set_part_visible("no_btn", asks)
	var buttons := {"yes_btn": ["AUX_SI", on_yes], "no_btn": ["AUX_NO", Callable()]} if asks else {"ok_btn": ["AUX_OK", Callable()]}
	for part: String in buttons:
		alert.set_text(part + "/txtLabel", config.text(buttons[part][0]))
		var button := alert.clip(part)
		button.make_button(true)
		var action: Callable = buttons[part][1]
		button.pressed.connect(func() -> void:
			queue_free()
			if action.is_valid():
				action.call())
