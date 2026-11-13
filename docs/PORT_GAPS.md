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
| [Unit list and unit collections](#unit-list-and-unit-collections) | Done |
| [News window](#news-window) | Done |
| [Spy screen art](#spy-screen-art) | Done |
| [Achievement publish](#achievement-publish) | Done |
| [Female host](#female-host) | Done |
| [Units in buildings in battles](#units-in-buildings-in-battles) | Done |
| [Island Forge](#island-forge-collect-game) | Large; needs a decision |

Do the save migration before the unit list, because the unit list reads `boughtUnits`.

### Group 3: the look

| Item | Work |
|---|---|
| [HUD on modern screens](#the-hud-on-modern-screens) | Medium to large; the layout for wide screens needs a decision |
| [Blend modes with the map](#blend-modes-with-the-map) | Medium to large |
| [Health bars, selection rings and effects that the client only draws](#graphics-that-the-port-does-not-draw) | Small to medium |
| [PvP attack screen art](#pvp-attack-screen-art) | Medium |

Do the HUD before the builds, because it changes the window settings and the options panel.

### Group 4: parts of a release that are not the launcher

| Item | Work |
|---|---|
| [Player save and start screen](#player-save-and-start-screen) | Small to medium |
| [Import of the game files](#import-of-the-game-files) | Depends on the launcher |
| [Builds](#builds) | Step 6.2 |

### Order

1. Group 1 (done).
2. Group 2 without the Island Forge (the save migration, the first purchase offer, the unit list, the news window and the spy screen are done).
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

Gift > Units opens the unit list (`PopupAllUnits`). The port now has it, with the rules of the client and the server:

- The list shows the 128 unit collections of the mega patch (`units_collections_categories`), 4 on a page, in the order of `position`: the name, the units, and the number of units that the player has. The pictures of the other units are grey. The bar at the bottom shows all units that the player has against the total.
- The count is the count of `UnitCollectionsManager`: when the town loads, the units of `boughtUnits` and the units of the player on the map; then each unit of the player that comes on the map. Five units are in two collections; the client counts them once for the player and twice in the total (504), and the port does the same.
- The mouse over a unit shows its card with its values and the unit, which walks, attacks and makes its first special attack in turns, every 3 seconds.
- A complete collection shows "Get reward". The reward adds the collection to `unitCollectionsCompleted` and gives 1 cash, as `unit_collections_completed` does; then the reward window replaces the list. The configuration names a reward unit, but neither the client nor the server gives it. The row then shows "COMPLETED!".
- When a unit that comes on the map completes a collection without a reward taken, the alert of the client tells the player to go to Gift > Units.
- Open Units Packs closes the list and opens the unit packs.

The configuration has a cash price for each unit, and the client has the code that sells a unit (`buy_stored_item_cash`), but the client of 1.4.07 never calls it: in Ruffle a click on a unit did nothing. The port also does not sell the units.

Compared with the original client in Ruffle on the same save: the list (11 / 504, the same grey and coloured units, the counts and "Get reward"), the cards in the first and second row, page 2, the reward (cash 53 to 54, `unitCollectionsCompleted` [1]) and the reward window. Small differences: the card of a unit in the first row is 8 pixels lower in the port, and a few long names get a slightly different font size.

The client has a bug in its test before the alert: it looks for the index of the collection in the list of taken rewards, not its id. So the alert does not show when a taken reward has the same number as that index. The port tests the id only.

A fix on the way: in the port, the inner Flash button of the Gift button, the World button and Gifts in the Gift menu took the click, so these did not open with the mouse. A click on an inner button named "button" now also reaches its button sprite, as in Flash.

### News window

Gift > News opens the news window of the client (`PopupNews`). The port now has it, with the rules of the client and the server:

- The 10 news of `globals.NEWS_ITEM`, with their numbers and arrows; the next news shows every 6 seconds. The pictures are in `assets/images_new/en`, as the `images` table of the configuration says.
- The links of the news: a store tab (`12.121.0` opens the News tab at Limited Edition), `gods` (the story of the gods, `PopupLore`, which starts at its fifth page as in the client) and `godsquests` (the quests; the client asks for page 7 but shows the page of the current island). A news without a link does nothing.
- The promotion packs: for each position, the first enabled pack of `offer_packs` (8 packs: 65, 33, 11, 7, 6, 5, 3, 1). A click opens the window of the pack, which replaces the news:
  - a normal pack (`PopupGetPack`): its cash, resources, experience, mana and items, as `buy_offer_pack` does;
  - a random pack (`PopupMistery`): one item by the limits of its list, then the window of the prize (`PopupGotPack`);
  - a super pack (`PopupSuperMistery`): boxes of 1, 2 and 4 items for 60, 100 and 200 cash, as `buy_super_offer_pack` does, with the opening of the box. The mouse over a unit shows its card.
- Without enough cash, the client opens its window with a cash shop button; the port shows the same text in an alert.
- Get More Cash shows the message of the Add Cash button: the port has no cash shop.
- The client opens the news among the windows of the start (`checkForNextStartPopup`) from level 5. In 1.4.07 only the window of a quest in the town starts that sequence, so the port opens the news when the first of these windows of the session closes. This is from the code; it did not happen in the Ruffle runs, in which no such window opened.

Compared with the original client in Ruffle on the same save: the news window, the three pack windows, the card in the super pack, the purchases (super pack: cash 1000 to 800, +1000 experience, +5 mana, 4 items; normal pack: cash to 755, +750 experience, 4 items; random pack: cash to 695, +1000 experience, 1 item), the prize window, the store link, the story and the quests. Differences:

- The client shows the gains as numbers that float up, and makes the box and the prizes of a super pack bright with a glow. The port does not draw these effects.
- The card of a unit in the super pack is about 15 pixels lower in the port.
- The store link shows the items of the port's own store rotation, so the items differ from those of the Ruffle run.
- In Ruffle the first news picture was empty until it loaded; the port shows it at once.

### Spy screen art

`StateSpy` hides the village HUD and shows the spy frame of the attack bar (`HudSpyEnemy`): the name and level of the enemy, its resources, Attack, Find next with its cost, and My town. Attack asks about the shield and opens `popupLoadingAssault`: the player chooses one of the 16 start points at the edge of a small map, Battle Help opens `PopupPvpHelp` with four tips, Start Loading plays an animation, and Start Battle starts the attack.

The port now shows the same with the art of the client (`godot/pvp/spy_screen.gd`, `godot/pvp/assault_start_window.gd`), in the same order. It also shows the options panel, as the client does. Compared in Ruffle on the same save: the panel, the buttons, the cost, the start window with the chosen point and the point under the mouse, the help window, the animation and the end text are the same.

Changes on the way:

- **Search cost and loot limit.** The client takes the value of a row of `PVP_SEARCH_ENEMY_COST` and `PVP_MAX_RESOURCES` before it compares the level, so it uses the first row above the level (`getSearchEnemyCost`, `getMaxResources`). In Ruffle a search at level 53 cost 1000 gold; the port asked 500. The port now uses the same rule (`GameConfig.value_for_level`). The server charges the cost that the client sends.
- **Shapes above pictures.** The port drew all shapes of a window below its parts, so the pictures of the help window covered the numbers of the tips. The importer now makes the shapes above an empty part into which the client loads a picture into sprites of their own (one-frame windows only). This changes the order in 17 windows and parts; without pictures they look the same as before, with differences of less than one pixel at the edges of the moved shapes.

Differences that are left:

- The client shows the assault HUD behind the start window; the port shows the village of the enemy, without the bar.
- The client grows the label of Attack until it fills the button (`ButtonGenericTall`). The port does not measure text as Flash does, so it uses the size that Ruffle shows (34).
- The import keeps only named masks. The animation of the start window has an unnamed mask, so `assault_start_window.gd` cuts it with the rectangle of that mask.
- The zoom slider of the client is not on the spy screen of the port.
- Wrapped texts can break at other words, for example the end text of the animation, because the fonts measure a little differently.

### Achievement publish

When a unit with `achievement` 1 of the player comes on the map in the normal game, and the unit is not in `achievedUnits`, the client sends `rt_publish_achievement_unit` and adds the unit to `achievedUnits` (`IsoEngine.addElement`). The server keeps the list. The client also posts the achievement on Facebook. 473 units have `achievement` 1; no building has it.

The port now keeps the same list (`Village.achieve_unit`), without the post. `main.gd` calls it for each unit of the player on the map when the town loads, and for each unit that comes on the map later (`VillageEvent.Kind.UNIT_ARRIVED`). It does not call it for the villages of other players, because `Village` also holds them.

Compared with the original client in Ruffle on the same save (`saves/initial.save.json`, with an empty list): at the load the client sent the command for the 7 units of the player on the map, and the port puts the same 7 units in the list. In the list of the client the dragons come first; the port uses the order of the map. The order has no effect, because the list is only searched.

### Female host

The client takes the gender of the player from the page (`sex`; `f` is female, any other value male). The gender chooses the host: Arthur or Guinevere. It changes the host of the tutorial (`GameShowHostMC` or `GameShowFemaleHostMC`), the host of the goal box (`GameShowHostMissionMC` or `GameShowFemaleMissionMC`), the picture and the name of the host in the neighbour bar (`thumbrey.jpg` or `thumbprincess.jpg`), and the name in the texts with `#0#` (tutorial and goals). The server page always sends `sex=m`, so the original game on this server always shows Arthur.

The port now has the choice (`godot/host/`): `host="female"` in the section `[game]` of `user://settings.cfg`, or `--host female` for one run. The default is Arthur, as on the server. The launcher can offer the setting later. The importer now also imports the three other host symbols and `thumbprincess.jpg`.

The port did not show the host of the tutorial before. It now shows it as the client does: at the top-left of the stage at y −190, under the bars of the HUD, from step 0 to step 13. It appears, and at each new step it plays "bien1". While it shows, the host of the goal box is hidden. The two hosts behave differently after an animation, because the frame scripts of their symbols differ: Arthur waits in a loop after he appears and talks in a loop after "bien1"; Guinevere stops at the end of each animation. The port follows these frame scripts (`Host.frame_scripts()`).

Compared in Ruffle, with `sex=f` in a copy of the page and with the original page:

- Guinevere at step 0 and after Next: the same frame at the same place (the crown at x 622–719, y 138–195, and after "bien1" at x 619–722, y 129–191), and the texts name Guinevere.
- Arthur: the crown moves with his waiting animation, and the port stays within the same range (for example x 587–755, y 121–201 in both).
- The neighbour bar shows Guinevere with her picture, level 1 and 29 experience, in both.
- The goal box after the tutorial shows no host in Ruffle with `sex=f`, and none in the port with either host: the icons of the goals cover it.

Differences that are left:

- The client hides the Goals button of the goal box during the tutorial; the port shows it, as before this change.
- In a window larger than 760 × 600, the port keeps the host at the top of the screen, at the left edge of the HUD of 760 pixels; how the client places it on a larger stage was not compared.

### Units in buildings in battles

The client takes a unit off the map when it goes into a building, and puts it back on a free tile when it comes out. A unit in a building is therefore not in a fight: no unit can attack it, and it does not attack. The client has no other rule for refuges in battles. In a PvP attack the refuges are buildings of the enemy like the others, because their race is "a". The port already did the same: the units in a building are in the save entry of the building, not on the map.

The Fortress (`FortressDelegate`) was the missing part. With each cannonball, each unit in it fires an arrow of 1 point at a target of its own. The number of units comes from the save: in the own village the units in the building, in a PvP attack the units in the save of the other player. Each unit keeps its target while the target is on the map and within half the range of the Fortress. Otherwise it takes the next of the nearest opponents (units or buildings) around the centre of the Fortress, within its range plus half its width. The port now does this (`godot/battle/abilities/fortress_ability.gd`, `BattleFighter.units_inside`, set by `VillageBattle` and `PvpBattle`).

Checks: `battle_check.gd` has a scenario for the Fortress: no arrows without units; 2 units fire 2 arrows of 1 point at the 2 nearest enemies; they keep these targets when a nearer enemy comes. A scratch run with a Fortress with 3 archers fired 11 arrows in a PvP attack and 22 arrows against trolls in the own village in 600 frames, and all arrows landed.

Differences that are left:

- In the client the arrows start at the places of the units in the graphic of the Fortress (`unit1` to `unit6`), and the units are drawn there with their idle frame. The port does not draw the units in the Fortress, and the arrows start at the shot point of the Fortress.
- Not compared with the original game in Ruffle. A fight in the own village needs an attack that comes near a filled Fortress, and no village in `villages/` and no save in `saves/` has a Fortress.

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


### PvP attack screen art

The attack on another player (`StateAssault` with `GuiPVPMC`, the eighth frame of the attack bar), its result window (`PopupPVPFinished`) and the PvP window with the shields and the attack log (`PopupPvp`, `PopupBuyShields`, `PopupAttackLog`) still use Godot controls in the port (`godot/pvp/pvp_screen.gd`, `godot/pvp/pvp_window.gd`). The rules are done.

Work: import these symbols and show them like the spy screen. Also check the place of the attack bar: the client puts it at y 35.15 of the stage in the spy screen (see [Spy screen art](#spy-screen-art)), and the quest, survival and tournament screens of the port use y 50.1. Compare these screens with Ruffle before you change them.
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
