# Godot port: status before the release

This file replaces `docs/PORT_GAPS.md`. That file described finished work at length and did not show clearly what is still wrong or unknown. Its last version is in commit `2d21606`.

This file has three lists:

1. [Differences from the client that stay](#1-differences-from-the-client-that-stay): known, with their cause.
2. [Parts not compared with the original game](#2-parts-not-compared-with-the-original-game): the port follows the client code, but nobody saw the original game do the same.
3. [Work for the release](#3-work-for-the-release): step 6.2.

"The client" is the 1.4.07 client (`SocialEmpires1.4.07sec_fixed.swf`). "Ruffle" is the client in the Ruffle build of `templates/js/ruffle/` with the Python server; it is the reference of the port. Flash Player was not used. The battle details are in `docs/GODOT_BATTLES.md`, the art details in `docs/FLASH_ART.md`.

## The state in short

- The port has all parts of the original game that this server supports, except the parts that the owner decided against (see [Decisions of the owner](#decisions-of-the-owner)).
- Nobody has played the port for a long time. The tests are the checks in `godot/checks/`, scratch runs of single features, screenshots, and the comparisons with Ruffle named in this file and in `docs/GODOT_BATTLES.md`. A long play from a new empire, and with an advanced save, can find faults that cross features. Do it before the release.
- The port was run only on Linux.

## 1. Differences from the client that stay

Kind:

- **Open**: a fault of the port that can be fixed.
- **Port rule**: the port does it differently on purpose; the reason is in the row.
- **Limit**: a limit of Godot, of the data or of the offline game.

### The village and its HUD

| Difference | Kind | Notes |
|---|---|---|
| The floating numbers (`NumberParticle`): the client calls them at 68 places. The port calls them for all parts that it has; `ui/number_layer.gd` lists the rules. The calls of parts that the port does not have are missing: darts, Kompu, the Arabic deals, the admin panel, building upgrades, the sale of stored items, the Heavy Siege window, graveyard capacity, the population of the recruitment, the hurry-up help of friends and the quest bars (`FauxBar`). | Limit | These parts are not in the port. |
| The floating numbers of the actions of special buildings (graveyard, Soul Mixer, Time Machine, nests) start at the middle of the screen. The client starts some of them at a button of its window. | Port rule | The port shows these actions in a panel of the HUD, not in the client windows. |
| The numbers of the purchase of the troll town do not show: the port loads the new town at once. | Port rule | |
| "Teleport not ready yet" and the Dragon Hunter text show over the unit. The client adds half the stage size instead of the place of the map, so it shows them at a wrong place when the map has moved. | Port rule | A fault of the client. |
| During a fight in the village, the store, World, Gift, the town selector, the goals, the shield, the empire name and the icons show "Wait until the fight in your village ends." In the client they work. Open windows hide during the fight. The top bars change at the end of the fight. | Port rule | The port fights on a copy of the village (`VillageBattle`) and writes the result at the end. |
| The quests in the town play in the port. The box `mcTrolls` of the bottom bar shows the quest or the time until the next one, also during a fight in the village. The client 1.4.07 does not start these quests and always hides the box (`StateNormal`). | Port rule | `town_quests/town_quests.gd` gives the rules of the port. |
| During a fight in the village the player cannot build. The fight screen shows the number of enemies; the client does not. | Port rule | Same cause as above. |
| Tutorial steps 15 to 31: the port shows a short text with the arrow; the client shows only the arrow. | Port rule | Decision 3. `ARROW_TEXTS` in `tutorial/tutorial.gd`. |
| The bottom bar is 3 pixels higher than in Ruffle at 760 × 600. | Port rule | The port uses the full-screen layout of the client (`StateNormal.setFullScreen`) at every window size. |
| When the spy screen or the tournament sets its own zoom, the knob of the zoom slider shows that zoom. The knob of the client stays where it was. | Port rule | The knob of the client is wrong there. |
| The window of the Harbor or the Zeppelin Tower opens at the page of the current island. The client opens page 1 or 3 first, then moves to that page. | Port rule | The page that shows at the end is the same. |

### Windows

| Difference | Kind | Notes |
|---|---|---|
| The cover under windows (`GuiManager.addGuiCover`, black at alpha 0.85). The client has one cover and moves it: to the HUD layer (`Base.Gui`), under all windows, or to the popup layer, over the windows that are open; when a window closes, the cover goes back to its last place. The port gives each window its own `GuiCover` (`ui/gui_cover.gd`) with one of these two places and shows only one cover: the newest when it is over the windows, else the lowest. The result on the screen is the same. The 102 calls were checked: the windows of the port with a cover in the client now have it, and the windows without one (the assist question, the team alert, the PvP help from the attack start and the shield windows) have none. | Port rule | Ruffle: the HUD under the quest start window has 0.15 of its brightness (224 to 34), as alpha 0.85 gives. |
| Spy screen, attack log, Withdraw: the client grows the button labels until they fill the button (`ButtonGenericTall`). | Port rule | The port does the same in `UiClip.grow_text()`, called from `SpyScreen.grow_label()`. It gives Attack 34, Withdraw 21 and ATTACK LOG 19 without fixed sizes (checked with a script in headless Godot). A log in Ruffle (patched copy of the SWF, outside the repository) found two causes. First, the client reads the size of the button with its scale (`asset.width`), for example 169.9 × 62.7 for Attack, and the port had used the size without the scale (155.8 × 56). Second, `GameStatic.gotoFrame` writes the text again with `setHTML` after the growth, and `resizeText` makes the font smaller while the text does not fit the field. Attack grows to 40, where the word breaks, and then shrinks to 34. The study of 12 forms of the rule missed the second step. Not checked: a text of another language in Ruffle. |
| The animation of the start window of an attack has an unnamed mask. The import keeps only named masks, so `assault_start_window.gd` cuts the animation with the rectangle of the mask. | Limit | The result looks the same. |
| PvP result window: the client shows the loss animation only from the second result of a session on, because it loads the file at the first result. The port shows it each time. | Port rule | A load fault of the client. |
| The Invite button of the Island Forge shows a message of the port. | Limit | No friends offline. |
| The cash buttons show a message of the port. | Limit | Decision 8: no cash shop. |
| Tournament: the port builds the formations from their texts and button pictures, hides the help of the start window, and writes "YOU LOST" as the title of a lost match. The window of the bots is the port's own. | Limit | The configuration has no formation layouts and none of these texts. The client windows show server data. |
| Team window in a quest: the port sorts the units by life. The client asks to sort by life but does not give the value, so its order comes from a Flash object. | Port rule | |

### Text

| Difference | Kind | Notes |
|---|---|---|
| Each line can be up to 0.5 pixel higher or lower than in Ruffle. In the help text of 11 lines, the last line was 5 pixels from its place in Ruffle. | Limit | Godot uses whole pixels between lines. |
| A field that keeps the size of the art and has no auto size cuts a text that is too long: a line that is too wide starts at the left edge and is cut at the right edge, and the lines below the field are not shown. The port does not draw a line that is only partly inside the field; Flash draws the top part of it. | Limit | The importer reads the AutoSize flag of DefineEditText. No field of the client SWFs has it, so the client code decides: 5 calls of `UiClip.set_text` have `clip` false, because the client gives the field an auto size before it writes the text (`nombreIsla` in the quest list and the forge, `attackedTxt`, `infoTxt` and `txNext` of the survival screens, `txInfo` of the unit collection reward). The other 28 calls with `fit` false cut, as the client writes these fields with `TextField.text` (for example `SagaOTDC.swf`, the shield, PvP, tournament, quest list and first offer windows). All real texts of the 28 fields were checked in the port: none is cut. A long text in the PvP search button was cut on screen. Not compared with Ruffle. |

### Art

| Difference | Kind | Notes |
|---|---|---|
| Where the graphic is half transparent below an overlay or hard light part, the part mixes with the graphic and with the map each by itself, not with their mix. The large fireball on sand: 17.4 % of its pixels differ from Ruffle by more than 24 of 255. | Limit | `docs/FLASH_ART.md`, 3.11. |
| Over the map, parts of different blend modes mix in the order of their modes, not of their depths. | Limit | Same section. |
| Thin lines of about one pixel differ in single pixels (`p.ulisesArrow`: 5.6 % of 305 pixels). | Limit | Ruffle tessellates lines; the extension strokes them. |
| Blend mode "layer" with alpha (the shadow of `2367_devilAncientDraggy`): the port applies the alpha to the group, as the Flash documentation says; Ruffle applies it to each part. | Port rule | Flash Player was not checked. |
| The gradient glow filter (3 graphics) is drawn as a glow with one colour from the gradient. Gradients with linear RGB interpolation are drawn in sRGB. Strokes that do not scale are handled only when they scale in neither direction. | Limit | `docs/FLASH_ART.md`, section 4. |
| The extension does not run frame scripts. A `stop()` in a nested animation has no effect; the animation loops. | Limit | Spells use frame labels and `spells.json` instead. |

### Battles and the mini-game

| Difference | Kind | Notes |
|---|---|---|
| The client shows other lines in the speech bubble of a unit (`IsoUnit.say`) that the port does not show, because the port does not have the event that starts them: the farewell of the cart of the allies (`ASALTO_CARRO_DESPEDIDA`, `IACartAlly.fadeCart`; the port has no cart unit in the village), the messenger of a quest (`CustomQuest`, `CustomQuestNew`; the port has no messenger unit and no camera move after the quest window), the end of a mummy (`UNIT_MOMIA_EXPIRADO`, `IsoMummy.showUnitExpired`; the port does not remove special units after 86400 s), and the boss of the dragon quest (`POPUP_MISION_CHINOSDRAGON_BOSS_SAY`, `CQuestChinosDragon.onBossAlmostKilled`; the port has no event when the boss is almost killed). All four are on the village map, where the port shows no speech bubbles. | Open | The Greater Demon says its lines: "Death to the servants of the false Emperor!" at each of the 3 quakes of Earthquake, and "Blood for the Blood God!" when Dark Ritual brings the demons. The client has a third line in `giant()`, but no code calls it. The port shows the bubble with `BattleView.say()`, through the signal `BattleSim.said`. |
| A kill comes up to about 10 % earlier or later than in Ruffle. | Limit | Random numbers in both games, and the path search of the client in Ruffle, which stops after 50 ms of real time. |
| The client shows Start Battle when the island has loaded, about 1.5 s after the first second in which it finds it loaded (`PopupLoadingQuest.onTestIfLoaded`, `onLoaded`). The port loads at once and shows it after 1.5 s. After that, the player chooses when to start in both games. | Limit | The comparison scripts waited a fixed real time, so their frame counts under the window (client 200 to 950, port about 575) depended on the speed of the run, not on a rule of the game. |
| Mini-game: the client tests the pixels of the hero and the enemies against the terrain. The port tests the bottom of their bounds against the top of the terrain. | Port rule | |

### Not a difference

Neither game can draw these: the 33 graphics with no SWF file in `assets/` (both show the loading placeholder), and the effect `b.cerberusSkullBlast`. The Dummy (`DummyDelegate`, item 1533) is not in the configuration, so neither game has it.

The dotted lines on the borders of the land blocks of the second dragon island (quest 100000033) are an effect of the Ruffle picture at a small scale, not a difference of the port. A new empire played this island in Ruffle with the setup of `tools/ruffle_quest.js` (viewport 1000 x 900, frame clock). At 1 and 2 pixels for each CSS pixel there is no line anywhere on the island. At 0.5 pixel for each CSS pixel, a dotted line shows on the borders of the land blocks. Its pixels are black (0, 0, 0), the colour of the background of this island, so they are seams between the land bitmaps that Ruffle leaves when it draws at this scale. The client code draws no line there, and the port at its own scale draws no seam.

## 2. Parts not compared with the original game

For each part: what was done, and what a comparison needs. "From the code" means that the port follows the decompiled client, and the checks or scratch runs test the port against that reading.

### Battles

| Part | What was done | What a comparison needs |
|---|---|---|
| The special abilities: 582 item ids with a delegate, 261 special units with buttons and limit attacks | From the code. Scratch runs of each id for 600 frames and of each button found no script errors. Some single attacks were checked in small battles against the code. | A Ruffle run for each unit that a player can own, with its buttons. Start with the units in the store, the nests and the Soul Mixer. |
| The effects of units: the cracks of the Mole, the bubble of Anubis, the Mother Monster balls, the Titan Lythos minions, the heads of the Three-Headed Dragon, the Swamp Minions, the flash of the Huge Egg and of Instant Limit, the extra rocks of the Catapult, the fire arrows of Castle III | From the code; seen in port screenshots. | Ruffle runs with these units. |
| The 15 spells in battles | From the code and `spell_check.gd`. No Ruffle comparison of the spell effects is recorded. | A quest in Ruffle with each spell. |
| The Fortress: the arrows of the units in it, and the units at their places | From the code and the SWF; `battle_check.gd`; port screenshot of both frames. | A save with a filled Fortress, and an attack in the village or a PvP attack on it. No save in `villages/` or `saves/` has a Fortress. |
| The health bars, the selection marks, the dome ranges and the domes | From the code; port screenshots. | Screenshots of the same battle in Ruffle. |
| Survival and the tournament | From the code; `quest_check.gd`. Their screens and bottom bar were seen only in the port. | Ruffle runs of both modes. The tournament needs a server answer with the bot teams. |
| The place of the attack bar in quests, survival and the tournament (y 50.1). The spy and PvP screens use another place, which was compared. | Not compared. | Screenshots in Ruffle. |
| Fights in general | The 28 islands were compared with one order each; troll island 1 and hard island 1 with three orders; the village attacks for 16,500 frames. | Fights with many orders. A frame-by-frame comparison is not possible, because Ruffle runs slower than real time. |

### Village and windows

| Part | What was done | What a comparison needs |
|---|---|---|
| Island Forge: the hammer animation, the prizes, Buy All, the pictures of found items, a fight on a forge island, the glow of a complete item | From the code; `village_check.gd` and `quest_check.gd`; port screenshots. The window, the dragon card and the island list were compared. | Ruffle with the event running and items given in the save. |
| The timing of the floating numbers and of the glows of a super pack, and the "Best value" star of the box of 4 items while it moves to the middle | Layout and colours compared; times not. The client code keeps the frame with the star for 1.5 seconds, as the port does. The Ruffle screenshot was taken after the box opened, and the port screenshots before, so they do not show a difference. | A Ruffle run in real time. Headless Ruffle runs too slowly. |
| The floating numbers other than those of a pack: collections, purchases, sales, training, repairs, neighbour help, rewards, battle damage and heals, PvP loot, spells and the special-building windows | From the code; a port screenshot of the kinds of values and one of a fight in the village. | Ruffle runs of these actions. |
| The place of the host on a stage larger than 760 × 600 | Not compared. | Ruffle in a larger page. |
| The news window opening at the start of a session | From the code. It did not open in the Ruffle runs, because no window of a town quest opened first. | A Ruffle session that starts with a town quest window, at level 5 or higher. |
| The tool tips and the menus of the HUD during a change of the window size | Not checked. | A port run only. |

### Points where only Ruffle was seen, not Flash Player

- The 9 nest steps at the end of the tutorial: Ruffle sent them, and the port sends them.
- The order in which the forge window fills its places (4, 5, 6, 1, 2, 3 in Ruffle).
- The second frame of an egg in the first purchase offer: the client code asks for it, Ruffle did not show it, the port shows it.

### Other parts

- **Sound**: the 7 music files and 35 sound effects play by the rules of the client's SoundManager. Nobody listened to them; the test machine has no sound card.
- **Mini-game**: the start of the 8 levels and the 3 result screens were compared. The fights were not compared frame by frame, and the window of the client around the game was not compared.
- **Memory and speed**: at 2560 × 1440 with the largest zoom, the map frames used 500 MB of the 512 MB limit of `FrameCache`. 3840 × 2160 was not measured on a GPU. The cost of the screen copy for each frame with blend layers was not measured. The first loop of a large unit can wait for its frames.

## 3. Work for the release

Step 6.2 of `docs/NATIVE_PORT.md`:

- **Import.** Done. The import runs inside the port (`godot/importer/`, with the SWF work in the extension `flash_art`), without Python and without the server code, as decision 9 sets. At the first start the port shows an import screen: the player selects the socialemperors folder, the import runs with a progress bar and can stop and continue, and then the game starts. It also runs from the command line (`importer/import_cli.gd`). An import of the unchanged socialemperors files gives the same data folder as the earlier Python importer: the same 5870 files, `config.json`, the mock villages, `layout.json` and the other JSON files equal byte for byte, and the copied and extracted files equal; only the hash of the import code in the records of the resumable import (`meta.json`, `import.json`, `mock_generator.json`) differs. The configuration was also equal at 7 other times (other shop rotations and darts dates) and with test mods, all events on and the fully random shop. The checks give the same results with the new data folder (village 917 ok, battle 143, quest 135, spell 85, mini-game 0 failed). The Python importer is removed (decision of the owner). `godot/importer/game_config_builder.gd` is a second copy of the configuration rules of `get_game_config.py` and must stay equal to it; `godot/README.md` has the method to compare them.
- **Builds.** `godot/export_presets.cfg` has presets for Linux, Windows and macOS; `godot/README.md` ("Export") tells how to build the extension and export. State of each platform:
  - Linux: exported and run. In the export, the import screen imported the unchanged socialemperors files: the data folder is equal to an import from the editor at the same time, except the hash of the import code in the records (1624 files; the export keeps the scripts as tokens). The import stopped with Stop and with a killed process, and continued after a restart to the same data folder as an import without a stop. A new empire, the village and a fight in the village ran in the export. The checks cannot run in an export (Godot export templates have no `--script`); with the editor, on the data folder of the export, they gave village 917 ok, battle 143, quest 135, spell 85, mini-game 0 failed.
  - Windows: the extension cross-builds on Linux and the export is made, but it was not run. Wine stops at its own start in the build container. A run on Windows is to do.
  - macOS: the preset is valid, but the export needs `libflash_art.dylib`, which must be built on a Mac. Not built and not run.
- **Launcher.** The exported game is the launcher: at the first start it shows the import screen, then the start screen with the saves. The start screen has a button to import the game files again, for example after an update of the port; the import skips the graphics that are up to date. Open points: the import screen does not remember the socialemperors folder of the last import, so the player selects it again; and the game does not let the player choose the data folder (now: `--data` or `SE_DATA_DIR`).

## Decisions of the owner

1. Dragon Riding and the Rider Academy play the mini-game of the client (`SagaOTDC.swf`); the academy keeps Fast train.
2. No darts. Players cannot open darts in 1.4.07: its menu is always hidden.
3. Tutorial steps 15 to 31 keep the port's short text with the arrow.
4. On large screens, the port has a UI scale only; the layout of the client stays. Ctrl and + or − change it, Ctrl and 0 sets it back to automatic.
5. No ship and zeppelin exploration maps. The 1.4.07 client opens them only with developer keys, and no copy of the maps is known. Sail and Fly open the island window, as in the client.
6. The Island Forge is in the port. The event uses the date of the server configuration, or `island_forge_date` and `island_forge_days` in `[events]` of `user://settings.cfg`. Horns are bought for cash only.
7. The server bugs found while reading the server code are fixed.
8. No cash shop and no new cash source. The cash comes from the start (20), most new levels (1), the login bonus (10 on day 3), unit collections (1 each), and the PvP shields, which give back twice their price.
9. The import runs inside the port, in GDScript and the extension `flash_art`, without Python and without the server code. The player selects a socialemperors folder, and the import reads only its data: `assets/`, `config/`, `mods/`, `villages/`, `server_config.json` and `templates/img/profile/`. The port then has its own copy of the configuration rules of `get_game_config.py` (patches, mods, events), which must give the same configuration as the server.

The battle decisions (quest limit, Sacred Rain, Ether Shield, the tournament against bots without ranking or prizes) are in `docs/GODOT_BATTLES.md`.

Parts of the client that are not in the port because they need Facebook, payments or other players: the cash shop, the other viral icons (all off in the server config), the PvP and tournament rankings, and help from real friends. The neighbours are the villages of `villages/` and 10 mock villages. The Monday bonus, the comeback bonus, the Ivory Challenge, the Night Forge and the Easter Dragon events are off in the server config. Whether a player can reach the mystery boxes (`PopupMistery`, `PopupSuperMistery`) outside the packs was not checked.
