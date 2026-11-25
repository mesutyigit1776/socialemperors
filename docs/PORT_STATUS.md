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
| The floating numbers (`NumberParticle`): the client calls them at 68 places. The port calls them for all parts that it has; `ui/number_layer.gd` lists the rules. The calls of parts that the port does not have are missing: darts, Kompu, the Arabic deals, the admin panel, building upgrades, the sale of stored items, the Heavy Siege window, graveyard capacity, the population of the recruitment, the hurry-up help of friends, the Round Table rewards and the quest bars (`FauxBar`). | Limit | These parts are not in the port. |
| The floating numbers of the actions of special buildings (graveyard, Soul Mixer, Time Machine, nests) start at the middle of the screen. The client starts some of them at a button of its window. | Port rule | The port shows these actions in a panel of the HUD, not in the client windows. |
| The numbers of the purchase of the troll town do not show: the port loads the new town at once. | Port rule | |
| "Teleport not ready yet" and the Dragon Hunter text show over the unit. The client adds half the stage size instead of the place of the map, so it shows them at a wrong place when the map has moved. | Port rule | A fault of the client. |
| During a fight in the village, the store, World, Gift, the town selector, the goals, the shield, the empire name and the icons show "Wait until the fight in your village ends." In the client they work. Open windows hide during the fight. The top bars change at the end of the fight. | Port rule | The port fights on a copy of the village (`VillageBattle`) and writes the result at the end. |
| The quests in the town play in the port. The box `mcTrolls` of the bottom bar shows the quest or the time until the next one, also during a fight in the village. The client 1.4.07 does not start these quests and always hides the box (`StateNormal`). | Port rule | `town_quests/town_quests.gd` gives the rules of the port. |
| During a fight in the village the player cannot build. The fight screen shows the number of enemies; the client does not. | Port rule | Same cause as above. |
| Tutorial steps 15 to 31: the port shows a short text with the arrow; the client shows only the arrow. | Port rule | Decision 3. `ARROW_TEXTS` in `tutorial/tutorial.gd`. |
| The bottom bar is 3 pixels higher than in Ruffle at 760 × 600. | Port rule | The port uses the full-screen layout of the client (`StateNormal.setFullScreen`) at every window size. |
| When the spy screen or the tournament sets its own zoom, the knob of the zoom slider shows that zoom. The knob of the client stays where it was. | Port rule | The knob of the client is wrong there. |
| The banner of a cast spell (`CastBanner`) does not move when the window size changes during its 2 seconds. | Open | |
| The village does not stop while the mini-game is open; the client stops it. | Open | |
| The window of the Harbor or the Zeppelin Tower opens at the page of the current island. The client opens page 1 or 3 first, then moves to that page. | Port rule | The page that shows at the end is the same. |

### Windows

| Difference | Kind | Notes |
|---|---|---|
| After a purchase in a super pack, the box shows a "Best value" star while it moves to the middle. Ruffle shows no star. | Open | |
| In the unit list a few long names get a slightly different font size. | Open | Cause not found. |
| Spy screen: the client shows the assault HUD behind the start window; the port shows the enemy village without the bar. | Open | |
| Spy screen, attack log, Withdraw: the client grows the button labels until they fill the button (`ButtonGenericTall`). The port uses the sizes that Ruffle showed (Attack: 34). | Open | A text of another length gets the wrong size. |
| The animation of the start window of an attack has an unnamed mask. The import keeps only named masks, so `assault_start_window.gd` cuts the animation with the rectangle of the mask. | Limit | The result looks the same. |
| PvP result window: the client shows the loss animation only from the second result of a session on, because it loads the file at the first result. The port shows it each time. | Port rule | A load fault of the client. |
| A found forge item (`ForgeToken`) shows no picture on the map of a forge island, because the port gives the copper at the end of the quest. In the client the picture of a fight stays until the player clicks it; in the port it goes away with the fight screen. | Open | |
| The Invite button of the Island Forge shows a message of the port. | Limit | No friends offline. |
| The cash buttons show a message of the port. | Limit | Decision 8: no cash shop. |
| Tournament: the port builds the formations from their texts and button pictures, hides the help of the start window, and writes "YOU LOST" as the title of a lost match. The window of the bots is the port's own. | Limit | The configuration has no formation layouts and none of these texts. The client windows show server data. |
| Team window in a quest: the port sorts the units by life. The client asks to sort by life but does not give the value, so its order comes from a Flash object. | Port rule | |
| The second dragon island: the client draws land blocks without land black and draws blue dotted lines on the borders of land blocks. The port draws sea and no lines. | Open | Only the picture changes. |

### Text

| Difference | Kind | Notes |
|---|---|---|
| Each line can be up to 0.5 pixel higher or lower than in Ruffle. In the help text of 11 lines, the last line was 5 pixels from its place in Ruffle. | Limit | Godot uses whole pixels between lines. |
| A character without a glyph in the font: Flash gives it no width; the port draws the empty glyph, half an em wide. | Open | |
| A text that the client writes with `TextField.text` or with an auto size does not get smaller in the client. The port makes every text smaller when it does not fit. | Open | Not found in the fields that the port writes, but 105 calls of the port were not all compared with the client. |

### Art

| Difference | Kind | Notes |
|---|---|---|
| Where the graphic is half transparent below an overlay or hard light part, the part mixes with the graphic and with the map each by itself, not with their mix. The large fireball on sand: 17.4 % of its pixels differ from Ruffle by more than 24 of 255. | Limit | `docs/FLASH_ART.md`, 3.11. |
| Over the map, parts of different blend modes mix in the order of their modes, not of their depths. | Limit | Same section. |
| In windows, parts with these blend modes mix only with the graphic, not with what is behind the window. | Open | The scan was for the map only. |
| Thin lines of about one pixel differ in single pixels (`p.ulisesArrow`: 5.6 % of 305 pixels). | Limit | Ruffle tessellates lines; the extension strokes them. |
| Blend mode "layer" with alpha (the shadow of `2367_devilAncientDraggy`): the port applies the alpha to the group, as the Flash documentation says; Ruffle applies it to each part. | Port rule | Flash Player was not checked. |
| The gradient glow filter (3 graphics) is drawn as a glow with one colour from the gradient. Gradients with linear RGB interpolation are drawn in sRGB. Strokes that do not scale are handled only when they scale in neither direction. | Limit | `docs/FLASH_ART.md`, section 4. |
| The extension does not run frame scripts. A `stop()` in a nested animation has no effect; the animation loops. | Limit | Spells use frame labels and `spells.json` instead. |

### Battles and the mini-game

| Difference | Kind | Notes |
|---|---|---|
| The client shows other lines in the speech bubble of a unit (`IsoUnit.say`) that the port does not show: the farewell of the cart of the allies (`ASALTO_CARRO_DESPEDIDA`), the messenger of a quest (`CustomQuest`, `CustomQuestNew`), the end of a mummy (`UNIT_MOMIA_EXPIRADO`), the boss of the dragon quest of `CQuestChinosDragon` and the Greater Demon. | Open | Found with the lines of the captains. The port shows the bubble with `BattleView.say()`. |
| A kill comes up to about 10 % earlier or later than in Ruffle. | Limit | Random numbers in both games, and the path search of the client in Ruffle, which stops after 50 ms of real time. |
| The time under the start window of a quest differs (client 200 to 950 frames, port about 575), so the fights that start under it are at another point. | Open | |
| Mini-game: the client tests the pixels of the hero and the enemies against the terrain. The port tests the bottom of their bounds against the top of the terrain. | Port rule | |
| Mini-game: in the client, flying spears and arrows also move with the hero while the screen does not follow him (at the start and end of a level). In the port they do not. | Open | |

### Not a difference

Neither game can draw these: the 33 graphics with no SWF file in `assets/` (both show the loading placeholder), and the effect `b.cerberusSkullBlast`. The Dummy (`DummyDelegate`, item 1533) is not in the configuration, so neither game has it.

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
| The timing of the floating numbers and of the glows of a super pack | Layout and colours compared; times not. | A Ruffle run in real time. Headless Ruffle runs too slowly. |
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

- **Launcher and import.** The import (`godot/importer/import_assets.py`) needs Python 3, the server requirements and a copy of the socialemperors folder, and runs from the command line. The player must supply the game files (the legal rule of option C). The launcher must do this for the player, or the import must change.
- **Builds.** The project has no export presets. The extension `flash_art` must be built for each platform; the Windows cross build compiles, but the port was never run on Windows or macOS.

## Decisions of the owner

1. Dragon Riding and the Rider Academy play the mini-game of the client (`SagaOTDC.swf`); the academy keeps Fast train.
2. No darts. Players cannot open darts in 1.4.07: its menu is always hidden.
3. Tutorial steps 15 to 31 keep the port's short text with the arrow.
4. On large screens, the port has a UI scale only; the layout of the client stays. Ctrl and + or − change it, Ctrl and 0 sets it back to automatic.
5. No ship and zeppelin exploration maps. The 1.4.07 client opens them only with developer keys, and no copy of the maps is known. Sail and Fly open the island window, as in the client.
6. The Island Forge is in the port. The event uses the date of the server configuration, or `island_forge_date` and `island_forge_days` in `[events]` of `user://settings.cfg`. Horns are bought for cash only.
7. The server bugs found while reading the server code are fixed.
8. No cash shop and no new cash source. The cash comes from the start (20), most new levels (1), the login bonus (10 on day 3), unit collections (1 each), and the PvP shields, which give back twice their price.

The battle decisions (quest limit, Sacred Rain, Ether Shield, the tournament against bots without ranking or prizes) are in `docs/GODOT_BATTLES.md`.

Parts of the client that are not in the port because they need Facebook, payments or other players: the cash shop, the other viral icons (all off in the server config), the PvP and tournament rankings, and help from real friends. The neighbours are the villages of `villages/` and 10 mock villages. The Monday bonus, the comeback bonus, the Ivory Challenge, the Night Forge and the Easter Dragon events are off in the server config. Whether a player can reach the mystery boxes (`PopupMistery`, `PopupSuperMistery`) outside the packs was not checked.
