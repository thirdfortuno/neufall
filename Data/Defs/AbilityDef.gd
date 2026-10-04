class_name AbilityDef
extends Resource

@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var ability_range: int = 1
@export_enum("manhattan", "rook", "bishop", "queen") var targeting: String = "manhattan"
@export_flags("tile", "unit") var blockers: int = 0
@export_flags("enemy", "ally", "self", "tile") var targets: int = 1
@export var effects: Array[EffectDef] = []
@export var size_requirement: int = 0
@export var size_cost: int = 0
