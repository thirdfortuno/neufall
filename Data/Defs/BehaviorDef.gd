class_name BehaviorDef
extends Resource

@export var search_range: int = 15
@export_enum("roam") var peace_method: String = "roam"
@export var war_methods: PackedStringArray = ["nearest", "weakest", "random"]
