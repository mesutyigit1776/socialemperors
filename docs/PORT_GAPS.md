# Godot port: work before the release

This file lists the work that remains on the Godot port before the launcher and the builds (step 6.2 of the roadmap in `docs/NATIVE_PORT.md`). Step 6.1, the comparison of the whole game with the original client, is done. The design of the launcher can still change, so this list does not include it.

Each item tells what the original game does, what the server of this repository supports, what the port has, and the work to add it. Work: small is up to a few days, medium is about one week, large is more than one week.

Sources: the decompiled 1.4.07 client (read to learn the rules; it is not in the repository), the server code in this repository, the port in `godot/`, runs of the original client in Ruffle, and the web. Class names below are the names in the client.

## Work list

### Group 1: fixes to parts that the port has

Done. See [Group 1: fixes](#group-1-fixes) for what changed.

| Item | State |
|---|---|
| [Tutorial](#tutorial): save steps 11 and 20 at the end of the construction, send the 9 nest steps, no dark screen behind the goal window | Done |
| [Battle zoom](#battle-zoom): keep the zoom of the village | Done |
| [Thin line between land pieces](#thin-line-between-land-pieces) | Done |

### Group 2: parts of the original game that this server supports

All of them work offline. No decision of the owner is necessary, except for the Island Forge.

| Item | Work |
|---|---|
| [Save migration](#save-migration) | Done |
| [First purchase offer ("open me")](#first-purchase-offer-open-me) | Done |
| [Unit list and unit collections](#unit-list-and-unit-collections) | Medium |
| [News window](#news-window) | Medium |
| [Spy screen art](#spy-screen-art) | Medium |
| [Achievement publish](#achievement-publish) | Small |
| [Female host](#female-host) | Small |
| [Units in buildings in battles](#units-in-buildings-in-battles) | Medium |
| [Island Forge](#island-forge-collect-game) | Large; needs a decision |

Do the save migration before the unit list, because the unit list reads `boughtUnits`.

### Group 3: the look

| Item | Work |
|---|---|
| [HUD on modern screens](#the-hud-on-modern-screens) | Medium to large; the layout for wide screens needs a decision |
| [Blend modes with the map](#blend-modes-with-the-map) | Medium to large |
| [Health bars, selection rings and effects that the client only draws](#graphics-that-the-port-does-not-draw) | Small to medium |

Do the HUD before the builds, because it changes the window settings and the options panel.

### Group 4: parts of a release that are not the launcher

| Item | Work |
|---|---|
| [Player save and start screen](#player-save-and-start-screen) | Small to medium |
| [Import of the game files](#import-of-the-game-files) | Depends on the launcher |
| [Builds](#builds) | Step 6.2 |

### Order

1. Group 1 (done).
2. Group 2 without the Island Forge (the save migration and the first purchase offer are done).
3. The player save and the start screen.
4. The HUD, then the blend modes and the other graphics.
5. The launcher and the builds (step 6.2).

Group 2 is about two to three weeks of work (*estimate*). With group 3 and the player save, about four to six weeks.

## Decisions of the owner

1. **Mini-games of the nests and the Rider Academy.** Keep the rule of the port (each game counts as won), or write a new flying game. See [Nest and Rider Academy mini-games](#nest-and-rider-academy-mini-games).
2. **Darts.** Players cannot open it in 1.4.07. Adding it is a change from 1.4.07. See [Darts](#darts).
3. **The text of tutorial steps 15 to 31.** The client shows only the arrow; the port also shows its own short text. See [Tutorial](#tutorial).
4. **HUD on wide screens.** Only a UI scale, or also a new layout. See [The HUD on modern screens](#the-hud-on-modern-screens).
5. **Ship and zeppelin explorations.** Find the maps, make them again from videos, or make new maps. See [Ship and zeppelin explorations](#ship-and-zeppelin-explorations).
6. **Island Forge.** Add it with a new event date, or leave it out. See [Island Forge](#island-forge-collect-game).
7. **Server bugs.** Fix them in the server or leave them. The port already uses the correct rule of `fix_bought_units` in its save migration. See [Server bugs](#server-bugs).
8. **Cash without payment.** The port has no cash shop. See [Facebook and payment parts](#facebook-and-payment-parts).

## Group 1: fixes

### Tutorial

Step 4.3 compared the tutorial with the original client up to step 10. A later run in Ruffle went through all 32 steps on the save of a new empire. The house must go on tile (55, 55), and the click that gives this tile is not at the centre of the green marked place on the screen. The server saved the steps 1 to 13 and 15 to 31 (14 does not show), and the save ends with `completed_tutorial` 31.

The port was then run on the same save with a script that calls its functions (not with mouse clicks). These agree with the client: the order of the steps, the skip of step 14, the tiles of the house (55, 55) and the farm (52, 44), the texts of the boxes of steps 0 to 13, goals 1, 2, 3, 4, 5 and 11 rewarded, gold, food and stone at the end, and the dragon nest. Both count any tree for the last step, not only the three marked trees.

The port now does the same as the client in these points:

1. **Steps 11 and 20.** The step goes on when the construction of the house or the farm ends, not when the player places it (`IsoElement.endConstruction`). After the house, the map moves to the knights in 1.4 seconds, and then the step is 11 (`TutorialMain.doPan`).
2. **The nest steps at the end.** After the dragon nest of the tutorial, the client sends 9 `next_step` commands without cash (`MapInitializer.spawnDragonNest`), and the server accepts them, because a new empire has `dragonNestActive` 1. The port gives the nest the same 9 steps, with the time of the last step. The client sends them only when `privateState.iphoneTutorialCompleted` is below 100. The saves of this server do not have this value; Ruffle then sent the 9 commands (server log of the run). Flash Player was not checked.
3. **The goal window in the tutorial.** The client hides the dark background of the goal window in the tutorial (`MissionPopup`, `fons`); the port does the same.

Open:

- **Steps 15 to 31.** The client shows only the arrow. The port also shows its own short text (`ARROW_TEXTS` in `godot/tutorial/tutorial.gd`, decision 3).
- Wood and experience at the end were a little lower in the port (1135 against 1175 wood, 30 against 32 experience), and the goals were completed in another order. The villager of the client cut 5 trees by itself and the port script cut 3, which explains the difference in wood; the experience was not traced.
- Not checked: if the client saves step 17 at the first click on the goal box or at the "+Info" click, because the server got steps 16 and 17 in one batch.

### Battle zoom

The client has one zoom for the whole game (`Base.currentZoom`). Each map starts at the zoom of the map before it. Only the spy screen (0.5), the tournament (0.1) and the quests in which the player cannot move the map (0.7; the ship and zeppelin quests, which the port does not have) set their own zoom, and the maps after them keep it. The port did the same only for the spy screen and the tournament, and started all other maps at 0.7. Now `MapCamera` keeps the zoom of the last map for the next one (`godot/village/map_camera.gd`). The game starts at 0.7, as in the client.

### Thin line between land pieces

On troll island 1 the port showed a gray line between two land pieces. The client in Ruffle shows a line at the same place, but a light one, which is in the art. The dark line of the port came from the black color of the transparent pixels of the frame images, which Godot mixed into the edges when it filtered the frames. FlashArt now gives the transparent edge pixels the color of their visible neighbours (`docs/FLASH_ART.md`, 3.12).

## Group 2: parts that the server supports

### Save migration

The server runs `version.py` `migrate_loaded_save` on each save that it loads. The port now does the same repairs when it loads a save (`godot/village/save_migration.gd`):

- When `boughtUnits` is missing or empty, the port makes the list again from the units on the maps, in buildings, in the item stores and warehouses, the gifts and the dead heroes. It uses the correct race rule (see [Server bugs](#server-bugs), item 1) and reads only the towns that the player owns. The server adds the troll town to each save, also when the player did not buy it.
- Old saves: a list of gifts becomes a dictionary, `collectionsCompleted` is made from the collections when it is empty, and the Heroes Grave keeps only heroes when the save has no graveyard list.
- Saves of old server versions (with the key `version`): the items get their missing values and the time of the load, the player gets the mana of the levels, the monster nest becomes active and the graveyard is emptied.

The port does not write the plain defaults that the server adds for missing values. The code that reads a value uses the same default. The troll town is added when the player buys it, and the goal box completes the land goals at the start. The port does not need the darts values, the list of banned units (empty on the server) or the removal of old fields.

Check: the port and the server, with the race rule fixed, give the same results on 8 saves of the repository (from `villages/` and `saves/`), the 10 mock neighbours and two made-up saves (two towns with old gifts, and an old server save). This was a script run; it is not part of the checks. `village_check.gd` checks the race rule, the old gifts, the Heroes Grave and an old server save.

### First purchase offer ("open me")

The "open me" chest at the side of the HUD is the icon of the first purchase offer (`FirstOfferButton`), the only viral icon with `active` 1 in the server config. The port now has it, with the rules of the client and the server:

- The icon shows in the first two days of the login bonus (`numDayLogged` below 3) until the player opens the offer, and then for 24 hours (`POPUP_FIRST_PURCHASE_OFFER_TIME`), with the time that is left. It is not shown when the session starts in the tutorial. The port places it where the client's icon panel puts it: at the right edge, under the options button.
- The first opening saves the time (`set_first_purchase_timestamp`). The window (`PopupFirstBuy`) shows the three eggs, the card of each unit when the mouse is over its egg, and the time; it closes when the time ends.
- HATCH! costs 28 cash (`POPUP_FIRST_PURCHASE_OFFER_COST`). It gives 20000 gold and 40000 food in the current town and puts the three dragons in the item store, as `buy_first_purchase` and the three `store_add_items` of the client do, and sets `firstPurchaseTimestamp` to 1. Then the icon goes away and an alert tells where the dragons are. Without enough cash, the alert of the client says so.

Compared with the original client in Ruffle on the same save: the icon at the same place at 760 × 600, the window, the unit card, the purchase (cash 53 to 25, +20000 gold, +40000 food, the three dragons in the item store) and the alert. In Ruffle the egg under the mouse did not show its second frame, which the client code asks for; the port shows it.

### Unit list and unit collections

The Gift menu has a Units button (`PopupAllUnits`). It lists the unit collections: groups of units with a reward unit. The player buys each unit for cash (`buy_stored_item_cash`; the unit goes to the item store). When all units of a group are bought, a reward button shows. In 1.4.07 the reward button opens the reward window, adds the group to `unitCollectionsCompleted`, gives 1 cash and sends `unit_collections_completed`. Neither the client nor the server stores the reward unit; this is from the code only and was not seen in a run. `UnitCollectionsManager` counts the units from `boughtUnits` and shows an alert when a group is complete.

- Config: the mega patch replaces the 62 groups of `units_collections_categories` with 128 groups.
- Server: both commands exist. `boughtUnits` is kept by `engine.py` `register_bought_unit`.
- Port: `godot/village/village_hud.gd` hides the Units button. The port keeps `boughtUnits` as the server does (`village_map.gd`), but has no list, no cash buy of units and no completion.

Web: the SuperCheats guide on collections ([link](https://www.supercheats.com/guides/social-empires/collections)) is about the item collections, which the port has; its search text also mentions units bought with cash.

Work: a list window with the art of the client, the cash buy, the completion and the alert.

### News window

`PopupNews` opens from Gift > News and also at login for players from level 5. It shows the 10 news pictures of `globals.NEWS_ITEM`, each with a link to a tab of the store, the promotion packs of `offer_packs`, the cash of the player with a button to the cash shop, and a button to the store. The server needs no command; the packs use the same commands as the store packs.

Port: `village_hud.gd` hides the News button. The port already has the store and the unit packs.

Not checked: that all 10 news pictures are in `assets/`.

Work: the window with its art; the store links and packs use the code that the port has. The cash button needs the cash shop, which is not possible offline.

### Spy screen art

`StateSpy` hides the village HUD and shows the spy frame of the attack bar (`HudSpyEnemy`): the name and level of the enemy, its resources, Attack, Find next with its cost, and My town. The port (`godot/pvp/spy_screen.gd`) has the same functions with Godot controls and the zoom of the client, 0.5.

Work: import the spy frame of the attack bar like the other HUD parts; the logic stays.

### Achievement publish

When a unit with `achievement` 1 first shows on the map, the client sends `rt_publish_achievement_unit` once and keeps the unit in `achievedUnits`. The server has the command. Only the post on Facebook needs Facebook.

Work: the save operation and the list of achieved units, without the post.

### Female host

The goal box shows a female host (`GameShowFemaleMissionMC`) when the page gives the client `sex=f`; the tutorial has a female host too (`GameShowFemaleHostMC`). The goal texts also use the gender. The server page always sends `sex=m` (`templates/play.html`, `templates/ruffle.html`), so the original game on this server always shows the male host. Both symbols are in the client.

Work: a setting in the port, the import of the two symbols, and the choice in `goal_box.gd` and the tutorial.

### Units in buildings in battles

In the client, refuges protect their units in battles, and each unit in a Fortress shoots an arrow of 1 point at its own target. The port has no units in buildings in battles: the units stay in the building, and the Fortress shoots only its cannonballs (`godot/battle/abilities/shot_ability.gd`).

Work: read the rules of the client for units in buildings during a fight, then add them to `BattleSim`.

### Island Forge (collect game)

`CollectGameManager` and `PopupIslandForge` are a timed event on the forge island (building 1530). The player collects six forge items from quests, troll kills, PvP and invites, can buy or speed up items for cash, and gets rewards at item counts.

- Server: the five `collect_game_*` commands (`op.py` `cmd_hellforge_*`), the save field `collectGame`, and the event `HELL_FORGE_ISLAND` in `server_config.json`. The event has a fixed date, 20 October 2025, for 7 days, so it is not active now unless the owner changes the date (decision 6).
- Port: none. `godot/game_data/collections.gd` says that the collect game is not in the port.
- The roadmap called these "the collection islands" (quest maps `100000051` to `100000055`). In the code the forge island is the only island of the collect game.

Work: large. The window, the six items, the timers and prices, the rewards, and the places where items drop.

## Group 3: the look

### The HUD on modern screens

The client was made for a Flash stage of 760 × 600 pixels in a Facebook page. In full screen it keeps the HUD at 760 pixels and puts it in the middle of the screen, with the bottom bar at the bottom and the top bars at the top (`StateNormal.setFullScreen`). The port does the same in its window.

What the port does now:

- `project.godot` sets a window of 1280 × 800 and no stretch mode. The HUD, the windows and their text are drawn at one pixel for each pixel of the client.
- The windows of the client are drawn by FlashArt at scale 1 only (`sprites/frame_cache.gd`). Only the map frames are drawn again at the scale of the camera (1, 1.5 or 2).
- The zoom of the map (0.7 at the start, 0.15 to 1.4) does not change with the size of the window.
- Some screens place parts from the 760-pixel stage of the client (`QuestHud`, `SurvivalScreen`, `TournamentScreen`, `CastBanner`, `SpellBookHud`); the goal box and the zoom slider are at the edges of the window.

Measurement: screenshots of the village of Arthur with the login bonus window, at four window sizes (Xvfb, OpenGL 3). The HUD and the windows have the same size in pixels at all window sizes; the numbers of the resources are about 10 pixels high. Only their share of the screen and their size on the screen change:

| Window | HUD width / window width | Text height on a typical screen |
|---|---|---|
| 1280 × 800 | 59% | the size at which the port was checked |
| 1920 × 1080 (24-inch, 92 pixels per inch) | 40% | about 2.8 mm |
| 2560 × 1440 (27-inch, 109 pixels per inch) | 30% | about 2.3 mm |
| 3840 × 2160 (27-inch, 163 pixels per inch) | 20% | about 1.6 mm |

At 3840 × 2160 the HUD and the windows are a narrow strip in the middle of the screen, and the goal box is far from them at the left edge. The village also looks small, because the zoom does not follow the window size.

Godot 4 gives the window the physical pixels of the screen (`display/window/dpi/allow_hidpi` is on by default), so the scaling of the operating system (for example 200% on a 4K laptop) does not make the HUD larger.

What must change:

1. **A UI scale.** Scale the HUD and the windows by a factor from the window height (for example height / 600, rounded to steps of 0.25), with a setting in the options panel. Godot can do this with the content scale of the window (`content_scale_mode` "canvas_items" with aspect "expand"), or with a scale on the CanvasLayers of the HUD and the windows. The content scale is the smaller change, but it also scales the map; the CanvasLayer scale keeps the map at its own zoom.
2. **Sharp art at the UI scale.** FlashArt must draw the window frames at the UI scale, as it does for the map frames, else the scaled HUD is blurred. The fonts of the text fields must be drawn at the scaled size. The bitmap pictures of the windows (for example `DailyBonus/imgs`, the quest pictures) have a fixed size and get soft above scale 1.
3. **Layout for wide screens.** The client puts everything in a 760-pixel column. With a UI scale this column is still narrow on 16:9 and 21:9 screens. Decide for each part if it stays in the column (the bottom bar) or goes to an edge (the goal box, the zoom slider, the spell book; the neighbour bar could be wider and show more neighbours). This is a change of the look of the original game (decision 4).
4. **Map zoom for the window size.** Scale the start zoom and the zoom limits by the same factor, so that the village shows the same area of the map as on the client's screen.
5. **Checks.** Screenshots at 1280 × 800, 1920 × 1080, 2560 × 1440, 3840 × 2160 and 3440 × 1440 of the village, a quest, the windows and the tournament, before and after.

### Blend modes with the map

Parts of the art with the blend modes overlay, multiply, hard light, screen, lighten and darken mix only with the graphic itself, not with the map behind it (`docs/FLASH_ART.md`, 3.11). They are in 441 files, among them fire and glow effects of shots and dragons. Work: draw these parts as separate nodes with a shader that reads the map behind them, or draw the graphic with the map behind it. This changes the structure of `ClipSprite`, because a frame is no longer one image.

### Graphics that the port does not draw

- The health bars and the selection rings are simple shapes (`godot/battle/battle_view.gd`); the graphics of the client are in its main file.
- Effects that the client only draws (`docs/GODOT_BATTLES.md`, "The islands of the campaign" and "Special abilities"): the domes of protection, the cracks of the Mole, the size of the minions of Titan Lythos, and other small effects.
- The client skews some parts of its windows; the port turns and scales them, but does not skew them (`godot/ui/ui_clip.gd`).
- Graphics that the original files do not have (`docs/FLASH_ART.md`, section 1, and some items without a SWF file in `assets/`, for example `2025_fire_draggy`). Neither game can draw them, unless a copy is found in other game files.

## Group 4: parts of a release

### Player save and start screen

By default the port opens `<data>/villages/initial.json` (`godot/main.gd`) and writes each change to the file that it opened. So the first game overwrites the starting village of the import, and the port has only one save. There is no screen to start a new empire or to continue.

Work: keep the player's save in `user://`, make it from the starting village at the first start, and add a start screen (new empire or continue). The format stays the format of the server, so that the server and the original client can load the save.

### Import of the game files

The import is a Python tool (`godot/importer/import_assets.py`) that needs Python 3, the server requirements and a copy of the socialemperors folder, and it runs from the command line. The user must supply the game files, by the legal decision of option C. Who runs the import, and when, depends on the design of the launcher.

### Builds

- The project has no export presets (`godot/export_presets.cfg`).
- The extension `flash_art` must be compiled for each platform. It is tested on Linux; the Windows cross build compiles, but the port was not run on Windows or macOS (`godot/README.md`, "Graphics").

## Decisions and parts that are not possible offline

### Nest and Rider Academy mini-games

Taming a dragon in a nest (`PopupDragonTaming`, level 8) and each training step of the Rider Academy (`PopupDragonRiderTraining`, the level of the step) start a flying game from `swf/minigames/SagaOTDC.swf` (`WindowMiniGameDragonRider`). A win sends the step to the server; a loss changes nothing. The server accepts the result of the client.

Port: `village.gd` (`train_rider`, `tame`) counts each step as won. A new game in Godot is large work.

### Darts

`PopupDarts` is a game of 25 balloons. A hit shows an item; when all items are found, the player gets the main prize. One free throw each day; more throws cost cash (`DART_COST_CASH`). A new board starts each week from the dates of `darts_items`.

In 1.4.07 players cannot open it: the games menu is always hidden (`GuiManager`), the function of the darts button has no caller, and only the admin panel opens the window. The SuperCheats guide ([link](https://www.supercheats.com/guides/social-empires/darts)) describes a darts icon, so older versions of the client had it.

- Server: `darts_reset`, `darts_new_free` and `darts_shoot_balloon` (`op.py`), and `darts.py` makes the weekly dates.
- Port: none; the games menu is hidden as in the client.

Work: medium.

### Ship and zeppelin explorations

The client gets the maps of the ship (`100000009`) and the zeppelin (`100000016`) from the game server when the player starts the exploration, not from its files. No copy is in `assets/`, in the `villages/` folders, or in the forks of `AcidCaos/socialemperors` that were checked (18 of the forks; one other fork has the same 35 quest maps as this repository). `server.py` also does not send these ids to the quest code, because they are not in its list of quest ids. So the original game cannot play them on this server either. Web searches found no copy of the maps and no pictures of their layout.

To add them the port needs one of these:

- a copy of the two maps from an old capture of the Social Point servers on the web archive, or from a fork that was not checked;
- pictures or videos of the explorations, to make the maps again by hand;
- new maps made for the port, with the client's rules for the ship and zeppelin quests (the map does not move in these quests, and the zoom is 0.7).

### Facebook and payment parts

- **Cash shop.** "Add Cash" and the cash buttons of other windows call `gotoBuy` on the page. The server page does not define it, so the button does nothing on this server. A real shop needs a payment service. The port shows a message.
- **Other viral icons.** Cross-promotion of other Social Point games, the like button, video ads, the Monday bonus, the comeback bonus, special-day offers and the achievements button are all off in the server config (`active` 0). Most need Facebook or other Social Point services.
- **Friend features.** Potions and help from friends, viral offers bought from friends and hiring friends need other players. The port uses the villages of `villages/` and mock villages as neighbours (step 4.4).

### Other client parts

Parts that are in the 1.4.07 client and not in the port, besides the items above:

| Part | Server | Notes |
|---|---|---|
| Monday bonus and comeback bonus (`MondayBonusPopUp`, `ComebackBonusPopUp`) | No handler for `weekly_reward` and `comeback_reward` | Off in the config, so the original game does not show them here. |
| Arabic deals (`PopupArabicDeals`) | The client sends `add_items_store`; the server knows only `store_add_items` | Opened from a building. The server answers that the command is not implemented, so it does not save the buy. |
| Mystery boxes (`PopupMistery`, `PopupSuperMistery`) | No command found | Not checked if a player can reach them. |
| Kompu offers | `kompu_offers` is empty in the mega patch | Nothing to show on this server. |
| Ivory Challenge, Night Forge and Easter Dragon events | Off in `server_config.json` | The units of these events are in the port's battles. |
| PvP leaderboard and tournament ranking and prizes | `/pvp/ranking` and `get_continent_ranking` | The owner decided against the ranking and prizes of the tournament (step 4.1). |

Not in the 1.4.07 client: chat and guilds. "Allies" in this game are the allies buildings and market, which the port has.

### Server bugs

These were found by reading the code and are not fixed (decision 7).

1. `version.py` `fix_bought_units`: for a troll map the line that should set the ignored race to "h" is a comparison (`==`), so the troll units are left out and the human units are counted. `engine.py` `register_bought_unit` has the correct rule, and the port's save migration uses it.
2. The client sends `add_items_store` for the Arabic deals; `command.py` has only `store_add_items`.
3. `weekly_reward` and `comeback_reward` have no handler (the icons are off).
4. `get_game_config.py` lists `unit_collections` in `patch_ignore`, but no patch has that name.

## Limits of the research

The web research was partial. Web searches worked, but the session could not open the Social Empires fan wiki (`socialempires.fandom.com`), `web.archive.org` and the SuperCheats guides; only search results and the GitHub page of `AcidCaos/socialemperors` could be read. A session with these hosts in the allowed domains of its environment can complete this part, and can look for the exploration maps and the missing graphics on the web archive.
