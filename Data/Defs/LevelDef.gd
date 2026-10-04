class_name LevelDef
extends Node2D

@export var mission_name: String = ""
@export var max_generation: int = 1
@export_enum("eliminate_all", "reach_tile", "kill_unit") var victory_type: String = "eliminate_all"
@export var first_clear_reward: Dictionary = {}
@export var requires: PackedStringArray = []
@export var challenges: Array[ChallengeDef] = []
