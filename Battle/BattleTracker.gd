extends Node

signal battle_finished(result)

var finished = false
var victory_checks
var challenge_checks

var squad = []
var turns = 0
var units_lost = 0

func start_battle(unit_ids):
	squad = unit_ids

func turn_started():
	turns = turns + 1

func unit_killed(unit):
	if unit.team == "player":
		units_lost = units_lost + 1
	check()

func check():
	if finished:
		return
	
	var battle = get_parent()
	var victory = battle.mission["victory"]
	
	if battle.units_live_player.size() == 0:
		_finish("defeat")
	elif victory_checks[victory["type"]].call(battle, victory):
		_finish("victory")

func _finish(outcome):
	finished = true
	
	var challenges_met = []
	if outcome == "victory":
		for challenge in get_parent().mission["challenges"]:
			if challenge_checks[challenge["type"]].call(challenge["params"]):
				challenges_met.append(challenge["id"])
	
	battle_finished.emit({
		"outcome": outcome,
		"turns": turns,
		"units_lost": units_lost,
		"challenges_met": challenges_met
	})

func _victory_eliminate_all(battle, victory):
	return battle.units_live_ai.size() == 0

func _victory_reach_tile(battle, victory):
	var unit = battle.grid_units.get_value(victory["x"], victory["y"])
	return unit != null && unit.team == "player"

func _victory_kill_unit(battle, victory):
	for unit in battle.units_live_ai:
		if unit.enemy_id == victory["enemy"]:
			return false
	return true

func _challenge_win_within_turns(params):
	return turns <= params["turns"]

func _challenge_no_unit_lost(params):
	return units_lost == 0

func _challenge_max_generation(params):
	for unit_id in squad:
		if Game.units[unit_id]["generation"] > params["generation"]:
			return false
	return true

func _challenge_max_units(params):
	return squad.size() <= params["count"]

func _challenge_only_tag(params):
	for unit_id in squad:
		if !Game.units[unit_id]["tags"].has(params["tag"]):
			return false
	return true

func _challenge_require_tag(params):
	var count = 0
	for unit_id in squad:
		if Game.units[unit_id]["tags"].has(params["tag"]):
			count = count + 1
	return count >= params["count"]

func _ready():
	victory_checks = {
		"eliminate_all": Callable(self, "_victory_eliminate_all"),
		"reach_tile": Callable(self, "_victory_reach_tile"),
		"kill_unit": Callable(self, "_victory_kill_unit")
	}
	
	challenge_checks = {
		"win_within_turns": Callable(self, "_challenge_win_within_turns"),
		"no_unit_lost": Callable(self, "_challenge_no_unit_lost"),
		"max_generation": Callable(self, "_challenge_max_generation"),
		"max_units": Callable(self, "_challenge_max_units"),
		"only_tag": Callable(self, "_challenge_only_tag"),
		"require_tag": Callable(self, "_challenge_require_tag")
	}
