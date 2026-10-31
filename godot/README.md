# Social Empires: Godot 4 port

A new client for Social Empires, written in GDScript for Godot 4.7. It does not contain Social Point files. You import the graphics and the game configuration from your own copy of the socialemperors server.

Status: the thirteenth milestone. The port shows one village map with its land, buildings, decorations and units, at the same positions as the original client. You can pan with a mouse drag and zoom with the mouse wheel.

You can buy buildings and decorations from the store (the village, defense, army, decoration, wonder and "New" categories) and place them on your own land. The store shows the items for the race of the map, as the original client does: it hides items until their store level, and it does not offer the items for "gold members", because the server starts the client without gold membership.

The "New" category is the store rotation of the server. The server offers 2 groups of items from `config/shop_rotation.json` for 48 hours, then 2 other groups, and the Halloween group on 31 October. The importer copies these groups and the shop settings from `server_config.json` to `shop.json`, and the port applies the same rules. It chooses the groups with its own random numbers, so in the same period it can offer other groups than the server. Only humans can buy the rotation items, as on the server. The port checks the map edges, the owned land, the other items (units also block a tile), the construction limits, the level and the resources. The construction limits are the same as in the original client: for example one market, one mine of each level, a number of houses that the town hall sets, and 10 towers for each land area. When the experience reaches the next level, the level goes up and the player gets the reward of that level, as in the original game. After each purchase it saves the village in the server format, with the previous version in `<save>.bak`. The server and the original client can load this save.

Click an item on the map to select it. You can move your own buildings and decorations, also the town hall, and sell them, except the town hall. You can turn them with the Turn button, and with the space bar while you place or move an item. A sale gives back a twentieth of the cost, in the resource of the cost. Items that cost cash give nothing back. The port does not move or sell units, trees and stone or gold deposits, as in the original game.

Units walk. Click a unit, then a free tile: the unit walks there around the other items. Click a mine, mill or farm to send a villager to work in it, or a tree, stone or gold deposit to harvest it. Select a building to take its units out. A harvest takes a few seconds and gives the resource; more villagers on the same resource give more. Gold deposits give more gold at higher levels. A harvested stone or gold deposit grows again after 3 hours. Buildings that train units, for example the town hall and the barracks, have a Train button. A training queue holds 5 units, and the units must fit in the population that your houses allow. Units of the other race on your map are not yours, as in the original client. Some units, for example the ghost, cost cash and food. The "Finish all" button ends the whole training queue at once for 1 cash for each started hour of training time that is left. The "Cancel" button takes the last unit out of the queue and gives back what you paid for it, as the original game does.

Units play the animations of the original graphics, for example the walk in each direction. A data folder from an import before this change has no animations, so its units show still images; import the files again to get them. Units walk at the speed of the original client: their velocity in pixels in each frame, with a short stop at each tile. Villagers walk faster when the town hall has a higher level, and faster again with a Fitness Centre or a Troll Coliseum. Units do not walk by themselves, as in the original client. An idle unit sometimes turns toward a neighbouring tile. When one of your units stands on a building other than a farm, or on another unit, it walks to a free tile near it. Saves from the server or the original client can have such units. The client moves wild animals in the same way but does not save the move, so the port keeps them in place.

Wild animals come to the village: sheep and cows for humans, also horses from level 11, and boars for trolls. At each start the port adds animals on the land that you do not own, until the map has 7 of each kind (6 horses), as the client does. The server counts the animals of the day in the save, and the client adds no more than 20 of a kind. When one of your units comes within 4 tiles of a wild animal, the animal becomes yours and walks into the nearest ranch of its kind; a horse walks into the Training Stables. When the ranch is full, the animal stops next to it; without a ranch, it walks to the town hall. Animals on your own land are yours when the village loads, as in the client. You can send your animals into buildings like other units.

Some buildings take units. A spearman, swordsman or archer that goes into the Training Stables with a horse in it takes the horse and becomes a knight or a mounted archer. The Nursery breeds a new animal every 9 hours from two animals of the same kind. The Sacrifice Altar takes any unit except siege units, and after one second the unit is gone and gives back a twentieth of its cost. Refuges take any unit, and the Fortress takes units that shoot; in the original game they protect these units in battles, which the port does not have yet. The Unit Warehouse keeps units outside the map and the population: select it to take a unit out or to buy one more place for 2 cash. When you sell a building, or a farm is removed, its units come out first, as in the client.

Mills, mines, farms, ranches and other production buildings produce a resource. A building with room for units works only with a unit in it: a villager in a mine, mill or farm, animals in a ranch. A ranch uses one animal for each collection. A mark shows the buildings that are ready, and a click on a ready building collects from it. The production times and amounts come from the game configuration. The mills and mines of humans work only after you choose a work time: 5 minutes, 1 hour, 4 hours or 8 hours, which give 0.5, 1, 2 or 3 times the amount. After a collection you choose again. Each unit in a building after the first one adds a fifth to the amount. A farm costs a third of its amount in wood at each collection. If you do not have the wood, the farm is removed, as in the original game. You can pay 2 cash to collect at once from a working mill, mine, restaurant, bakery, temple or wonder.

The Treasure Mine gives an item of a collection every 24 hours instead of a resource. A harvest of a tree, stone or gold also finds an item 4 times in 100. Only humans find items, as in the original game. The Collections button shows the items that you have. When you have each item of a collection, you can complete it and get its reward, for example a garden. You can also complete a collection for cash. The reward goes into the item store; the Item store button places it on your land.

Special buildings show their actions under the selection. The client gives every player a free Dragon Breeding Nest, and from level 8 a free Soul Mixer, when the map does not have one. The dragon nest and the Monsters Nest start for gold or cash. Then each care step makes the dragon or monster grow, and after it you wait 6 hours or pay a little cash. After 10 steps the unit comes out next to the nest, and the next one starts. The Rider Academy trains a dragon rider in 5 to 7 steps, with 15 hours or 15 cash after each step. A rider and a dragon of the rider's type go into Dragon Riding and become a tamed dragon. In the original game each training step and each taming needs a mini-game, which is a separate Flash file. The port does not have the mini-games and counts each one as won.

The Soul Mixer takes two units with a soul power. It chooses a new unit from their powers, at random, and you can pay cash for a stronger one. The mix takes the time of the new unit, which you can end with cash. Then the new unit and the two units come out. Units die only in battles, which the port does not have yet, but saves from the server can have dead units. The graveyard brings them back for potions, and sells 25 potions for 5 cash. The Heroes Grave brings heroes back for gold.

A new building that needs workers gets only the player's own villager. The server also hires neighbours from its other saves, which the port cannot see. You can hire the other workers in the game.

The save changes are the same as from the server commands, with three differences. All follow what the client shows. When the first unit goes into an empty building (in the Nursery, the second), the port starts the production time then, as the client does on screen; the server does not change the time. When a unit comes out of a training queue, the port moves the start time of the queue to the next unit; the server keeps it, so after a reload all units of a queue come out at once. When you finish a training queue with cash, the port charges the price that the client shows and takes, which counts all units of the queue; the server charges only for the next unit.

Battles have started. The port has the battle rules of the original client: units look for enemies, walk around buildings and attack, towers shoot, healers heal, and the damage, the timing and the walking speed are the same as in the client. You control your units as in the original game. Click a unit to select it, or click it twice within one second to select your units of the same kind near it, for example all archers. Drag from one of your units, or press the space bar and drag, to select the units in a box. Click the ground to send the selected units there in a formation, or an enemy to attack it. The selected items and the item under the mouse show a health bar.

The campaign quests are playable on 12 islands: the 4 troll islands and the 8 civilisation islands. The Quests button opens the island window of the original game, with its pictures, buttons and fonts. The islands open one after the other, as in the original game; the window shows the stars that you won and a lock on the islands that you cannot start yet. The other islands have bosses and scripts of their own, which the port does not have yet; they show a lock and the sign "Not in the port yet". Click an open island to sail there with all fighting units of your village (not the villagers and animals). Choose 1 to 3 stars, at most one more than you won on the island; more stars give each enemy unit a copy. On a troll island, defeat all enemy units, then click the treasure to win. On a civilisation island, destroy the town hall. The bar at the top shows the gold and experience of the quest, and the Withdraw button ends the battle early. At the end, the result window shows the gold, the experience, the honour and the units that you lost: 60 percent of the units that died come back. The save then changes as the server command `end_quest` changes it, and the next island opens after a win. You can start 3 quests in a row, or 4 with the Odin statue; after 2 hours without a new quest you can start them again (the original game waits 6 hours; `quest/quest_book.gd` explains how to change this). The units on the islands do not use their special attacks yet.

Spells work as in the original game. Human players get the spell book at the bottom left from level 15; troll players always have it. Click the book to see your spells, and the button under it to open the spell window, where you buy spells for gold or cash and see their levels. Click the mana to buy 5 mana for 20000 gold or 1 cash. Choose a spell, move the marker over the map and click to cast it; a right click, the Escape key or a click on the book cancels. Each cast costs mana and counts towards the next spell level (25 and 50 casts). In quests the 14 spells of the port act as in the client, with two errors of the client that the port keeps or corrects; see `docs/GODOT_BATTLES.md`. Instant Limit shows the sign "Not in the port yet". In the village a cast costs its mana and shows the spell, but does not change your units, as summoned units are not saved there. When a player reaches level 15 in the village, the port gives a free Wizardry Academy, as the original game does; select it to open the spell window. The panel of the port is at the top right, so that it does not cover the book.

You can also try a battle on any quest map: start the port with `--battle <file>`, for example `--battle <socialemperors folder>/villages/quests/100000013.save.json`. All items of that map except the trees, rocks and other neutral items are enemies, and the units of your village start in the land area with the fewest items. Shots use the graphics of the original game and fly as in the client: arrows and rocks in a curve, rocks and cannonballs with smoke and a blast where they land, fireballs and other shots straight or in an arc. They start at the point of the graphic from which the original shoots, and aim at the height of the target, as the client does. A data folder from an import before this change has no graphics of shots, and its shots start and aim at the feet of the items; import the files again to get them. The health bars and the selection rings are simple shapes; their graphics are in the main file of the client, from which the importer takes only the windows of the quests. `docs/GODOT_BATTLES.md` has the plan for the next stages: spells, the other quests, special abilities and the single-player modes.

Not done yet: the quests of the other islands, neighbours, and the functions of the other special buildings, for example the Time Machine, the weather machine and the Bahamut temple. You can buy these buildings, and the save is correct, but the port does not use them yet. Help from neighbours, for example potions from friends and their help in the nests, is not done. The server has no command to buy more graveyard places, so the port does not offer it.

## Import the game files

You need Python 3 with the server requirements (`pip install -r requirements.txt` in the server folder), Java, and the JPEXS decompiler (`ffdec-cli.jar`, https://github.com/jindrapetrik/jpexs-decompiler).

```bash
python godot/importer/import_assets.py --source <socialemperors folder> --out <data folder> --jpexs <path to ffdec-cli.jar>
```

- `--source` defaults to this repository.
- `--village <file>` selects a village save to import, for example `saves/<USERID>.save.json`. The default is `villages/initial.json`. You can give the option more than one time.
- By default the tool imports the land, the store buildings, all items of the store rotation, the units and rewards that the special buildings and the collections give, and the items of the villages: the imported villages, the player saves in `saves/` and the quest maps in `villages/quests/` of the server folder. This includes the units in buildings, in the unit warehouse, in training queues, in the item store and in the graveyards. `--all` imports the graphics of all items. This takes a long time.
- The tool also imports the graphics of the shots and effects of battles from `assets/fx/` and of the spells from `assets/buildingsprites/magic_*.swf`, copies the quest maps, and exports the windows of the quests and the spells from the client file `assets/flash/SocialEmpires1.4.07sec_fixed.swf`, with their fonts and pictures, the banner of a cast from `magic_cast_marquee.swf`, and the alert of the spell book with its picture. An import before the alert shows the gift of level 15 only as a message. `spells.json` tells at which frame each spell acts. A data folder from an import before the spells has no spell book; the Quests button then asks you to import again.
- `--jobs <n>` sets how many JPEXS processes run at the same time (default 4).
- The import of all graphics takes several hours. You can stop it with Ctrl+C, or it can stop for another reason, and continue it later: run the same command with the same `--out` folder. The tool skips each graphic and the windows that an earlier run finished, and imports the others. It imports a graphic again when its SWF file or the code of the tool changed, so after an update of the port the same command brings the data folder up to date. To start from the beginning, delete the data folder.

## Run

Open the `godot` folder in Godot 4.7, or run:

```bash
godot --path godot -- --data <data folder>
```

Import the files again after an update of the port when it reports that a file in the data folder is missing; with the same `--out` folder, the tool skips the graphics that are still up to date. The port reads the data folder from `--data`, then from the `SE_DATA_DIR` environment variable, then from `user://imported`. Use `--village <file>` to open a different save, and `--screenshot <file.png>` to save an image and quit.

The port writes each change to the village file that it opened. To play a server save, give its path, for example `--village saves/<USERID>.save.json`. Do not run the server with the same save at the same time.

## Check the rules

`checks/village_check.gd` checks the placement rules, level-up, moving, selling, turning, collection and the save format without a window. It needs a data folder from an import of the unchanged socialemperors files, because the tiles and the expected values come from them. It writes its files to `user://checks/`.

```bash
godot --headless --path godot --script res://checks/village_check.gd -- --data <data folder>
```

`checks/battle_check.gd` checks the battle rules with fixed random seeds. It needs the same data folder for the stats of the units and buildings.

```bash
godot --headless --path godot --script res://checks/battle_check.gd -- --data <data folder>
```

`checks/quest_check.gd` checks the rules of the campaign quests: the island list, the quest limit, the save changes of a quest result, the sides, the stars, the goals and the units that come back. It needs the same data folder, with the quest maps in `quests/`.

```bash
godot --headless --path godot --script res://checks/quest_check.gd -- --data <data folder>
```

`checks/spell_check.gd` checks the spell rules of the save (mana, buying spells and casts) and the 14 spells in battles, with fixed random seeds. It needs the same data folder, with `spells.json`.

```bash
godot --headless --path godot --script res://checks/spell_check.gd -- --data <data folder>
```

The exit code is the number of failed checks. Run the village check after you change the village rules or the save code, the battle check after you change the battle rules or the path search, the quest check after you change the quests, and the spell check after you change the spells.

## Layout

| Path | Contents |
|---|---|
| `importer/` | Import tool. `swf_bounds.py` reads symbol bounds, text fields and placements from SWF files, so the images keep the position of the original graphics. `ui_import.py` exports the windows of the client. |
| `game_data/` | Game configuration (item and level definitions), and the construction limits and the collections that the client contains as fixed values |
| `village/` | Village save model and placement rules, map coordinates, path search, map view, camera and screen interface |
| `battle/` | Battles: the rules (the battle, its items, the unit AI, formations, shots, special abilities, and the spells in `battle/spells/`), `battle_view.gd`, which draws a battle, and `battle_screen.gd`, which runs it and turns the mouse into orders |
| `sprites/` | Loads the imported graphics of the items and of the shots and effects. `clip_sprite.gd` plays the animation of a frame; `unit_sprite.gd` chooses the frame of a unit from its action and direction. |
| `quest/` | Campaign quests: the islands, the island list rules, the quest battle with its goals and result, and the windows of the quests |
| `spell_book/` | The spell book, the spell window, the mana window, aiming and casting, and the graphics of the spells on the map |
| `ui/` | Shows the windows of the client that the importer exported (`ui_import.py`): their images, buttons, stars and text fields |
| `checks/` | Headless checks of the village rules, the save format, the battle rules, the quests and the spells |
