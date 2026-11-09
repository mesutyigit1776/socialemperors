# Godot port: open items and gaps

This file records what the Godot port does not have yet, after step 6.1 of the roadmap (`docs/NATIVE_PORT.md`). Each item gives what the original game did, what this server supports, what the port has, and the work to add it. The owner decides which items the port gets.

Sources: the decompiled 1.4.07 client (read to learn the rules; it is not in the repository), the server code in this repository, the port in `godot/`, and the web. Class names below are the names in the client.

The web research was partial. Web searches worked, but this session could not open the pages: the Social Empires fan wiki (`socialempires.fandom.com`), `web.archive.org` and the SuperCheats guides were not reachable on the network of the session. Only search results and the GitHub page of `AcidCaos/socialemperors` could be read. A later session with these hosts allowed can complete this part.

## Summary

Work: small is up to a few days, medium is about one week, large is more than one week.

| Item | In the 1.4.07 client | Server | Port | Work | Offline |
|---|---|---|---|---|---|
| [First purchase offer ("open me")](#first-purchase-offer-open-me) | Yes, the only viral icon that the server config turns on | Yes | No | Small to medium | Yes |
| [Unit list and unit collections](#unit-list-and-unit-collections) | Yes (Gift > Units) | Yes | No, button hidden | Medium | Yes |
| [News window](#news-window) | Yes (Gift > News, opens at login from level 5) | Config only | No, button hidden | Medium | Yes |
| [Darts](#darts) | Code only; players cannot open it | Yes | No | Medium | Yes |
| [Island Forge (collect game)](#island-forge-collect-game) | Yes | Yes, as a dated event | No | Large | Yes |
| [Nest and Rider Academy mini-games](#nest-and-rider-academy-mini-games) | Yes (separate SWF) | Trusts the client | Counted as won | Large | Yes |
| [Spy screen art](#spy-screen-art) | Yes | Yes | Screen without client art | Medium | Yes |
| [Battle zoom](#battle-zoom) | Keeps the village zoom | — | Starts at 0.7 | Small | Yes |
| [Female host](#female-host) | Yes | Always sends male | No | Small | Yes |
| [Achievement publish](#facebook-parts) | Yes | Yes | No | Small | Yes, without the post |
| [Cash shop and other Facebook parts](#facebook-parts) | Yes | No | Message only | — | No |
| [Save migration](#save-migration) | — | Yes (`version.py`) | Defaults where needed | Small to medium | Yes |
| [Tutorial after step 10](#the-tutorial-after-step-10) | Yes | Yes | Yes, with 3 differences | Small | Yes |
| [Ship and zeppelin explorations](#ship-and-zeppelin-explorations) | Yes | No maps | No | See the section | No maps |
| [HUD on modern screens](#the-hud-on-modern-screens) | — | — | Fixed 760-pixel HUD | Medium to large | Yes |

## First purchase offer ("open me")

The "open me" chest at the side of the HUD is not a Facebook feature. It is the icon of the first purchase offer (`FirstOfferButton`; its text is `POPUP_FIRST_OFFER_VIRAL`, "open me"). Of the eleven viral icons in the server config (`viral_icons` in `config/patch/1-mega_patch.json`), it is the only one with `active` 1, so the original game shows it on this server.

- The client shows the icon while the player is in the first 3 days of play and has not opened the offer, or while the offer time (`POPUP_FIRST_PURCHASE_OFFER_TIME`) has not passed since the first opening.
- The window (`PopupFirstBuy`) shows three dragon units and the resources of `POPUP_FIRST_PURCHASE_OFFER_REWARD`, with a timer. The first opening sends `set_first_purchase_timestamp`. The buy costs `POPUP_FIRST_PURCHASE_OFFER_COST` cash (the game currency, not real money) and sends `buy_first_purchase`.
- The server has both commands (`op.py`, `cmd_set_first_purchase_ts` and `cmd_buy_first_purchase`).
- The port has no viral icon panel and no offer.

Work: small to medium. The icon panel at the side of the HUD, the window with its art, and the two save operations.

## Unit list and unit collections

The Gift menu has a Units button (`PopupAllUnits`). It lists the unit collections: groups of units with a reward unit. The player buys each unit for cash (`buy_stored_item_cash`; the unit goes to the item store). When all units of a group are bought, a reward button shows. In 1.4.07 the reward button opens the reward window, adds the group to `unitCollectionsCompleted`, gives 1 cash and sends `unit_collections_completed`. Neither the client nor the server stores the reward unit; this is from the code only and was not seen in a run. `UnitCollectionsManager` counts the units from `boughtUnits` and shows an alert when a group is complete.

- Config: the mega patch replaces the 62 groups of `units_collections_categories` with 128 groups.
- Server: both commands exist. `boughtUnits` is kept by `engine.py` `register_bought_unit`.
- Port: `godot/village/village_hud.gd` hides the Units button. The port keeps `boughtUnits` as the server does (`village_map.gd`), but has no list, no cash buy of units and no completion.

Web: the SuperCheats guide on collections ([link](https://www.supercheats.com/guides/social-empires/collections)) is about the item collections, which the port has; its search text also mentions units bought with cash.

Work: medium. A list window with the art of the client, the cash buy, the completion and the alert.

## News window

`PopupNews` opens from Gift > News and also at login for players from level 5. It shows the 10 news pictures of `globals.NEWS_ITEM`, each with a link to a tab of the store, the promotion packs of `offer_packs`, the cash of the player with a button to the cash shop, and a button to the store. The server needs no command; the packs use the same commands as the store packs.

Port: `village_hud.gd` hides the News button. The port already has the store and the unit packs.

Not checked: that all 10 news pictures are in `assets/`.

Work: medium. The window with its art; the store links and packs use the code that the port has. The cash button needs the cash shop, which is not possible offline.

## Darts

`PopupDarts` is a game of 25 balloons. A hit shows an item; when all items are found, the player gets the main prize. One free throw each day; more throws cost cash (`DART_COST_CASH`). A new board starts each week from the dates of `darts_items`.

In 1.4.07 players cannot open it: the games menu is always hidden (`GuiManager`), the function of the darts button has no caller, and only the admin panel opens the window. The SuperCheats guide ([link](https://www.supercheats.com/guides/social-empires/darts)) describes a darts icon, so older versions of the client had it.

- Server: `darts_reset`, `darts_new_free` and `darts_shoot_balloon` (`op.py`), and `darts.py` makes the weekly dates.
- Port: none; the games menu is hidden as in the client.

Work: medium. Adding it is a change from 1.4.07, because the 1.4.07 client does not show it.

## Island Forge (collect game)

`CollectGameManager` and `PopupIslandForge` are a timed event on the forge island (building 1530). The player collects six forge items from quests, troll kills, PvP and invites, can buy or speed up items for cash, and gets rewards at item counts.

- Server: the five `collect_game_*` commands (`op.py` `cmd_hellforge_*`), the save field `collectGame`, and the event `HELL_FORGE_ISLAND` in `server_config.json`. The event has a fixed date, 20 October 2025, for 7 days, so it is not active now unless the owner changes the date.
- Port: none. `godot/game_data/collections.gd` says that the collect game is not in the port.
- The roadmap called these "the collection islands". In the code the forge island is the only island of the collect game.

Work: large. The window, the six items, the timers and prices, the rewards, and the places where items drop.

## Nest and Rider Academy mini-games

Taming a dragon in a nest (`PopupDragonTaming`, level 8) and each training step of the Rider Academy (`PopupDragonRiderTraining`, the level of the step) start a flying game from `swf/minigames/SagaOTDC.swf` (`WindowMiniGameDragonRider`). A win sends the step to the server; a loss changes nothing. The server accepts the result of the client.

Port: `village.gd` (`train_rider`, `tame`) counts each step as won.

Work: large. The mini-game is a separate Flash program; the port would need a new game written in Godot. The other choice is to keep the current rule.

## Spy screen art

`StateSpy` hides the village HUD and shows the spy frame of the attack bar (`HudSpyEnemy`): the name and level of the enemy, its resources, Attack, Find next with its cost, and My town. The port (`godot/pvp/spy_screen.gd`) has the same functions with Godot controls and the zoom of the client, 0.5.

Work: medium. Import the spy frame of the attack bar like the other HUD parts; the logic stays.

## Battle zoom

The client sets the zoom only for the spy screen (0.5), the tournament (0.1) and the quests in which the player cannot move the map, which are the ship and zeppelin quests (0.7). In all other battles it keeps the zoom that the player had in the village. The port starts each battle at 0.7 (`map_camera.gd`).

Work: small. Give the zoom of the village camera to the battle screens.

## Female host

The goal box shows a female host (`GameShowFemaleMissionMC`) when the page gives the client `sex=f`; the tutorial has a female host too (`GameShowFemaleHostMC`). The goal texts also use the gender. The server page always sends `sex=m` (`templates/play.html`, `templates/ruffle.html`), so the original game on this server always shows the male host. Both symbols are in the client.

Work: small. A setting in the port, the import of the two symbols, and the choice in `goal_box.gd` and the tutorial.

## Facebook parts

- **Achievement publish.** When a unit with `achievement` 1 first shows on the map, the client sends `rt_publish_achievement_unit` once and keeps the unit in `achievedUnits`. The server has the command. Only the post on Facebook needs Facebook. Work: small.
- **Cash shop.** "Add Cash" and the cash buttons of other windows call `gotoBuy` on the page. The server page does not define it, so the button does nothing on this server. A real shop needs a payment service. The port shows a message. A way to get cash without payment is a decision of the owner.
- **Other viral icons.** Cross-promotion of other Social Point games, the like button, video ads, the Monday bonus, the comeback bonus, special-day offers and the achievements button are all off in the server config (`active` 0). Most need Facebook or other Social Point services.
- **Friend features.** Potions and help from friends, viral offers bought from friends and hiring friends need other players. The port uses the villages of `villages/` as neighbours (step 4.4).

## Other client parts

The client classes were compared with the port. Parts that are in the 1.4.07 client and not in the port, besides the items above:

| Part | Server | Notes |
|---|---|---|
| Monday bonus and comeback bonus (`MondayBonusPopUp`, `ComebackBonusPopUp`) | No handler for `weekly_reward` and `comeback_reward` | Off in the config, so the original game does not show them here. |
| Arabic deals (`PopupArabicDeals`) | The client sends `add_items_store`; the server knows only `store_add_items` | Opened from a building. The server answers that the command is not implemented, so it does not save the buy. |
| Mystery boxes (`PopupMistery`, `PopupSuperMistery`) | No command found | Not checked if a player can reach them. |
| Kompu offers | `kompu_offers` is empty in the mega patch | Nothing to show on this server. |
| Ivory Challenge, Night Forge and Easter Dragon events | Off in `server_config.json` | The units of these events are in the port's battles. |
| PvP leaderboard and tournament ranking and prizes | `/pvp/ranking` and `get_continent_ranking` | The owner decided against the ranking and prizes of the tournament (step 4.1). |

Not in the 1.4.07 client: chat and guilds. "Allies" in this game are the allies buildings and market, which the port has.

## Server bugs found

These were found by reading the code and are not fixed. They matter for the port only where it copies the server's rules.

1. `version.py` `fix_bought_units`: for a troll map the line that should set the ignored race to "h" is a comparison (`==`), so the troll units are left out and the human units are counted. `engine.py` `register_bought_unit` has the correct rule.
2. The client sends `add_items_store` for the Arabic deals; `command.py` has only `store_add_items`.
3. `weekly_reward` and `comeback_reward` have no handler (the icons are off).
4. `get_game_config.py` lists `unit_collections` in `patch_ignore`, but no patch has that name.

## Save migration

The server runs `version.py` `migrate_loaded_save` on each save that it loads. It fills missing fields, rebuilds `boughtUnits` from the maps when the list is empty, fixes collections, the forge and events, the graveyard, banned units, survival maps, quest ranks and some goals. The port has no general migration; it reads defaults where it needs them, and ports the troll empire fix (`village_map.gd`).

Work: small to medium. A loader that fills the missing fields of an old save, with the correct race rule for `boughtUnits`. This matters most for the unit list.

## Tutorial and explorations

### The tutorial after step 10

Step 4.3 compared the tutorial with the original client only up to step 10, because the automation could not place the house. The house must go on tile (55, 55), and the click that gives this tile is not at the centre of the green marked place on the screen. With the correct click, the original client in Ruffle went through all 32 steps on the save of a new empire. The server saved the steps 1 to 13 and 15 to 31 (14 does not show), and the save ends with `completed_tutorial` 31.

The port was then run on the same save with a script that calls its functions (not with mouse clicks). These agree with the client: the order of the steps, the skip of step 14, the tiles of the house (55, 55) and the farm (52, 44), the texts of the boxes of steps 0 to 13, goals 1, 2, 3, 4, 5 and 11 rewarded, gold, food and stone at the end, and the dragon nest. Both count any tree for the last step, not only the three marked trees.

Differences from the client:

1. **Steps 11 and 20.** The client saves step 11 (after the house) and step 20 (after the farm) when the construction ends; step 11 also waits for a move of the map. The port saves them when the building is placed. Work: small.
2. **The nest steps at the end.** After the tutorial the client sends 9 `next_step` commands for the new dragon nest, and the server accepts them, because a new empire has `dragonNestActive` 1. The save of the client ends with `stepNumber` 9; the port leaves it at 0. The comment in `village.gd` (`add_tutorial_nest`) says that the server refuses these commands; that is not correct. Work: small.
3. **Steps 15 to 31.** The client shows only the arrow. The port shows its own short text with the arrow (`ARROW_TEXTS` in `tutorial/tutorial.gd`, a choice of the port), and it also darkens the screen behind the goal window, which the client does not do in the tutorial. Removing the text is a decision of the owner; the dark screen is a small fix.
4. Wood and experience at the end were a little lower in the port (1135 against 1175 wood, 30 against 32 experience), and the goals were completed in another order. The villager of the client cut 5 trees by itself and the port script cut 3, which explains the difference in wood; the experience was not traced.

Not checked: if the client saves step 17 at the first click on the goal box or at the "+Info" click, because the server got steps 16 and 17 in one batch.

### Ship and zeppelin explorations

The client gets the maps of the ship (`100000009`) and the zeppelin (`100000016`) from the game server when the player starts the exploration, not from its files. No copy is in `assets/`, in the `villages/` folders, or in the forks of `AcidCaos/socialemperors` that were checked (18 of the forks; one other fork has the same 35 quest maps as this repository). `server.py` also does not send these ids to the quest code, because they are not in its list of quest ids. Web searches found no copy of the maps and no pictures of their layout; the web archive and the fan wiki could not be opened from this session.

So the explorations cannot be checked against the original game. To add them the port needs one of these:

- a copy of the two maps from an old capture of the Social Point servers on the web archive, or from a fork that was not checked;
- pictures or videos of the explorations, to make the maps again by hand;
- new maps made for the port, with the client's rules for the ship and zeppelin quests (the map does not move in these quests, and the zoom is 0.7).

## The HUD on modern screens

The client was made for a Flash stage of 760 × 600 pixels in a Facebook page. In full screen it keeps the HUD at 760 pixels and puts it in the middle of the screen, with the bottom bar at the bottom and the top bars at the top (`StateNormal.setFullScreen`). The port does the same in its window.

### What the port does now

- `project.godot` sets a window of 1280 × 800 and no stretch mode. The HUD, the windows and their text are drawn at one pixel for each pixel of the client.
- The windows of the client are drawn by FlashArt at scale 1 only (`sprites/frame_cache.gd`). Only the map frames are drawn again at the scale of the camera (1, 1.5 or 2).
- The zoom of the map (0.7 at the start, 0.15 to 1.4) does not change with the size of the window.
- Some screens place parts from the 760-pixel stage of the client (`QuestHud`, `SurvivalScreen`, `TournamentScreen`, `CastBanner`, `SpellBookHud`); the goal box and the zoom slider are at the edges of the window.

### Measurement

Screenshots of the village of Arthur with the login bonus window, at four window sizes (Xvfb, OpenGL 3).

The HUD and the windows have the same size in pixels at all window sizes; the numbers of the resources are about 10 pixels high. Only their share of the screen and their size on the screen change:

| Window | HUD width / window width | Text height on a typical screen |
|---|---|---|
| 1280 × 800 | 59% | the size at which the port was checked |
| 1920 × 1080 (24-inch, 92 pixels per inch) | 40% | about 2.8 mm |
| 2560 × 1440 (27-inch, 109 pixels per inch) | 30% | about 2.3 mm |
| 3840 × 2160 (27-inch, 163 pixels per inch) | 20% | about 1.6 mm |

At 3840 × 2160 the HUD and the windows are a narrow strip in the middle of the screen, and the goal box is far from them at the left edge. The village also looks small, because the zoom does not follow the window size.

Godot 4 gives the window the physical pixels of the screen (`display/window/dpi/allow_hidpi` is on by default), so the scaling of the operating system (for example 200% on a 4K laptop) does not make the HUD larger.

### What must change

1. **A UI scale.** Scale the HUD and the windows by a factor from the window height (for example height / 600, rounded to steps of 0.25), with a setting in the options panel. Godot can do this with the content scale of the window (`content_scale_mode` "canvas_items" with aspect "expand"), or with a scale on the CanvasLayers of the HUD and the windows. The content scale is the smaller change, but it also scales the map; the CanvasLayer scale keeps the map at its own zoom.
2. **Sharp art at the UI scale.** FlashArt must draw the window frames at the UI scale, as it does for the map frames, else the scaled HUD is blurred. The fonts of the text fields must be drawn at the scaled size. The bitmap pictures of the windows (for example `DailyBonus/imgs`, the quest pictures) have a fixed size and get soft above scale 1.
3. **Layout for wide screens.** The client puts everything in a 760-pixel column. With a UI scale this column is still narrow on 16:9 and 21:9 screens. Decide for each part if it stays in the column (the bottom bar) or goes to an edge (the goal box, the zoom slider, the spell book, the neighbour bar could be wider and show more neighbours).
4. **Map zoom for the window size.** Scale the start zoom and the zoom limits by the same factor, so that the village shows the same area of the map as on the client's screen.
5. **Checks.** Screenshots at 1280 × 800, 1920 × 1080, 2560 × 1440, 3840 × 2160 and 3440 × 1440 of the village, a quest, the windows and the tournament, before and after.

This is a change of the look of the original game. The owner decides how far the port goes: only a scale, or also a new layout for wide screens.
