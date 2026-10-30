# Social Empires: Godot 4 port

A new client for Social Empires, written in GDScript for Godot 4.7. It does not contain Social Point files. You import the graphics and the game configuration from your own copy of the socialemperors server.

Status: the twelfth milestone. The port shows one village map with its land, buildings, decorations and units, at the same positions as the original client. You can pan with a mouse drag and zoom with the mouse wheel.

You can buy buildings and decorations from the store (the village, defense, army, decoration, wonder and "New" categories) and place them on your own land. The store shows the items for the race of the map, as the original client does: it hides items until their store level, and it does not offer the items for "gold members", because the server starts the client without gold membership.

The "New" category is the store rotation of the server. The server offers 2 groups of items from `config/shop_rotation.json` for 48 hours, then 2 other groups, and the Halloween group on 31 October. The importer copies these groups and the shop settings from `server_config.json` to `shop.json`, and the port applies the same rules. It chooses the groups with its own random numbers, so in the same period it can offer other groups than the server. Only humans can buy the rotation items, as on the server. The port checks the map edges, the owned land, the other items (units also block a tile), the construction limits, the level and the resources. The construction limits are the same as in the original client: for example one market, one mine of each level, a number of houses that the town hall sets, and 10 towers for each land area. When the experience reaches the next level, the level goes up and the player gets the reward of that level, as in the original game. After each purchase it saves the village in the server format, with the previous version in `<save>.bak`. The server and the original client can load this save.

Click an item on the map to select it. You can move your own buildings and decorations, also the town hall, and sell them, except the town hall. You can turn them with the Turn button, and with the space bar while you place or move an item. A sale gives back a twentieth of the cost, in the resource of the cost. Items that cost cash give nothing back. The port does not move or sell units, trees and stone or gold deposits, as in the original game.

Units walk. Click a unit, then a free tile: the unit walks there around the other items. Click a mine, mill or farm to send a villager to work in it, or a tree, stone or gold deposit to harvest it. Select a building to take its units out. A harvest takes a few seconds and gives the resource; more villagers on the same resource give more. Gold deposits give more gold at higher levels. A harvested stone or gold deposit grows again after 3 hours. Buildings that train units, for example the town hall and the barracks, have a Train button. A training queue holds 5 units, and the units must fit in the population that your houses allow. Units of the other race on your map are not yours, as in the original client. Some units, for example the ghost, cost cash and food. The "Finish all" button ends the whole training queue at once for 1 cash for each started hour of training time that is left. The "Cancel" button takes the last unit out of the queue and gives back what you paid for it, as the original game does.

Units do not walk by themselves, as in the original client. An idle unit sometimes turns toward a neighbouring tile. When one of your units stands on a building other than a farm, or on another unit, it walks to a free tile near it. Saves from the server or the original client can have such units. The client moves wild animals in the same way but does not save the move, so the port keeps them in place.

Wild animals come to the village: sheep and cows for humans, also horses from level 11, and boars for trolls. At each start the port adds animals on the land that you do not own, until the map has 7 of each kind (6 horses), as the client does. The server counts the animals of the day in the save, and the client adds no more than 20 of a kind. When one of your units comes within 4 tiles of a wild animal, the animal becomes yours and walks into the nearest ranch of its kind; a horse walks into the Training Stables. When the ranch is full, the animal stops next to it; without a ranch, it walks to the town hall. Animals on your own land are yours when the village loads, as in the client. You can send your animals into buildings like other units.

Some buildings take units. A spearman, swordsman or archer that goes into the Training Stables with a horse in it takes the horse and becomes a knight or a mounted archer. The Nursery breeds a new animal every 9 hours from two animals of the same kind. The Sacrifice Altar takes any unit except siege units, and after one second the unit is gone and gives back a twentieth of its cost. Refuges take any unit, and the Fortress takes units that shoot; in the original game they protect these units in battles, which the port does not have yet. The Unit Warehouse keeps units outside the map and the population: select it to take a unit out or to buy one more place for 2 cash. When you sell a building, or a farm is removed, its units come out first, as in the client.

Mills, mines, farms, ranches and other production buildings produce a resource. A building with room for units works only with a unit in it: a villager in a mine, mill or farm, animals in a ranch. A ranch uses one animal for each collection. A mark shows the buildings that are ready, and a click on a ready building collects from it. The production times and amounts come from the game configuration. The mills and mines of humans work only after you choose a work time: 5 minutes, 1 hour, 4 hours or 8 hours, which give 0.5, 1, 2 or 3 times the amount. After a collection you choose again. Each unit in a building after the first one adds a fifth to the amount. A farm costs a third of its amount in wood at each collection. If you do not have the wood, the farm is removed, as in the original game. You can pay 2 cash to collect at once from a working mill, mine, restaurant, bakery, temple or wonder.

The Treasure Mine gives an item of a collection every 24 hours instead of a resource. A harvest of a tree, stone or gold also finds an item 4 times in 100. Only humans find items, as in the original game. The Collections button shows the items that you have. When you have each item of a collection, you can complete it and get its reward, for example a garden. You can also complete a collection for cash. The reward goes into the item store; the Item store button places it on your land.

Special buildings show their actions under the selection. The client gives every player a free Dragon Breeding Nest, and from level 8 a free Soul Mixer, when the map does not have one. The dragon nest and the Monsters Nest start for gold or cash. Then each care step makes the dragon or monster grow, and after it you wait 6 hours or pay a little cash. After 10 steps the unit comes out next to the nest, and the next one starts. The Rider Academy trains a dragon rider in 5 to 7 steps, with 15 hours or 15 cash after each step. A rider and a dragon of the rider's type go into Dragon Riding and become a tamed dragon. In the original game each training step and each taming needs a mini-game, which is a separate Flash file. The port does not have the mini-games and counts each one as won.

The Soul Mixer takes two units with a soul power. It chooses a new unit from their powers, at random, and you can pay cash for a stronger one. The mix takes the time of the new unit, which you can end with cash. Then the new unit and the two units come out. Units die only in battles, which the port does not have yet, but saves from the server can have dead units. The graveyard brings them back for potions, and sells 25 potions for 5 cash. The Heroes Grave brings heroes back for gold.

A new building that needs workers gets only the player's own villager. The server also hires neighbours from its other saves, which the port cannot see. You can hire the other workers in the game.

The save changes are the same as from the server commands, with three differences. All follow what the client shows. When the first unit goes into an empty building (in the Nursery, the second), the port starts the production time then, as the client does on screen; the server does not change the time. When a unit comes out of a training queue, the port moves the start time of the queue to the next unit; the server keeps it, so after a reload all units of a queue come out at once. When you finish a training queue with cash, the port charges the price that the client shows and takes, which counts all units of the queue; the server charges only for the next unit.

Not done yet: battles, quests and neighbours, and the functions of the other special buildings, for example the spell book, the Time Machine, the weather machine and the Bahamut temple. You can buy these buildings, and the save is correct, but the port does not use them yet. Help from neighbours, for example potions from friends and their help in the nests, is not done. The server has no command to buy more graveyard places, so the port does not offer it.

## Import the game files

You need Python 3 with the server requirements (`pip install -r requirements.txt` in the server folder), Java, and the JPEXS decompiler (`ffdec-cli.jar`, https://github.com/jindrapetrik/jpexs-decompiler).

```bash
python godot/importer/import_assets.py --source <socialemperors folder> --out <data folder> --jpexs <path to ffdec-cli.jar>
```

- `--source` defaults to this repository.
- `--village <file>` selects a village save to import, for example `saves/<USERID>.save.json`. The default is `villages/initial.json`. You can give the option more than one time.
- By default the tool imports the land, the store buildings, all items of the store rotation, the units and rewards that the special buildings and the collections give, and the items of the villages: the imported villages and the player saves in `saves/` of the server folder. This includes the units in buildings, in the unit warehouse, in training queues, in the item store and in the graveyards. `--all` imports the graphics of all items. This takes a long time.
- `--jobs <n>` sets how many JPEXS processes run at the same time (default 4).

## Run

Open the `godot` folder in Godot 4.7, or run:

```bash
godot --path godot -- --data <data folder>
```

Import the files again after an update of the port when it reports that a file in the data folder is missing. The port reads the data folder from `--data`, then from the `SE_DATA_DIR` environment variable, then from `user://imported`. Use `--village <file>` to open a different save, and `--screenshot <file.png>` to save an image and quit.

The port writes each change to the village file that it opened. To play a server save, give its path, for example `--village saves/<USERID>.save.json`. Do not run the server with the same save at the same time.

## Check the rules

`checks/village_check.gd` checks the placement rules, level-up, moving, selling, turning, collection and the save format without a window. It needs a data folder from an import of the unchanged socialemperors files, because the tiles and the expected values come from them. It writes its files to `user://checks/`.

```bash
godot --headless --path godot --script res://checks/village_check.gd -- --data <data folder>
```

The exit code is the number of failed checks. Run it after you change the village rules or the save code.

## Layout

| Path | Contents |
|---|---|
| `importer/` | Import tool. `swf_bounds.py` reads symbol bounds from SWF files, so the images keep the position of the original graphics. |
| `game_data/` | Game configuration (item and level definitions), and the construction limits and the collections that the client contains as fixed values |
| `village/` | Village save model and placement rules, map coordinates, map view, camera and screen interface |
| `sprites/` | Loads the imported item graphics |
| `checks/` | Headless checks of the village rules and the save format |
