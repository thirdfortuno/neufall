@tool
class_name EnemyMarker
extends Marker2D

@export var unit: UnitDef
@export var behavior: BehaviorDef
@export var is_target: bool = false

func _draw():
	if Engine.is_editor_hint():
		draw_rect(Rect2(-16, -16, 32, 32), Color(1.0, 0.2, 0.2, 0.5))
