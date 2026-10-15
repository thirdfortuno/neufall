extends AcceptDialog

func _on_overworld_button_pressed():
	$LeaveDialog.popup_centered()

func _on_leave_confirmed():
	Game.go_to_overworld()
