extends Node2D

export(PackedScene) var tile_scene

onready var Grid = preload("Grid.gd")

const TILE_SIZE = 64

var grid_input = [
	[0,0,0,0,0,0,0,0],
	[0,1,1,1,1,1,1,0],
	[0,1,1,1,1,1,0,0],
	[0,1,1,1,1,1,1,0],
	[0,0,0,0,0,0,0,0]
]

var tile_selected

# Called when the node enters the scene tree for the first time.
func _ready():
	var grid_tile_states = Grid.new(grid_input)

	var grid_size = grid_tile_states.getSize()

	var grid_tiles = Grid.new(grid_size["width"], grid_size["height"])

	for x in grid_size["width"]:
		for y in grid_size["height"]:
			var tile = tile_scene.instance()

			tile.x = x
			tile.y = y
			tile.state = grid_tile_states.getValue(x,y)
			tile.position = Vector2(x*TILE_SIZE + TILE_SIZE/2, y*TILE_SIZE + TILE_SIZE/2)

			tile.connect("selected", self, "_on_tile_select")

			add_child(tile)
			grid_tiles.setValue(x,y,tile)

func _on_tile_select(tile):
	if tile_selected:
		tile_selected.unselect()
	tile_selected = tile
	tile_selected.select()

func _input(ev):
	if Input.is_key_pressed(KEY_Q):
		if tile_selected:
			tile_selected.unselect()
		tile_selected = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
