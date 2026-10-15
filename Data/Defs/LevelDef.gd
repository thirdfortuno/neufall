@tool
class_name LevelDef
extends Node2D

const FLOOR_TILESET = "res://Levels/floor_tileset.tres"

@export var mission_name: String = ""
@export var company: CompanyDef
@export_multiline var mission_info: String = ""
@export var max_generation: int = 1
@export var max_memory: int = 0
@export_enum("eliminate_all", "reach_tile", "kill_unit") var victory_type: String = "eliminate_all"
@export var first_clear_reward: Array[ResourceAmount] = []
@export var requires: Array[PackedScene] = []
@export var challenges: Array[ChallengeDef] = []

@export_tool_button("Add Floor") var add_floor_button = add_floor

func add_floor():
	var scene_root = get_tree().edited_scene_root
	if scene_root != self || get_node_or_null("Floor"):
		return
	
	var layer = TileMapLayer.new()
	layer.name = "Floor"
	layer.tile_set = load(FLOOR_TILESET)
	layer.scale = Vector2(0.5, 0.5)
	add_child(layer)
	move_child(layer, 0)
	layer.owner = scene_root

func _ready():
	if Engine.is_editor_hint():
		add_floor.call_deferred()
