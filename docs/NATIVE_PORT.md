# Native port: feasibility and plan

Date: 2026-10-29. Based on `docs/AUDIT.md`, measurements of the client SWF, and web research. Sources are linked inline. Statements marked *estimate* are judgments, not sourced figures. None of this is legal advice.

## Summary

A native version is possible, at two very different levels of effort:

1. **Run the original client natively.** Package the original game with Ruffle's desktop player (a native Rust/wgpu application) and the existing Python server as one installable app. This takes weeks, keeps the original behaviour, and runs on Windows, macOS and Linux. It depends on how well Ruffle runs this game, which has not been tested yet.
2. **Rewrite the client in a modern engine.** Rebuild it in Godot 4 (or Unity), with the art converted to sprite sheets and the game logic reimplemented. This takes one to three person-years, reaches mobile, and performs best. Most of the work is the client, not the server.

Decision (2026-10-29): do option A (section 2) first. When it is finished and working well, move on to option C. Option A gives a playable native build quickly and produces the test setup and documentation that option C needs. Decide the legal approach (section 6) before starting option C.

Update (2026-10-29): option A is paused at about 20%. Ruffle 0.7.1 is bundled, and the server fixes in Phase 1, step 3 are done (atomic saves with a `.bak` copy). The desktop app, the full play test and the `ExternalInterface` question are still open. Work continues on option C, on a separate branch.

Decisions for option C (2026-10-29):

- The port contains only our own code. Users supply the original game files, and an import tool converts the art.
- We may study the decompiled client to learn the rules for combat, units and other client-side logic. We write new code and do not translate the decompiled code. Note: section 6 explains that this makes the port a derived work, not a clean-room reimplementation.
- The language is GDScript.

## 1. What the client contains

Measured from `assets/flash/SocialEmpires1.4.07sec_fixed.swf`. Details are in `docs/AUDIT.md`, section 4.

| Item | Finding | Why it matters |
|---|---|---|
| Language | ActionScript 3, SWF version 10 | Ruffle's AS3 support (AVM2) is less complete than its AS1/2 support. Harman AIR and Haxe/OpenFL tooling both apply. |
| Code size | 2.7 MB of bytecode, about 1,950 classes, about 17,000 methods | A rewrite is a large project. |
| Rendering | Display list with vector shapes, timelines and JPEG bitmaps. No Stage3D found. | Ruffle handles this kind of content better than Stage3D. Art can be baked to bitmaps. |
| Obfuscation | About 6% of identifiers renamed (for example `_-DZ`). Package and class names are mostly readable. | Decompiled code is readable enough to study. |
| Network | HTTP through `URLLoader`, plus `ExternalInterface`. No sockets. | Easy to point at a local server. `ExternalInterface` needs a replacement outside a browser. |
| Logic location | Isometric engine, pathfinding (`com.socialpoint.astar`), battles (`core.attacks`, `battle`), magic, quests and goals are all in the client. | The Python server is not a full specification of the game. Combat and simulation would have to be reconstructed from client behaviour. |

The last row is the main constraint on a rewrite. The server stores state and applies commands, but how a battle plays out is decided in the client.

## 2. Options

### A. Original client with Ruffle desktop and a local server

Ship one app containing:

- the Ruffle desktop player;
- the server, built with PyInstaller;
- the game files;
- a small launcher that starts the server and then opens Ruffle on the local URL.

Ruffle is licensed MIT or Apache-2.0, so it can be bundled ([README](https://github.com/ruffle-rs/ruffle)).

- **Ruffle status:** stable releases come out every few weeks (0.5.0 on 2026-08-03, 0.6.0 on 2026-09-06, 0.7.1 on 2026-10-07, per the npm package history), with nightly builds almost daily in between ([releases](https://github.com/ruffle-rs/ruffle/releases)). Stable builds exist for the web and for desktop on Windows, macOS and Linux. The project describes AS3 support as good, with "most games playable" ([FAQ](https://github.com/ruffle-rs/ruffle/wiki/Frequently-Asked-Questions-For-Users)). Secondary sources put it at about 90% of the AS3 language and 76–82% of the AS3 API; no current official figure was found.
- **Desktop player:** `ruffle_desktop` is a native application that renders with wgpu, and raw sockets work in it ([Using Ruffle](https://github.com/ruffle-rs/ruffle/wiki/Using-Ruffle)). There is no built-in way to pack a SWF into an executable, so the launcher has to start it.
- **ExternalInterface:** the client uses `ExternalInterface` for Facebook-style calls and for `templates/js/external_interface.js`. Ruffle desktop has no page JavaScript to answer those calls. There are two ways to handle this:
  1. Use a webview shell (Tauri or Electron) running Ruffle's web build. This keeps `ruffle.html` and the existing JavaScript bridge unchanged.
  2. Handle the calls in a patched Ruffle desktop build.

  Option 1 is less work. Option 2 gives a lighter app.
- **Effort** (*estimate*): 0.5–1.5 person-months. Most of the time goes into testing the game in Ruffle and fixing or reporting what breaks.
- **Limits:**
  - Performance is limited to what Ruffle achieves with this content.
  - Mobile is impractical.
  - The game still runs the original Social Point code.

### B. Harman AIR wrapper

Harman maintains the AIR SDK. Version 51.3.3.2 was released on 2026-07-07 and supports Windows, macOS, Android and iOS, with Linux on glibc 2.34 or newer ([announcements](https://github.com/airsdk/Adobe-Runtime-Support/discussions/1699)). The captive runtime bundles AIR with the app.

A small AIR shell app would load `SELoader.swf` and the client with `Loader`. It would replace the `ExternalInterface` calls with AS3 code and point all requests at the server.

- **Benefit:** the original code runs on Adobe's own runtime design, so behaviour should be close to Flash Player. It is the only route to mobile that keeps the original client.
- **Costs** (*estimate*):
  - 2–4 person-months.
  - Security-domain changes for the loader.
  - Possible license fees: Harman's published pricing charges above $50k/year revenue, which does not apply to a free project ([pricing PDF](https://airsdk.harman.com/assets/pdfs/Adobe%20AIR%20-%20Updated%20Pricing.pdf); may be out of date).
  - Dependence on one small vendor.
  - The Python server cannot run on iOS or Android, so a mobile build would also need the server logic ported.

### C. Rewrite in Godot 4

A new client in Godot 4 (MIT license, no fees, exports to Windows, macOS, Linux, Android and iOS).

- **Art:** batch-export the SWF sprites with JPEXS FFDec ([repo](https://github.com/jindrapetrik/jpexs-decompiler), GPL-3.0, has a command line). Bake each building and unit animation into sprite-sheet atlases. Converting the vector timelines into live Godot animations is possible with plugins such as GDAnimate, but those are lightly maintained, and baking is simpler for about 1,600 building sprites.
- **Logic:**
  - Economy, buildings, quests and goals can follow the Python server (`op.py`, `engine.py`) and `config/`.
  - Combat, unit AI, pathfinding and magic exist only in the client. They have to be reconstructed by studying the decompiled AS3 or by observing the running game.
  - Keep the Python server running alongside during development and compare results to catch differences.
- **Server:** for a single-player release, move the rules into the client and keep saves local. A small server is only needed for shared features such as visiting neighbours or PvP between real players.
- **Effort** (*estimate*): 12–36 person-months, depending on how much of the content (all units, bosses, minigames, events) is included. The comparable case of FlowPlay converting 1.4 million lines of AS3 to Haxe took a team, not one person ([case study](https://haxe.org/blog/flowplay-casestudy/)).
- **Benefits:**
  - Best performance.
  - Runs on every platform, including mobile.
  - Can be released without Social Point's code. See section 6.

### D. Convert the decompiled AS3 to Haxe/OpenFL

Decompile the client and convert it with as3hx, fixing the result by hand. OpenFL keeps a Flash-like API, so the structure carries over.

- **Effort** (*estimate*): 8–18 person-months.
- **Trade-offs:** fidelity is high where the conversion works. The 6% obfuscated names, E4X usage and the Flash UI components need manual work. The result is derived directly from Social Point's code, which is the weakest legal position of the four options.

## 3. Comparison

| | A. Ruffle desktop | B. AIR wrapper | C. Godot rewrite | D. Haxe conversion |
|---|---|---|---|---|
| Effort, person-months (*estimate*) | 0.5–1.5 | 2–4 | 12–36 | 8–18 |
| Matches original behaviour | Yes, within Ruffle's support | Yes | Approximately | Mostly |
| Performance on modern hardware | Good, untested on large villages | Unknown | Best | Good |
| Windows / macOS / Linux | Yes | Yes (Linux limited) | Yes | Yes |
| Android / iOS | No | Yes, with server ported | Yes | Yes |
| Contains Social Point code | Yes (original files) | Yes (original files) | No | Yes (converted) |

## 4. Recommended plan

**Phase 1: playable native build (about 1 month)**

1. Pin Ruffle: include a specific stable release in the repo instead of loading it from unpkg.
   Done: Ruffle `0.7.1` (web self-hosted build, released 2026-10-07) is in `templates/js/ruffle/`, and `templates/ruffle.html` loads it from there. In headless Chromium it loads the newest client (`SocialEmpires1.4.07sec_fixed.swf`), creates a new empire and reaches the tutorial, with the client sending commands to the server. The 2026-10-29 nightly gave the same result. Nothing past the first tutorial screen has been tested yet.
2. Test the newest client (`SocialEmpires1.4.07sec_fixed.swf`) in Ruffle. Cover a full session: login, building, production, a quest, a PvP attack, Soul Mixer and a save/reload. Record each failure and report Ruffle bugs upstream.
3. Fix the server bugs in `docs/AUDIT.md`, section 7, and make saves atomic.
4. Build the desktop app: launcher, PyInstaller server, and Ruffle. Use a webview shell first, so the existing `ExternalInterface` JavaScript keeps working.
5. Add a smoke test for the server. The project does not use CI.

**Phase 2: decide on legal approach and document the game (1–2 months)**

1. Choose between distributing the game files and requiring users to supply them (section 6).
2. Write a specification of the server protocol and the game rules from `op.py`, `engine.py` and `config/`. This is useful for Phase 1 maintenance and is the starting point for a rewrite.

**Phase 3: rewrite prototype (3 months, now started before Phase 1 is finished)**

1. In Godot 4, build an isometric map with one village, building placement, production, and a few animated units, using art baked from the SWFs.
2. Measure the size of the baked art compared with the 1.3 GB of SWFs, and frame rate on large villages.
3. Decide whether to continue to the full rewrite, based on the prototype.

**Phase 4: full rewrite (12 or more months)**

Port the economy and quests, then combat and the remaining systems. Check each system against the original game running in Phase 1's build. Add Android and iOS builds at the end.

Update (2026-10-30): the prototype became the port on branch `godot-port`. It has the village economy, the special buildings, the battle rules, and the battle screen with the unit controls. The roadmap below replaces the order of Phase 4. Step 1 of the roadmap is done: 12 campaign islands can be played. The owner moved the desktop build to step 6, so that the work continues with the port.

## 4a. Roadmap of the Godot port

The steps come in this order. Each step ends with checks, and, where it changes the save, a replay against the server. `docs/GODOT_BATTLES.md` has the details of the battle stages.

**1. First playable quest** (done)

1. Finish the battle screen: the graphics of shots and effects from `assets/fx/`, and shots that start at 0.75 of the height of the shooter, as in the client (battle stage 2).
2. Campaign quests: the island list, open islands, the limit of quests in a row, the army, the map, the goals of the troll and civilisation islands (12 islands), and the end of the quest as `end_quest` writes it: gold, experience, honour, stars and lost units (battle stage 3). The windows of the quests use the art and the fonts of the client.
3. Let the loader read the quest maps `100000053` and `100000054`, which store the level as text.

**2. Spells and the first comparison** (done)

1. Spells: mana, buying and using spells, shields (battle stage 4). Done.
2. An import that continues after a stop. Done. The port then draws the SWF art itself while it runs (the Rust extension `godot/flash_art`), so the import only copies the files and takes less than a minute. Done.
3. The first comparison with the original game: the same quest in Ruffle and in the port, for targets, duration and losses. This also shows if Ruffle can run the game far enough to be the reference. Until now, the port is checked only against the rules in the client code, so this comparison comes before the quests of step 3. Done: Ruffle runs troll island 1 from the village to the end of the quest. The targets, the gold, the experience and the losses agree, and the fights take about as many frames; the client runs the battle while its start window is open; the port now does the same (`docs/GODOT_BATTLES.md`, "Comparison with the original client"). The pictures of the extension were also compared with Ruffle and changed where they differed (`docs/FLASH_ART.md`).

**3. The campaign, one quest at a time** (done)

1. For each quest: the quest script and the special abilities of the units and bosses on its map. Each quest is then complete (battle stage 5). Done: all 28 islands of the island list are in the port (`docs/GODOT_BATTLES.md`, "Stage 5 result"). Survival and the tournament are not in the island list; they are in step 4. The collection islands belong to the collect game, an event of the client, which is not in the port yet.
2. The special abilities of the other units that a player can own: store, nests, Soul Mixer, riders (battle stage 6). Done: all delegates and special unit classes of the client that change a battle, the portrait buttons with their cast and cooldown times, the limit bars and the limit attacks, and the spell Instant Limit (`docs/GODOT_BATTLES.md`, "Stage 6 result").

**4. The rest of the single-player game** (done)

1. Sieges on the own village, survival and tournament (battle stage 7). Done: the idle enemies, bandits, sieges, stampedes, armies and the Evil Orc Dragon of the own village, survival, and the weekly tournament against its bots without a ranking and prizes, by the decision of the owner (`docs/GODOT_BATTLES.md`, "Stage 7 result"). The heavy siege is off in the client.
2. The other special buildings: Time Machine, weather machine, Bahamut temple. Done: the Time Machine moves the times of the save back as the server does, the Weather Machine changes the style of the map (land, trees and background), and the Supreme Dragon Temple gives the Supreme Bahamut Dragon after its 12 steps. A replay of the 44 commands on the server gives the same save. After a use of a machine, the port loads the village again, as the client does. In Ruffle, the original client shows the same snow land and snow trees for the snow style.
3. Goals and the tutorial. Done: the 205 goals of the configuration with the rules of the client's goal classes (15 active goals, counts of the session, rewards as `reward_mission` and `complete_mission` write them), the goal box and window with the pictures of the goals, and the tutorial of a new empire with its 32 steps and its limits. The owner decided to add the village actions that the goals need: land, the market, the name of the empire, the store button, unit packs, the workers of buildings, the selection of several units, repairs of damaged buildings and the healing spring. Only the goals that need other players stay open. A replay of 30 commands on the server gives the same save. In Ruffle, the original client went through tutorial steps 0 to 10 with the same steps, texts and saved step numbers as the port; the automation could not place the house at step 10, so the later steps are checked only against the client code.
4. Neighbours. Done: by the decision of the owner, the neighbours are the villages of `villages/` (Arthur and Guinevere, the friend village) and 10 mock villages that the importer makes (`godot/importer/mock_villages.py`), from level 4 to 38 and from easy to brutal. They are saves in the format of the server, and one class (`godot/neighbours/neighbour_source.gd`) reads them, so that a server can replace them. The port has the neighbour bar, visits with the help of 5 buildings, the help of neighbours from the save, the workers that the server hires from the neighbours, land for gold, the allies buildings, and PvP: the search, the attack with the loot rules of the client, the result for both villages, shields and the attack log. Also the fire of damaged buildings, which 4.3 did not have. The owner decided that the search finds villages of all levels; the server finds only villages from level 8. A replay of 56 commands on the server gives the same save for the player and for the attacked village. What other players do to the village (their help, potions, the Round Table) comes only from a server.

**4.5. The troll village (the second town)** (done)

The client has a second town with the troll race, which the player buys and then travels to (PopupRaceSelector and TownManager). Done:

1. The World button and the town window (`godot/towns/`): the troll town for 100000 gold or 22 cash from level 20, as the server command `buy_map` checks; after the purchase, a button for each town. The button shows in the human town from level 20 and always in the troll town, as in the client.
2. Travel between map 0 and map 1 of the save. Each town has its own level, experience, resources, land and items; cash, the goals and the other data of privateState belong to the player. A save without map 1 gets the troll town of the server's save migration (`fix_troll_empire`) at the purchase.
3. The troll town in play: the troll store, units, animals and village attacks, quests and attacks with the troll army, and the client's race rules: no collections and no received help in the troll town.
4. Checks (`village_check.gd`), a server replay of `buy_map` and of commands in both towns with identical saves, a UI run, and the docs.

**4.6. The quests in the town (QuestsInMap)** (done)

The 1.4.07 client has a chain of 30 quests on the player's own map, but it never starts them: only its admin console calls the code that places a quest. A quest building in a save (the princess camp of `villages/initial1407.json`) shows "Defeat all enemies to rescue the Princess!", but it cannot open: when the last enemy dies, the client reads a HUD timer that it never creates (`countdownTimerOgres` is null), and the code stops. Ruffle shows the same text and does not open the prisoner. The owner decided that the port plays these quests. Done:

1. The rules (`godot/town_quests/town_quests.gd`): a quest starts when the map is open and 4 hours passed since the last one, after the tutorial. The race filter of the client chooses the quest: humans skip quests 9 and 11, and the troll town plays only 1, 2, 5, 10, 12, 13 and 14. The quest keeps its state in `currentQuestVars` with `set_quest_var`, and its end sends `collect_treasure` with the gold and experience of the client's level bands, the units that the client gives (by race), and the rewards of the event quests.
2. The 28 quests that a race can play, with new layouts (`godot/town_quests/town_quest_book.gd`): walled camps with towers and a prisoner or treasure, guarded activators, and boss waves. The texts, items, rewards and order come from the client. The camp walls and towers fight for the enemy in village fights; the player cannot move or sell them.
3. Changes from the client: an activator or treasure opens when no enemy unit is within 7 tiles, not when no enemy is left on the whole map. The port places quest items with `place_stored_item`, which gives no experience; the client's free `buy` gave more than 800 experience for the walls of some camps. Level 26 gives the reward of the last band; the client gives nothing at level 26. At the end the camp goes away.
4. The window at the start and the end, the HUD line with the task or the time to the next camp, marks on the open items, and the importer exports the graphics of the quest items. Checks (`village_check.gd`), a run of all 30 quest numbers for both races in the model, a fight at a camp, and server replays of a camp, an activator quest and a wave quest (106 to 173 commands) with identical saves.

**5. The look and the sound of the original game** (done)

1. The art and the fonts of the original windows and HUD, imported from the client files, and the screens built with them. Done:
   - The HUD of the village is GuiMC of the client (`godot/village/village_hud.gd`), laid out as the client lays it out on a full screen: the bars of the top at the top, the bottom bar at the bottom, 760 pixels wide in the middle. The tools of the bottom bar have the menus of the client. The town selector of 4.5 is now the town button of the client's games menu, with its level rule. Survival, which 1.4.07 hides, shows in the World menu.
   - The store (`store_window.gd`) has the tabs, subcategories, item buttons, pages and order of BuildingWindow. The panel of a selected item (`selection_panel.gd`) uses the extended portraits EP_House_MC, EP_UnitMC, EP_Farm_MC and EP_NewBarracksMC. The actions of the port that the client has in other windows are buttons in a box above the panel.
   - The goal box and goal windows (MissionPopup, PopupGoalList), the neighbour bar (FriendsWindow, FriendButton, PopOverVisit), the tutorial box, PopupConfirm, the town window (PopupRaceSelector), the window of a quest in the town (PopupQuestInfo2 with the pictures of the quests by race), the zoom slider and a visit to a neighbour (StateNeighbour) use the art of the client. The spell book is at the place of the client's magic box.
   - The importer writes the names of the fonts, imports unnamed buttons (the icons of the menus), and makes the shapes under a named mask a sprite of their own, so that a bar fills as in Flash (the experience bar, the time bars). The other controls of the port get the fonts and colours of the client from a theme (`godot/ui/client_theme.gd`).
   - A comparison with Ruffle, the same save at 760 × 600, puts the parts of the HUD at the same places. Not in the port: the viral buttons of Facebook ("open me"), the animations of the shield (separate SWF files), the host of the goal box, the Add Cash shop and the options panel (the options panel came with 5.2; the host and the shield with 6.1).
   - The comparison also found a rule difference from step 4.1: the client sends `buy` for the idle enemies at the load of the map, which gives their experience on the server, but then sends `rt_publish_score` with its own experience, which does not count them. With the save of the comparison, the port showed 634 and the client 504. Fixed in 5.2.
2. Music and sounds. Done:
   - The importer copies the 7 music files of the client and extracts its 35 sound effects (MP3 frames in `assets/swf/120608_dynamic.swf`) to MP3 files (`godot/importer/sound_import.py`).
   - `godot/sound/` plays them with the rules of SoundManager: the volume 0.25, the cross fade of 1 second between two pieces of music, the random wait of 50 to 150 ms before an effect, and the limit of copies of each effect. The music follows the client: the town music, the troll music in the troll town, the battle music while the items of the player are attacked in the village, the quest music in quests and survival (1.4.07 never plays its survival music), and the assault music in PvP. The ship quests are not in the port, so its ship music does not play.
   - The effects play where the client plays them: the shots of the units by unit type, the hits of melee attackers, the deaths (male, female, troll and boss, machines), the magic particles, and the sounds of the special units in their abilities (beam dragons, two-head dragons, the Three-Headed Dragon with its wings, roar and death, Merlins, werewolves, the Rockdriller, the kamikaze); in the village building and the end of a construction, a building that is ready, collecting, cutting and digging, the level up, a complete collection, resurrections, the help of neighbours, the orders to units, the eagle and the ships, and the clicks of the store, the menus and the buttons that the client has as ButtonGenericTall.
   - The options panel of GuiMC: music and sounds on or off (kept in `user://settings.cfg`), full screen, and the pause with the curtain and the window of the client. In 5.2 the port showed the panel only in the village; 6.1 adds it to the battles.
   - The client builds a new building for 10 seconds with a bar; in 5.2 the port showed the building at once and played the sounds of the start and the end of the construction at the same times. 6.1 adds the scaffold and the bar.
   - The rule difference of 5.1: the experience of the idle enemies at the load stays on the save without a level up, and from level 5 the load ends with `rt_publish_score`, which takes it back (`Village.publish_score()`).
   - Checks: all checks pass (village 769, battle 130, quest 125, spell 85; the village check has a new check of the experience rule). The test machine has no sound card, so nobody listened to the sounds. They were checked by their files (all 35 effects decode), by a UI run (the town music starts, the panel turns the music and the sounds off and on, the pause stops the game, effects play) and by a battle of 60 seconds (35 shots, 55 hits, 5 deaths, up to 4 effects at the same time, no errors). With the save of the 5.1 comparison, the load placed 54 idle enemies and the experience stayed at 504, as in the client.

**6. Release**

1. A comparison of the whole game with the original, and the fixes that it finds. Done:
   - The comparison: four saves (Arthur at level 53, a test save at level 60 with two towns, a mock village at level 31 and the save of a new player) ran for 4 minutes in the original client (Ruffle with the server) and in the port, and the saves after the run were compared item by item. The server log gave the commands of the client. Screens of the village at level 2 and level 60, the login bonus window, a tournament and the goal box were compared at 760 × 600.
   - Rules that the comparison found and the port now has: the login bonus of the server (a reward for each new day of play, 5 days, with the window of the client; the unit of a day goes to the item store when the window opens); the clean of the border of the map at each start of the map (all items on the 20 tiles at the edge go away, the units of the player go near the town hall); the groups of gold, stone and trees and the single trees that the client places on the land that the player does not own at each start of the map; and the experience: the server gives the experience of the items that the client places without cost (idle enemies, the free Dragon Nest, Soul Mixer and Wizardry Academy, animals), but the client does not count it, so its `rt_publish_score` takes all of it back (5.2 took back only the idle enemies). The client checks the goals before this start of the map, so items at the border can still complete a goal (in the save of the new player, two Troll Caves of an old camp complete "Build another house"). After a quest, survival, a tournament match and an attack the client starts the map again in the same way; the port now does it too (before, only the idle enemies and attacks came again).
   - The look: the windows of the client could lose a shape of one frame when another frame had a named part at the same depth (the "Today" box of the login bonus had no gold background), and a faded part under the drawing of a window covered it; the importer now leaves out only the placements of the named parts and marks the parts under the drawing. The village starts at the zoom of the client, 0.7, with its limits 0.15 and 1.4 (before 1.0, 0.25 and 2.0); the spy screen shows the enemy at 0.5 and the tournament at 0.1, as the client does. The options panel is in the quests, survival, the tournament and PvP, and it is 50 pixels lower than in 5.2, where the client has it (in 5.2 it was under the banner of the top bar on a screen of 600 pixels). A new building shows the scaffold of the client for its size and race with the bar of the client for 10 seconds, and takes no units then. The goal box has its host (the king of GameShowHostMissionMC, which appears and then waits) and marks goals 6 to 9, 249, 250 and 1008 with "Click here!" until the player clicks them. The shield of the HUD plays the animations of `swf/shieldEnabled.swf` and `swf/shieldDisabled.swf`.
   - Checks: village 794 (new checks of the start of the map and the login bonus), battle 130, quest 125, spell 85, all pass. After the fixes, the four saves give the same login bonus values, the same goals and the same experience as the client after the load (69467 for Arthur); later differences come only from the fights of the units. The resources agree within the random sizes of the groups: for Arthur 18 stones, 15 gold and 289 trees against 18, 18 and 280 in the client.
   - Not in the port, for a decision of the owner: the list of units with the unit collections (Gift > Units, which reads `boughtUnits`), the news window and the darts game, which the menus of the port hide; the Facebook parts (the "open me" chest and the other viral buttons, `rt_publish_achievement_unit`, and the Add Cash shop); the female host of the goal box (the server always gives a male player); the spy screen without the art of the client. The ship and zeppelin explorations of the dock and the zeppelin tower cannot be compared: the server has no maps for them (`100000009`, `100000016`), so the original game cannot play them on this server either. The port does not do the other parts of the server's save migration (for example `boughtUnits` from the units of an old save); they change only the parts above that the port does not have. In battles the client keeps the zoom of the village; the port starts each battle at 0.7.
2. Builds for Windows, macOS and Linux, and for mobile if the owner decides so. Until then the port runs from the Godot editor or the command line.

Open decisions of the owner: mobile builds (touch changes the unit control in battles) and the mini-games of the nests and the Rider Academy (the port counts them as won).

## 5. Risks

- **Ruffle gaps:** if Ruffle cannot run the game well, option A fails, and option B becomes the main native option for the original client. Phase 1, step 2 tests this first.
- **Combat reconstruction:** the battle logic exists only in the client, which makes the rewrite the largest and least predictable part of option C.
- **Assets in git:** the 1.3 GB of assets in the repo make the repository slow to clone and complicate any change to how assets are distributed.
- **Single maintainer:** effort estimates assume one developer. Options C and D are realistic only with sustained time or more people.

## 6. Legal position

- Social Empires belongs to Socialpoint. Take-Two bought Socialpoint in 2017 ([tech.eu](https://tech.eu/2017/02/01/social-point-take-two-250-million/)), and Socialpoint now sits under Zynga, which Take-Two completed buying in May 2022 ([pocketgamer.biz](https://www.pocketgamer.biz/zynga-acquisition-by-take-two-now-completed)). No license or public release of the game was found.
- The repository already distributes the original SWFs, art and audio. That is the highest-risk part of the project, whichever option is chosen.
- The US DMCA preservation exemption covers bypassing protection for preservation. It does not grant a right to distribute copies.
- Precedents:
  - Disney had Club Penguin Online taken down in 2020 ([Techdirt](https://archive.techdirt.com/articles/20200515/11250044510/disney-if-we-cant-run-club-penguin-no-one-can-run-club-penguin-updated.shtml)).
  - Club Penguin Rewritten closed in 2022 with arrests by London police ([NME](https://www.nme.com/news/club-penguin-fan-remake-closed-as-police-make-three-arrests-3204722)).
  - Toontown Rewritten continues without permission. It is non-commercial and takes no donations ([FAQ](https://toontownrewritten.com/help/faq/about-toontown)).
- Lower-risk choices:
  - Release only your own code, and have users supply the game files.
  - Stay non-commercial.
  - Do not run a public hosted server.
  - Respond to takedown requests.
  - Consider asking Socialpoint for written permission.

  A rewrite based on decompiled code is a derived work. A clean-room rewrite needs one person to document behaviour and a different person to write the code.
