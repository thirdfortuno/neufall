@tool
class_name SpawnMarker
extends Marker2D

func _draw():
	if Engine.is_editor_hint():
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.2, 1.0, 0.2, 0.5))
