@tool
class_name GoalMarker
extends Marker2D

func _draw():
	if Engine.is_editor_hint():
		draw_rect(Rect2(-16, -16, 32, 32), Color(1.0, 0.9, 0.2, 0.5))
