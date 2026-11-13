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

All of them work offline. For the Island Forge the owner chose the event time and the rule for the horns (decision 6).

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
| [Island Forge](#island-forge-collect-game) | Done |

Do the save migration before the unit list, because the unit list reads `boughtUnits`.

### Group 3: the look

| Item | Work |
|---|---|
| [HUD on modern screens](#the-hud-on-modern-screens) | Done |
| [Blend modes with the map](#blend-modes-with-the-map) | Done |
| [Health bars, selection rings and effects that the client only draws](#graphics-that-the-port-does-not-draw) | Done |
| [PvP attack screen art](#pvp-attack-screen-art) | Done |


### Group 4: parts of a release that are not the launcher

| Item | Work |
|---|---|
| [Player save and start screen](#player-save-and-start-screen) | Done |
| [Import of the game files](#import-of-the-game-files) | Depends on the launcher |
| [Builds](#builds) | Step 6.2 |

### Order

1. Group 1 (done).
2. Group 2 (done).
3. The player save and the start screen (done).
4. Group 3 (done).
5. The launcher and the builds (step 6.2).

Groups 1 to 3 and the player save are done. The launcher and the builds (step 6.2) remain.

## Decisions of the owner

1. **Mini-games of the nests and the Rider Academy.** Keep the rule of the port (each game counts as won), or write a new flying game. See [Nest and Rider Academy mini-games](#nest-and-rider-academy-mini-games).
2. **Darts.** Players cannot open it in 1.4.07. Adding it is a change from 1.4.07. See [Darts](#darts).
3. **The text of tutorial steps 15 to 31.** The client shows only the arrow; the port also shows its own short text. See [Tutorial](#tutorial).
4. **HUD on wide screens.** Decided: only a UI scale; the layout of the client stays. See [The HUD on modern screens](#the-hud-on-modern-screens).
5. **Ship and zeppelin explorations.** Find the maps, make them again from videos, or make new maps. See [Ship and zeppelin explorations](#ship-and-zeppelin-explorations).
6. **Island Forge.** Decided: the port has it. The event runs at the date of the server, or at the date of the settings file; the horns are bought for cash, as on the server. See [Island Forge](#island-forge-collect-game).
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

`CollectGameManager` and `PopupIslandForge` are a timed event of the client. While the event runs and a prize is left, the forge island (building 1530) stands in the village, and an icon in the icon panel opens its window. The player collects six forge items and gets a dragon at 90 items (Demon Dragon, 2272) and at 110 items (Forge Dragon, 2269).

Decision 6: the port has the event. The event time is the date that the server writes into the configuration from `server_config.json` (`HELL_FORGE_ISLAND`, 20 October 2025 for 7 days). The settings `island_forge_date` ("YYYY-MM-DD", UTC) and `island_forge_days` (default 7) in the section `[events]` of `user://settings.cfg` replace it, so that a player can start the event without a new import. The horns come only from purchases for 10 cash each, as on the server, because the port cannot invite friends.

The rules (`godot/forge/island_forge.gd`) follow the client and the server:

- Copper: a win on one of the five forge islands with more stars than before. The start of a forge island starts a wait of 20 hours, and the forge window hides the button during the wait.
- Fang: by chance when an enemy unit dies in the own village, at most one each 300 seconds. Skull: the same in an attack on another player. The bonus of the client for the life of the killed unit is 0, because the client keeps the multiplier 0.5 in an integer.
- Iron: by chance when the player collects a mill or mine. The chance grows with the work time.
- Horn: bought only. The number is the number of friends of the viral offer 2.
- Hammer: the Forge button, then a wait of 25 hours.
- The chance is `3 ^ (missing / 7)` times the chance of the source, against a roll from 0 to 100. The player finds no items before level 2.
- The player can buy each item except the hammer, and end the wait of an item, for cash. "Buy All" uses the formula of the client and the server, with a discount for the part that is missing.
- The forge islands (`ForgeQuest`, quest maps `100000051` to `100000055`): the player wins when all skeletons are dead. The first island gives no gold and no experience; the others give gold and experience for each enemy by its price. The win opens no island of the campaign. The server keeps no start time for these islands, but their starts count for the quest limit.
- The window opens by itself in the village when a prize is ready. After the last prize the event ends for the player: the island and the icon go away.
- The island is not in the save, as in the client. It stands in a free square of 10 × 10 tiles near tile (10, 10). In a village fight it belongs to no side.
- The save uses the lists of the server: `collectGame` (6 items), `collectGameGivenPrizes` and `viralOffers` (5 offers). The save migration drops these lists when they have another size, because the server makes them again.

Checks: `village_check.gd` has 31 checks for the event time, the chances, the sources, the waits, the prices (506 and 72 cash, the values of the server's `hellforge_buy_all_price` for the same saves), the prizes, the end of the event and the save. `quest_check.gd` has 9 checks for the forge islands.

Comparison with the original game in Ruffle, with the server event set to start on the day of the test: the island stands at the top corner of the map in both. The forge icon is under the icon of the first purchase offer in both. The forge window, the dragon card, the wait of the hammer with its speed-up button, the Buy All price (439 cash at 20 of 110 items), the island list and the start window of a forge island have the same layout and texts. Ruffle showed four differences, which the port now follows:

- The client fills the places of the window with the items in the order 4, 5, 6, 1, 2, 3 (in Ruffle), and the picture of each place comes from the number of the place. So the copper picture is above the name Skull, and so on. The order in Flash Player is not known.
- The island list shows the name ribbons and the stars, not the level lock.
- The client writes a red "NEW!" with a font that it does not have under that name, so Ruffle shows no text.
- The arrows of the island list do not look disabled.

Differences that are left:

- The port draws the dragon of a prize card larger than Ruffle. The port fits the walking frame of the dragon into 400 × 300 pixels, as the client does; the cause of the difference was not found.
- The client gives a complete item a white glow; the port does not.
- The picture of a found item (`ForgeToken`) shows on the map of the village, of a village fight and of a PvP attack, but not on the map of a forge island, because the port gives the copper at the end of the quest. In the client the picture stays until the player clicks it; in the port the picture of a fight goes away with the fight screen.
- The Invite button shows a message of the port. Without enough cash, the port shows the text of the client and says that it has no cash shop.
- Not compared in Ruffle: the hammer animation, the prizes, Buy All, the pictures of found items, and a fight on a forge island.

## Group 3: the look

### The HUD on modern screens

Done. Decision 4: a UI scale only; the layout of the client stays.

The client was made for a Flash stage of 760 × 600 pixels in a Facebook page. In full screen it keeps the HUD at 760 pixels and puts it in the middle of the screen, with the bottom bar at the bottom and the top bars at the top (`StateNormal.setFullScreen`). The port did the same at one pixel for each pixel of the client, so on a large screen the HUD was a narrow strip with text of about 1.6 mm at 3840 × 2160.

What the port does now (`godot/ui/ui_scale.gd`, autoload `InterfaceScale`):

- The window has a content scale factor (the interface size), in steps of 0.25 from 1 to 4. The nodes keep the coordinates of the client; the viewport is the window size divided by the factor. The map is enlarged with the HUD, so the village shows the same part of the map as at 100%; the zoom limits of the camera do not change.
- Automatic: the largest step that leaves at least 760 × 600 pixels of the client in the window (1280 × 800: 1.25, 1920 × 1080: 1.75, 2560 × 1440 and 3440 × 1440: 2.25, 3840 × 2160: 3.5). Ctrl and + or − choose a fixed size, at most the automatic one; Ctrl and 0 goes back to automatic. The choice is `ui_scale` in `[display]` of `user://settings.cfg`. A message at the top-left shows the new size for 2 seconds. The options panel of the client has no place for this setting, so the port uses the keys.
- Sharp art: `FrameCache` draws the frames of the windows at the interface size and the frames of the map at the camera zoom times the interface size, rounded up to a step of 0.5 (at most 6). When a scale changes, it draws the frames that show again. `FlashArt.render_button` has a scale, and `UiButton` draws its image again when the size of the screen changes. The fonts of the text fields are drawn at the scaled size by Godot. Bitmaps in the art (the pictures of the windows, the ground of the map) have a fixed size and get soft above 1.
- A change of the window size or of the interface size moves the windows and bars: `UiClip.keep_at()` and `keep_centred()` keep a clip at a point of the screen, and the quest HUD, the spy screen, the unit buttons of battles, the PvP window, the tournament window and the pause window are placed again. Before, the windows that were open during a change of the window size (for example the full screen button) stayed at their old place.

Checks: screenshots of the village with the login bonus at 1280 × 800, 1920 × 1080, 2560 × 1440, 3840 × 2160 and 3440 × 1440 (Xvfb, OpenGL 3, llvmpipe), before and after. A scale change with the keys while the village, the login bonus, the tournament window, the start windows of the tournament and survival and the pause window show; the shop and the quest list opened after a change. The village zoomed in at 2560 × 1440 (map frames at scale 3.5). The start screen at 1920 × 1080. The village, battle, quest and spell checks pass with the same counts as before (899, 136, 134, 85).

Limits:

- Memory: the frames of the map need the square of the scale. At 2560 × 1440 with the camera at its largest zoom, the frames used 500 MB of the 512 MB limit of `FrameCache` right after the start; above the limit the cache removes frames that no node shows and draws them again when they show. Whether the limit must be larger for 3840 × 2160 was not measured on a GPU; this machine renders 4K too slowly with llvmpipe for a test of play.
- The banner of a cast spell (`CastBanner`) is placed when it appears; it shows for about 2 seconds and does not move after a change of the size.
- The tool tips and the menus of the HUD were not checked during a change of the size.

### Blend modes with the map

Done. The parts of the art with the blend modes multiply, screen, lighten, darken, difference, add, overlay and hard light mixed only with the graphic itself, not with the map behind it. Such parts reach the map in 192 graphics: 182 items, mostly dragons and colossi, and 10 shots and effects (a scan of the imported graphics).

What the port does now (`docs/FLASH_ART.md`, 3.11):

- `FlashArt.open_map()` loads the graphics of the map. A frame with such parts is a normal image and one layer for each blend mode. Where the graphic is below a part, the part mixes with the graphic in the normal image; the layer holds the part for the map.
- `FrameMaterial` (`godot/sprites/frame_material.gd`) shows a frame on a node. For a frame of layers it sets the shader `sprites/blend_layers.gdshader`, which mixes the layers with the screen behind the node and draws the normal image over them, and a `BackBufferCopy` before the node. `ClipSprite` (units, shots, effects) and the buildings of `VillageView` use it.
- The colour that the battle adds to frozen, poisoned and marked units (`ClipSprite.tint`) is now in the same shaders. The old tint shader multiplied the texture twice, because in Godot 4 `COLOR` in `fragment()` already holds the texture; frozen and poisoned units were too dark.
- The filters of a clip that its frame shows at another size now have the size of the stage (`docs/FLASH_ART.md`, 3.13). Before, for example, the blur of the large fireball was half as wide as in the client.

Checks: comparisons with Ruffle on a stage of the colour of grass and of sand (`ground_compare`, `docs/FLASH_ART.md`), for the large fireball, two other shots, the attack clips of two dragons and three other dragons; and the large fireball drawn by Godot on the screen against Ruffle: 1.3 % of the pixels differ by more than 24 on grass, 7.4 % on sand. A scene with four dragons, three fireballs and a frozen dragon on grass and sand. The village, battle, quest and spell checks pass with the same counts as before.

Limits:

- Where the graphic is half transparent below an overlay or hard light part, the part mixes with the graphic and with the map each by itself, not with their mix. This is why the large fireball on sand differs more than before (17.4 % against 14.2 % of its pixels in the comparison of the frames; largest difference 44 levels against 34). Parts of different blend modes over the map mix in the order of their modes, not of their depths.
- Memory: a frame of layers needs up to 2.8 times the memory of a normal frame (`2209_redHotEpicDraggy`).
- Each node that shows a frame of layers copies the whole screen before it is drawn. With `COPY_MODE_RECT` the OpenGL renderer of Godot 4.7 gave a black copy when the rectangle started above the node. The cost was not measured.
- The windows still mix such parts only with the graphic; the scan was for the map.

### Graphics that the port does not draw

Done. The importer now takes these symbols of the client file: the health bars, the selection marks, the range of a dome, and the placeholders of a missing graphic; and `swf/blue_dome.swf`. What the port draws now:

- **Health bars** (`battle/health_bar.gd`): `BarraVidaMC` for the player and `BarraVidaEnemyMC` for an enemy, at 0.6 of their size, 5 pixels above the graphic; the red part covers the lost life. In a tournament the enemies always show theirs, twice as big. A damaged item in the village shows the bar too.
- **Selection marks** (`ui/selection_mark.gd`): `PeanaMC` under a unit (half a tile below its position) and `PeanaBuilding<w>x<w>MC` under a building of width w, for the player, an enemy or a neutral item; a child of the item node, under its graphic, as in the client. In battles and in the village (selected item and selected group).
- **Domes** (`battle/dome_range.gd`, rules in `BattleSim`): the client halves the damage to the items of its side within the range of a Protection Dome, and halves the attack interval of the towers of its side placed after a Tower Enhancer within its range. The port had neither the rules nor the graphics. Now it has both: the range on the ground (`DomeRangeBottom`) while the dome is under the mouse or selected, and the dome of `blue_dome.swf` over a selected dome, red for the Tower Enhancer. `battle_check.gd` checks the rules.
- **Effects of units**: the cracks of the Mole (the hole of the Hell Abyss at 0.4), the red bubble of Anubis (the particle of Force Shield, twice as big, red, alpha 0.7), the Mother Monster balls at 1.6, the Titan Lythos minions at 0.3, the heads of the Three-Headed Dragon in turn (special animations 1 to 3 for its beams), the Swamp Minions that grow from half their height and fade in (0.5 seconds, elastic), the red flash of the Huge Egg when it is hit, the white flash of the units of Instant Limit, the 4 extra rocks without damage of the Catapult (speed 8 to 10), the stream of fire arrows of Castle III (one every 2 frames while it has a target), and the units in a Fortress at the places `unit1` to `unit6` of its graphic, in battles and in the village; their arrows start there. The list in `docs/GODOT_BATTLES.md` said "the colour of the Swamp Minion when it is hit"; the client has no such colour (its delegate is empty); the minions grow in when they come.
- **Skew** (`ui/ui_clip.gd`): a skewed part of a window is the child of a Node2D with the matrix of Flash. Two parts of the imported windows skew: the titles of the goal list and of the PvP window (2.5°).
- **Missing graphics**: no copy of the 33 missing graphics is in the 1936 SWF files of `assets/`. The client shows a placeholder while a graphic loads, and it stays when the graphic is missing (`IsoElement.setProvisionalGrahic`): `LoadingUnit` in black for a unit, `Loading1x1` to `Loading4x4` for a building. The port shows the same (`SpriteLibrary.get_item_sprite`).

Checks: the battle check has a new scenario for the domes; the village, battle, quest and spell checks pass (counts in the commit). Screenshots: health bars and marks on a quest map (own dragons, an enemy building with a third of its life), the marks of a building and of a group in the village, the dome range, and the placeholders of items 1315, 1410 and 2213 in the village.

Limits:

- The marks, bars and the dome are drawn with the frames of the windows at the scale of the map, not compared with the client in Ruffle.
- The units of a Fortress are drawn over its whole graphic; in the client parts of the graphic in front of a place cover the unit.
- The shots and effects above were read from the code of the client; they were not compared with Ruffle.

### PvP attack screen art

Done. The importer now takes the symbols of the PvP windows from the client file (`PopupPvpMC`, `PopupBuyShieldsMC`, `PopupAttackLogMC` with `AttackLogItemMC` and `AttackLogEndItemMC`, `ArmyUnitCellMC`, `PopupPVPFInishedMC`) with their pictures, and `swf/anim_win.swf` and `swf/anim_lose.swf`. What the port shows now:

- **PvP window** (`pvp/pvp_window.gd`): the army in cells of `ArmyUnitCell` (the thumb at 66 pixels and the count), on pages; Search enemy with its cost; Attack Log; the help (`pvp/pvp_help.gd`). The client also has a ranking button; the port hides it, because the owner decided against the ranking (see [Other client parts](#other-client-parts)).
- **Shield window** (`pvp/shield_window.gd`): the three shields with their days, cooldown and price. The shield button of the HUD opens it.
- **Attack log** (`pvp/attack_log_window.gd`): 4 attacks on a page, newest first, with the level, the name, the stolen resources, the time since the attack (two units, as `GameStatic.dhms`), the result and the revenge or attack button; then the end of the log. The client shows "You've won the battle" in both frames of the result (green and red), and the port shows the same. The client shows the Facebook picture of the attacker; the port shows the empty frame.
- **Attack screen** (`pvp/pvp_screen.gd`): the eighth frame of the attack bar (`pvpHud`) at the place of the spy screen (`SpyScreen.BAR_POSITION`, compared with Ruffle in [Spy screen art](#spy-screen-art)); Withdraw 150 pixels above the bottom of the screen (`StateAssault.adjustScreen`); the time in red in the last 30 seconds.
- **Result window** (`pvp/pvp_result_window.gd`): the flags, names and levels, the animation of a win or a loss and then the result text (from 0.2 of its size, 0.3 seconds), the loot, the damage, the experience, the honour and the units that did not come back, 9 × 2 on a page. The client saves the result while it shows "Saving Results ..."; the port saves when the window closes, so it shows the close button at once.

Checks: the village, battle, quest and spell checks pass (counts in the commit). Screenshots at 1280 × 800 of the PvP window, the shield window, the attack log with two attacks, the attack screen and the result window of a withdrawn attack.

Limits:

- These windows were not compared with the client in Ruffle. The places come from the imported symbols and from the code of the client.
- The picture of an army cell (66 × 66) is higher than the frame of the cell (66 × 61), so the bottom of some pictures shows below the frame. The numbers are those of the client.
- The quest, survival and tournament screens of the port still put the attack bar at y 50.1, not at the place of the spy screen. Compare them with Ruffle before you change them.

## Group 4: parts of a release that are not the launcher

| Item | Work |
|---|---|
| [Player save and start screen](#player-save-and-start-screen) | Done |
| [Import of the game files](#import-of-the-game-files) | Depends on the launcher |
| [Builds](#builds) | Step 6.2 |

### Order

1. Group 1 (done).
2. Group 2 (done).
3. The player save and the start screen (done).
4. Group 3 (done).
5. The launcher and the builds (step 6.2).

Groups 1 to 3 and the player save are done. The launcher and the builds (step 6.2) remain.

## Decisions of the owner

1. **Mini-games of the nests and the Rider Academy.** Keep the rule of the port (each game counts as won), or write a new flying game. See [Nest and Rider Academy mini-games](#nest-and-rider-academy-mini-games).
2. **Darts.** Players cannot open it in 1.4.07. Adding it is a change from 1.4.07. See [Darts](#darts).
3. **The text of tutorial steps 15 to 31.** The client shows only the arrow; the port also shows its own short text. See [Tutorial](#tutorial).
4. **HUD on wide screens.** Decided: only a UI scale; the layout of the client stays. See [The HUD on modern screens](#the-hud-on-modern-screens).
5. **Ship and zeppelin explorations.** Find the maps, make them again from videos, or make new maps. See [Ship and zeppelin explorations](#ship-and-zeppelin-explorations).
6. **Island Forge.** Decided: the port has it. The event runs at the date of the server, or at the date of the settings file; the horns are bought for cash, as on the server. See [Island Forge](#island-forge-collect-game).
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

`CollectGameManager` and `PopupIslandForge` are a timed event of the client. While the event runs and a prize is left, the forge island (building 1530) stands in the village, and an icon in the icon panel opens its window. The player collects six forge items and gets a dragon at 90 items (Demon Dragon, 2272) and at 110 items (Forge Dragon, 2269).

Decision 6: the port has the event. The event time is the date that the server writes into the configuration from `server_config.json` (`HELL_FORGE_ISLAND`, 20 October 2025 for 7 days). The settings `island_forge_date` ("YYYY-MM-DD", UTC) and `island_forge_days` (default 7) in the section `[events]` of `user://settings.cfg` replace it, so that a player can start the event without a new import. The horns come only from purchases for 10 cash each, as on the server, because the port cannot invite friends.

The rules (`godot/forge/island_forge.gd`) follow the client and the server:

- Copper: a win on one of the five forge islands with more stars than before. The start of a forge island starts a wait of 20 hours, and the forge window hides the button during the wait.
- Fang: by chance when an enemy unit dies in the own village, at most one each 300 seconds. Skull: the same in an attack on another player. The bonus of the client for the life of the killed unit is 0, because the client keeps the multiplier 0.5 in an integer.
- Iron: by chance when the player collects a mill or mine. The chance grows with the work time.
- Horn: bought only. The number is the number of friends of the viral offer 2.
- Hammer: the Forge button, then a wait of 25 hours.
- The chance is `3 ^ (missing / 7)` times the chance of the source, against a roll from 0 to 100. The player finds no items before level 2.
- The player can buy each item except the hammer, and end the wait of an item, for cash. "Buy All" uses the formula of the client and the server, with a discount for the part that is missing.
- The forge islands (`ForgeQuest`, quest maps `100000051` to `100000055`): the player wins when all skeletons are dead. The first island gives no gold and no experience; the others give gold and experience for each enemy by its price. The win opens no island of the campaign. The server keeps no start time for these islands, but their starts count for the quest limit.
- The window opens by itself in the village when a prize is ready. After the last prize the event ends for the player: the island and the icon go away.
- The island is not in the save, as in the client. It stands in a free square of 10 × 10 tiles near tile (10, 10). In a village fight it belongs to no side.
- The save uses the lists of the server: `collectGame` (6 items), `collectGameGivenPrizes` and `viralOffers` (5 offers). The save migration drops these lists when they have another size, because the server makes them again.

Checks: `village_check.gd` has 31 checks for the event time, the chances, the sources, the waits, the prices (506 and 72 cash, the values of the server's `hellforge_buy_all_price` for the same saves), the prizes, the end of the event and the save. `quest_check.gd` has 9 checks for the forge islands.

Comparison with the original game in Ruffle, with the server event set to start on the day of the test: the island stands at the top corner of the map in both. The forge icon is under the icon of the first purchase offer in both. The forge window, the dragon card, the wait of the hammer with its speed-up button, the Buy All price (439 cash at 20 of 110 items), the island list and the start window of a forge island have the same layout and texts. Ruffle showed four differences, which the port now follows:

- The client fills the places of the window with the items in the order 4, 5, 6, 1, 2, 3 (in Ruffle), and the picture of each place comes from the number of the place. So the copper picture is above the name Skull, and so on. The order in Flash Player is not known.
- The island list shows the name ribbons and the stars, not the level lock.
- The client writes a red "NEW!" with a font that it does not have under that name, so Ruffle shows no text.
- The arrows of the island list do not look disabled.

Differences that are left:

- The port draws the dragon of a prize card larger than Ruffle. The port fits the walking frame of the dragon into 400 × 300 pixels, as the client does; the cause of the difference was not found.
- The client gives a complete item a white glow; the port does not.
- The picture of a found item (`ForgeToken`) shows on the map of the village, of a village fight and of a PvP attack, but not on the map of a forge island, because the port gives the copper at the end of the quest. In the client the picture stays until the player clicks it; in the port the picture of a fight goes away with the fight screen.
- The Invite button shows a message of the port. Without enough cash, the port shows the text of the client and says that it has no cash shop.
- Not compared in Ruffle: the hammer animation, the prizes, Buy All, the pictures of found items, and a fight on a forge island.

## Group 3: the look

### The HUD on modern screens

Done. Decision 4: a UI scale only; the layout of the client stays.

The client was made for a Flash stage of 760 × 600 pixels in a Facebook page. In full screen it keeps the HUD at 760 pixels and puts it in the middle of the screen, with the bottom bar at the bottom and the top bars at the top (`StateNormal.setFullScreen`). The port did the same at one pixel for each pixel of the client, so on a large screen the HUD was a narrow strip with text of about 1.6 mm at 3840 × 2160.

What the port does now (`godot/ui/ui_scale.gd`, autoload `InterfaceScale`):

- The window has a content scale factor (the interface size), in steps of 0.25 from 1 to 4. The nodes keep the coordinates of the client; the viewport is the window size divided by the factor. The map is enlarged with the HUD, so the village shows the same part of the map as at 100%; the zoom limits of the camera do not change.
- Automatic: the largest step that leaves at least 760 × 600 pixels of the client in the window (1280 × 800: 1.25, 1920 × 1080: 1.75, 2560 × 1440 and 3440 × 1440: 2.25, 3840 × 2160: 3.5). Ctrl and + or − choose a fixed size, at most the automatic one; Ctrl and 0 goes back to automatic. The choice is `ui_scale` in `[display]` of `user://settings.cfg`. A message at the top-left shows the new size for 2 seconds. The options panel of the client has no place for this setting, so the port uses the keys.
- Sharp art: `FrameCache` draws the frames of the windows at the interface size and the frames of the map at the camera zoom times the interface size, rounded up to a step of 0.5 (at most 6). When a scale changes, it draws the frames that show again. `FlashArt.render_button` has a scale, and `UiButton` draws its image again when the size of the screen changes. The fonts of the text fields are drawn at the scaled size by Godot. Bitmaps in the art (the pictures of the windows, the ground of the map) have a fixed size and get soft above 1.
- A change of the window size or of the interface size moves the windows and bars: `UiClip.keep_at()` and `keep_centred()` keep a clip at a point of the screen, and the quest HUD, the spy screen, the unit buttons of battles, the PvP window, the tournament window and the pause window are placed again. Before, the windows that were open during a change of the window size (for example the full screen button) stayed at their old place.

Checks: screenshots of the village with the login bonus at 1280 × 800, 1920 × 1080, 2560 × 1440, 3840 × 2160 and 3440 × 1440 (Xvfb, OpenGL 3, llvmpipe), before and after. A scale change with the keys while the village, the login bonus, the tournament window, the start windows of the tournament and survival and the pause window show; the shop and the quest list opened after a change. The village zoomed in at 2560 × 1440 (map frames at scale 3.5). The start screen at 1920 × 1080. The village, battle, quest and spell checks pass with the same counts as before (899, 136, 134, 85).

Limits:

- Memory: the frames of the map need the square of the scale. At 2560 × 1440 with the camera at its largest zoom, the frames used 500 MB of the 512 MB limit of `FrameCache` right after the start; above the limit the cache removes frames that no node shows and draws them again when they show. Whether the limit must be larger for 3840 × 2160 was not measured on a GPU; this machine renders 4K too slowly with llvmpipe for a test of play.
- The banner of a cast spell (`CastBanner`) is placed when it appears; it shows for about 2 seconds and does not move after a change of the size.
- The tool tips and the menus of the HUD were not checked during a change of the size.

### Blend modes with the map

Done. The parts of the art with the blend modes multiply, screen, lighten, darken, difference, add, overlay and hard light mixed only with the graphic itself, not with the map behind it. Such parts reach the map in 192 graphics: 182 items, mostly dragons and colossi, and 10 shots and effects (a scan of the imported graphics).

What the port does now (`docs/FLASH_ART.md`, 3.11):

- `FlashArt.open_map()` loads the graphics of the map. A frame with such parts is a normal image and one layer for each blend mode. Where the graphic is below a part, the part mixes with the graphic in the normal image; the layer holds the part for the map.
- `FrameMaterial` (`godot/sprites/frame_material.gd`) shows a frame on a node. For a frame of layers it sets the shader `sprites/blend_layers.gdshader`, which mixes the layers with the screen behind the node and draws the normal image over them, and a `BackBufferCopy` before the node. `ClipSprite` (units, shots, effects) and the buildings of `VillageView` use it.
- The colour that the battle adds to frozen, poisoned and marked units (`ClipSprite.tint`) is now in the same shaders. The old tint shader multiplied the texture twice, because in Godot 4 `COLOR` in `fragment()` already holds the texture; frozen and poisoned units were too dark.
- The filters of a clip that its frame shows at another size now have the size of the stage (`docs/FLASH_ART.md`, 3.13). Before, for example, the blur of the large fireball was half as wide as in the client.

Checks: comparisons with Ruffle on a stage of the colour of grass and of sand (`ground_compare`, `docs/FLASH_ART.md`), for the large fireball, two other shots, the attack clips of two dragons and three other dragons; and the large fireball drawn by Godot on the screen against Ruffle: 1.3 % of the pixels differ by more than 24 on grass, 7.4 % on sand. A scene with four dragons, three fireballs and a frozen dragon on grass and sand. The village, battle, quest and spell checks pass with the same counts as before.

Limits:

- Where the graphic is half transparent below an overlay or hard light part, the part mixes with the graphic and with the map each by itself, not with their mix. This is why the large fireball on sand differs more than before (17.4 % against 14.2 % of its pixels in the comparison of the frames; largest difference 44 levels against 34). Parts of different blend modes over the map mix in the order of their modes, not of their depths.
- Memory: a frame of layers needs up to 2.8 times the memory of a normal frame (`2209_redHotEpicDraggy`).
- Each node that shows a frame of layers copies the whole screen before it is drawn. With `COPY_MODE_RECT` the OpenGL renderer of Godot 4.7 gave a black copy when the rectangle started above the node. The cost was not measured.
- The windows still mix such parts only with the graphic; the scan was for the map.

### Graphics that the port does not draw

Done. The importer now takes these symbols of the client file: the health bars, the selection marks, the range of a dome, and the placeholders of a missing graphic; and `swf/blue_dome.swf`. What the port draws now:

- **Health bars** (`battle/health_bar.gd`): `BarraVidaMC` for the player and `BarraVidaEnemyMC` for an enemy, at 0.6 of their size, 5 pixels above the graphic; the red part covers the lost life. In a tournament the enemies always show theirs, twice as big. A damaged item in the village shows the bar too.
- **Selection marks** (`ui/selection_mark.gd`): `PeanaMC` under a unit (half a tile below its position) and `PeanaBuilding<w>x<w>MC` under a building of width w, for the player, an enemy or a neutral item; a child of the item node, under its graphic, as in the client. In battles and in the village (selected item and selected group).
- **Domes** (`battle/dome_range.gd`, rules in `BattleSim`): the client halves the damage to the items of its side within the range of a Protection Dome, and halves the attack interval of the towers of its side placed after a Tower Enhancer within its range. The port had neither the rules nor the graphics. Now it has both: the range on the ground (`DomeRangeBottom`) while the dome is under the mouse or selected, and the dome of `blue_dome.swf` over a selected dome, red for the Tower Enhancer. `battle_check.gd` checks the rules.
- **Effects of units**: the cracks of the Mole (the hole of the Hell Abyss at 0.4), the red bubble of Anubis (the particle of Force Shield, twice as big, red, alpha 0.7), the Mother Monster balls at 1.6, the Titan Lythos minions at 0.3, the heads of the Three-Headed Dragon in turn (special animations 1 to 3 for its beams), the Swamp Minions that grow from half their height and fade in (0.5 seconds, elastic), the red flash of the Huge Egg when it is hit, the white flash of the units of Instant Limit, the 4 extra rocks without damage of the Catapult (speed 8 to 10), the stream of fire arrows of Castle III (one every 2 frames while it has a target), and the units in a Fortress at the places `unit1` to `unit6` of its graphic, in battles and in the village; their arrows start there. The list in `docs/GODOT_BATTLES.md` said "the colour of the Swamp Minion when it is hit"; the client has no such colour (its delegate is empty); the minions grow in when they come.
- **Skew** (`ui/ui_clip.gd`): a skewed part of a window is the child of a Node2D with the matrix of Flash. Two parts of the imported windows skew: the titles of the goal list and of the PvP window (2.5°).
- **Missing graphics**: no copy of the 33 missing graphics is in the 1936 SWF files of `assets/`. The client shows a placeholder while a graphic loads, and it stays when the graphic is missing (`IsoElement.setProvisionalGrahic`): `LoadingUnit` in black for a unit, `Loading1x1` to `Loading4x4` for a building. The port shows the same (`SpriteLibrary.get_item_sprite`).

Checks: the battle check has a new scenario for the domes; the village, battle, quest and spell checks pass (counts in the commit). Screenshots: health bars and marks on a quest map (own dragons, an enemy building with a third of its life), the marks of a building and of a group in the village, the dome range, and the placeholders of items 1315, 1410 and 2213 in the village.

Limits:

- The marks, bars and the dome are drawn with the frames of the windows at the scale of the map, not compared with the client in Ruffle.
- The units of a Fortress are drawn over its whole graphic; in the client parts of the graphic in front of a place cover the unit.
- The shots and effects above were read from the code of the client; they were not compared with Ruffle.

### PvP attack screen art

The attack on another player (`StateAssault` with `GuiPVPMC`, the eighth frame of the attack bar), its result window (`PopupPVPFinished`) and the PvP window with the shields and the attack log (`PopupPvp`, `PopupBuyShields`, `PopupAttackLog`) still use Godot controls in the port (`godot/pvp/pvp_screen.gd`, `godot/pvp/pvp_window.gd`). The rules are done.

Work: import these symbols and show them like the spy screen. Also check the place of the attack bar: the client puts it at y 35.15 of the stage in the spy screen (see [Spy screen art](#spy-screen-art)), and the quest, survival and tournament screens of the port use y 50.1. Compare these screens with Ruffle before you change them.
## Group 4: parts of a release

### Player save and start screen

Done. Without `--village`, the port opens a start screen (`godot/start/start_screen.gd`) in place of the login page of the server. It lists the saves in `user://saves` with the name, level and experience of the town in `default_map`, the last changed save first, as `templates/login.html` does. Play opens a save. The name field makes a new empire with `Village.new_empire()`, the rule of the server's `new_village()`: a copy of `villages/initial.json` with a random UUID as the player id, the name without the spaces at the ends, no picture, and the time of the first map; the key `version` makes the save migration repair it as a very old save, as on the server. The name rule is the rule of `check_player_name()`. The server also lets the player choose a picture; the port does not, so the picture stays empty, as on the server when the player chooses none. The chosen save stays open when the scene starts again (the Time Machine, the Weather Machine, travel to the other town). `--village <file>` opens a file as before.

The saves keep the format and the file names of the server. `village_check.gd` has 16 checks for the name rule and the new empire (`_check_new_empire`). A new empire of the port and one of the server's `new_village()` from the same `initial.json` differ only in the keys that the server's migration adds with default values (the port reads the same defaults when the keys are missing), in `dartsGotExtra`, `dartsHasFree` and `potionsReceived`, which the server's migration changes, and in the troll town, which the server adds to each save when it loads it.

Tested: the server lists a save of the port on its login page, and the original client in Ruffle loads it. A new empire file of the port, before the port opened it, gave the same commands in the client as a new empire of the server (only the spawn of trees, stones and animals). A save after its first load in the port made the client harvest 122 trees at load (`collect_new` and `sell` with `HARV`), which gave the experience for level 4, and buy new gold and stone groups. A save of the server opened a second time in the client gave no harvest. So the cause is in what the port writes when it loads a map (`_init_map()`: the border clean and the spawn of resources and animals), not in the new empire; it applies to every save that the port opens. The cause is not found yet.

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
