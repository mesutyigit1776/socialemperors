class_name SpecialActions
extends RefCounted
## The action panel of VillageHud for the special buildings, the collections
## and the item store: what the panel shows, and what each action does in the
## village. The client shows a popup window for each of them.

enum View { NONE, BUILDING, COLLECTIONS, STORE }

## Result of run(): the message for the player, whether the village changed (then
## the caller updates the view and saves), whether the client loads the map
## again after the change (the Time Machine and the Weather Machine), and the
## stored item that the player wants to place, or null.
class Outcome:
	var text: String
	var changed: bool
	var reload: bool
	var place: GameConfig.ItemDef


var _village: Village
var _config: GameConfig
var _rng: RandomNumberGenerator


func _init(village: Village, config: GameConfig, rng: RandomNumberGenerator) -> void:
	_village = village
	_config = config
	_rng = rng


## Returns [text, actions] for VillageHud.show_actions(). building is the selected
## item for View.BUILDING; the text and actions are empty when it is not special.
func describe(view: View, building: Village.PlacedItem, now: int) -> Array:
	match view:
		View.COLLECTIONS:
			return _describe_collections()
		View.STORE:
			return _describe_store()
		View.BUILDING:
			if building != null:
				return _describe_building(building, now)
	return ["", []]


## Runs the action with the id that describe() gave.
func run(id: String, building: Village.PlacedItem, now: int) -> Outcome:
	var outcome := Outcome.new()
	var parts := id.split(":")
	var argument := int(parts[1]) if parts.size() > 1 else 0
	var result := Village.Placement.NOT_ALLOWED
	var name := _config.get_item(building.item_id).name if building != null else ""
	match parts[0]:
		"place":
			outcome.place = _config.get_item(argument)
			outcome.text = "Place %s. Right-click cancels." % outcome.place.name
			return outcome
		"collection", "collection_cash":
			result = _village.complete_collection(argument, parts[0] == "collection_cash")
			if result == Village.Placement.OK:
				outcome.text = "You completed %s. %s is in your item store." % [_collection_name(argument), _config.get_item(_config.collection_rewards[argument]).name]
		"activate":
			result = _village.activate_nest(building, parts[1])
			if result == Village.Placement.OK:
				outcome.text = "%s is active. Care for %s." % [name, _village.nest_unit(building).name]
		"care":
			var unit := _village.nest_unit(building)
			result = _village.care_for_nest(building, now)
			if result == Village.Placement.OK:
				outcome.text = "You cared for %s." % unit.name
		"nest_wait":
			result = _village.end_nest_wait(building, now)
			if result == Village.Placement.OK:
				outcome.text = "The wait is over."
		"nest_take":
			var unit := _village.nest_unit(building)
			result = _village.take_nest_unit(building, now)
			if result == Village.Placement.OK:
				outcome.text = "%s came out of %s." % [unit.name, name]
		"rider":
			result = _village.select_rider(argument)
			if result == Village.Placement.OK:
				outcome.text = "%s starts the training." % _config.get_item(Village.RIDER_UNITS[argument - 1]).name
		"rider_train":
			result = _village.train_rider(now)
			if result == Village.Placement.OK:
				outcome.text = "The rider finished a training step."
		"rider_wait":
			result = _village.end_rider_wait(now)
			if result == Village.Placement.OK:
				outcome.text = "The wait is over."
		"rider_take":
			var rider := _config.get_item(Village.RIDER_UNITS[_village.rider_type() - 1])
			result = _village.take_rider(building, now)
			if result == Village.Placement.OK:
				outcome.text = "%s is trained." % rider.name
		"tame":
			result = _village.tame(building, now)
			if result == Village.Placement.OK:
				outcome.text = "The rider tamed the dragon."
		"resurrect":
			result = _village.resurrect(building, argument, now)
			if result == Village.Placement.OK:
				outcome.text = "%s came back." % _config.get_item(argument).name
		"potions":
			result = _village.buy_potions()
			if result == Village.Placement.OK:
				outcome.text = "You bought %d potions." % _config.graveyard_potions
		"hero":
			result = _village.resurrect_hero(building, argument, now)
			if result == Village.Placement.OK:
				outcome.text = "%s came back." % _config.get_item(argument).name
		"power_up":
			result = _village.power_up_soul_mix(building, _rng)
			if result == Village.Placement.OK:
				outcome.text = "The result is now %s." % _village.soul_mix_result(building, _rng).name
		"mix":
			var unit := _village.soul_mix_result(building, _rng)
			result = _village.mix_souls(building, now, _rng)
			if result == Village.Placement.OK:
				outcome.text = "%s mixes %s." % [name, unit.name]
		"mix_finish":
			result = Village.Placement.OK if _village.speed_up_training(building, now) == Village.Training.OK else Village.Placement.NOT_ENOUGH_RESOURCES
			if result == Village.Placement.OK:
				outcome.text = "The mix is finished."
		"mix_take":
			var unit := _config.get_item(_village.soul_mix_unit_id(building))
			result = _village.take_soul_mix(building, now)
			if result == Village.Placement.OK:
				outcome.text = "%s came out of %s." % [unit.name, name]
		"time_buy":
			result = _village.buy_time_packet(argument)
			if result == Village.Placement.OK:
				outcome.text = "You bought a packet of %s." % _hours_text(_config.time_packets[argument][0])
		"time_use":
			result = _village.use_time_packet(argument)
			if result == Village.Placement.OK:
				outcome.text = "The village moved %s forwards in time." % _hours_text(_config.time_packets[argument][0])
				outcome.reload = true
		"skin", "skin_unlock":
			result = _village.set_skin(argument) if parts[0] == "skin" else _village.unlock_skin(argument)
			if result == Village.Placement.OK:
				outcome.text = "The village now has the style %s." % _skin_name(argument)
				outcome.reload = true
		"temple":
			result = _village.do_temple_step(argument, now)
			if result == Village.Placement.OK:
				outcome.text = "%s: step %d of %d is done." % [name, _village.temple_steps_done().size(), Village.TEMPLE_STEPS]
		"temple_wait":
			result = _village.end_temple_wait(now)
			if result == Village.Placement.OK:
				outcome.text = "The wait is over."
		"temple_take":
			result = _village.take_supreme_bahamut(building, now)
			if result == Village.Placement.OK:
				outcome.text = "%s came out of %s." % [_config.get_item(Village.SUPREME_BAHAMUT).name, name]
	outcome.changed = result == Village.Placement.OK
	if not outcome.changed:
		outcome.text = "There is no free place next to %s." % name if result == Village.Placement.OCCUPIED \
				else VillageHud.PLACEMENT_MESSAGES.get(result, "")
	return outcome


func _describe_building(building: Village.PlacedItem, now: int) -> Array:
	var name := _config.get_item(building.item_id).name
	var actions := []
	match building.item_id:
		Village.WIZARDRY:
			return ["%s: learn spells and see their levels." % name, [["spells", "Open the spell book", true]]]
		Village.DRAGON_NEST, Village.MONSTERS_NEST:
			if not _village.is_nest_active(building):
				var costs: Dictionary = _config.dragon_nest_costs if building.item_id == Village.DRAGON_NEST else _config.monster_nest_costs
				for code: String in costs:
					actions.append(["activate:%s" % code, "Start for %d %s" % [costs[code], VillageHud.RESOURCE_NAMES[code]], _village.get_resource(code) >= costs[code]])
				return ["%s grows a new unit after %d steps of care. Start it first." % [name, Village.NEST_STEPS], actions]
			var unit := _village.nest_unit(building)
			var units: Array = Village.NESTS[building.item_id]["units"]
			var text := "%s (%d of %d): %d of %d steps of care." % [unit.name, units.find(unit.id) + 1, units.size(), _village.nest_steps_done(building, now), Village.NEST_STEPS]
			var wait := _village.nest_wait_seconds(building, now)
			if _village.nest_steps_done(building, now) >= Village.NEST_STEPS:
				actions.append(["nest_take", "Take %s" % unit.name, true])
			elif wait > 0:
				text += " Next care in %s." % VillageHud.duration(wait)
				actions.append(["nest_wait", "End the wait for %d cash" % _village.nest_wait_cash(building), true])
			else:
				actions.append(["care", "Care for %s" % unit.name, true])
			return [text, actions]
		Village.RIDER_ACADEMY:
			if _village.rider_type() == 0:
				for rider_type in range(1, Village.RIDER_UNITS.size() + 1):
					var level: int = _config.dragon_riders[rider_type - 1]["level"]
					var label := "Train %s" % _config.get_item(Village.RIDER_UNITS[rider_type - 1]).name
					actions.append(["rider:%d" % rider_type, label if _village.get_level() >= level else label + " (level %d)" % level, _village.get_level() >= level])
				return ["Choose a rider to train.", actions]
			var rider := _config.get_item(Village.RIDER_UNITS[_village.rider_type() - 1])
			var steps: int = _config.dragon_riders[_village.rider_type() - 1]["steps"]
			var text := "%s: %d of %d training steps." % [rider.name, _village.rider_steps_done(now), steps]
			var wait := _village.rider_wait_seconds(now)
			if wait > 0:
				text += " Next step in %s." % VillageHud.duration(wait)
				actions.append(["rider_wait", "End the wait for %d cash" % _config.dragon_riders[_village.rider_type() - 1]["cash"], true])
			elif _village.rider_steps_done(now) >= steps:
				actions.append(["rider_take", "Take %s" % rider.name, true])
			else:
				actions.append(["rider_train", "Train (step %d)" % (_village.rider_steps_done(now) + 1), true])
			return [text, actions]
		Village.DRAGON_RIDING:
			var inside := _village.units_in(building)
			var dragons := inside.filter(func(id: int) -> bool: return _config.dragons.has(id))
			if inside.size() == 2 and dragons.size() == 1:
				actions.append(["tame", "Tame into %s" % _config.get_item(_config.dragons[dragons[0]][1]).name, true])
			return ["Send a dragon rider and a dragon of the rider's type into %s. Then tame the dragon." % name, actions]
		Village.GRAVEYARD:
			var units := _village.graveyard_units()
			for id: int in units:
				var unit := _config.get_item(id)
				actions.append(["resurrect:%d" % id, "Bring back %s (%d) for %d potions" % [unit.name, units[id], unit.potion], _village.get_resource("p") >= unit.potion])
			actions.append(["potions", "Buy %d potions for %d cash" % [_config.graveyard_potions, _config.graveyard_potions_price], true])
			return ["%d potions. %s" % [_village.get_resource("p"), "No units died yet." if units.is_empty() else "Units that died in battles:"], actions]
		Village.HEROES_GRAVE:
			var heroes := _village.dead_heroes()
			for id: int in heroes:
				var hero := _config.get_item(id)
				actions.append(["hero:%d" % id, "Bring back %s for %d gold" % [hero.name, hero.cost_unit_cash * Village.RESURRECT_GOLD_PER_CASH], true])
			return ["No heroes died yet." if heroes.is_empty() else "Heroes that died in battles:", actions]
		Village.SOUL_MIXER:
			if _village.soul_mix_unit_id(building) != 0:
				var unit := _config.get_item(_village.soul_mix_unit_id(building))
				var left := _village.seconds_to_trained(building, now)
				if left > 0:
					actions.append(["mix_finish", "Finish for %d cash" % _village.speed_up_cost(building, now), true])
					return ["Mixing %s, ready in %s." % [unit.name, VillageHud.duration(left)], actions]
				actions.append(["mix_take", "Take %s" % unit.name, true])
				return ["%s is ready." % unit.name, actions]
			var result := _village.soul_mix_result(building, _rng)
			if result == null:
				return ["Send two units with a soul power into %s. It makes a new unit from them, and they come back out." % name, []]
			var cash := _village.soul_power_ups_cash(building)
			actions.append(["power_up", "Power up for %d cash" % _village.soul_power_up_cash(building), true])
			actions.append(["mix", "Mix" if cash == 0 else "Mix and pay %d cash for the power-ups" % cash, true])
			return ["Result: %s (power %d, %s to make)." % [result.name, result.breeding_order, VillageHud.duration(result.sm_training_time)], actions]
		Village.TIME_MACHINE:
			var counts := _village.time_packets()
			for i in _config.time_packets.size():
				var packet: Array = _config.time_packets[i]
				var hours := _hours_text(packet[0])
				actions.append(["time_buy:%d" % i, "Buy %s for %d cash" % [hours, packet[1]], _village.get_resource("c") >= packet[1]])
				actions.append(["time_use:%d" % i, "Use %s (you have %d)" % [hours, counts[i]], counts[i] > 0])
			return ["%s: %s Each packet moves the times of the village forwards." % [_config.text("POPUP_TIME_TITLE"), _config.text("POPUP_TIME_HEADER")], actions]
		Village.WEATHER_MACHINE:
			for skin: int in Village.SKINS:
				if skin == _village.skin:
					continue
				if _village.is_skin_unlocked(skin):
					actions.append(["skin:%d" % skin, "Use %s" % _skin_name(skin), true])
				else:
					actions.append(["skin_unlock:%d" % skin, "Unlock %s for %d cash" % [_skin_name(skin), _config.unlock_skin_cash], _village.get_resource("c") >= _config.unlock_skin_cash])
			return ["%s: the village has the style %s." % [name, _skin_name(_village.skin)], actions]
		Village.BAHAMUT_TEMPLE:
			return _describe_temple(building, now)
	return ["", []]


func _describe_temple(temple: Village.PlacedItem, now: int) -> Array:
	var actions := []
	var done := _village.temple_steps_done()
	var text := "%s: %s %d/%d." % [_config.text("TEMPLE_SUPREME_BAHAMUT_TITLE"), _config.text("TEMPLE_SUPREME_BAHAMUT_PROGRESS"), done.size(), Village.TEMPLE_STEPS]
	var wait := _village.temple_wait_seconds(now)
	if wait > 0:
		text += " %s %s." % [_config.text("TEMPLE_SUPREME_BAHAMUT_WAIT_NEXT_STEP"), VillageHud.duration(wait)]
		actions.append(["temple_wait", "End the wait for %d cash" % Village.TEMPLE_WAIT_CASH, _village.get_resource("c") >= Village.TEMPLE_WAIT_CASH])
		return [text, actions]
	if done.size() == Village.TEMPLE_STEPS:
		actions.append(["temple_take", _config.text("TEMPLE_SUPREME_BAHAMUT_GET_FINAL_DRAGON_BTN"), true])
		return [text + " " + _config.text("TEMPLE_SUPREME_BAHAMUT_GET_FINAL_DRAGON_INFO"), actions]
	for step in Village.TEMPLE_STEPS:
		if not step in done:
			var action := ["temple:%d" % step, _temple_step_label(step), _village.has_temple_offering(step)]
			if step >= Village.TEMPLE_OFFERINGS.size() and step < Village.TEMPLE_OFFERINGS.size() + Village.TEMPLE_SACRIFICES.size():
				var unit := _config.get_item(Village.TEMPLE_SACRIFICES[step - Village.TEMPLE_OFFERINGS.size()])
				action.append(_config.text("POPUP_BAHAMUT_SUPREME_TEMPLE_SURE_TO_SACRIFICE").replace("#0#", unit.name))
			actions.append(action)
	return [text + " The steps can come in any order.", actions]


## The button text of a step of the temple, for example "Offering: 100000 gold".
func _temple_step_label(step: int) -> String:
	var offerings := Village.TEMPLE_OFFERINGS
	if step < offerings.size():
		return "%s: %d %s" % [_config.text("TEMPLE_SUPREME_BAHAMUT_DONATE_BTN"), offerings[step][1], VillageHud.RESOURCE_NAMES.merged({"m": "mana"})[offerings[step][0]]]
	if step < offerings.size() + Village.TEMPLE_SACRIFICES.size():
		return "%s: %s" % [_config.text("TEMPLE_SUPREME_BAHAMUT_SACRIFICE_BTN"), _config.get_item(Village.TEMPLE_SACRIFICES[step - offerings.size()]).name]
	return "%s: %s" % [_config.text("TEMPLE_SUPREME_BAHAMUT_COLLECT_BTN"), _config.text(Collections.text_name(Village.TEMPLE_HEART_COLLECTION))]


## The time of a packet of the Time Machine, as the client writes it: "30
## mins", "1 hour", "4 hours", "1 day".
static func _hours_text(hours: float) -> String:
	if hours < 1:
		return "%d mins" % int(hours * 60)
	if hours >= 24:
		var days := int(hours / 24)
		return "%d day%s" % [days, "s" if days > 1 else ""]
	return "%s hour%s" % [str(hours) if hours != floorf(hours) else str(int(hours)), "s" if hours > 1 else ""]


func _skin_name(skin: int) -> String:
	return _config.text(Village.SKIN_TEXTS[Village.SKINS.find(skin)]) if skin in Village.SKINS else str(skin)


func _describe_collections() -> Array:
	var lines: Array[String] = []
	var actions := []
	var empty := 0
	for collection in range(1, Collections.count() + 1):
		var counts: Array[String] = []
		var any := false
		for index in range(1, Collections.ITEMS_PER_COLLECTION + 1):
			counts.append("%s %d" % [_config.text(Collections.text_name(collection, index)), _village.collected(collection, index)])
			any = any or _village.collected(collection, index) > 0
		if not any:
			empty += 1
			continue
		lines.append("%s: %s" % [_collection_name(collection), ", ".join(counts)])
		var reward := _config.get_item(_config.collection_rewards[collection]).name
		if _village.can_complete_collection(collection):
			actions.append(["collection:%d" % collection, "Complete %s for %s" % [_collection_name(collection), reward], true])
		elif _village.collection_cash_price(collection) > 0:
			var price := _village.collection_cash_price(collection)
			actions.append(["collection_cash:%d" % collection, "Complete %s for %s and %d cash" % [_collection_name(collection), reward, price], _village.get_resource("c") >= price])
	lines.append("%d collections have no items yet. Harvests and the Treasure Mine find items." % empty)
	return ["\n".join(lines), actions]


func _describe_store() -> Array:
	var actions := []
	var stored := _village.stored_items()
	for id: int in stored:
		actions.append(["place:%d" % id, "Place %s (%d)" % [_config.get_item(id).name, stored[id]], true])
	return ["The item store is empty." if stored.is_empty() else "Click an item, then a place on your land.", actions]


## The item of a collection that the player found, for a message.
static func found_text(config: GameConfig, found: Vector2i) -> String:
	return "%s for the collection %s" % [config.text(Collections.text_name(found.x, found.y)), config.text(Collections.text_name(found.x))]


func _collection_name(collection: int) -> String:
	return _config.text(Collections.text_name(collection))
