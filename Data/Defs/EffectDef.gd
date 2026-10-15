class_name EffectDef
extends Resource

@export_enum("damage", "heal", "hp_max_add", "moves_max_add", "drain", "tile_set") var type: String = "damage"
@export var amount: int = 1
@export_range(0, 1) var tile_state: int = 0
@export var sound: AudioStream
