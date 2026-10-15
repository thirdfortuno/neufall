class_name UnitDef
extends Resource

@export var unit_name: String = ""
@export_multiline var description: String = ""
@export var abbr: String = ""
@export_enum("player", "enemy") var side: String = "player"
@export var generation: int = 1
@export var starts_unlocked: bool = false
@export var tags: PackedStringArray = []
@export var hp_max: int = 3
@export var moves_max: int = 3
@export var memory: int = 1
@export_color_no_alpha var primary_bg_color: Color = Color.BLACK
@export_color_no_alpha var secondary_bg_color: Color = Color.BLACK
@export var sprite_main: Texture2D
@export var sprite_shadow: Texture2D
@export var sound_move: AudioStream
@export var sound_hurt: AudioStream
@export var sound_death: AudioStream
@export var abilities: Array[AbilityDef] = []
