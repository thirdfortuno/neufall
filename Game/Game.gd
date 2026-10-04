extends Node

const SAVE_PATH = "user://save.dat"
const UNIT_LIBRARY = "res://Data/UnitLibrary.tres"
const TECH_TREE = "res://Data/TechTree.tres"
const CAMPAIGN = "res://Data/Campaign.tres"
const Validator = preload("res://Data/Validator.gd")
const TechLayout = preload("res://Game/TechLayout.gd")
const TARGET_NAMES = ["enemy", "ally", "self", "tile"]
const BLOCKER_NAMES = ["tile", "unit"]

var profile
var selected_mission_id
var units = {}
var tech_nodes = {}
var missions = {}
var content_errors = []
var validator

func unit_to_dict(def):
	var data = {
		"name": def.unit_name,
		"abbr": def.abbr,
		"side": def.side,
		"generation": def.generation,
		"starts_unlocked": def.starts_unlocked,
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

func new_save():
	profile = _default_profile()
	save_game()
	_load_content()

func level_to_dict(scene):
	var level = scene.instantiate()
	var layer = level.get_node("Floor")
	var rect = layer.get_used_rect()
	
	var grid = []
	for y in rect.size.y:
		var row = []
		for x in rect.size.x:
			if layer.get_cell_source_id(rect.position + Vector2i(x, y)) == -1:
				row.append(0)
			else:
				row.append(1)
		grid.append(row)
	
	var spawn_tiles = []
	var enemies = []
	var goal = null
	for child in level.get_children():
		if child is SpawnMarker:
			spawn_tiles.append(marker_cell(layer, rect, child))
		elif child is GoalMarker:
			goal = marker_cell(layer, rect, child)
		elif child is EnemyMarker:
			var cell = marker_cell(layer, rect, child)
			var enemy = {
				"unit": child.unit.resource_path.get_file().get_basename(),
				"x": cell[0],
				"y": cell[1],
				"behavior": behavior_to_dict(child.behavior)
			}
			if child.is_target:
				enemy["id"] = "target"
			enemies.append(enemy)
	
	var victory = {"type": level.victory_type}
	if level.victory_type == "reach_tile":
		victory["x"] = goal[0]
		victory["y"] = goal[1]
	elif level.victory_type == "kill_unit":
		victory["enemy"] = "target"
	
	var challenge_list = []
	for challenge in level.challenges:
		challenge_list.append(challenge_to_dict(challenge))
	
	var data = {
		"name": level.mission_name,
		"scene": scene.resource_path,
		"max_generation": level.max_generation,
		"grid": grid,
		"spawn_tiles": spawn_tiles,
		"victory": victory,
		"first_clear_reward": level.first_clear_reward.duplicate(),
		"challenges": challenge_list,
		"enemies": enemies,
		"requires": Array(level.requires)
	}
	
	level.free()
	return data

func behavior_to_dict(def):
	if def == null:
		def = BehaviorDef.new()
	
	var war = []
	for method in def.war_methods:
		war.append({"method": method})
	
	return {
		"version": 1,
		"search": [{"range": def.search_range, "method": "absolute"}],
		"peace": [{"method": def.peace_method}],
		"war": war
	}

func challenge_to_dict(def):
	var params = {}
	match def.type:
		"win_within_turns":
			params["turns"] = def.value
		"max_generation":
			params["generation"] = def.value
		"max_units":
			params["count"] = def.value
		"only_tag":
			params["tag"] = def.tag
		"require_tag":
			params["tag"] = def.tag
			params["count"] = def.value
	
	return {
		"id": def.id,
		"description": def.description,
		"type": def.type,
		"params": params,
		"reward": def.reward.duplicate()
	}

func go_to_overworld():
	get_tree().change_scene_to_file("res://Overworld/Overworld.tscn")

func is_node_unlocked(node_id):
	return (
			profile["unlocked_nodes"].has(node_id) ||
			units[tech_nodes[node_id]["unit"]]["starts_unlocked"]
	)

func node_state(node_id):
	if is_node_unlocked(node_id):
		return "unlocked"
	if !_prerequisites_met(node_id):
		return "locked"
	return "available"

func node_for_unit(unit_id):
	for node_id in tech_nodes:
		if tech_nodes[node_id]["unit"] == unit_id:
			return node_id
	return null

func can_afford(cost):
	for type in cost:
		if profile["resources"].get(type, 0) < cost[type]:
			return false
	return true

func unlock_node(node_id):
	if node_state(node_id) != "available":
		return false
	
	var cost = tech_nodes[node_id]["cost"]
	if !can_afford(cost):
		return false
	
	for type in cost:
		profile["resources"][type] = profile["resources"][type] - cost[type]
	profile["unlocked_nodes"].append(node_id)
	save_game()
	return true

func is_unit_unlocked(unit_id):
	if units[unit_id]["starts_unlocked"]:
		return true
	for node_id in profile["unlocked_nodes"]:
		if tech_nodes.has(node_id) && tech_nodes[node_id]["unit"] == unit_id:
			return true
	return false

func available_units(max_generation):
	var result = []
	for unit_id in units:
		var data = units[unit_id]
		if data["side"] == "player" && data["generation"] <= max_generation && is_unit_unlocked(unit_id):
			result.append(unit_id)
	return result

func go_to_tech_tree():
	get_tree().change_scene_to_file("res://TechTree/TechTree.tscn")

func unit_label(unit_id):
	var data = units[unit_id]
	var ability_names = []
	for ability in data["abilities"]:
		ability_names.append(ability["ability_name"])
	return "%s: %s" % [data["name"], ", ".join(ability_names)]

func mission_state(mission_id):
	if has_cleared(mission_id):
		return "cleared"
	if !is_unlocked(missions[mission_id]):
		return "locked"
	return "available"

func has_cleared(mission_id):
	return profile["cleared_missions"].has(mission_id)

func is_unlocked(mission):
	for required_id in mission.get("requires", []):
		if !has_cleared(required_id):
			return false
	return true

func victory_text(victory):
	match victory["type"]:
		"eliminate_all":
			return "Eliminate all enemies"
		"reach_tile":
			return "Reach the data packet (PKT)"
		"kill_unit":
			return "Defeat the TARGET enemy"
	return victory["type"]

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
	var library = ResourceLoader.load(UNIT_LIBRARY, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	for def in library.units:
		if def == null:
			_report_errors(["UnitLibrary: a unit slot is empty"])
			continue
		
		var unit_id = _resource_id(def)
		var errors = validator.unit_errors(unit_id, def)
		if units.has(unit_id):
			errors.append("Unit %s: listed twice in the UnitLibrary" % unit_id)
		
		if errors.size() > 0:
			_report_errors(errors)
		else:
			units[unit_id] = unit_to_dict(def)

func marker_cell(layer, rect, marker):
	var cell = layer.local_to_map((marker.position - layer.position) / layer.scale) - rect.position
	return [cell.x, cell.y]

func _load_content():
	units.clear()
	tech_nodes.clear()
	missions.clear()
	content_errors.clear()
	validator = Validator.new()
	_load_units()
	_load_tech()
	_load_missions()

func _load_missions():
	var campaign = ResourceLoader.load(CAMPAIGN, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	
	var level_ids = []
	for scene in campaign.levels:
		if scene != null:
			level_ids.append(_resource_id(scene))
	
	for scene in campaign.levels:
		if scene == null:
			_report_errors(["Campaign: a level slot is empty"])
			continue
		
		var level_id = _resource_id(scene)
		var errors = validator.level_errors(level_id, scene, units.keys(), level_ids)
		if missions.has(level_id):
			errors.append("Level %s: listed twice in the Campaign" % level_id)
		
		if errors.size() > 0:
			_report_errors(errors)
		else:
			missions[level_id] = level_to_dict(scene)
	
	var parents = {}
	for mission_id in missions:
		var list = []
		for required_id in missions[mission_id]["requires"]:
			if missions.has(required_id):
				list.append(required_id)
		parents[mission_id] = list
	
	var positions = TechLayout.new().layout_parents(parents)
	for mission_id in positions:
		missions[mission_id]["position"] = positions[mission_id]

func _load_tech():
	var tree = ResourceLoader.load(TECH_TREE, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	
	var node_for_unit_id = {}
	var skipped = []
	for node in tree.nodes:
		if node == null:
			_report_errors(["TechTree: a node slot is empty"])
			continue
		if node.unit == null:
			continue
		
		var unit_id = _resource_id(node.unit)
		if node_for_unit_id.has(unit_id):
			_report_errors(["Tech nodes %s and %s both unlock unit %s" % [node_for_unit_id[unit_id], _resource_id(node), unit_id]])
			skipped.append(_resource_id(node))
		else:
			node_for_unit_id[unit_id] = _resource_id(node)
	
	var obtainable = node_for_unit_id.keys()
	for unit_id in units:
		if units[unit_id]["starts_unlocked"] && !obtainable.has(unit_id):
			obtainable.append(unit_id)
	
	var requires_by_id = {}
	for node in tree.nodes:
		if node == null || skipped.has(_resource_id(node)):
			continue
		
		var needs = []
		if node.requires_mode == "all":
			for required in node.required_units:
				if required != null && node_for_unit_id.has(_resource_id(required)):
					needs.append(node_for_unit_id[_resource_id(required)])
		requires_by_id[_resource_id(node)] = needs
	
	var in_cycle = validator.tech_cycle_ids(requires_by_id)
	
	for node in tree.nodes:
		if node == null || skipped.has(_resource_id(node)):
			continue
		
		var node_id = _resource_id(node)
		var errors = validator.tech_errors(node_id, node, units.keys(), obtainable)
		if in_cycle.has(node_id):
			errors.append("Tech node %s: is part of a prerequisite cycle" % node_id)
		
		if errors.size() > 0:
			_report_errors(errors)
			continue
		
		var required_ids = []
		for required in node.required_units:
			required_ids.append(_resource_id(required))
		
		tech_nodes[node_id] = {
			"unit": _resource_id(node.unit),
			"cost": node.cost.duplicate(),
			"required_units": required_ids,
			"requires_mode": node.requires_mode
		}
	
	var changed = true
	while changed:
		changed = false
		for node_id in tech_nodes.keys():
			if !_prerequisites_obtainable(node_id):
				_report_errors(["Tech node %s: can never be unlocked, because a prerequisite unit's node has errors" % node_id])
				tech_nodes.erase(node_id)
				changed = true
	
	var positions = TechLayout.new().layout(tech_nodes)
	for node_id in positions:
		tech_nodes[node_id]["position"] = positions[node_id]

func _prerequisites_obtainable(node_id):
	var node = tech_nodes[node_id]
	var available_count = 0
	for unit_id in node["required_units"]:
		if units[unit_id]["starts_unlocked"] || node_for_unit(unit_id) != null:
			available_count = available_count + 1
	
	if node["required_units"].size() == 0:
		return true
	if node["requires_mode"] == "any":
		return available_count > 0
	return available_count == node["required_units"].size()

func _prerequisites_met(node_id):
	var node = tech_nodes[node_id]
	if node["required_units"].size() == 0:
		return true
	
	if node["requires_mode"] == "any":
		for unit_id in node["required_units"]:
			if is_unit_unlocked(unit_id):
				return true
		return false
	
	for unit_id in node["required_units"]:
		if !is_unit_unlocked(unit_id):
			return false
	return true

func _resource_id(resource):
	return resource.resource_path.get_file().get_basename()

func _report_errors(errors):
	for error in errors:
		content_errors.append(error)
		push_error(error)

func _default_profile():
	return {
		"resources": {},
		"unlocked_nodes": [],
		"cleared_missions": [],
		"completed_challenges": {}
	}

func _add_resources(target, added):
	for type in added:
		target[type] = target.get(type, 0) + added[type]

func _ready():
	profile = _default_profile()
	load_game()
	_load_content()
