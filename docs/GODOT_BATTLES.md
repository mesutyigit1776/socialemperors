# Battles in the Godot port: plan

Status: stages 1 to 6 done. Branch `godot-port`.

## How the original game does battles

The Flash client simulates all battles. The server only stores the results that the client sends:

| Command | What the server does |
|---|---|
| `start_quest_new` | Adds the start time to `lastQuestTimes` of the map. |
| `end_quest` | Adds gold and experience, sets the quest rank and the next unlocked quest, adds honour points, and moves the lost units to the graveyard (`handle_unit_loss`). |
| `set_attack_team` | Stores a team of units for quests and tournaments. |
| `begin_attack_new`, `end_attack_new` | PvP: adds the resources and experience of an attack on another player. |
| `kill` | Removes an item of the own map that died. |

So the port must simulate battles itself and then write the same results. The server does not check the result, so the simulation does not have to give the same numbers as the client. It must follow the same rules.

The client has these game modes: normal (own village), neighbour visit, assault (PvP), campaign (quests), survival, tournament and spy.

### Size of the client code

| Part | Files | Lines |
|---|---|---|
| Unit class (`IsoUnit`) and fighting element (`IsoFightingElement`) | 2 | 6,000 |
| Unit AI and group AI (`battle/`) | 19 | 5,700 |
| Projectiles and beams | 16 | 1,400 |
| Special abilities of units (`delegates/`) | 445 | 39,500 |
| Quests (`quest/`) | 69 | 19,600 |

Most of the volume is in the special abilities and the quest scripts. The core rules are small.

### Core rules (from the client)

- Stats come from the configuration: `life`, `attack`, `defense`, `attack_range` (tiles), `attack_interval` (frames), `velocity`, `flying`, `protect`. Towers and some buildings also attack.
- The simulation runs in frames at 30 frames per second. A unit attacks when the frame counter is a multiple of its `attack_interval`.
- Damage: the attack plus a random value from -4 to +4. In 10% of attacks the damage is a critical hit: (attack + |random|) × 1.5. A magic shield takes a part of it. The defence is then subtracted. The damage is at least 1.
- Buffs, domes and some units change the attack or the damage (for example × 1.5 near a god colossus).
- The AI has states (idle, hold position, patrol, forced move, attacked, attacking) and conditions (defensive, aggressive, passive, survive). Units find targets, walk to them, and help allies that are attacked. Healers heal.
- Ranged units shoot projectiles that fly to the target. The damage comes when the projectile arrives.
- A dead unit of the player goes to the graveyard, or to the Heroes Grave for a hero. Villagers, summoned units and animals do not.

### Data that the port has or needs

- The 36 quest maps are village saves in `villages/quests/`. The importer copies them to `<data>/quests/`. Two of them (`100000053`, `100000054`) store the level as text; the loader reads it as a number, as the client does.
- Each frame of a unit graphic is one action in one direction: frame = action × 5 + direction. The actions are idle, walking, attacking, dying, harvesting, repairing, and from 6 the special attacks. Each frame contains a nested clip that plays the animation; the importer exports these clips (stage 2).
- The client starts a shot at a named point of the graphic of the shooter, else at 0.6 or 0.75 of its height, and aims at a part of the height of the target (`BattleGraphic`). The importer reads the bounds of each frame and the named points.
- Projectiles and effects are in 231 files in `assets/fx/`, one symbol in each, with the name of the file. The importer exports all of them; `BattleProjectile` names the graphic of each shooter, as the client does.
- The quest goals and scripted events are in the client quest classes, not in the data. Each class also keeps the start tile of the army, the land of the island and the units of the map that join the player (`QuestIsland`).

## Design

- The port is a one-to-one port: battles, unit control and the game modes work as in the original game.
- A new folder `godot/battle/` keeps the battle separate from the village save model.
- `BattleSim` is the model: it has no nodes and runs one frame at a time, so the checks can run it headless with a fixed random seed. It contains the fighters (units and attacking buildings), the projectiles, the AI and the damage rules.
- `BattleView` draws a `BattleSim` on the existing map view: animations, projectiles, health bars.
- `QuestBattle` reads a quest map, places the player's units, checks the goals and ends the battle; `QuestScreen` shows it.
- At the end, the battle writes the results through `Village.end_quest()`, which does what the server command does.
- Special abilities are added one unit at a time behind one interface, as the client does with its delegates.
- `docs/NATIVE_PORT.md`, section 4a, has the roadmap of the whole port. A comparison with the original game in Ruffle comes after stage 3.

## Stages

Each stage is a milestone with headless checks and, where it changes the save, a server replay.

1. **Battle core, headless.** Fighters from the configuration, the damage rules, frames, melee and ranged attacks, projectile travel time, towers and other attacking buildings, healers, death, and the basic AI states. Checks with a fixed seed: damage values, attack timing, target choice, who wins small fights.
2. **Battle view.** Attack and death animations, projectiles and effects (importer: `assets/fx/`), health bars, and orders to units during a battle (select, move, attack).
3. **Campaign quests.** The island list and its rules: open islands, stars, the limit of quests in a row. The army is all fighting units of the village map; teams are only for some later islands and tournaments. The map of the island, the sides, the copies of the enemies for more stars, the goals of the troll and civilisation islands, and the end: gold, experience, honour, stars and lost units, as `end_quest` writes them.
4. **Spells.** The spell book: mana, buying and using spells (`buy_magic`, `use_magic`), shields. Quests use them, so they come before the quest scripts.
5. **Quests one at a time.** For each of the other quests whose maps the server has: port the client quest class and the special abilities of the units and bosses on the map, and add the island to `QuestIsland.ISLANDS`. Each quest is then complete and playable, and the quests can be compared with the original game one at a time. The 12 islands of stage 3 also get the special abilities of their units here.
6. **Other special abilities.** The units that a player can own (store, nests, Soul Mixer, riders, collections) that no quest map has.
7. **Single-player modes.** Events such as the heavy siege on the own village, then survival and tournament, as far as they work without other players.
8. **Multiplayer, last or never.** PvP attacks and neighbour visits need other players' saves and a server. The port has no server, so this stage waits for a decision of the owner.

### Stage 1 result

`godot/battle/` has the rules of the client without graphics. `checks/battle_check.gd` checks them with fixed random seeds.

| File | Contents |
|---|---|
| `battle_sim.gd` | `BattleSim`: the items of the map, the frame loop, targets, damage, death, walking, the client's tile array and blocked tiles. Signals for hits, heals, shots and deaths. |
| `battle_fighter.gd` | `BattleFighter`: the state of one item (life, target, walk, animation). |
| `battle_ai.gd` | `BattleAI`: the conditions and states of a unit, as in the client. |
| `battle_projectile.gd` | `BattleProjectile`: the two kinds of shots of the client and which shooter uses which. |
| `battle_ability.gd`, `abilities/` | `BattleAbility`: the interface for special abilities. The healer is the first ability. |
| `village/pathfinder.gd` | `find_route()`: the A* search of the client (costs 10 and 14), which battles use. |

The rules come from the client:

- A unit checks its attack every 5 frames and attacks when the frame plus its random delay (0 to 4) is also a multiple of its attack interval. A building attacks when the frame is a multiple of its interval.
- The unit AI runs every 61 frames. Aggressive units take the enemy with the best score within 10 tiles: units first, then the town hall, then buildings that produce, then buildings that attack. Other buildings are not targets. An attacked item calls the units of its side on the 4 rings of tiles around it.
- A unit walks its velocity in pixels per frame on the longer axis and stops for 1 frame at each tile. It attacks from the free tile at its range nearest to it. A ranged unit shoots while it walks; a melee unit attacks when it stands.
- A tower keeps its target only within half its range. Arrows, rocks, axes and cannonballs move a fixed number of pixels per frame; other shots fly 1000 pixels per second, in an arc over 300 pixels or more. A shot hurts when it lands near the target.
- Siege units do half the damage to units and take 1.25 times the damage from units. Element units do 1.35 times the damage to the element that they beat.
- A dead unit stays on its tile for 4 seconds. A destroyed enemy building leaves the map.

Not in stage 1: special attacks (except the healer), spells, units in buildings, doors in walls, buildings under construction, and what a death gives or costs in each game mode. A unit whose path becomes blocked while it walks stops, as in the client; no check covers this case.

### Stage 2 result

| File | Contents |
|---|---|
| `sprites/unit_sprite.gd` | `UnitSprite`: plays the clips of a unit graphic at 30 frames per second. The village uses it too. |
| `battle_formation.gd` | `BattleFormation`: the tiles of a group order, as in the client: a square on free ground, the rings around an own item, the rings at the range around an enemy. `BattleSim.order()` uses them. |
| `battle_view.gd` | `BattleView`: draws the battle, the selection, the health bars, and the shots with their effects. |
| `battle_screen.gd` | `BattleScreen`: runs the battle at 30 frames per second and turns the mouse into orders, as in the client: click, double click (units of the same kind within 10 tiles), selection box, orders to the ground or to an enemy. `--battle <file>` starts a practice battle on a quest map. |
| `battle_graphic.gd` | `BattleGraphic`: the points of a graphic where shots start and aim, as the client measures them. |
| `sprites/clip_sprite.gd` | `ClipSprite`: plays the animation of one frame of a graphic, for units, shots and effects. |

The importer reads the quest maps, so that their items have graphics, and the graphics of the shots and effects. `BattleView` moves the shots as the client does, with the trails (smoke) and the blasts of rocks and cannonballs. The health bar and the selection mark are simple shapes; their graphics are in the main file of the client, from which the importer takes only the windows of the quests (stage 3). The shots of units with special attacks come with these units in later stages.

### Stage 3 result

`godot/quest/` has the campaign quests, and `godot/ui/` shows the windows of the client with their original graphics.

| File | Contents |
|---|---|
| `quest/quest_island.gd` | `QuestIsland`: the data of the 12 islands in the port, which the client keeps in its quest classes: the kind of quest, the gold key, the start tile, the land and the free units. Only these islands can start. |
| `quest/quest_book.gd` | `QuestBook`: the island list rules: open islands, the level of some islands, the stars, and the limit of quests in a row. |
| `quest/quest_battle.gd` | `QuestBattle`: one quest: the sides, the landing of the army, the copies of the enemies, the gold and experience, the goals, the end and the units that come back. |
| `quest/quest_screen.gd` | `QuestScreen`: the island on the screen with the start window, the battle bar and the result window. |
| `quest/quest_list_window.gd`, `quest_start_window.gd`, `quest_end_window.gd`, `quest_hud.gd` | The windows of the client for the quests. |
| `ui/ui_library.gd`, `ui/ui_clip.gd`, `ui/alert_window.gd` | The windows of the client: images without their named parts, and the parts (buttons, stars, locks, text fields with the fonts of the client) as nodes. |
| `village/village.gd` | `start_quest()`, `end_quest()`: the save changes of the server commands `start_quest`, `start_quest_new` and `end_quest`. |
| `importer/ui_import.py` | Exports the windows from the client file `SocialEmpires1.4.07sec_fixed.swf`, with their fonts, pictures and the pictures of the units. |

The rules come from the client:

- The islands open one after the other in `ISLE_ORDER`. Two islands also need level 40, and the three god islands are always open. The player chooses 1 to 3 stars, at most one more than they won on the island.
- The army lands on the free tiles nearest to the start tile of the island, unit by unit. For each star above 1, each enemy unit gets a copy on the nearest free tile; civilisation islands do not copy animals.
- Troll islands: the treasure opens when the last enemy unit is dead, and collecting it wins. Civilisation islands: the last town hall wins. The player loses when the last of their units is dead; the client counts the free units of the island too, so on the Viking island, which counts one unit that its map does not have, the player cannot lose this way.
- Each dead enemy gives its experience, up to 7500. Half of the gold of the quest goes in equal parts to the enemies that attack and do not produce; the other half comes with the win.
- After the quest, 60% of the dead units (rounded up) come back, chosen at random; the free units always come back.

Changes from the original game:

- **Quest limit.** The original game allows 3 quests in a row (4 with the Odin statue) while less than 6 hours lie between them. The owner chose 2 hours. `QuestBook.QUEST_WINDOW_SECONDS` sets the time and `QuestBook.QUEST_LIMIT_ENABLED` turns the limit off; the comment there explains both. The alert of the limit names the hours of the port.
- **Islands that the port does not have yet** show the lock of the game and a sign "Not in the port yet" in the style of the name ribbon, and cannot start. To open an island, port its quest class and add it to `QuestIsland.ISLANDS`.
- **Sharing.** After a quest the client offers to share the result on Facebook. The port shows the OK button at once, as the client does after the player skips the sharing.

Not exact yet:

- The client builds the screen for a stage 760 pixels wide. The port keeps the battle bar at the top centre and the Withdraw button at the bottom right. The client draws the counter of the enemies in its code, and its place on the screen is not clear from the code; the port shows it at the top right.
- In the scripted test, an army of 70 units lost on the Viking island; a win on a civilisation island is checked only headless. The special abilities of the units and the doors of walls came in stage 5.

Also in this stage: the client puts the registration point of a building graphic half the width of the frame left of the position and the height of the frame above it. Stage 2 also moved it by the top-left corner of the frame, which put the shots of such buildings in the wrong place; `BattleGraphic` now follows the client. The land of a quest island keeps the place of the first frame of the land graphic for all frames, as the client does, so that the coasts meet.

### Stage 4 progress

Stage 4 has five steps: 4a the spell rules of the save, 4b the states that spells give, 4c the 15 spells, 4d the spell book and the other windows with the original art, and 4e the checks by hand and the documents. All five steps are done.

| File | Contents |
|---|---|
| `game_data/game_config.gd` | `SpellDef` and the spells of the configuration ("magics"), the mana prices and the casts for spell levels 2 and 3. |
| `village/village.gd` | `spell_uses()`, `buy_mana()`, `buy_spell()`, `use_spell()`: the save changes of `buy_mana_new`, `buy_magic` and `use_magic`. |
| `battle/battle_sim.gd` | Timers in frames, `items_near()`, and the states: `stun()`, `freeze()`, `poison()`, `enlarge()`, `swallow()`, `summon()`, shields. |
| `quest/quest_battle.gd` | Summoned units do not count in a quest. |
| `battle/spells/` | `BattleSpell` and one class for each spell, with the numbers of the client. A battle makes its own spells with `BattleSpell.create()`. |
| `importer/import_assets.py`, `importer/swf_bounds.py` | `spells.json`: the frame with the label "attack" in the graphic of each spell, at which the spell acts. |
| `checks/spell_check.gd` | Checks of the spell rules of the save and of each spell in a battle. |

The rules come from the client:

- 5 mana cost 20000 gold or 1 cash. A spell costs gold or cash once and gives the mana of one cast. The server does not check the level of a spell; the client offers it only from that level, so the port checks the level. A cast costs mana and counts. The client counts the cast before it reads the level, so the 25th cast already has level 2 and the 50th level 3.
- A stunned unit cannot walk or attack for 2.5 seconds and then drops its target. Bosses, enlarged units and units with a population of 4 or more are not stunned. A frozen unit stops at once. The client keeps one state for both, so the end of one also ends the other.
- Poison hurts every 3 seconds and can pass to the nearest units within 1 tile, with one tick less. The poisoned unit counts in the number of units that it can poison, so it passes the poison to one unit less than the number. A unit that gets the poison with no ticks left stays poisoned until it dies, because the timer of the client then does not stop. Two units next to each other pass the poison back and forth until this happens.
- An enlarged unit does 1.5 times its damage. A shield lets only its factor of the damage through to all items on its tiles, also to enemies; the first shield counts, and shields do not add up.
- A swallowed unit or building dies after 0.5 seconds, without a killer. Units with 500 life or more cannot be swallowed.
- Summoned units do not count in a quest: they give no gold or experience, are not in the result, and do not keep the player in the quest.

The port counts the timers of the client in frames at 30 frames per second.

The spells (4c) follow their classes in the client. The player casts on a tile, the corner of the marked square with the largest x and y. Each effect waits for its delay and then for the frame of its graphic with the label "attack" (10 frames without a label).

| Spell | What it does in the client |
|---|---|
| Fire Havoc | 30 fireballs, one every 3 frames, of 150, 200 or 250 damage. Every third ball falls on an enemy unit within 2 tiles of the middle of the area, the others on random tiles. The client drops half tiles, so the area of the balls lies 3 tiles left and up of the marked square. |
| Ultimate Hail | A stone on each tile of a square one tile wider than the marked one, within 100 frames: 800, 1000 or 1500 damage to enemy buildings for each of their tiles, a tenth of it and a stun to enemy units. Town halls, treasures and activators take nothing. |
| Deadly Frostbite | Ice on each tile of the same square within 60 frames: freezes enemy units for 15, 20 or 30 seconds, without damage. Bosses do not freeze. |
| Sacred Rain | Rain on each tile of the same square within 30 frames heals the unit of the player on it by 100 life, and at levels 2 and 3 by 20 life each second for 5 or 10 seconds. In the client it heals nobody; the port corrects this, see below. |
| Golem's Wrath, Yeti's Trail | A golem or a yeti with 4000, 5000 or 7000 life on the free tile nearest to the tile, within 4 rings. |
| Summon Dragon | One of 5 Bahamut dragons, the same way. It leaves after 30 or 60 seconds at levels 1 and 2, and stays at level 3. |
| Hell Abyss | Swallows the enemy units and buildings within 3, 4 or 5 tiles of the middle of the square, except bosses, town halls, treasures, activators and units with 500 life or more. |
| Poisonous Flood | Poisons the enemy units within 5, 7 or 9 tiles of the tile, except bosses: 15, 20 or 25 damage, 5, 7 or 10 times. |
| Ether Shield | A shield for 20, 30 or 40 seconds that lets 70, 55 or 40 percent of the damage through. See below for its errors. |
| Age of Colossus | The units of the player within 5, 7 or 9 tiles of the tile get bigger for 30, 45 or 60 seconds. |
| 2x Speed, 2x Range | Up to 20 units of the player within 3, 4 or 5 tiles of the middle of the square get double speed or range for 15, 30 or 45 seconds. 2x Range stops at the first building of the player, with an error of the client: the units before it keep the double range, the units after it get nothing. |
| Black Hole | Like Hell Abyss, at once and then every second for 15, 20 or 30 seconds. |
| Instant Limit | Up to 20 units of the player within 3, 4 or 5 tiles of the middle of the square that have a limit bar get a full bar (stage 6). |

Errors of the client, each with a switch in the code:

- **Sacred Rain** heals nobody in the client. Its rain acts only on enemy items, but its healing acts only on units of the player. The owner chose to correct this: the port heals the player's units. `SacredRainSpell.FIX_CLIENT_ERROR` set to false gives the behaviour of the client.
- **Ether Shield** (kept as in the client) covers 7 tiles at level 1, 9 at level 2 and none at level 3, protects all sides, and a second cast before the end of the first leaves the first shield for the rest of the battle. `EtherShieldSpell.FIX_CLIENT_ERRORS` protects the marked square, only for the player, and ends each shield after its time.

Not ported: when a freeze ends, the client lets the frozen unit hit a unit of the player on the same tile for 10 points.

The screens of the spells (4d) use the art of the client:

| File | Contents |
|---|---|
| `spell_book/spell_book.gd` | `SpellBook`: the book, the windows, aiming with the marker of the area and casting, in quests and in the village. |
| `spell_book/spell_book_hud.gd` | The book at the bottom left (PopupMagic): the spells of the player, three at a time, and the mana. |
| `spell_book/spell_shop_window.gd` | The spell window (PopupWizardry): the spells by level, their prices, texts, stars and casts to the next level. |
| `spell_book/buy_mana_window.gd`, `cast_banner.gd`, `spell_particle.gd` | The mana window, the banner with the name of a cast spell, and a particle of a spell on the map. |
| `battle/battle_view.gd` | The particles of the spells, the colours of frozen and poisoned units, the size of enlarged units, the jump of stunned units, the shrinking of swallowed items and the glow of the items that a spell marks. |
| `ui/ui_button.gd`, `ui/ui_clip.gd`, `ui/ui_library.gd`, `importer/ui_import.py` | Named buttons of the windows, frame labels, turned parts and fading parts. |

The rules of the screens come from the client:

- Human players have the spell book from level 15; trolls always have it. The book lists the spells that the player has, by id.
- A spell without enough mana opens the mana window. While the player aims, the marker of the area is centred half a tile below the tile under the mouse, and the items of the side of the spell on the square from that tile to the left and up glow.
- The graphics of most spells stop at their last frame; Ether Shield and Black Hole repeat their last part, and Sacred Rain repeats all. A particle fades in 1 second, most 1 second after it acts.

Not exact yet:

- The banner of a cast and the book are placed for a stage of 760 x 600 pixels: the book at the bottom left, the banner over the bottom centre.
- The client turns the shapes of some parts of its windows with a skew; the port turns and scales them, but does not skew them.
- In the village a cast shows its graphic on the tile and costs its mana, but changes no units. The client also brings summoned units at home, which it does not save.

Step 4e added the gift of the client at level 15 and checked the whole stage by a played quest:

- At level 15 the client gives a free Wizardry Academy on the free 3 x 3 place nearest to tile (59, 59), with "buy" without cost, which gives the experience of the building. It shows the alert of the spell book with its picture. The building opens the spell window. The client gives it only for a level that the player reaches in the own village, also to troll players, and also when the village has one already. A level from the experience of a quest gives nothing, because the client adds that experience during the quest, outside its normal mode. `Village.add_free_buildings()` places it.
- The panel of the port, which is not art of the client, moved to the top right, so that it does not cover the spell book.
- A scripted quest on troll island 1 with a level 50 player and 24 units: the script opened the book with a click, cast 10 spells with the mouse (Age of Colossus, 2x Speed, Sacred Rain and Golem's Wrath on the army; Hell Abyss, Fire Havoc, Black Hole, Poisonous Flood, Deadly Frostbite and Ultimate Hail on the enemies), sent the army at the last enemies, and clicked the treasure. The quest ended with a win after 26 seconds: 2247 gold, 22 experience, 1 unit dead and back. The 10 casts cost 89 mana, 200 to 111, and each counted once. The golem was not in the result. The save after the quest had the mana, the casts, the gold, the experience and the rank of the island.

## How to check the result

- Headless checks with a fixed seed for the rules.
- Server replays of `end_quest` and the other commands, as for the village.
- The same quest in the original client (Ruffle) and in the port. The results cannot be equal, because both use random numbers, but the course of the battle must be similar: the same targets, about the same duration and losses. See the next section.

## Comparison with the original client

The first comparison (step 2.3 of `docs/NATIVE_PORT.md`) played troll island 1 (quest `100000006`, 1 star) in the original client and in the port, with the same village (level 50, 24 units: 12 spearmen, 10 light archers, 2 light knights) and the same orders.

Method:

- Client: `tools/ruffle_quest.js` runs the client `SocialEmpires1.4.07sec_fixed.swf` with the Ruffle build in `templates/js/ruffle/`, in headless Chromium, against the Python server. It clicks the orders on the screen. The client runs its battle in ENTER_FRAME, and Ruffle drops frames when the software rendering is slow; so the script gives Ruffle a clock that moves one frame per animation callback and counts the callbacks. The results are in game frames (30 per second), as in the port. The script records the frames at which the gold and experience counters change, which is when an enemy dies.
- Port: `godot/checks/quest_compare.gd` plays the same plan headless and prints each death with its frame.
- The plan: no orders until the army stands still, then select all and attack the Battle Troll (59, 44), then the War Troll (44, 39), then the Big Troll (30, 36), then collect the chest. Between the orders the army stands still in both games, so the time between the orders does not change the result.

Result of 3 runs of the client and 4 runs of the port (frames after the order):

| Event | Client | Port |
|---|---|---|
| Battle Troll dies | 193 to 219 | 178 to 202 |
| Boar Rider (comes to help) dies | 257 to 275 | 246 to 275 |
| War Troll dies | 399 to 460 | 353 to 423 |
| First Big Troll dies | 331 to 369 | 285 to 318 |
| Second Big Troll dies | 374 to 458 | 332 to 429 |
| Own units dead | 4 to 5 | 3 to 7 |
| Units lost after the quest | 1 to 2 | 1 to 2 |
| Gold, experience | 2247, 22 | 2247, 22 |

- The targets are the same in every run: the High Elf at the landing, the Battle Troll, the Boar Rider, which comes to help it, the War Troll, and the two Big Trolls. In both games the light knights die to the War Troll and the Big Trolls. The gold, the experience, the win and the format of `end_quest` are the same.
- The fights after the second and third orders take 10 to 15 % longer in the client. A probable cause is the path search of the client: when a search takes longer than a time budget in milliseconds (`getTimer`), it gives no path, and the unit cannot search again for 1 to 3 seconds of real time. Ruffle in WebAssembly is slower than Flash Player, so in this test more searches stop. The port has no time budget. Not confirmed.

Difference found: the client runs the battle while the start window is open. On this island the High Elf stands next to the landing, so the army fights it while the player chooses the stars; after 30 seconds in the window, the elf is dead before the battle starts. The client shares the gold of the quest among the enemies only when the player starts, so this elf then gives no gold. The port now follows the client: the battle runs under the start window, and the player can give orders only after the start. An enemy that dies before the start gives no gold, as in the client. The quest ends only after the start. `QuestScreen.RUN_UNDER_START_WINDOW` set to false makes the battle wait for the start button.

### Played islands

After stage 6, a scratch script played all 28 islands through the game window (`main.tscn` with `--quest`), as a player does. It used a village of level 60 with 38 units (gods, colossi, dragons, heroes, archers and knights) and 1 star. It waited 3 seconds under the start window, pressed the start button, and then, every 2 seconds: it sent each idle unit to the nearest enemy unit that it can reach (then the town hall, then other targets), used each portrait button that it could use, and collected keys and treasures. On the islands with a team it chose 20 units in the team window. Each island ran for at most 20000 frames.

- 24 islands were won: the 4 troll and 8 civilisation islands, the Yeti, Golem and Rockdriller islands, both dragon islands, the Heroes island (all 7 doors), and hard islands 1, 2, 3, 5, 6 and 7.
- Hard island 4 and the 3 god islands were lost: all units of the army or team died. The quest then ended with the result window, as it must. Without the window and with an army of twice the size, hard island 4 and god islands 1 and 2 were won. The same test of god island 3 is not finished yet.
- On each island, about 570 frames ran under the start window, and the portrait buttons were used 21 to 153 times. No script error occurred.
- The first runs found no error of the port. They found three weak points of the test script: it attacked walls before the town hall, it sent units to enemies behind closed doors, and it attacked the Deadly Dragon, which attacks cannot hurt, instead of the eggs. A player does not do these things; the script was changed.

Not tested: islands with 2 or 3 stars, and a play by a person.

### Second comparison: hard island 1

Hard island 1 (Celestial Isle, `100000041`) was played in the client in Ruffle and in the port with the same village (the 38 units above) and the same plan: three orders "select all, attack" on the Celestial Mech at (60, 65), the Reaper at (57, 57) and an archer at (53, 50), at 130, 459 and 606 frames after the start. One run of each.

| | Client | Port |
|---|---|---|
| Island and goal in the start window | Celestial Isle, "Defeat the Celestial Empire!" | the same |
| First enemy dies (frames after the start) | about 392 | 469 |
| Enemies dead 845 frames after the start | 16 (1280 gold, 64 experience) | 15 (1200 gold, 60 experience) |

The gold and the experience of each kill are the same (80 gold and 4 experience). The port kills one enemy fewer in this time, and its first kill comes later; the order of the army and the walk to the enemies 30 tiles away decide this time, and the path search of the client in Ruffle is not exact in time (see above). The client counts the frames of the page, so its numbers have an error of about 20 frames.

### Stage 5 result

All 28 islands of the island list are in the port. The "not in the port" sign shows on no island of the list. Survival (`100000035`, `100000036`), the tournament (`100000040`) and the collection islands (`100000051` to `100000055`) are not in the island list; they belong to stage 7.

| File | Contents |
|---|---|
| `quest/quest_island.gd` | The data of the 28 islands: the kind (`Family`), start tiles, land, free units, item rewards, pictures of the start window, and the team rules. |
| `quest/quest_battle.gd` | `QuestBattle`: the rules of `QuestBase` of the client, with hooks for each kind. `create()` chooses the subclass. |
| `quest/kinds/troll_quest.gd`, `civilisation_quest.gd` | The 12 islands of stage 3. |
| `quest/kinds/key_quest.gd` | The Yeti, Golem and Rockdriller islands: groups of units, keys, the boss, penguins on the Arctic island. |
| `quest/kinds/dragon_quest.gd`, `dragon_2_quest.gd` | The two dragon islands: the egg, the rocks, the dragons, and the eggs that take the life of the Deadly Dragon. |
| `quest/kinds/heroes_quest.gd` | The Heroes island: 7 areas with doors that open when their units are dead. |
| `quest/kinds/hard_quest.gd` | The 7 hard islands and the 3 god islands. |
| `quest/quest_team.gd`, `quest/team_window.gd` | The team of at most 20 units for hard islands 6 and 7 and the god islands, with the window of the client (`SelectionTeamWindowMC`). |
| `battle/battle_ability.gd`, `battle/abilities/` | The delegates of the client: one ability object for each fighter, with the hooks of the delegates (`onAttack`, `onUpdate`, `onRecibirAtaque` and others). `AbilityTable` maps the item ids. `HeroAbility` has the special attacks that the client writes in `IsoUnit` itself (Valkyrie, Wallace, Thor, High Elf, Arthur, King and others). |
| `battle/ai/` | The AI of the bosses: `BossAI`, `ThreatAI`, the Rockdriller, the Sanddriller and the dragon boss. |
| `battle/magic_particles.gd` | The types of magic particles and the frame at which each one attacks. |

The battle got the parts that the abilities use: forced animations with events at frames, pushes through the air, conversions, explosions, doors, magic particles, shots and beams with their own graphics, and the immunities of the units. `BattleView` draws the magic particles from `MagicParticleMC` of the client library `20131010_magicParticles.swf`, the flight of pushed units, beams, open doors and the size of units that the client draws bigger or smaller.

The rules come from the client. Where the client has an error that the player can see, the port keeps it and the comment in the code tells it:

- The Heroes island counts the death of a unit outside the areas (a copy for more stars, or a converted unit) in area 0, so the door of area 0 can open early.
- Titan Hydros, Titan Lythos and Titan Stratos put their hurricanes, minions and tornados on the side of the player, also when the titan is an enemy. The cracks of the Mole swallow units on the enemy side, also when the mole is an enemy.
- Titan Pyros does its three special attacks next to the target only once in a battle, because the client does not set its count back.

Changes from the original game:

- **Item rewards.** The client puts the reward units of the boss islands in the store itself, and sends them in `item_rewards`; the server of this project does not read this field. `Village.end_quest()` puts them in the store.
- **Team window.** The client asks with Yes and No when the team has fewer than 20 units. The port shows the question in an alert; a second click on OK starts the quest. The port hides the formations of the tournaments in this window, because they do not change a quest.
- **Collection items** that the player finds in a quest go to the village when the quest ends. The client sends them at once with `add_collectable`.

Not in this stage:

- The attacks that the player starts with the buttons of the portraits (limit attacks, smash, healing beams) came in stage 6, see "Stage 6 result". Enemy units do not use them in the client either.
- The minions of Titan Lythos have full size; the client draws them at 0.3 of their size.
- The port does not draw the cracks of the Mole.

Tests: `checks/quest_check.gd` has scenarios for the keys and the boss of the Arctic island, the altar of the Desert island, the second dragon island, the doors of the Heroes island, the team rules and the item rewards. A scratch test ran every island of the list for 3000 frames with a fixed army and found no script errors. The played tests and the second comparison with the client are in "Played islands" below.

### Stage 6 result

All delegates of the client and all special unit classes (`isounits/`) that change a battle are in the port. The units that a player can own (store, nests, Soul Mixer, riders, collections) fight as in the client, also when no quest map has them.

| File | Contents |
|---|---|
| `battle/special_units/` | The special units (`IsoSpecialUnit` and its subclasses): `SpecialUnitTable` maps 261 item ids to the family scripts (dragons, gods, colossi, gladiators, heroes, monsters, old special units). Each family makes the portrait buttons of its units: the action, the cast and cooldown times, the condition and the text when the button cannot be used, the limit button and its attack. |
| `battle/abilities/` | The delegates: `AbilityTable` maps 582 item ids. Group scripts hold the units whose delegates are close: `ShotAbility` and `BeamAbility` (data only: shots, delays, beams), `CycleUnitsAbility`, `WarriorUnitsAbility`, `GladiatorUnitsAbility`, `OrcUnitsAbility`, `NecroSoldiersAbility`, `GodUnitsAbility`, `MinionUnitsAbility`, `MonsterUnitsAbility`, `TowersAbility` and others. |
| `battle/attacks/` | The attack objects of the client that the buttons use: frames of a forced animation, rains, beams, damages with their conditions. |
| `battle/unit_button_panel.gd` | The portrait buttons at the bottom of the battle screen, with the pictures of the client, the masks of the cast and cooldown times and the limit bar. |
| `battle/spells/instant_limit_spell.gd` | Instant Limit. |

How the player uses it: select one own unit that has buttons; its buttons show at the bottom of the screen. A click uses a button. After a click the unit casts, then acts, then the buttons wait for their cooldown. The limit bar fills with the damage (or for healers the healing) that the unit does, at most once a second; a Limit Wizard within 10 tiles doubles it. When the bar is full, the limit button starts the limit attack.

The rules come from the client. Where the client has an error that the player can see, the port keeps it, and the comment in the code tells it. Examples:

- The earthquake of the Greater Demon and the rage of the Samurai stop at the first building in their area.
- The Ice and Shadow Genesis colossi look for their targets on the enemy side of the player, also when the colossus is an enemy.
- The bonus of 1.5 times the attack that some gods and colossi have against their own groups never applies in the client, so the port does not have it.
- The smash of the 4-Weapons Gladiator kills a small unit when the unit lands; a unit that cannot fly does not die.
- A star particle of a healer also gives an attack of 0 to an enemy on its tile.

Not in this stage, because they do not change the battle:

- Effects that the client only draws: the domes of protection (1357 to 1359), the colour of the Swamp Minion and of the Huge Egg when it is hit, the extra rocks of the Catapult, the red bubble of Anubis, the bigger balls of the Mother Monster, the white flash of Instant Limit, and the heads of the Three-Headed Dragon in turn.
- The arrows of the units in a Fortress: the port has no units in buildings, so the Fortress shoots only its cannonballs.
- The Dummy (`DummyDelegate`, item 1533) is not in the configuration.

Tests: `checks/spell_check.gd` has a scenario for Instant Limit. Scratch tests ran each of the 600 item ids with an ability or buttons in a battle against spearmen and a tower for 600 frames, and each of the 261 special units with each of its buttons; they found no script errors. The attacks of single units were also checked in small battles against the client code, for example the helpers of the Black Yeti, the conversions of Anubis and the target choice of the Dragon Killer Fortress. Not tested: a played battle by hand with each unit, and a comparison with the original game in Ruffle.

## Decisions of the owner

1. Campaign quests come before PvP. The port has no server, and no multiplayer is planned for now.
2. The player controls the units during battles as in the original game.
3. Survival and tournament are ported where they work without other players.
4. The limit of quests in a row uses 2 hours instead of 6, and the code makes it easy to change or remove.
5. Islands that the port does not have yet are locked, with a "not in the port" sign in the style of the game, until their quest is ported.
6. Ether Shield works as in the client, with its errors: at levels 1 and 2 it protects a square one size larger than its picture, at level 3 it protects nothing, and it also protects enemies. `EtherShieldSpell.FIX_CLIENT_ERRORS` turns on a correction.
7. Instant Limit was locked with the "not in the port" sign until units had their limit bars. Since stage 6 it is in the port.
8. The player can cast spells in the own village, as in the client.
9. Sacred Rain heals the units of the player. In the client it heals nobody.
