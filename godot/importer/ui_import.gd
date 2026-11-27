class_name UiImport
## Imports the windows of the client that the port shows with the original graphics.
##
## A window of the client is a symbol of the client SWF file. Its parts with an
## instance name (buttons, stars, locks, text fields) change at run time, so the
## port must place them itself. This writes:
##
##   <out>/ui/windows.swf          a copy of the SWF file in which the sprites of the windows do not
##                                 place their named parts and text fields; the port draws the
##                                 frames of the sprites, the named buttons and the fonts from it
##   <out>/ui/layout.json          {"symbols": {name: sprite id}, "fonts": {font name: font id},
##                                  "clips": {id: {"origin": [x, y] or null, "frames": [[part, ...] for each frame],
##                                                 "labels": {label: frame (0-based)}}},
##                                  "buttons": {id: {}}}
##                                 "origin" is the corner of the bounds of the sprite without its
##                                 parts, or null when it draws nothing besides them.
##   <out>/ui/images/<name>        pictures that the windows load from assets/images_new
##   <out>/ui/thumbs/<img_name>.jpg  small pictures of the units, for the units lost in a quest
##   <out>/ui/cast/...             the banner of a cast spell, from its own SWF file, in the same form
##   <out>/ui/viral/...            the icon of the first purchase offer, from its own SWF file, in the same form
##   <out>/ui/forge_icon/..., forge_bar/..., forge_hammer/...
##                                 the icon, the progress bar and the hammer of the Island Forge, the same
##   <out>/ui/dome/..., anim_win/..., anim_lose/...
##                                 the dome of a selected dome building and the animations of the
##                                 result of a PvP attack, the same
##
## A part is {"name", "depth", "matrix": [a, b, c, d, x, y], and "clip": id (a
## sprite), "button": id (a button) or "text": settings (the rectangle, font,
## size, color, alignment, leading, line settings and text of the field)},
## with "alpha", "glow" or "mask" when the placement has them, and "start": the
## frame that placed the instance, when it is not the first frame, and
## "clip_rect": [x0, y0, x1, y1], the bounds of a shape that masks the part in
## the first frame, for example the frame of a unit picture. Unnamed text
## fields are parts too, so that the port draws their text with the font, and
## unnamed buttons, which the drawing of a sprite leaves out. The extension
## flash_art reads the SWF files and writes windows.swf and layout.json
## (SwfImport.windows(), flash_art/src/swf_import.rs).

const CLIENT_SWF := "assets/flash/SocialEmpires1.4.07sec_fixed.swf"
## The marks under a building of each width, for the player, an enemy and a
## neutral item (PeanaBuilding<side><n>x<n>MC), come after PeanaNeutralMC.
const MARK_SIDES := ["", "Enemy", "Neutral"]
const MARK_WIDTHS := 6
## Windows of the quests, and parts of the screen of the client ("GuiMC/..."
## names a child of a symbol by its instance names); see symbols().
const SYMBOLS_BEFORE_MARKS := [
	"PopupQuestsManagerMC",
	"NewQuestIslandButtonMC",
	"PopupLoadingQuestMC",
	"PopupQuestFinishedMC",
	"GuiMC/barraAttackArriba",
	"GuiMC/bgBar/btnExit",
	"PopupAlertMC",
	"PopUpAlertaMC",
	# The window around the mini-game of the Dragon Riding and the Rider Academy.
	"WindowMiniGameDragonRiderMC",
	"PortraitAssaultMC",
	# The spell book, its window, the window that sells mana, and the marker of the area of a spell.
	"PopupMagicMC",
	"SpellButtonMC",
	"InfoPopupManaMc",
	"PopupWizardryMC",
	"MagicentryMC",
	"SelectedMagicMC",
	"PopupBuyManaMC",
	"AOEMC",
	# The window in which the player chooses the team for an island with teams.
	"SelectionTeamWindowMC",
	# The alert of the team window (Alert of the client).
	"AlertTournamentMC",
	# Survival: the window of the maps, a map in it, the reward of a time, the
	# window before the start and the result window.
	"PopupSurvivalMC",
	"SurvivalMapMC",
	"SurvivalMinRewardMc",
	"PopupLoadingSurvivalMC",
	"PopupSurvivalResultsMC",
	# Tournament: the window before a match and the window of its result.
	"PopupLoadingTournamentMC",
	"PopupTournamentFinishedMC",
	# The village screen: the HUD with its menus, the store with its tabs,
	# item buttons and subcategories, the panels of a selected item
	# (RecuadroInfoNew), the goal box, the neighbour bar and the zoom slider.
	"GuiMC",
	"StoreMC",
	"TabMC",
	"MenuTabMC",
	"BuildButtonLargeMC",
	"PastillaSubcategoriaMC",
	"EP_House_MC",
	"EP_Farm_MC",
	"EP_NewBarracksMC",
	"EP_Market_MC",
	"EP_UnitMC",
	# The portrait of a unit in a selection of several units, the mark for more
	# than 20 units, and the panel of a special unit with its attack buttons.
	"PortraitMC",
	"PortraitMorUnitsMC",
	"EP_SpecialUnitMc",
	# The label of the item under the mouse: its name, and the time and share
	# of the production of a building (InfoPopup).
	"InfoPopupMC",
	"popUpMissionsMC",
	"NewGoalMC",
	"MenuTabFriendsMC",
	"FriendButtonMC",
	"PopOverVisitMC",
	"ZoomSliderMC",
	# Windows of the village: the goal list, the tutorial, the confirm window,
	# the town window and the window of a quest in the town.
	"PopupGoalListMC",
	"GoalListLineMC",
	"TutorialPopupMC",
	"PopupConfirmMC",
	"PopupRaceSelectorMC",
	"PopupQuestInfo2MC",
	# The pause of the options panel: the dark curtain and the window over it.
	"GamePausedMC",
	"CortinaMC",
	# The options panel of the battle screens, which have no GuiMC.
	"GuiMC/options_panel",
	# The bar of a new building during its construction.
	"FauxBarMC",
	# The window of the login bonus.
	"PopupNewDailyBonusMC",
	# The window of the first purchase offer and the card of a unit in it.
	"PopupFirstBuyMC",
	"InfoButtonStore6bMC",
	# The unit list of the Gift menu: the window, a place of a unit, the cards
	# of a unit that the player has and has not, and the window of the reward.
	"PopupAllUnitsMC",
	"UnitListMC",
	"InfoButtonUnitCollectionMC",
	"InfoButtonUnitCollectionBuyMC",
	"PopupNextIslandAttackMC",
	# The news window, the card of a promotion pack in it, the windows that
	# sell the normal, random and super packs, the window of a random prize,
	# and the window of a story (the gods).
	"PopupNewsMC",
	"PackCardMC",
	"PopupGetPackMC",
	"PopupMisteryMC",
	"PopupSuperMisteryBoxMC",
	"PopupGotPackMC",
	"PopupLoreMC",
	# The window of the start point of a PvP attack and its help window.
	"PopupLoadingAssaultMC",
	"PopupPvpHelpMC",
	# The window of the Island Forge (the class name of the client has this spelling).
	"PoupIslandForgeMC",
	# Battles: the health bar of an item of the player and of an enemy, the
	# selection marks under a unit and under a building of each width, for
	# the player, an enemy and a neutral item, and the range of a dome.
	"BarraVidaMC",
	"BarraVidaEnemyMC",
	"PeanaMC",
	"PeanaEnemyMC",
	"PeanaNeutralMC",
]
const SYMBOLS_AFTER_MARKS := [
	"DomeRangeBottom",
	# PvP: the window of the army and the search, the window that sells
	# shields with a shield in it, the attack log with its lines and its end,
	# the place of a unit in the army, and the result window of an attack.
	"PopupPvpMC",
	"PopupBuyShieldsMC",
	"PopupBuyShields.ShieldItemMC",
	"PopupAttackLogMC",
	"AttackLogItemMC",
	"AttackLogEndItemMC",
	"ArmyUnitCellMC",
	"PopupPVPFInishedMC",
	# The graphics that the client shows while the graphic of an item loads,
	# and that stay when it is missing (IsoElement.setProvisionalGrahic).
	"LoadingUnit",
	"Loading1x1",
	"Loading2x2",
	"Loading3x3",
	"Loading4x4",
	# The numbers that float up when the player gets or pays resources
	# (NumberParticle), with the icons of the resources.
	"NumberParticle2MC",
	"IconResourcesMC",
	# The speech bubble of a unit (IsoUnit.say), for the lines of the captains.
	"BS_MC",
]
## The island window shows 7 pictures side by side; the start and end windows
## show a picture for the kind of quest and for the result. The spell windows
## show a book and a wizard; the pictures of the spells come with the spell
## pictures of import_ui(). The alert with a picture tells the player about
## the spell book. The neighbour bar shows the host of the tutorial with the
## picture of the king, the town window a picture of each town, and the story
## of the gods in the news window its pictures. The help of a PvP attack has
## the background of the generic windows.
const IMAGES := [
	"quests_manager_img_1.jpg", "quests_manager_img_2.jpg", "quests_manager_img_3.jpg", "quests_manager_img_4.jpg",
	"quests_manager_img_5.jpg", "quests_manager_img_6.jpg", "quests_manager_img_7.jpg",
	"TESORO.jpg", "COLLECT_GEMS.jpg", "pop_up_nieve.jpg", "rockdriller_start.jpg", "boss2_ini.jpg", "ataque_ganado.jpg",
	"ataque_perdido.jpg", "pop_up5_sueno2.jpg", "llibre.png", "mago_altar.png", "alert_magic.jpg",
	"SURVIVAL_DESIERTO.jpg", "SURVIVAL_MINERAL.jpg", "SURVIVAL_NUBES.jpg", "SURVIVAL_NIEVE.jpg", "SURVIVAL_SELVA.jpg", "aldeana-regalos.png",
	"tournament_weekly_gold.jpg", "weekly_tournament_bot1.png", "weekly_tournament_bot2.png", "weekly_tournament_bot3.png",
	"thumbrey.jpg", "thumbprincess.jpg", "townHuman.png", "townTroll.png",
	"gods_1.jpg", "gods_2.jpg", "gods_3.jpg", "gods_4.jpg", "gods_5.jpg", "gods_6.jpg", "gods_7.jpg",
	"generic_bg.png",
	"hell_forge.jpg", "quests_island_manager_img_1.jpg",
]
## The login bonus window loads its background and the pictures of the days
## from assets/externalized/DailyBonus, the help of a PvP attack its tips
## from assets/externalized/popup_elements, and the PvP windows their
## backgrounds, shields and flags from there and from PopupBuyShields and
## PopupPVPFinished; the port keeps the same folders.
const EXTERNALIZED_IMAGES := [
	"DailyBonus/bg.png", "DailyBonus/imgs/day1.png", "DailyBonus/imgs/day2.png", "DailyBonus/imgs/day3.png",
	"DailyBonus/imgs/day4.png", "DailyBonus/imgs/day5.png",
	"popup_elements/popup_pvp_help/tip_1.png", "popup_elements/popup_pvp_help/tip_2.png",
	"popup_elements/popup_pvp_help/tip_3.png", "popup_elements/popup_pvp_help/tip_4.png",
	"IslandForge/bg.jpg", "IslandForge/dragonBG.png",
	"IslandForge/1.jpg", "IslandForge/1.png", "IslandForge/2.jpg", "IslandForge/2.png", "IslandForge/3.jpg", "IslandForge/3.png",
	"IslandForge/4.jpg", "IslandForge/4.png", "IslandForge/5.jpg", "IslandForge/5.png", "IslandForge/6.jpg", "IslandForge/6.png",
	"popup_elements/popup_pvp/pvp_bg.png", "popup_elements/popup_pvp/red_shield.png", "popup_elements/popup_pvp/units_frame.png",
	"PopupBuyShields/background.png", "PopupBuyShields/shield_1.png", "PopupBuyShields/shield_2.png", "PopupBuyShields/shield_3.png",
	"popup_elements/popup_pvp_shields_help/tip_1.png", "popup_elements/popup_pvp_shields_help/tip_2.png",
	"popup_elements/popup_pvp_shields_help/tip_3.png", "popup_elements/popup_pvp_shields_help/tip_4.png",
	"popup_elements/popup_attack_log/attack_log_bg.png", "popup_elements/popup_end_battle/end_pvp_bg.jpg",
	"popup_elements/popup_end_battle/bg_units_container.png",
	"PopupPVPFinished/blue_flag.png", "PopupPVPFinished/red_flag.png",
]
## The banner that shows the name of a cast spell.
const CAST_SWF := "assets/buildingsprites/magic_cast_marquee.swf"
## The windows of other SWF files: [SWF file, symbols, folder in ui/]. The
## icon of the first purchase offer at the side of the HUD ("open me"); the
## Island Forge: the icon of the event in the HUD (the viral offer 2 has the
## icon "easterDragon"), and the progress bar and the hammer of its window;
## the dome over a selected dome building (DomeDelegate), and the animations
## of the result window of a PvP attack (PopupPVPFinished).
const OTHER_SWFS := [
	[CAST_SWF, ["magic_cast"], "cast"],
	["assets/externalized/viral_buttons/viralFirstOffer.swf", ["viralFirstOffer"], "viral"],
	["assets/externalized/viral_buttons/easterDragon.swf", ["easterDragon"], "forge_icon"],
	["assets/externalized/IslandForge/island_progressbar.swf", ["island_progressbar"], "forge_bar"],
	["assets/externalized/IslandForge/forge_hammer.swf", ["forge_hammer"], "forge_hammer"],
	["assets/swf/blue_dome.swf", ["blue_dome"], "dome"],
	["assets/swf/anim_win.swf", ["anim_win"], "anim_win"],
	["assets/swf/anim_lose.swf", ["anim_lose"], "anim_lose"],
]
## The copy of a SWF file with the windows, from which the port draws them.
const WINDOWS_FILE := "windows.swf"


## The symbols of the client file whose windows the port shows.
static func symbols() -> PackedStringArray:
	var names := PackedStringArray(SYMBOLS_BEFORE_MARKS)
	for side: String in MARK_SIDES:
		for n in range(1, MARK_WIDTHS + 1):
			names.append("PeanaBuilding%s%dx%dMC" % [side, n, n])
	names.append_array(SYMBOLS_AFTER_MARKS)
	return names


## Imports the windows and their pictures. unit_thumbs: the file names of the
## pictures in buildingthumbs that the windows and the portrait buttons can
## show. more_images: other pictures of assets/images_new, for example of the
## spells ("<img_name>.jpg" and "prev_<img_name>.jpg") and of the goals.
## Returns {"count": number of imported sprites and buttons} or {"error": text}.
static func import_ui(source: String, out_dir: String, unit_thumbs: PackedStringArray, more_images: PackedStringArray) -> Dictionary:
	var ui_dir := out_dir.path_join("ui")
	var result := import_windows(source.path_join(CLIENT_SWF), symbols(), ui_dir)
	if result.has("error"):
		return result
	var count: int = result["count"]
	for other: Array in OTHER_SWFS:
		result = import_windows(source.path_join(other[0]), PackedStringArray(other[1]), ui_dir.path_join(other[2]))
		if result.has("error"):
			return result
		count += result["count"]
	var copies := []  # [from, to]
	for image: String in IMAGES + Array(more_images):
		copies.append([source.path_join("assets/images_new").path_join(image), ui_dir.path_join("images").path_join(image)])
	for image: String in EXTERNALIZED_IMAGES:
		copies.append([source.path_join("assets/externalized").path_join(image), ui_dir.path_join("images").path_join(image)])
	for copy: Array in copies:
		var error := ImportFiles.make_dir(copy[1].get_base_dir())
		if error.is_empty():
			error = ImportFiles.copy(copy[0], copy[1])
		if not error.is_empty():
			return {"error": error}
	var error := ImportFiles.make_dir(ui_dir.path_join("thumbs"))
	if not error.is_empty():
		return {"error": error}
	for thumb in unit_thumbs:
		var path := source.path_join("assets/buildingthumbs").path_join(thumb)
		if FileAccess.file_exists(path):
			error = ImportFiles.copy(path, ui_dir.path_join("thumbs").path_join(thumb))
			if not error.is_empty():
				return {"error": error}
	return {"count": count}


## Writes windows.swf and layout.json of the symbols of one SWF file to ui_dir.
## Returns {"count": number of sprites and buttons} or {"error": text}.
static func import_windows(swf_path: String, names: PackedStringArray, ui_dir: String) -> Dictionary:
	var result: Dictionary = SwfImport.windows(swf_path, names)
	if result.has("error"):
		return {"error": "%s: %s" % [swf_path, result["error"]]}
	var windows: Dictionary = result["value"]
	var error := ImportFiles.make_dir(ui_dir)
	if error.is_empty():
		error = ImportFiles.write_bytes(ui_dir.path_join(WINDOWS_FILE), windows["swf"])
	if error.is_empty():
		error = ImportFiles.write_bytes(ui_dir.path_join("layout.json"), (windows["layout"] as String).to_utf8_buffer())
	if not error.is_empty():
		return {"error": error}
	return {"count": windows["count"]}
