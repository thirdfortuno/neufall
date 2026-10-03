class_name TechNodeDef
extends Resource

@export var unit: UnitDef
@export var cost: Dictionary = {}
@export var requires: Array[TechNodeDef] = []
@export var position: Vector2 = Vector2.ZERO
