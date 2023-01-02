extends Node2D

export(PackedScene) var tile_scene
export(PackedScene) var unit_scene

onready var Grid = preload("Grid.gd")

const TILE_SIZE = 32

var grid_input = [
	[0,0,0,0,0,0,1,1,1,1],
	[0,1,1,1,1,1,1,0,1,1],
	[0,1,1,1,1,1,0,0,1,1],
	[0,1,1,1,1,1,1,1,1,1],
	[0,0,1,0,1,0,0,0,1,1],
	[0,0,1,1,1,0,0,0,1,1],
	[0,0,0,0,0,0,0,0,1,1]
]

var unit_input = [
	{
		"x": 1,
		"y": 1,
		"hp_max": 5,
		"moves_max": 4
	}
]

var height
var width

var grid_tiles
var grid_units

var tile_selected
var unit_selected

var click_state = "default"

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
	grid_tiles = Grid.new(width, height)

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
	grid_units = Grid.new(width, height)
	
	for u in unit_input:
		var unit = unit_scene.instance()
		var x = u["x"]
		var y = u["y"]
		
		unit.x = x
		unit.y = y
		unit.position = Vector2(x*TILE_SIZE + TILE_SIZE/2, y*TILE_SIZE + TILE_SIZE/2)
		
		unit.hp_max = u["hp_max"]
		unit.moves_max = u["moves_max"]
		
		add_child(unit)
		grid_units.setValue(x,y,unit)
		units_live.append(unit)

func _unit_move_get_legal_range(unit, move_range):
	var curr_tile = grid_tiles.getValue(unit.x, unit.y)
	var tiles_legal = []
	var tiles_to_explore_curr = []
	var tiles_to_explore_next = []
	var tiles_legal_adjacent = []

	tiles_to_explore_next.append(curr_tile)

	for depth in move_range + 1:
		tiles_to_explore_curr = tiles_to_explore_next.duplicate()
		tiles_to_explore_next.clear()
		
		for tile in tiles_to_explore_curr:
			var x = tile.x
			var y = tile.y
			
			if (tile.state == 1):
				var unit_on_tile = grid_units.getValue(x, y)
				
				if (unit_on_tile == null || unit_on_tile == unit):
					tiles_legal.append(tile)
					
					for tile_next in grid_tiles.getAdjacentValues(x, y):
						if (
							tiles_legal.find(tile_next) == -1 &&
							tiles_to_explore_curr.find(tile_next) == -1 &&
							tiles_to_explore_next.find(tile_next) == -1
						):
							tiles_to_explore_next.append(tile_next)
		if depth == 1:
			tiles_legal_adjacent = tiles_legal.duplicate()
	
	tiles_legal.erase(curr_tile)
	tiles_legal_adjacent.erase(curr_tile)
	
	return {
		"adjacent": tiles_legal_adjacent,
		"all": tiles_legal
	}

func _clear_tile_tags():
	for tile in grid_tiles.grid_data:
		tile.setUI("none")

func _on_tile_select(tile):
	match click_state:
		"default":
			if click_state == "default":
				if tile_selected:
					tile_selected.unselect()
				tile_selected = tile
				tile_selected.select()
				
				var unit = grid_units.getValue(tile.x, tile.y)
				
				if unit:
					unit_selected = unit
					var legal_range = _unit_move_get_legal_range(unit, unit.moves_available)
					for tile in legal_range["all"]:
						tile.setUI("moveable")
					click_state = "unit_move"
		"unit_move":
			_handle_unit_move(tile)

func _handle_unit_move(tile):
	var x = tile.x
	var y = tile.y
	var legal_range = _unit_move_get_legal_range(unit_selected, unit_selected.moves_available)
	if (legal_range["adjacent"].has(tile)):
		unit_selected.moveTo(x, y)

		_clear_tile_tags()
		var new_legal_range = _unit_move_get_legal_range(unit_selected, unit_selected.moves_available)
		for tile in new_legal_range["all"]:
			tile.setUI("moveable")
	
	var test = 0
	while test != -1:
		test = grid_units.grid_data.find(unit_selected)
		grid_units.grid_data[test] = null
	
	for body in unit_selected.bodies:
		grid_units.setValue(body.x, body.y, unit_selected)
	
	unit_selected.update_body_positions()
	
func _input(_ev):
	if Input.is_key_pressed(KEY_Q):
		if tile_selected:
			tile_selected.unselect()
		tile_selected = null
		
		unit_selected = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
