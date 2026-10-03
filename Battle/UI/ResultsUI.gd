extends CanvasLayer

func show_result(result):
	var lines = ["Turns: %d" % result["turns"]]
	
	if result["outcome"] == "victory":
		$Center/VBox/Title.text = "Victory"
		
		var summary = result["summary"]
		if summary["first_clear"]:
			lines.append("First clear!")
		for description in summary["new_challenges"]:
			lines.append("Challenge complete: %s" % description)
		lines.append("Rewards: %s" % Game.resources_text(summary["rewards"], "+"))
		lines.append("Total: %s" % Game.resources_text(Game.profile["resources"]))
	else:
		$Center/VBox/Title.text = "Defeat"
	
	$Center/VBox/Summary.text = "\n".join(lines)
	visible = true

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_missions_button_pressed():
	Game.go_to_mission_select()
