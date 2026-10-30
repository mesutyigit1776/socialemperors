# Battles in the Godot port: plan

Status: stages 1 to 3 done. Branch `godot-port`.

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
- The units on the islands do not have their special abilities yet (stage 5), and walls have no doors (stage 1). In the scripted test, an army of 70 units lost on the Viking island; a win on a civilisation island is checked only headless.

Also in this stage: the client puts the registration point of a building graphic half the width of the frame left of the position and the height of the frame above it. Stage 2 also moved it by the top-left corner of the frame, which put the shots of such buildings in the wrong place; `BattleGraphic` now follows the client. The land of a quest island keeps the place of the first frame of the land graphic for all frames, as the client does, so that the coasts meet.

## How to check the result

- Headless checks with a fixed seed for the rules.
- Server replays of `end_quest` and the other commands, as for the village.
- The same quest in the original client (Ruffle) and in the port. The results cannot be equal, because both use random numbers, but the course of the battle must be similar: the same targets, about the same duration and losses.

## Decisions of the owner

1. Campaign quests come before PvP. The port has no server, and no multiplayer is planned for now.
2. The player controls the units during battles as in the original game.
3. Survival and tournament are ported where they work without other players.
4. The limit of quests in a row uses 2 hours instead of 6, and the code makes it easy to change or remove.
5. Islands that the port does not have yet are locked, with a "not in the port" sign in the style of the game, until their quest is ported.
