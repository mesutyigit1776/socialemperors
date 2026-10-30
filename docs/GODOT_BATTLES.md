# Battles in the Godot port: plan

Status: plan, not started. Branch `godot-port`.

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
- Unit graphics have 25 frames: 5 animations of 5 directions. The port uses the first two (idle, walking). The others are probably attack and death; stage 2 confirms this.
- Projectiles and effects are in 231 files in `assets/fx/`. The importer does not read them yet.
- The quest goals and scripted events are in the client quest classes, not in the data.

## Design

- A new folder `godot/battle/` keeps the battle separate from the village save model.
- `BattleSim` is the model: it has no nodes and runs one frame at a time, so the checks can run it headless with a fixed random seed. It contains the fighters (units and attacking buildings), the projectiles, the AI and the damage rules.
- `BattleView` draws a `BattleSim` on the existing map view: animations, projectiles, health bars.
- A quest runner reads a quest map, places the player's units, checks the goals and ends the battle.
- At the end, the battle writes the results through new `Village` methods that do what the server commands do. If they are large, they get their own layer, `village_battle.gd`, above `village.gd`.
- Special abilities are added one unit at a time behind one interface, as the client does with its delegates.

## Stages

Each stage is a milestone with headless checks and, where it changes the save, a server replay.

1. **Battle core, headless.** Fighters from the configuration, the damage rules, frames, melee and ranged attacks, projectile travel time, towers and other attacking buildings, healers, death, and the basic AI states. Checks with a fixed seed: damage values, attack timing, target choice, who wins small fights.
2. **Battle view.** Attack and death animations, projectiles and effects (importer: `assets/fx/`), health bars, and orders to units during a battle (select, move, attack).
3. **Campaign quests.** The quest list and its rules: unlocked quests, the waiting time between quests, the team. Load the quest map, place the units, the generic goals (destroy all enemies), and the end: gold, experience, honour, rank and lost units, as `end_quest` writes them.
4. **Quest scripts.** Port the client quest classes for the 36 quests whose maps the server has.
5. **Spells.** The spell book: mana, buying and using spells (`buy_magic`, `use_magic`), shields.
6. **Special abilities.** First the units that a player can own (store, nests, Soul Mixer, riders, collections), then the bosses of the quests.
7. **Other modes.** PvP attacks on other saves of the local server, neighbour visits, and events such as the heavy siege. Survival and tournament last, if at all.

## How to check the result

- Headless checks with a fixed seed for the rules.
- Server replays of `end_quest` and the other commands, as for the village.
- The same quest in the original client (Ruffle) and in the port. The results cannot be equal, because both use random numbers, but the course of the battle must be similar: the same targets, about the same duration and losses.

## Decisions for the owner

1. Order: campaign quests first (recommended, all data is local), or PvP first.
2. Unit control during battles: as in the client (recommended), or simpler at first.
3. Survival and tournament: port them, or leave them out.
