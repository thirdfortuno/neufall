class_name ChallengeDef
extends Resource

@export var id: String = ""
@export var description: String = ""
@export_enum("win_within_turns", "no_unit_lost", "max_generation", "max_units", "only_tag", "require_tag") var type: String = "win_within_turns"
@export var value: int = 0
@export var tag: String = ""
@export var reward: Dictionary = {}
