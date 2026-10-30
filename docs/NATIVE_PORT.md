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

Update (2026-10-30): the prototype became the port on branch `godot-port`. It has the village economy, the special buildings, the battle rules, and the battle screen with the unit controls. The roadmap below replaces the order of Phase 4.

## 4a. Roadmap of the Godot port

The steps come in this order. Each step ends with checks, and, where it changes the save, a replay against the server. `docs/GODOT_BATTLES.md` has the details of the battle stages.

**1. First playable quest**

1. Finish the battle screen: the graphics of shots and effects from `assets/fx/`, and shots that start at 0.75 of the height of the shooter, as in the client (battle stage 2).
2. Campaign quests: the quest list, unlocked quests, the waiting time between quests, the team, the map, the goal "destroy all enemies", and the end of the quest as `end_quest` writes it: gold, experience, honour, rank and lost units (battle stage 3).
3. Let the loader read the quest maps `100000053` and `100000054`, which have no level.

**2. A build for tests by hand**

1. A desktop build, so that the owner can play without the command line.
2. An import that continues after a stop. The full import of all graphics takes several hours.
3. The first comparison with the original game: the same quest in Ruffle and in the port, for targets, duration and losses. This also shows if Ruffle can run the game far enough to be the reference. Until now, the port is checked only against the rules in the client code, so this comparison comes early.

**3. The campaign, one quest at a time**

1. Spells: mana, buying and using spells, shields (battle stage 4).
2. For each of the 36 quests: the quest script and the special abilities of the units and bosses on its map. Each quest is then complete (battle stage 5).
3. The special abilities of the other units that a player can own: store, nests, Soul Mixer, riders (battle stage 6).

**4. The rest of the single-player game**

1. Sieges on the own village, survival and tournament (battle stage 7).
2. The other special buildings: Time Machine, weather machine, Bahamut temple.
3. Goals and the tutorial.
4. Neighbours, if the owner decides on a form without a server, for example the neighbour villages in `villages/`.

**5. The look and the sound of the original game**

1. The art and the fonts of the original windows and HUD, imported from the client files, and the screens built with them. This comes after the screens exist.
2. Music and sounds.

**6. Release**

1. A comparison of the whole game with the original, and the fixes that it finds.
2. Builds for Windows, macOS and Linux, and for mobile if the owner decides so.

Open decisions of the owner: mobile builds (touch changes the unit control in battles), the mini-games of the nests and the Rider Academy (the port counts them as won), and neighbours.

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
