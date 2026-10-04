extends Control

@onready var Content = $Content

func _gui_input(event):
	if (
			event is InputEventMouseMotion &&
			event.button_mask & MOUSE_BUTTON_MASK_LEFT
	):
		Content.position = Content.position + event.relative
