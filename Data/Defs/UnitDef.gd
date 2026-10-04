class_name UnitDef
extends Resource

@export var unit_name: String = ""
@export var abbr: String = ""
@export_enum("player", "enemy") var side: String = "player"
@export var generation: int = 1
@export var starts_unlocked: bool = false
@export var tags: PackedStringArray = []
@export var hp_max: int = 3
@export var moves_max: int = 3
@export var sprite_main: Texture2D
@export var sprite_shadow: Texture2D
@export var abilities: Array[AbilityDef] = []
