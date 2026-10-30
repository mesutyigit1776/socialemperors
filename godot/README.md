# Social Empires: Godot 4 port

A new client for Social Empires, written in GDScript for Godot 4.7. It does not contain Social Point files. You import the graphics and the game configuration from your own copy of the socialemperors server.

Status: the seventh milestone. The port shows one village map with its land, buildings, decorations and units, at the same positions as the original client. You can pan with a mouse drag and zoom with the mouse wheel.

You can buy buildings and decorations from the store (the village, defense, army and decoration categories) and place them on your own land. The store shows the items for the race of the map. The port checks the map edges, the owned land, the other items (units also block a tile), the construction limits, the level and the resources. The construction limits are the same as in the original client: for example one market, one mine of each level, a number of houses that the town hall sets, and 10 towers for each land area. When the experience reaches the next level, the level goes up and the player gets the reward of that level, as in the original game. After each purchase it saves the village in the server format, with the previous version in `<save>.bak`. The server and the original client can load this save.

Click an item on the map to select it. You can move your own buildings and decorations, also the town hall, and sell them, except the town hall. You can turn them with the Turn button, and with the space bar while you place or move an item. A sale gives back a twentieth of the cost, in the resource of the cost. Items that cost cash give nothing back. The port does not move or sell units, trees and stone or gold deposits, as in the original game.

Mills, mines, farms, ranches and other production buildings produce a resource. A mark shows the buildings that are ready, and a click on a ready building collects from it. The production times and amounts come from the game configuration. The mills and mines of humans work only after you choose a work time: 5 minutes, 1 hour, 4 hours or 8 hours, which give 0.5, 1, 2 or 3 times the amount. After a collection you choose again. Each unit in a building after the first one adds a fifth to the amount. A farm costs a third of its amount in wood at each collection. If you do not have the wood, the farm is removed, as in the original game. You can pay 2 cash to collect at once from a working mill, mine, restaurant, bakery, temple or wonder.

A new building that needs workers gets only the player's own villager. The server also hires neighbours from its other saves, which the port cannot see. You can hire the other workers in the game.

Not done yet: the wonders and the "New" store categories, units that walk and collect trees and deposits, putting units into buildings, and the functions of special buildings. Buildings that produce units, potions or other special resources, for example the Nursery and the Treasure Mine, do not produce yet. The functions of special buildings include the graveyard, the nests and the Soul Mixer. You can buy these buildings, and the save is correct, but the port does not use them yet.

## Import the game files

You need Python 3 with the server requirements (`pip install -r requirements.txt` in the server folder), Java, and the JPEXS decompiler (`ffdec-cli.jar`, https://github.com/jindrapetrik/jpexs-decompiler).

```bash
python godot/importer/import_assets.py --source <socialemperors folder> --out <data folder> --jpexs <path to ffdec-cli.jar>
```

- `--source` defaults to this repository.
- `--village <file>` selects a village save to import, for example `saves/<USERID>.save.json`. The default is `villages/initial.json`. You can give the option more than one time.
- By default the tool imports the land, the store buildings and the items in the villages. `--all` imports the graphics of all items. This takes a long time.
- `--jobs <n>` sets how many JPEXS processes run at the same time (default 4).

## Run

Open the `godot` folder in Godot 4.7, or run:

```bash
godot --path godot -- --data <data folder>
```

The port reads the data folder from `--data`, then from the `SE_DATA_DIR` environment variable, then from `user://imported`. Use `--village <file>` to open a different save, and `--screenshot <file.png>` to save an image and quit.

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
| `game_data/` | Game configuration (item and level definitions) and the construction limits that the client contains as fixed values |
| `village/` | Village save model and placement rules, map coordinates, map view, camera and screen interface |
| `sprites/` | Loads the imported item graphics |
| `checks/` | Headless checks of the village rules and the save format |
