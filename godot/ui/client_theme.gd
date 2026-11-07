class_name ClientTheme
extends RefCounted
## A Godot theme in the style of the client windows, for the controls that
## the port makes itself (lists of actions, dialogs, the windows that the
## client gets from its server): the fonts of the client, buttons in the brown
## and orange of its buttons and panels in the colours of its parchment.

const BODY_FONT := "Arial Rounded MT Bold"
const TITLE_FONT := "Eras Bold ITC"
const TEXT_COLOUR := Color8(0x3b, 0x24, 0x10)
const PARCHMENT := Color8(0xf6, 0xe7, 0xb5)
const FRAME := Color8(0x6b, 0x3e, 0x1a)
const BUTTON := Color8(0x7a, 0x3b, 0x12)
const BUTTON_HOVER := Color8(0x9a, 0x50, 0x1c)
const BUTTON_BORDER := Color8(0xe8, 0x9a, 0x2c)


static func make(ui: UiLibrary) -> Theme:
	var theme := Theme.new()
	theme.default_font = ui.named_font(BODY_FONT)
	theme.default_font_size = 13
	for type in ["Label", "RichTextLabel", "LineEdit"]:
		theme.set_color("font_color", type, TEXT_COLOUR)
	theme.set_color("default_color", "RichTextLabel", TEXT_COLOUR)
	theme.set_stylebox("panel", "PanelContainer", _box(PARCHMENT, FRAME, 3, 8))
	theme.set_stylebox("panel", "AcceptDialog", _box(PARCHMENT, FRAME, 3, 8))
	theme.set_stylebox("embedded_border", "Window", _box(PARCHMENT, FRAME, 3, 8))
	theme.set_color("title_color", "Window", TEXT_COLOUR)
	theme.set_font("title_font", "Window", ui.named_font(TITLE_FONT))
	theme.set_stylebox("normal", "Button", _box(BUTTON, BUTTON_BORDER, 2, 10))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, BUTTON_BORDER, 2, 10))
	theme.set_stylebox("pressed", "Button", _box(FRAME, BUTTON_BORDER, 2, 10))
	theme.set_stylebox("disabled", "Button", _box(BUTTON.darkened(0.3).lerp(Color.GRAY, 0.5), BUTTON_BORDER.lerp(Color.GRAY, 0.6), 2, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	theme.set_stylebox("normal", "LineEdit", _box(Color.WHITE, FRAME, 2, 6))
	return theme


static func _box(fill: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(margin)
	return box
