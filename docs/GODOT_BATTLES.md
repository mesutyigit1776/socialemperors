# Battles in the Godot port: plan

Status: stage 1 done; stage 2 has the view and the unit control, without the graphics of shots and effects. Branch `godot-port`.

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

- The 36 quest maps are village saves in `villages/quests/`. The port reads 34 of them. Two (`100000053`, `100000054`) have no level, so the loader refuses them; a quest map needs a looser check.
- Each frame of a unit graphic is one action in one direction: frame = action × 5 + direction. The actions are idle, walking, attacking, dying, harvesting, repairing, and from 6 the special attacks. Each frame contains a nested clip that plays the animation; the importer exports these clips (stage 2).
- The client starts a shot at 0.75 of the height of the graphic of the shooter and aims at the same height of the target. Stage 1 uses the anchor points of the items, so its shots fly a little shorter or longer. Stage 2 adds the heights from the graphics.
- Projectiles and effects are in 231 files in `assets/fx/`. The importer does not read them yet.
- The quest goals and scripted events are in the client quest classes, not in the data.

## Design

- The port is a one-to-one port: battles, unit control and the game modes work as in the original game.
- A new folder `godot/battle/` keeps the battle separate from the village save model.
- `BattleSim` is the model: it has no nodes and runs one frame at a time, so the checks can run it headless with a fixed random seed. It contains the fighters (units and attacking buildings), the projectiles, the AI and the damage rules.
- `BattleView` draws a `BattleSim` on the existing map view: animations, projectiles, health bars.
- A quest runner reads a quest map, places the player's units, checks the goals and ends the battle.
- At the end, the battle writes the results through new `Village` methods that do what the server commands do. If they are large, they get their own layer, `village_battle.gd`, above `village.gd`.
- Special abilities are added one unit at a time behind one interface, as the client does with its delegates.
- `docs/NATIVE_PORT.md`, section 4a, has the roadmap of the whole port. A comparison with the original game in Ruffle comes after stage 3.

## Stages

Each stage is a milestone with headless checks and, where it changes the save, a server replay.

1. **Battle core, headless.** Fighters from the configuration, the damage rules, frames, melee and ranged attacks, projectile travel time, towers and other attacking buildings, healers, death, and the basic AI states. Checks with a fixed seed: damage values, attack timing, target choice, who wins small fights.
2. **Battle view.** Attack and death animations, projectiles and effects (importer: `assets/fx/`), health bars, and orders to units during a battle (select, move, attack).
3. **Campaign quests.** The quest list and its rules: unlocked quests, the waiting time between quests, the team. Load the quest map, place the units, the generic goals (destroy all enemies), and the end: gold, experience, honour, rank and lost units, as `end_quest` writes them.
4. **Spells.** The spell book: mana, buying and using spells (`buy_magic`, `use_magic`), shields. Quests use them, so they come before the quest scripts.
5. **Quests one at a time.** For each of the 36 quests whose maps the server has: port the client quest class and the special abilities of the units and bosses on the map. Each quest is then complete and playable, and the quests can be compared with the original game one at a time.
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

### Stage 2 so far

| File | Contents |
|---|---|
| `sprites/unit_sprite.gd` | `UnitSprite`: plays the clips of a unit graphic at 30 frames per second. The village uses it too. |
| `battle_formation.gd` | `BattleFormation`: the tiles of a group order, as in the client: a square on free ground, the rings around an own item, the rings at the range around an enemy. `BattleSim.order()` uses them. |
| `battle_view.gd` | `BattleView`: draws the battle, the selection, the health bars and the shots. |
| `battle_screen.gd` | `BattleScreen`: runs the battle at 30 frames per second and turns the mouse into orders, as in the client: click, double click (units of the same kind within 10 tiles), selection box, orders to the ground or to an enemy. `--battle <file>` starts a practice battle on a quest map. |

The importer now reads the quest maps, so that their items have graphics. Not done yet in stage 2: the graphics of shots and effects from `assets/fx/` (shots are lines), the health bar and selection graphics of the client (simple shapes for now), and shot heights.

## How to check the result

- Headless checks with a fixed seed for the rules.
- Server replays of `end_quest` and the other commands, as for the village.
- The same quest in the original client (Ruffle) and in the port. The results cannot be equal, because both use random numbers, but the course of the battle must be similar: the same targets, about the same duration and losses.

## Decisions of the owner

1. Campaign quests come before PvP. The port has no server, and no multiplayer is planned for now.
2. The player controls the units during battles as in the original game.
3. Survival and tournament are ported where they work without other players.
