# Native port: plan and status

Started 2026-10-29, from `docs/AUDIT.md`, measurements of the client SWF and web research. Statements marked *estimate* are judgments, not sourced figures. None of this is legal advice.

## Summary

The project has two ways to a native game:

- **Option A: the original client with Ruffle desktop and the local server.** Paused at about 20%. It keeps the original behaviour and runs on Windows, macOS and Linux, but not on mobile.
- **Option C: a new client in Godot 4.** The current work, on branch `godot-port`. Steps 1 to 6.1 of the roadmap (section 3) are done. The work before the release is in `docs/PORT_GAPS.md`; then come the launcher and the builds (step 6.2).

Two other options were studied on 2026-10-29 and not chosen: a Harman AIR wrapper around the original client (2–4 person-months, possible license fees, one small vendor) and a conversion of the decompiled AS3 to Haxe/OpenFL (8–18 person-months, the weakest legal position). The study is in the history of this file (commit `8c4125c`).

Decisions for option C (2026-10-29):

- The port contains only our own code. Users supply the original game files, and an import tool converts them.
- We may study the decompiled client to learn the rules for combat, units and other client-side logic. We write new code and do not translate the decompiled code. Section 5 explains that this makes the port a derived work, not a clean-room reimplementation.
- The language is GDScript.

## 1. What the client contains

Measured from `assets/flash/SocialEmpires1.4.07sec_fixed.swf`. Details are in `docs/AUDIT.md`, section 4.

| Item | Finding |
|---|---|
| Language | ActionScript 3, SWF version 10 |
| Code size | 2.7 MB of bytecode, about 1,950 classes, about 17,000 methods |
| Rendering | Display list with vector shapes, timelines and JPEG bitmaps. No Stage3D. |
| Obfuscation | About 6% of identifiers renamed (for example `_-DZ`). Package and class names are mostly readable. |
| Network | HTTP through `URLLoader`, plus `ExternalInterface`. No sockets. |
| Logic location | Isometric engine, pathfinding (`com.socialpoint.astar`), battles (`core.attacks`, `battle`), magic, quests and goals are all in the client. |

The server stores state and applies commands, but how a battle plays out is decided in the client. So the port had to rebuild the battles from the client code.

## 2. Option A: original client with Ruffle desktop

One app with:

- the Ruffle desktop player (MIT or Apache-2.0, so it can be bundled; [README](https://github.com/ruffle-rs/ruffle));
- the server, built with PyInstaller;
- the game files;
- a small launcher that starts the server and then opens Ruffle on the local URL.

Facts for the launcher:

- **Ruffle desktop** (`ruffle_desktop`) is a native application that renders with wgpu ([Using Ruffle](https://github.com/ruffle-rs/ruffle/wiki/Using-Ruffle)). There is no built-in way to pack a SWF into an executable, so the launcher has to start it. Stable releases come out every few weeks, with nightly builds almost daily ([releases](https://github.com/ruffle-rs/ruffle/releases)).
- **ExternalInterface.** The client uses `ExternalInterface` for Facebook-style calls and for `templates/js/external_interface.js`. Ruffle desktop has no page JavaScript to answer those calls. Two ways: a webview shell (Tauri or Electron) with Ruffle's web build, which keeps `ruffle.html` and the JavaScript bridge unchanged; or a patched Ruffle desktop build. The webview is less work; the patched build gives a lighter app.
- **Limits:** the performance is what Ruffle achieves with this content, mobile is impractical, and the game still runs the original Social Point code.

Status:

1. Ruffle `0.7.1` (web self-hosted build, released 2026-10-07) is in `templates/js/ruffle/`, and `templates/ruffle.html` loads it from there. Done.
2. The server fixes of `docs/AUDIT.md`, section 7, for the player-name check, the asset loader and atomic saves with a `.bak` copy. Done.
3. Ruffle runs the client well enough to be the reference of the Godot port: the tutorial, quests, the village load, the windows and the attacks were played in it (section 3 and `docs/GODOT_BATTLES.md`). A full play test of option A as a product was not done. Ruffle is slower than Flash Player: the path search of the client stops after 50 ms of real time, so armies sometimes walk late or not at all.
4. Open: the desktop app (launcher, PyInstaller server, Ruffle) and the `ExternalInterface` question.

## 3. Roadmap of the Godot port

Each step ended with checks and, where it changed the save, a replay of the commands on the server that gave the same save. `godot/README.md` describes what the port does; `docs/GODOT_BATTLES.md` has the battle rules and the comparisons of the battles; `docs/FLASH_ART.md` has the art renderer.

**1. First playable quest** (done)

The battle screen with the shots and effects of `assets/fx/`, the campaign quests of the 12 troll and civilisation islands with the windows of the client, and the quest maps that store the level as text.

**2. Spells and the first comparison** (done)

1. Spells: mana, buying and using spells, shields.
2. An import that continues after a stop. The port then draws the SWF art itself while it runs (the Rust extension `godot/flash_art`), so the import only copies the files and takes less than a minute.
3. The first comparison with the original game: troll island 1 in Ruffle and in the port. The targets, the gold, the experience and the losses agree, and the fights take about as many frames. The client runs the battle while its start window is open; the port does the same.

**3. The campaign** (done)

1. All 28 islands of the island list, with the quest scripts and the special abilities of the units and bosses on their maps.
2. The special abilities of all other units that a player can own: all delegates and special unit classes of the client that change a battle, the portrait buttons with their cast and cooldown times, the limit bars and the limit attacks, and the spell Instant Limit.

**4. The rest of the single-player game** (done)

1. The enemies of the own village (idle enemies, bandits, sieges, stampedes, armies and the Evil Orc Dragon), survival, and the weekly tournament against its bots, without a ranking and prizes (decision of the owner). The heavy siege is off in the client.
2. The Time Machine, the Weather Machine and the Supreme Dragon Temple. After a use of a machine, the port loads the village again, as the client does.
3. The 205 goals with the rules of the client's goal classes, the goal box and window, and the tutorial of a new empire with its 32 steps. By the decision of the owner, the village actions that the goals need: land, the market, the name of the empire, the store button, unit packs, the workers of buildings, the selection of several units, repairs of damaged buildings and the healing spring.
4. Neighbours. By the decision of the owner, the neighbours are the villages of `villages/` and 10 mock villages that the importer makes (`godot/importer/mock_villages.py`), from level 4 to 38. One class (`godot/neighbours/neighbour_source.gd`) reads them, so that a server can replace them. The port has the neighbour bar, visits with help, the help of neighbours from the save, the workers that the server hires from the neighbours, land for gold, the allies buildings, PvP with the loot rules of the client, shields, the attack log, and the fire of damaged buildings. The PvP search finds villages of all levels (decision of the owner); the server finds only villages from level 8.

**4.5. The troll town** (done)

The second town of the client (PopupRaceSelector and TownManager): the purchase for 100000 gold or 22 cash from level 20, travel between map 0 and map 1 of the save, and the race rules of the client in the troll town. A save without map 1 gets the troll town of the server's save migration (`fix_troll_empire`).

**4.6. The quests in the town** (done)

The 1.4.07 client has a chain of 30 quests on the player's own map, but it never starts them: only its admin console places a quest, and the end of a camp stops on a HUD timer that the client never creates. Ruffle shows the same. The owner decided that the port plays these quests:

1. A quest starts when the map is open and 4 hours passed since the last one, after the tutorial. The race filter of the client chooses the quest. The quest keeps its state in `currentQuestVars` with `set_quest_var`, and its end sends `collect_treasure` with the rewards of the client.
2. The 28 quests that a race can play have new layouts (`godot/town_quests/town_quest_book.gd`). The texts, items, rewards and order come from the client.
3. Changes from the client: an activator or treasure opens when no enemy unit is within 7 tiles, not when no enemy is left on the whole map. The port places quest items with `place_stored_item`, which gives no experience; the client's free `buy` gave more than 800 experience for the walls of some camps. Level 26 gives the reward of the last band; the client gives nothing at level 26. At the end the camp goes away.

**5. The look and the sound of the original game** (done)

1. The HUD of the village is GuiMC of the client, laid out as the client lays it out on a full screen. The store, the selection panel, the goal windows, the neighbour bar, the tutorial box, the town window, the confirm window, the zoom slider and the visits use the art of the client. A comparison with Ruffle at 760 × 600 puts the parts of the HUD at the same places.
2. The 7 music files and the 35 sound effects of the client, played with the rules of its SoundManager, and the options panel of GuiMC (music, sounds, full screen, pause). Nobody listened to the sounds: the test machine has no sound card. They were checked by their files and by runs.

**6. Release**

1. A comparison of the whole game with the original, and its fixes. Done. Four saves ran for 4 minutes in the original client (Ruffle with the server) and in the port, and the saves after the run were compared item by item. The port got the rules that the comparison found: the login bonus of the server; at each start of the map, the clean of the border and the trolls, deposits, trees and animals on the land that the player does not own; and the experience rule of `rt_publish_score`. Screens were compared at 760 × 600; the port got the start zoom of the client, the scaffold of a new building, the host of the goal box and the shield animations. After the fixes, the four saves give the same login bonus values, goals and experience as the client after the load; later differences come only from the fights of the units.
2. The launcher, and builds for Windows, macOS and Linux. Mobile builds come much later, if the owner decides so (touch changes the unit control in battles). Until then the port runs from the Godot editor or the command line.

Before step 6.2 comes the work in `docs/PORT_GAPS.md`.

## 4. Risks

- **Ruffle gaps:** option A depends on how well Ruffle runs the game. It runs it well enough to be the reference of the port, but slower than Flash Player.
- **Assets in git:** the 1.3 GB of assets in the repository make it slow to clone and complicate any change to how assets are distributed.
- **Single maintainer:** the estimates assume one developer.

## 5. Legal position

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
