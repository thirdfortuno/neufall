class_name TechNodeDef
extends Resource

@export var unit: UnitDef
@export var cost: Array[ResourceAmount] = []
@export var required_units: Array[UnitDef] = []
@export_enum("all", "any") var requires_mode: String = "all"
