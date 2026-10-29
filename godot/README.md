# Social Empires: Godot 4 port

A new client for Social Empires, written in GDScript for Godot 4.7. It does not contain Social Point files. You import the graphics and the game configuration from your own copy of the socialemperors server.

Status: the first milestone. The port shows one village map with its land, buildings, decorations and units, at the same positions as the original client. You can pan with a mouse drag and zoom with the mouse wheel. There is no game play yet.

## Import the game files

You need Python 3 with the server requirements (`pip install -r requirements.txt` in the server folder), Java, and the JPEXS decompiler (`ffdec-cli.jar`, https://github.com/jindrapetrik/jpexs-decompiler).

```bash
python godot/importer/import_assets.py --source <socialemperors folder> --out <data folder> --jpexs <path to ffdec-cli.jar>
```

- `--source` defaults to this repository.
- `--village <file>` selects a village save to import, for example `saves/<USERID>.save.json`. The default is `villages/initial.json`. You can give the option more than one time.
- `--all` imports the graphics of all items, not only the items in the villages. This takes a long time.

## Run

Open the `godot` folder in Godot 4.7, or run:

```bash
godot --path godot -- --data <data folder>
```

The port reads the data folder from `--data`, then from the `SE_DATA_DIR` environment variable, then from `user://imported`. Use `--village <file>` to show a different save, and `--screenshot <file.png>` to save an image and quit.

## Layout

| Path | Contents |
|---|---|
| `importer/` | Import tool. `swf_bounds.py` reads symbol bounds from SWF files, so the images keep the position of the original graphics. |
| `game_data/` | Game configuration (item definitions) |
| `village/` | Village save model, map coordinates, map view and camera |
| `sprites/` | Loads the imported item graphics |
