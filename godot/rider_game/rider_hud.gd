class_name RiderHud
extends RefCounted
## The parts of the screen of the mini-game with buttons and texts, from
## <data>/rider_game/ui: the health bar with the picture of the rider, the
## skill bar with the cooldown of each skill and its tip, and the screens of a
## won, lost or finished level, whose button ends the game.

signal skill_pressed(skill: int)
signal done_pressed

const HEALTH_BAR_PLACE := Vector2(10.0, 15.0)
const SKILL_BAR_PLACE := Vector2(0.0, 430.0)
## The frames of the cooldown sweep of a skill button.
const SWEEP_FRAMES := 1000.0
## The tip of a skill shows after the mouse stayed this many frames on its button.
const TIP_WAIT := 15
## The text of a hit at the health bar fades by this much in each frame and moves right 1.5 pixels.
const TEXT_FADE := 0.05
## The skills on the bar in each training level: 3 in levels 1-2, 4 in 3-4, 5 in 5-6, 6 from 7.
const SKILLS_BY_LEVEL := [0, 3, 3, 4, 4, 5, 5, 6, 6]

var health_bar: UiClip
var skill_bar: UiClip
var end_screen: UiClip
var _ui: UiLibrary
var _skills := 0
var _hovered := 0
var _hover_frames := 0
var _texts := {}  # Name of a text of the health bar -> [alpha, x].
var _end_frames := 0


func _init(ui: UiLibrary, level: int, rider_type: int) -> void:
	_ui = ui
	health_bar = ui.make("main.heroHealthBar")
	health_bar.position = HEALTH_BAR_PLACE
	var icon := health_bar.clip("riderIcon")
	if icon != null:
		icon.show_frame(clampi(rider_type, 1, icon.frame_count()) - 1)
	for name in ["minusHealth_txt", "addHealth_txt"]:
		_texts[name] = [0.0, 0.0]
		health_bar.part(name).modulate.a = 0.0
	skill_bar = ui.make("main.control_board")
	skill_bar.position = SKILL_BAR_PLACE
	_skills = SKILLS_BY_LEVEL[clampi(level, 1, SKILLS_BY_LEVEL.size() - 1)]
	for name in ["sound_butt", "music_butt", "reload_butt", "menu_butt", "tips_mc"]:
		skill_bar.set_part_visible(name, false)
	for skill in range(1, 7):
		var button := skill_bar.clip("butt_%d" % skill)
		if skill > _skills:
			button.visible = false
			continue
		button.make_button()
		button.pressed.connect(func() -> void: skill_pressed.emit(skill))
		button.mouse_entered.connect(func() -> void: _hovered = skill)
		button.mouse_exited.connect(func() -> void: _hovered = 0)


## One frame: the cooldown of each skill, the tip, and the texts of the health bar.
func update(hero: RiderHero) -> void:
	for skill in range(1, _skills + 1):
		var sweep := skill_bar.clip("butt_%d/cd_counter" % skill)
		if sweep == null:
			continue
		var time := hero.skill_time[skill - 1]
		var cooldown := RiderHero.SKILL_COOLDOWNS[skill - 1]
		var ratio := float(time) / cooldown if time < cooldown else hero.cooldown / float(RiderHero.COMBAT_FRAMES)
		sweep.show_frame(clampi(roundi(SWEEP_FRAMES * ratio), 1, sweep.frame_count()) - 1)
	if _hovered >= 1:
		_hover_frames += 1
		if _hover_frames > TIP_WAIT:
			skill_bar.set_part_visible("tips_mc", true)
			skill_bar.clip("tips_mc").show_label("f_%d" % _hovered)
	else:
		_hover_frames = 0
		skill_bar.set_part_visible("tips_mc", false)
	for name: String in _texts:
		var text: Array = _texts[name]
		if text[0] >= 0.0:
			text[0] -= TEXT_FADE
			text[1] += 1.5
			var part := health_bar.part(name)
			part.modulate.a = clampf(text[0], 0.0, 1.0)
			part.position.x = text[1]
	if end_screen != null and end_screen.frame_count() > 1 and end_screen.frame < end_screen.frame_count() - 1:
		end_screen.show_frame(end_screen.frame + 1)


## The text without the characters that the font of the label does not have:
## the file embeds only the glyphs of the texts in its art, and Flash leaves
## out the others (for example "Level  failed" for "Level 4 failed").
static func drawable(label: Label, text: String) -> String:
	var font := label.get_theme_font("font")
	var result := ""
	for character in text:
		if font == null or font.has_char(character.unicode_at(0)):
			result += character
	return result


func _write(clip: UiClip, path: String, text: String) -> void:
	clip.set_text(path, drawable(clip.part(path) as Label, text))


func show_health(health: float, max_health: float) -> void:
	health_bar.clip("healthBar").scale.x = clampf(health / max_health, 0.0, 1.0)
	_write(health_bar, "currentHealth_txt", "%d/%d" % [health, max_health])


## The text of a hit (-) or a heal (+) at the health bar; it starts at x and fades.
func show_change(name: String, text: String, x: float) -> void:
	_write(health_bar, name, text)
	_texts[name] = [1.4, x]
	health_bar.part(name).position.x = x


## The screen of the end of a level: "won" (levels 1-7), "lost" or "complete" (the dragon).
func show_end(kind: String, level: int) -> UiClip:
	match kind:
		"won":
			end_screen = _ui.make("main.game_won")
			_write(end_screen, "congratztext", "Level %d completed" % level)
			for name in ["next_level_button", "level_select_button", "more_games_button"]:
				end_screen.set_part_visible(name, false)
		"lost":
			end_screen = _ui.make("main.game_over")
			_write(end_screen, "overtext", "Level %d failed" % level)
			for name in ["play_again_button", "level_select_button", "more_games_button"]:
				end_screen.set_part_visible(name, false)
		_:
			end_screen = _ui.make("main.game_complete")
			for name in ["level_select_button", "more_games_button"]:
				end_screen.set_part_visible(name, false)
	end_screen.button("main_menu_button").pressed.connect(func() -> void: done_pressed.emit())
	return end_screen
