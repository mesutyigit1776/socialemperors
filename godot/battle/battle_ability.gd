class_name BattleAbility
extends RefCounted
## The special behaviour of one kind of unit or building, like a delegate of the
## original client. The battle asks the ability of a fighter at fixed points.
## Abilities are added one kind at a time, see for_item().

## A special fighter repeats a cycle of animations while it attacks: the normal
## attack, then special attack n after special_intervals[n] frames, which lasts
## special_durations[n] frames. Empty for fighters without special attacks.
var special_intervals: Array[int] = []
var special_durations: Array[int] = []


## The ability of the item, or null when it has none.
static func for_item(item_id: int) -> BattleAbility:
	match item_id:
		502, 590:  # Healer and troll healer
			return HealerAbility.new()
	return null


## Called at each attack of fighter in range of its target. Returns false when
## the normal attack must not happen.
func on_attack(_sim: BattleSim, _fighter: BattleFighter) -> bool:
	return true
