extends Node

signal battle_finished(result)

var finished = false
var victory_checks

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
	battle_finished.emit({
		"outcome": outcome
	})

func _victory_eliminate_all(battle, victory):
	return battle.units_live_ai.size() == 0

func _ready():
	victory_checks = {
		"eliminate_all": Callable(self, "_victory_eliminate_all")
	}
