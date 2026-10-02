extends CanvasLayer

func show_result(result):
	if result["outcome"] == "victory":
		$Center/VBox/Title.text = "Victory"
	else:
		$Center/VBox/Title.text = "Defeat"
	visible = true

func _on_restart_button_pressed():
	get_tree().reload_current_scene()
