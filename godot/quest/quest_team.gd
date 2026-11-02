class_name QuestTeam
extends RefCounted
## The rules of the team for an island with QuestIsland.team (the window
## SelectionTeamWindow of the client in its quest mode):
## - The player chooses at most QuestBattle.TEAM_SIZE units of the army.
## - Of a unit with a units_limit, the team can have at most that number.
## - On an island with QuestIsland.groups, at least group_count units of the
##   team must be in one of these groups.

## The units that the player can choose: [unit id, number], the units with
## the most life first, as the client sorts them. army: unit id -> number,
## see Village.quest_army().
static func choices(army: Dictionary, config: GameConfig) -> Array[Array]:
	var result: Array[Array] = []
	for id: int in army:
		var def := config.get_item(id)
		if def == null:
			continue
		var count := int(army[id])
		if def.units_limit > 0:
			count = mini(count, def.units_limit)
		result.append([id, count])
	result.sort_custom(func(a: Array, b: Array) -> bool:
		var life_a := config.get_item(a[0]).life
		var life_b := config.get_item(b[0]).life
		return life_a > life_b if life_a != life_b else a[0] < b[0])
	return result


## The number of units in team (unit id -> number).
static func size(team: Dictionary) -> int:
	var total := 0
	for id: int in team:
		total += int(team[id])
	return total


## True when team has the units of the groups that the island asks for.
static func meets_groups(island: QuestIsland, team: Dictionary, config: GameConfig) -> bool:
	if island.groups.is_empty():
		return true
	var count := 0
	for id: int in team:
		if config.get_item(id).groups in island.groups:
			count += int(team[id])
	return count >= island.group_count
