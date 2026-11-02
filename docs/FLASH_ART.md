# Flash art in the Godot port: failures and differences

The port draws the art of the SWF files while it runs, with the Rust extension `godot/flash_art` (see "Graphics" in `godot/README.md`). This file records what does not work yet and where the pictures differ from other renderers, so that we can work on each item.

The measurements come from the default import of this repository (1516 graphics). The reference for the pictures was JPEXS, the tool of the earlier imports. JPEXS is not Flash Player. For the items marked "reference needed", the planned comparison with Ruffle (`docs/NATIVE_PORT.md`, step 2.3) must decide which picture is correct.

## How to measure

- `cargo build --release --no-default-features --examples --manifest-path godot/flash_art/Cargo.toml` builds three tools in `godot/flash_art/target/release/examples/`:
  - `render <file.swf> <symbol or id> <out dir> [frame]` writes the frames to PNG files and prints the canvas.
  - `dump <file.swf> <symbol or id> [frame]` prints the display list of a frame: depths, matrices, color transforms, blend modes and the filters that change the picture.
  - `layout <file.swf> <symbol> ...` prints the bounds, shot points and clips of the frames as JSON.
- JPEXS exports frames for a comparison: `java -jar ffdec-cli.jar -selectclass <symbol> -format sprite:png -export sprite <out dir> <file.swf>`.
- The counts of features below come from a scan of all files in `assets/buildingsprites/` and `assets/fx/`. A "placement" is one PlaceObject tag; one animation has many.

## 1. Import failures

The import reports 3 graphics that it cannot import. All three are faults in the original files. The original client cannot show them either.

| Item | Graphic | Fault |
|---|---|---|
| 1315 Necro Deco 4 (building, not in the store) | `1315_necro_deco_4` | `assets/buildingsprites/1315_necro_deco_4.swf` does not exist. |
| 1410 Bahamut Heart (building, not in the store) | `1410_bahamut_heart` | `assets/buildingsprites/1410_bahamut_heart.swf` is empty (0 bytes). |
| 2213 Neon Epic Dragon Rider (unit, not in the store) | `2213_neonEpicDragonRider` | The file exports its main sprite (id 448) with the class name `2211_neonEpicDragon`, the name of another unit. No sprite has the name `2213_neonEpicDragonRider`. |

To do:

- Find these graphics in another copy of the game files, for example an archive of the CDN files. The owner of this fork has no other copy now; this item stays open until a copy is found.
- For 2213: read in the decompiled client what it does when a class is missing. If the client shows a placeholder, the port can show the same. A name alias in the importer (graphic 2213 uses sprite 448) is possible, but only when we know that sprite 448 is the art of the rider and not of the dragon.

## 2. Frame data that changed

The extension now reads the bounds, the shot points and the clips of the frames; before, the Python importer read them. For 1511 of 1513 graphics the values are the same. Two effects differ: `fx/p.steamRay` and `fx/dead.teeth`.

Cause: a frame replaces the character at a depth (PlaceObject with the flags Move and HasCharacter) and gives no new matrix. The Python code reset the matrix to the identity. The extension keeps the old matrix, as the SWF specification and Ruffle do. This changes the bounds of these frames, for example frame 1 of `p.steamRay`: x from -478.25 to -23.13.

To do (reference needed): play both effects in Ruffle and compare their positions.

## 3. Differences from JPEXS

| Difference | Where it shows | Size | Cause |
|---|---|---|---|
| 3.1 Bitmaps on whole pixels | Units whose frames are one bitmap, for example `2006_elf_archer` | In one frame of the archer, 20.7 % of the drawn pixels differ by more than 24 of 255; 9.2 % for all frames | A bitmap that is not scaled or turned is put on whole pixels, rounded to the nearest pixel, and is not resampled. JPEXS resamples it at half pixels, so it is softer. |
| 3.2 Edges of turned bitmaps | `1236_molino` (the turned sails) | 6.9 % of the drawn pixels in frame 1 | The two programs sample turned bitmaps in different ways (tiny-skia bilinear against Java 2D). |
| 3.3 Softness of glows and blurs | `2093_elemental_heaven_god` (the glow of the lightning), most units with glows | 6.5 % mean over 40 frames | The blur is a box blur with `passes` steps of the size of the filter. The exact blur of Flash is not known. Ruffle uses other sizes for each step (`PASS_SCALES` in the `swf` crate). |
| 3.4 Blend modes mix only with the graphic | Overlay in 11486 placements, multiply in 4031, hard light in 885, screen in 48, lighten in 30, darken in 4; 441 files set a blend mode | Not measured on the map | A blend mode mixes the part with what the graphic drew under it. In Flash it also mixes with the map behind the graphic. The JPEXS frames had the same limit. |
| 3.5 Canvas without the extra space of JPEXS | `1209_portal`, `2023_frostfire_bahamut`, `2093_elemental_heaven_god` | JPEXS images are 10 to 54 pixels larger | JPEXS adds empty space around some symbols. The importer did not know about this space, so the old port showed these graphics 5 to 27 pixels too far to the right and down. The new canvas has the space of the filters only, and the position is correct. No action is necessary; this is recorded because the old screenshots differ. |

To do:

- 3.1 to 3.3 (reference needed): compare the same frames with Ruffle, then change the renderer where it differs from Ruffle. For 3.3, the parameters are in `godot/flash_art/src/filters.rs` (`box_blur`, `margin`).
- 3.4: draw the parts with a blend mode as separate nodes in Godot, with a shader that reads the map behind them, or draw the graphic with the map behind it. This changes the structure of `ClipSprite`, because a frame is no longer one image.

## 4. Features that the renderer does not have

These features are not in the art of the game, or the effect is small. Each one is checked by the scan or by the code.

| Feature | In the art | State |
|---|---|---|
| Blend modes subtract and invert | 0 placements | Drawn as normal. |
| Convolution filter, gradient bevel filter | 0 placements | Ignored. |
| GIF images in DefineBitsJPEG2 | 0 | Ignored. |
| Gradients with linear RGB interpolation | Not counted | Interpolated in sRGB. |
| Strokes that do not scale (LineStyle2 flags) | Not counted | Only the case "no scale in x and y" is handled. |
| Bevel filter | 503 filters in 4 files (the cerberus and devil dragons) | Drawn by a simple method: the light and shadow come from the blurred alpha, moved by the distance. Not compared with any other renderer. |
| Gradient glow filter | 369 filters in 3 files (`2117_priest_glad`, `2129_hell_dragon`, `2131_hell_rider`) | Drawn as a glow whose color comes from the gradient. Not compared. |
| Masks | 736 placements | Masks have soft edges (antialiased). Flash Player and Ruffle may use hard edges. Reference needed. |
| Filters on scaled parts | Many | Filter sizes are in pixels and do not change when the part is scaled. Not compared with Flash Player or Ruffle. |
| Kerning of fonts | The fonts of the windows | The TrueType fonts have no kerning table, as the JPEXS fonts had none. |

## 5. Rules that are estimated

- **Nested animations after their parent loops.** Every sprite plays on from the frame in which it was placed. After the parent goes back to its first frame, the extension assumes that the parts of the first frame stay and play on, and that the other parts were removed and placed again (`child_age` in `render.rs`). Flash keeps a part only when it is on the display list without a break. A part that stays on the list through the loop, but was placed after frame 1, gets a wrong age.
- **Frame scripts.** The extension does not run ActionScript. A `stop()` or `gotoAndPlay()` in a nested animation has no effect; the animation loops. The spells use the frame labels and the rules in `spells.json` instead.

## 6. Performance and memory

- **First display.** A frame is drawn when the game first shows it. One frame of a large unit takes 17 ms (`2000_bahamut`) to 118 ms (`2093_elemental_heaven_god`) on one core. When an animation starts, 3 threads draw its frames ahead. The first loop of a large unit can still wait for frames.
- **No limit on memory.** The port keeps every frame that it drew until the graphic is no longer used. Frames that the threads drew ahead, but that the game never showed, stay in the cache of the extension. A long session with many large units can use much memory. A limit with the least recently used frames is a possible fix.
- **Zoom.** The frames are drawn at the size of Flash. When the camera zooms in, Godot enlarges the image, and the art becomes soft. The extension can draw at another scale (`Art::render` has a `scale` argument), but the port does not use it yet.

## 7. Platforms

- Linux: built and tested.
- Windows: the cross build (`--target x86_64-pc-windows-gnu`) compiles and links. The port was not run on Windows.
- macOS: not built and not run.
- `godot/flash_art.gdextension` names the library paths for the three platforms. An exported game must contain the library; the export settings are not done.
