# Flash art in the Godot port: failures and differences

The port draws the art of the SWF files while it runs, with the Rust extension `godot/flash_art` (see "Graphics" in `godot/README.md`). This file records what does not work yet and where the pictures differ from other renderers, so that we can work on each item.

The measurements come from the default import of this repository (1516 graphics). The reference for the pictures is Ruffle at commit `89a7049` (the 0.7.1 build in `templates/js/ruffle/`). Ruffle is not Flash Player either; section 3 names the places where we kept a rule of Flash Player instead.

## How to measure

- `cargo build --release --no-default-features --examples --manifest-path godot/flash_art/Cargo.toml` builds these tools in `godot/flash_art/target/release/examples/`:
  - `render <file.swf> <symbol or id> <out dir> [frame | -count]` writes frames to PNG files and prints the canvas. `-count` draws the first frames, also after a loop.
  - `dump <file.swf> <symbol or id> [frame]` prints the display list of a frame: depths, matrices, color transforms, blend modes and the filters that change the picture.
  - `layout <file.swf> <symbol> ...` prints the bounds, shot points and clips of the frames as JSON.
  - `stage <file.swf> <symbol or id> <out.swf> <background RRGGBB> [frames]` writes a SWF file that shows the symbol on a stage of the size of its canvas, so that another player draws the same frames as `render`.
  - `compare <ours dir> <black dir> <white dir> [diff dir]` compares the frames of `render` with the frames that another player drew of two `stage` files, one on black and one on white. It prints, for each frame, the percent of the drawn pixels in which a premultiplied channel differs by more than 24 of 255, and the mean difference. The diff images show our frame, the other frame and the difference (red: more than 24).
  - `ground_compare <file.swf> <symbol or id> <other dir> <ground RRGGBB> [old]` mixes the map frames of the symbol with a ground of one colour, as the shader of the game does (3.11), and compares them with the frames that another player drew of a `stage` file of that colour, numbered from 1. With `old` it uses the frame of `render`, which mixes the blend modes only with the graphic.
- The Ruffle exporter draws the frames of a SWF file without a browser. Build it from the Ruffle source at the commit above: `cargo build --release -p exporter`. It needs a Vulkan driver; on a machine without a GPU, the Mesa software driver works (`mesa-vulkan-drivers`, then `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`).
- One comparison:
  1. `stage art.swf sym b.swf 000000` and `stage art.swf sym w.swf ffffff`
  2. `exporter -g vulkan --frames N b.swf black` and the same for `w.swf`
  3. `render art.swf sym ours`
  4. `compare ours black white diff`
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
- When a graphic is missing, the client keeps the placeholder that it shows while a graphic loads (`IsoElement.setProvisionalGrahic`): `LoadingUnit` for a unit, `Loading1x1` to `Loading4x4` for a building. The port now does the same for these three items (`SpriteLibrary.get_item_sprite`). A name alias in the importer (graphic 2213 uses sprite 448) is possible, but only when we know that sprite 448 is the art of the rider and not of the dragon.

## 2. Frame data that changed

The extension reads the bounds, the shot points and the clips of the frames; before, the Python importer read them. For 1511 of 1513 graphics the values are the same. Two effects differ: `fx/p.steamRay` and `fx/dead.teeth`.

Cause: a frame replaces the character at a depth (PlaceObject with the flags Move and HasCharacter) and gives no new matrix. The Python code reset the matrix to the identity. The extension keeps the old matrix, as the SWF specification and Ruffle do. This changes the bounds of these frames, for example frame 1 of `p.steamRay`: x from -478.25 to -23.13.

Ruffle confirms the new values: `p.steamRay` and `dead.teeth` draw at the same places in Ruffle and in the extension (0.0 % of the pixels differ). No action is necessary.

## 3. Comparison with Ruffle

### Result

428 graphics, 6 frames each (all 231 files of `assets/fx/` and 197 random files of `assets/buildingsprites/`, 65.7 million drawn pixels): 0.34 % of the pixels differ by more than 24 of 255.

| Pixels that differ | Graphics |
|---|---|
| less than 0.1 % | 320 |
| 0.1 to 1 % | 67 |
| 1 to 3 % | 27 |
| 3 to 10 % | 10 |
| 10 % or more | 4 |

Frames after a loop were compared too (`stage ... [frames]`, `render ... -count`): `2000_bahamut` for 50 frames, `2006_elf_archer` for 40 and `p.dragonSkull` for 20, each 0.0 %.

### Changes to the renderer

Each change made our frames equal to the frames of Ruffle. The numbers are the pixels that differ, before and after.

| Change | Example |
|---|---|
| 3.1 A smoothed bitmap is sampled bilinear at its exact place, also between two pixels. Before, a bitmap that was only moved was put on whole pixels and sampled with the nearest pixel. tiny-skia does that for every bitmap that is only moved, so the renderer adds a scale that changes no pixel. JPEXS was right here. | `2006_elf_archer`: 12.9 % to 0.0 % |
| 3.2 Shapes are drawn as with 4x multisampling (MSAA), as in Ruffle: each pixel has 4 samples at the standard positions; a shape covers a sample or not; its color comes from the center of the pixel (`samples.rs`). Before, each shape had antialiased edges of its own, and two shapes that touch left thin gaps between them. Edges now have 5 steps of alpha, as in Ruffle. Masks cover each sample or not, as the stencil of Ruffle. Lines are at least one pixel wide. | `777_crystal_dragon`: 27.3 % to 0.6 % |
| 3.3 An object with filters, also with filters that change nothing, is drawn as one image and put back on whole pixels (as cacheAsBitmap). The top-left corner of its bounds moves to the nearest pixel. Ruffle computes these bounds in whole twips with a rounding at each matrix product, and rounds the corner of the image with the space of the filters; the extension does the same (`snap.rs`). Nested objects with filters snap in the coordinates of the image of their parent. Its color transform applies to the whole image. | `2000_bahamut` 2.2 % to 0.0 %; `p.axeSkeleton` 22.7 % to 0.7 % |
| 3.4 Glow and drop shadow: the factor "behind the object" applied twice; the flag "composite source" was not used; an inner glow blurred the inverted alpha. Now as in the glow shader of Ruffle. The bevel mixes the light, the shadow and the object as the bevel shader of Ruffle. Each blur step rounds down to 1/255, as in Ruffle and Flash Player. The light and shadow of the bevel were already the same. | `p.dragonSkull` 63.2 % to 0.0 %; `p.wraithBeam` 5.1 % to 0.1 % |
| 3.5 Morph shapes: when only one of the two shapes moves its pen, the other shape keeps its pen. Before, it took the pen of the first shape, which moved the edges. Colors, ratios and matrices are interpolated with the rounding of Ruffle. | `t.blueEnergy` 25.6 % to 0.1 % |
| 3.6 After its parent loops, a nested sprite of the first frame plays on only if the last frame of the parent also has it. Else it starts again (see section 5). | `2006_elf_archer` after the loop: 1.1 % to 0.0 % |
| 3.7 The canvas starts on a whole twip, so that a SWF file can place a frame exactly on its grid. The change in position is less than 0.05 pixels. | |

These rules were already the same as in Ruffle: the sizes of filters are in pixels of the stage and do not change with the scale of the object; the matrix of a replaced character stays (section 2); the bevel, gradient glow and color matrix filters of the cerberus and devil dragons and of `2117_priest_glad` and `2131_hell_rider` (0.0 %).

### Differences that remain

| Difference | Where | Cause |
|---|---|---|
| 3.8 Blend modes over the empty canvas | Overlay and multiply in `p.fireballBahamut` (44 %), `p.catapultFireball`, `p.largeFireball`, `p.hugeFire`, `2341_thunderForgeDragonRider` | Ruffle mixes these parts with the stage behind the graphic, here black or white, so the comparison of `render` cannot measure them. In the game they mix with the map (3.11), and a comparison on a stage of the colour of the ground measures them. |
| 3.9 Blend mode "layer" with alpha | The shadow of `2367_devilAncientDraggy` (7.6 %) | Ruffle applies the alpha of the object to each of its parts; two overlapping parts become darker. The documentation of Flash says that "layer" makes a transparency group, so the alpha applies to the group. The artist used exactly this: two overlapping fills with "layer" and alpha 0.3. The extension keeps the rule of Flash. |
| 3.10 Thin lines | Small shots, for example `p.ulisesArrow` (5.6 % of 305 pixels) | Single pixels along lines of about one pixel differ. Ruffle tessellates lines; the extension strokes them. |

Fixed:

- 3.11 Blend modes with the map. A part with the blend mode multiply, screen, lighten, darken, difference, add, overlay or hard light mixes with everything below it, in the game also with the map, unless a parent of the part is drawn as one image (with filters or a blend mode). Before, these parts mixed only with the graphic. A scan of the imported graphics found such parts that reach the map in 192 graphics (182 items, mostly dragons and colossi, and 10 shots and effects).

  `Art::render_layers()` draws a frame of the map as a normal image and one layer for each such blend mode. Where the graphic is below a part, the part mixes with the graphic in the normal image (as "source atop": it adds no pixels). The part also goes to the layer of its mode. In Godot the shader `sprites/blend_layers.gdshader` mixes the layers with the screen behind the node, then draws the normal image over them; `FrameMaterial` puts the shader and a `BackBufferCopy` of the screen on the node. The normal image covers the layers by its alpha, so a part mixes with the map only where the map shows through the graphic. `FlashArt.render()` gives such a frame as one image with the layers one below the other, the normal image first; a node without the shader shows only the normal image.

  This is exact where the graphic covers a pixel fully or not at all, and for the modes that are linear in the backdrop (multiply, screen). Where the graphic is half transparent below an overlay or hard light part, the part mixes with the graphic and with the map each by itself, by the alpha of the graphic, not with the mix of the two. Parts of one mode that overlap over the map are one layer; parts of different modes mix with the map in the order of their modes, not of their depths. The first form of this change, with a layer for each run of parts, had up to 38 layers in a frame and 5 times the memory; this form has at most one layer for each mode (at most 4 layers in the scanned graphics) and up to 2.8 times the memory of the frame (`2209_redHotEpicDraggy`, 2.8 layers on average).

  Comparison with Ruffle on a stage of the colour of the ground (`stage ... 608c3c` for grass, `d2be8c` for sand), pixels that differ by more than 24, the new frames against the frames before the change:

  | Graphic | Grass | Sand |
  |---|---|---|
  | `p.fireballBahamut` | 0.0 % (before 24.2 %) | 17.4 % (before 14.2 %) |
  | `p.hugeFire` | 0.0 % (before 0.0 %) | |
  | `p.catapultFireball` | 0.1 % (before 0.1 %) | 1.4 % (before 1.3 %) |
  | attack clip of `2272_demonDragon` (sprite 198) | 0.1 % (before 0.3 %) | 0.1 % (before 0.1 %) |
  | attack clip of `2209_redHotEpicDraggy` (sprite 339) | 0.0 % (before 0.0 %) | 0.0 % (before 0.0 %) |
  | `833_dragon_jinete`, `875_bahamut`, `2209_redHotEpicDraggy` | 0.0 to 1.2 %, the same as before | 0.0 to 1.3 %, the same as before |

  On sand the fireball is worse than before: its glow is half transparent, and below it overlay is not linear. The largest difference is 44 levels, against 34 before. On grass the old frames were wrong in a large area (the cream parts were drawn as plain colour).

  The same fireball in Godot (OpenGL 3, llvmpipe), on the screen over a ground of one colour, against Ruffle: 1.3 % of the pixels differ by more than 24 on grass and 7.4 % on sand.

- 3.12 Dark edges where Godot filters a frame. On troll island 1 a gray line crossed the sand between two land pieces. The client in Ruffle also shows a line there, but a light one: the edge of the land piece in the art is lighter than the sand. In the port the line was about 30 levels darker than the sand. The cause: the images of the frames had black in their transparent pixels. Godot filters a frame where it draws it between pixels (the land pieces are at x.35 and y.5) or at another size, and mixed this black into the edge pixels. Now a transparent pixel next to a visible one gets the color of that neighbour (`bleed_edges` in `src/godot_api.rs`, as the "fix alpha border" of Godot's import of image files). This changes the edges of all graphics a little; in a screenshot of a village at 1280 × 800, 897 pixels changed by more than 10 levels. The pass takes about 7 ms for a land frame of 2205 × 1095 pixels at scale 1.

- 3.13 Filters of clips. The game draws the clip of a frame (`FrameClip`, for example the walk of a unit or the flight of a shot) by itself and scales it by the matrix of the frame. The sizes of filters are in pixels of the stage, so a clip that its frame shows at half size has filters of half the size in its own pixels. Before, the extension drew the clip with the filters at the size of its own pixels, so for example the blur of `p.fireballBahamut` (shown at 0.5) was half as wide as in Ruffle. Now `SpriteLibrary` tells the extension the scale of each clip (`FlashArt.set_parent_scale`).

The pictures of JPEXS, the tool of the earlier imports, are no longer a reference. JPEXS adds empty space around some symbols; the old import did not know about it, so the old port showed `1209_portal`, `2023_frostfire_bahamut` and `2093_elemental_heaven_god` 5 to 27 pixels too far to the right and down. Old screenshots differ for this reason.

## 4. Features that the renderer does not have

These features are not in the art of the game, or the effect is small. Each one is checked by the scan or by the code.

| Feature | In the art | State |
|---|---|---|
| Blend modes subtract and invert | 0 placements | Drawn as normal. |
| Convolution filter, gradient bevel filter | 0 placements | Ignored. |
| GIF images in DefineBitsJPEG2 | 0 | Ignored. |
| Gradients with linear RGB interpolation | Not counted | Interpolated in sRGB. |
| Strokes that do not scale (LineStyle2 flags) | Not counted | Only the case "no scale in x and y" is handled. |
| Gradient glow filter | 369 filters in 3 files (`2117_priest_glad`, `2129_hell_dragon`, `2131_hell_rider`) | Drawn as a glow whose color comes from the gradient. The Ruffle renderer (wgpu) does not draw this filter, so it cannot be a reference here; the frames that were compared agree. |
| Kerning of fonts | The fonts of the windows | The TrueType fonts have no kerning table, as the JPEXS fonts had none. |

## 5. Rules that are estimated

- **Frame scripts.** The extension does not run ActionScript. A `stop()` or `gotoAndPlay()` in a nested animation has no effect; the animation loops. The spells use the frame labels and the rules in `spells.json` instead.

The rule for nested animations after their parent loops is no longer estimated: a character of the first frame keeps playing only if the last frame also has it at the same depth (`Placed::stays`). This is the rule of Ruffle, and the comparison after loops agrees. The game asks for frames 0 to count - 1 only, so this rule changes nothing in the game today.

## 6. Performance and memory

- **First display.** A frame is drawn when the game first shows it. The 4 samples of each pixel (3.2) make the drawing 1.6 to 2.1 times slower than before. On one core of the test machine, one frame takes 5 ms (`2006_elf_archer`, before 2.6 ms), 97 ms (`2000_bahamut`, before 46 ms) and 312 ms (`2093_elemental_heaven_god`, before 195 ms). When an animation starts, 3 threads draw its frames ahead. The first loop of a large unit can still wait for frames. A possible improvement: use the 4 samples only at the edges of shapes.
- **Memory limit.** `FrameCache` (`godot/sprites/frame_cache.gd`) keeps the drawn frames of the map and of the windows. All frames together use at most `FrameCache.limit` bytes (512 MB). When a new frame needs more, the cache removes the frames that were used least recently. A frame that a node shows is in use: the cache does not remove it, and it counts as used now. A removed frame is drawn again when the game asks for it. The frames that the threads draw ahead stay in the extension until the game takes them. They have a separate limit of 128 MB for all graphics together (`AHEAD_LIMIT` in `godot_api.rs`); above it, the frames drawn first are removed.
- **Zoom.** The frames of the map are drawn at the zoom of the camera times the interface size of the window (`UiScale`), rounded up to a step of 0.5 from 1 to 6 (`FrameCache.scale_for`); below 1 the frames stay at scale 1. When the scale changes, the 3 threads draw the frames that nodes show again, and each node changes to the new image when it is ready. Until then the node shows the old image, enlarged. The other frames are drawn again when the game next asks for them. The windows do not zoom; their frames are drawn at the interface size, and again when it changes. The snapping of 3.3 uses the pixels of Flash at every scale.
- **Cost of the zoom.** A frame at scale 2 has 4 times the pixels of a frame at scale 1, and its first drawing takes about 4 times longer. In the first 600 drawn frames of troll island 1, with the village and the army of the comparison in `docs/GODOT_BATTLES.md`, the frames used 93 MB at zoom 1 and 376 MB at zoom 1.8. The longest wait for one frame was 125 ms at zoom 1 and 712 ms at zoom 1.8 (test machine, 4 cores, software OpenGL). At the change from zoom 1 to zoom 2 in the start village, the threads drew the shown frames again in 1.3 s.

## 7. Platforms

- Linux: built and tested.
- Windows: the cross build (`--target x86_64-pc-windows-gnu`) compiles and links. The port was not run on Windows.
- macOS: not built and not run.
- `godot/flash_art.gdextension` names the library paths for the three platforms. An exported game must contain the library; the export settings are not done.
