@tool
class_name BodyMarker
extends Marker2D

func _draw():
	if Engine.is_editor_hint():
		draw_rect(Rect2(-12, -12, 24, 24), Color(1.0, 1.0, 1.0, 0.5))
