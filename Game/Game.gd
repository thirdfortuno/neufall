extends Node

const SAVE_PATH = "user://save.dat"

var profile

func has_completed(mission_id, challenge_id):
	return profile["completed_challenges"].get(mission_id, []).has(challenge_id)

func completed_challenges(mission_id):
	return profile["completed_challenges"].get(mission_id, [])

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
