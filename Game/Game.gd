extends Node

const SAVE_PATH = "user://save.dat"
const UNIT_LIBRARY = "res://Data/UnitLibrary.tres"
const TARGET_NAMES = ["enemy", "ally", "self", "tile"]
const BLOCKER_NAMES = ["tile", "unit"]

var profile
var selected_mission_id
var units = {}

func unit_to_dict(def):
	var data = {
		"name": def.unit_name,
		"abbr": def.abbr,
		"side": def.side,
		"generation": def.generation,
		"tags": Array(def.tags),
		"hp_max": def.hp_max,
		"moves_max": def.moves_max,
		"abilities": []
	}
	
	if def.sprite_main:
		data["sprite_main"] = def.sprite_main.resource_path
	if def.sprite_shadow:
		data["sprite_shadow"] = def.sprite_shadow.resource_path
	
	for ability in def.abilities:
		data["abilities"].append(ability_to_dict(ability))
	
	return data

func ability_to_dict(def):
	var effects = []
	for effect in def.effects:
		effects.append(effect_to_dict(effect))
	
	var data = {
		"ability_name": def.ability_name,
		"ability_range": def.ability_range,
		"targeting": def.targeting,
		"blockers": _flag_names(def.blockers, BLOCKER_NAMES),
		"targets": _flag_names(def.targets, TARGET_NAMES),
		"effects": effects
	}
	
	if def.size_requirement > 0:
		data["size_requirement"] = def.size_requirement
	if def.size_cost > 0:
		data["size_cost"] = def.size_cost
	
	return data

func effect_to_dict(def):
	if def.type == "tile_set":
		return {
			"type": def.type,
			"state": def.tile_state
		}
	
	return {
		"type": def.type,
		"amount": def.amount
	}

func start_mission(mission_id):
	selected_mission_id = mission_id
	get_tree().change_scene_to_file("res://Battle/Battle.tscn")

func go_to_mission_select():
	get_tree().change_scene_to_file("res://MissionSelect/MissionSelect.tscn")

func has_cleared(mission_id):
	return profile["cleared_missions"].has(mission_id)

func is_unlocked(mission):
	for required_id in mission.get("requires", []):
		if !has_cleared(required_id):
			return false
	return true

func challenges_text(mission_id, mission):
	if mission["challenges"].size() == 0:
		return ""
	
	var lines = ["Challenges:"]
	for challenge in mission["challenges"]:
		var mark = "[ ]"
		if has_completed(mission_id, challenge["id"]):
			mark = "[x]"
		lines.append("%s %s (%s)" % [
			mark,
			challenge["description"],
			resources_text(challenge["reward"], "+")
		])
	return "\n".join(lines)

func has_completed(mission_id, challenge_id):
	return profile["completed_challenges"].get(mission_id, []).has(challenge_id)

func record_victory(mission_id, mission, met_ids):
	var summary = {
		"first_clear": false,
		"rewards": {},
		"new_challenges": []
	}
	
	if !profile["cleared_missions"].has(mission_id):
		profile["cleared_missions"].append(mission_id)
		summary["first_clear"] = true
		_add_resources(summary["rewards"], mission["first_clear_reward"])
	
	if !profile["completed_challenges"].has(mission_id):
		profile["completed_challenges"][mission_id] = []
	var done = profile["completed_challenges"][mission_id]
	
	for challenge in mission["challenges"]:
		if met_ids.has(challenge["id"]) && !done.has(challenge["id"]):
			done.append(challenge["id"])
			summary["new_challenges"].append(challenge["description"])
			_add_resources(summary["rewards"], challenge["reward"])
	
	_add_resources(profile["resources"], summary["rewards"])
	save_game()
	
	return summary

func resources_text(resources, prefix = ""):
	var parts = []
	for type in resources:
		parts.append("%s%d %s" % [prefix, resources[type], type])
	if parts.size() == 0:
		return "none"
	return ", ".join(parts)

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(profile)

func load_game():
	if !FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	
	var saved = file.get_var()
	if typeof(saved) != TYPE_DICTIONARY:
		return
	
	for key in saved:
		profile[key] = saved[key]

func _flag_names(flags, names):
	var result = []
	for i in names.size():
		if flags & (1 << i):
			result.append(names[i])
	return result

func _load_units():
	var library = load(UNIT_LIBRARY)
	for def in library.units:
		var unit_id = def.resource_path.get_file().get_basename()
		units[unit_id] = unit_to_dict(def)

func _default_profile():
	return {
		"resources": {},
		"cleared_missions": [],
		"completed_challenges": {}
	}

func _add_resources(target, added):
	for type in added:
		target[type] = target.get(type, 0) + added[type]

func _ready():
	profile = _default_profile()
	load_game()
	_load_units()
