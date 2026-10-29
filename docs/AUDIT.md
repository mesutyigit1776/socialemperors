# Project audit

Branch: `nerroth-rewrite` at commit `54df29e` ("Fix Build 20 Walls goal", 2026-08-16).
Audit date: 2026-10-29.

This audit was done by reading the code and inspecting files. Nothing was run: not the server, Ruffle, PyInstaller or any tests. Line numbers refer to the commit above.

## 1. What the project is

A private server for Social Empires, the Facebook Flash game Social Point ran from 2011 until its shutdown in 2019. The project consists of a Python/Flask server that emulates Social Point's backend, plus the original Flash client files, which the server hosts locally.

- License: GPL v3 (`LICENSE`).
- Latest tagged release: `0.04a` (2025-09-26), on `main`. `nerroth-rewrite` is 429 commits ahead of it and calls itself `"nerroth rewrite - beyond 0.04a"` (`version.py:17`).
- Entry point: `server.py`. It serves on the host and port in `server_config.json` (default `127.0.0.1:5050`) via `app.run(host=host, port=port, debug=False)` (`server.py:800`).
- Dependencies: `requirements.txt` lists `flask[async]` and `jsonpatch` with no versions. No supported Python version is stated.
- Packaging: `build/build.bat` (PyInstaller, one-folder build) and `build/launcher_build.bat` (one-file build, still named 0.03a). `bundle.py` resolves bundled paths through `sys._MEIPASS`.
- Platforms: Windows (release builds), Linux from source (`LINUX.md`, which needs a Chromium build with the PPAPI Flash plugin 32.0.0.371). macOS is not documented.

## 2. Layout

| Path | Contents |
|---|---|
| `server.py` | Flask app, 48 routes, all `async def` |
| `op.py` | Game command handlers (2,816 lines) |
| `engine.py` | Game rules and calculations (1,207 lines) |
| `sessions.py` | Save loading and saving, PvP pool and ranking (863 lines) |
| `constants.py` | Item and unit IDs (1,833 lines) |
| `version.py` | Save versioning and migration (587 lines) |
| `command.py` | Command name to handler table |
| `get_game_config.py`, `mods.py` | Game config loading, JSON-patch mods |
| `templates/` | Jinja pages (login, new empire, Flash player page, Ruffle page, PvP ranking) and `js/external_interface.js` |
| `config/` | Game config JSON (about 7.7 MB) and patches in `config/patch/` |
| `villages/` | 78 starting, quest and test villages (about 2.9 MB) |
| `assets/` | Original game media (about 1.3 GB) |
| `distr/` | Adobe Flash Player 32.0.0.371 debug installers, NPAPI and PPAPI (about 41 MB) |
| `tools/` | Offline converters (quests, fusion, unit patch) |
| `build/` | PyInstaller scripts |

Own code size, excluding game data: about 10.5k lines of Python (including `tools/`), 689 HTML, 1,600 CSS and 89 JavaScript.

### Server

The routes under `dynamic.flash1.dev.socialpoint.es/.../srvempires/*.php` stand in for the original backend: `get_game_config.php`, `get_player_info.php`, `command.php`, PvP enemy search and attack begin and end, `get_up_data.php`, and a reroute for `graph.facebook.com` profile pictures. Requests are signed with HMAC (`server_hmac.py`).

The routes are `async def`, but the work inside them is synchronous.

### Saves

Saves are JSON files at `saves/<USERID>.save.json` (`sessions.py:848-858`), with top-level keys `playerInfo`, `maps` and `privateState`. `BASE_DIR` is `"."` (`bundle.py`), so saves land in the current working directory. That contradicts the comment saying they go next to the executable. New players start from `villages/initial.json`.

### Game data

| File | Size |
|---|---|
| `config/game_config_20120723.json` | 1.7 MB |
| `config/game_config_20120826.json` | 1.7 MB |
| `config/game_config_4399.json` | 2.2 MB |
| `config/main.json` | 2.2 MB |
| `config/patch/2-unit_patch.json` | 1.8 MB |
| `config/patch/0-language_en.json` | 176 KB |
| `config/patch/1-mega_patch.json` | 74 KB |
| `config/goals.json` | 68 KB |

Patches are applied with `jsonpatch` (`get_game_config.py:98`, `mods.py:125`).

### Assets

4,825 files, 1.3 GB:

- 1,937 SWF files: 1,589 building sprites, 69 game client versions, 231 effects, 19 others.
- 2,874 images: 2,585 JPG, 288 PNG, 1 GIF.
- 14 MP3 files.

## 3. How the game client is loaded

The user picks a player on the login page: "Use Flash Player" or "Ruffle (Experimental)" (`templates/login.html:58-63`, `templates/new_empire.html:97-100`). Both pages load `SELoader.swf`, which then loads the chosen client from `assets/flash/`.

- **Flash Player:** `templates/play.html:89-92` embeds the SWF with `<object>`/`<embed>`. This needs Flash Player 32 in a browser that still supports the plugin. The installers in `distr/` are browser plugins, not standalone projectors.
- **Ruffle:** `templates/ruffle.html:11` loads `https://unpkg.com/@ruffle-rs/ruffle/ruffle.js` with no version pinned, then calls `window.RufflePlayer.newest()` (`templates/ruffle.html:94`). Ruffle is not included in the repo, so this mode needs internet access, and a new Ruffle release can change behaviour without warning. Whether the game works fully in Ruffle has not been tested.

The page passes these to the client: `spdebug=notnull`, `forceSyncError=1`, `debugResources=1`, and a hardcoded `user_key=123456789` (`templates/play.html:94-113`, `templates/ruffle.html`).

## 4. The Flash client

Measured from `assets/flash/SocialEmpires1.4.07sec_fixed.swf`, the newest client, using a small SWF and ABC parser. Decompilation was not done.

- ActionScript 3, SWF version 10, 4.3 MB compressed and 6.2 MB uncompressed.
- 2.7 MB of AS3 bytecode: about 1,950 classes and about 17,000 methods.
- Most names are readable. Main packages: `core.isoengine` (isometric engine, units, delegates), `core.attacks` (damage, special attacks), `core.magic`, `battle`, `quest`, `managers` and `managers.goals`, `popups`, `GUI`, `com.socialpoint.astar` (pathfinding), `com.socialpoint.statemachine`.
- Partly obfuscated: about 1,500 of 24,000 strings in the constant pool are generated names such as `_-DZ`. The "sec" suffix on the client file names probably refers to this protection pass.
- Third-party libraries: GreenSock (tweening), Caurina Tweener, `com.hurlant.crypto`, `com.adobe.serialization` (JSON), Flash CS UI components.
- The client talks to the server through `URLLoader` (HTTP) and `ExternalInterface`. No raw sockets were found.
- Building sprites are mainly vector shapes (`DefineShape`) and timeline animations (`DefineSprite`), with many embedded JPEG bitmaps (`DefineBitsJPEG3`).

The game simulation (isometric map, pathfinding, battles, unit AI, magic) runs in the client. The server stores state and applies the commands the client sends. This matters for any port. See `docs/NATIVE_PORT.md`.

## 5. Compared with the original game

Implemented (about 125 command names in `command.py` and `op.py`):

- Building, moving and selling; production and queues; upgrades.
- Quests and goals.
- Soul Mixer (`buy_powerups`), unit packs.
- PvP: enemy search, attacks, shields, resource stealing (`sessions.py:357-503`), honor ranking page (`server.py:393`, `sessions.py:715`).
- Neighbours and assists, gifts, graveyard.
- Shop and premium currency purchases (`shop_rotation.json`), daily bonus.
- Dragon and monster nests, rider, Hellforge, survival mode, darts.

Missing or stubbed:

- Tournaments, `register_found_item`, `get_continent`, `get_user_world` and `report_error` return 404 through `_api_not_implemented` (`server.py:~721-785`).
- `get_continent_ranking` returns fixed data and is marked "TODO - stub" (`server.py:~703`).
- `sell_iphone_item` and `buy_warehouse_capacity` map to `NOT_IMPLEMENTED` (`command.py:74`, `command.py:78`). Unknown commands do the same (`command.py:238`).

Cannot work as in the original:

- Facebook: the access token is a placeholder, and feed posts and messages are only logged (`templates/js/external_interface.js`).
- Multiplayer: PvP opponents are other save files on the same machine. There is no shared online world.

## 6. Code health

- Tests: none. CI: none (no `.github/`). Lint configuration: none.
- Nine broad `except:` or `except Exception:` clauses, for example `avatars.py:34`, `engine.py:270`, `engine.py:934` and `get_player_info.py:95`.
- 10 TODO or FIXME comments in Python files, including `save_session` and `save_session_path` (`sessions.py:845-861`).
- Logging goes to stdout through a custom logger. It is written to a file only when `write_logs` is set in `server_config.json`. Flask and werkzeug logging is turned off.
- About 1.3 GB of assets and 41 MB of Flash Player installers are committed to git.
- The two build scripts disagree on `--paths` and version names.

## 7. Bugs

1. **Player-name check crashes.** `check_player_name` returns `redirect("/")` when the name is shorter than 3 or longer than 16 characters (`sessions.py:327-328`). The caller then reads `result["ok"]` (`server.py:128-129`), which raises an error and returns HTTP 500.
2. **Cached asset downloads are never served.** `static_assets_loader` passes `"{ASSETS_DIR}/../download_assets/assets"` without the `f` prefix to `send_from_directory` (`server.py:268`, `server.py:272`). The path is used literally and does not exist.
3. **Saves can be corrupted.** `save_session` writes directly over the save file (`sessions.py:857`). A crash or power loss during the write leaves a truncated file.
4. **Save location.** `BASE_DIR = "."` puts saves in the current working directory. That differs from the "next to server EXE" comment in `bundle.py`, so the packaged build stores saves in different places depending on how it is started.

## 8. Security

These matter only if the server is reachable by other people. With the default `127.0.0.1` binding they do not apply.

1. **Hardcoded secret key:** `app.secret_key = 'SECRET_KEY'` (`server.py:796`). Anyone can forge session cookies.
2. **No authentication:** `user_key` is read by the routes (`server.py:282`, `322`, `336`, `368`, `534`) but never checked. `command.php` trusts the `USERID` sent by the client, so any client can read or change any save.
3. **Bind address:** setting `ip` to `0.0.0.0` in `server_config.json` exposes all of the above to the network.
4. **Asset download path:** `static_assets_loader` (`server.py:~245-280`) builds a local file path from the request path and downloads from `static.socialpointgames.com` at runtime. The request path should be normalised and kept inside the download directory.
5. **Debug options:** the client receives debug flags and a fixed `user_key` (section 3).

No use of `eval`, `exec`, `pickle` or `subprocess` was found. `os.system` is used only on Windows to set the console title and colour.

## 9. Recommended next steps

1. Fix bugs 1 and 2. Both are small changes.
2. Pin a Ruffle version or include it in the repo, then test the game in Ruffle and record what breaks.
3. Pin dependency versions in `requirements.txt` and state the supported Python version.
4. Make save writes atomic: write to a temporary file, then rename it over the old one. Set `BASE_DIR` to the executable's directory in packaged builds.
5. Add a smoke test using Flask's test client (log in, load `/play`, send one command, save and reload). The project does not use CI, so run it locally.
6. Before any public hosting: read the secret key from configuration, check `user_key`, and remove the debug flags.
7. Move the Flash Player installers and the asset set out of git history, into release downloads or Git LFS.
