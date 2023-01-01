extends Node2D

export(PackedScene) var tile_scene
export(PackedScene) var unit_scene

onready var Grid = preload("Grid.gd")

const TILE_SIZE = 32

var grid_input = [
	[0,0,0,0,0,0,0,0],
	[0,1,1,1,1,1,1,0],
	[0,1,1,1,1,1,0,0],
	[0,1,1,1,1,1,1,0],
	[0,0,0,0,0,0,0,0]
]

var unit_input = [
	{
		"x": 1,
		"y": 2
	}
]

var height
var width

var tile_selected

var units_live = []

# Called when the node enters the scene tree for the first time.
func _ready():
	var grid_tile_states = Grid.new(grid_input)

	var grid_size = grid_tile_states.getSize()
	
	height = grid_size["height"]
	width = grid_size["width"]

	_init_tiles(grid_tile_states)

	_init_units()

func _init_tiles(grid_tile_states):
	var grid_tiles = Grid.new(width, height)

	for x in width:
		for y in height:
			var tile = tile_scene.instance()

			tile.x = x
			tile.y = y
			tile.state = grid_tile_states.getValue(x,y)
			tile.position = Vector2(x*TILE_SIZE + TILE_SIZE/2, y*TILE_SIZE + TILE_SIZE/2)

			tile.connect("selected", self, "_on_tile_select")

			add_child(tile)
			grid_tiles.setValue(x,y,tile)

func _init_units():
	var grid_units = Grid.new(width, height)
	
	for u in unit_input:
		var unit = unit_scene.instance()
		var x = u["x"]
		var y = u["y"]
		
		unit.x = x
		unit.y = y
		unit.position = Vector2(x*TILE_SIZE + TILE_SIZE/2, y*TILE_SIZE + TILE_SIZE/2)
		
		add_child(unit)
		grid_units.setValue(x,y,unit)
		units_live.append(unit)

func _on_tile_select(tile):
	if tile_selected:
		tile_selected.unselect()
	tile_selected = tile
	tile_selected.select()

func _input(_ev):
	if Input.is_key_pressed(KEY_Q):
		if tile_selected:
			tile_selected.unselect()
		tile_selected = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
