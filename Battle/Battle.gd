extends Node2D

@export var tile_scene: PackedScene
@export var unit_scene: PackedScene

@onready var Grid = preload("Grid.gd")
@onready var AI = preload("AI.gd")

const TILE_SIZE = 32
const TILE_OFFSET_X = 150
const TILE_OFFSET_Y = 34

"""
var grid_input = [
	[1,1,1,1],
	[1,1,1,1],
	[1,1,1,0],
	[1,1,1,1]
]

"""
var grid_input = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,0,1,1,1,1,1,1],
	[1,1,1,1,1,1,0,0,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,1,0,1,0,0,0,1,1,1,1,1,1],
	[1,0,1,1,1,0,0,0,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

var unit_input = [
	{
		"x": 1,
		"y": 1,
		"team": "player",
		"data": {
			"type": "Hack",
			"hp_max": 3,
			"moves_max": 5,
			"abilities": [
				{
					"ability_name": "Slice",
					"damage": 2,
					"ability_range": 1
				},
				{
					"ability_name": "Dice",
					"damage": 2,
					"ability_range": 2,
					"size_requirement": 2,
					"size_cost": 1
				}
			]
		}
	},
	{
		"x": 2,
		"y": 2,
		"team": "player",
		"data": {
			"type": "Hack",
			"hp_max": 3,
			"moves_max": 5,
			"abilities": [
				{
					"ability_name": "Steroids",
					"hp_max_add": 2,
					"moves_max_add": 2,
					"ability_range": 1
				},
				{
					"ability_name": "Heal",
					"heal": 5,
					"ability_range": 2
				}
			]
		}
	},
	{
		"x": 3,
		"y": 3,
		"team": "ai",
		"data": {
			"type": "Security Camera",
			"hp_max": 3,
			"moves_max": 3,
			"abilities": [
				{
					"ability_name": "Slice",
					"damage": 2,
					"ability_range": 1
				}
			]
		},
		"behavior": {
			"version": 1,
			"search": [
				{
					"range": 15,
					"method": "absolute"
				}
			],
			"peace": [
				{
					"method": "roam"
				}
			],
			"war": [
				{
					"method": "nearest"
				},
				{
					"method": "weakest"
				},
				{
					"method": "random"
				}
			]
		}
	},
]

var height
var width

var grid_tiles
var grid_units

var active_player = "player"
var tile_selected
var unit_selected
var ability_selected

var click_state = "default"

var units_live_player = []
var units_live_ai = []

var ai_handler

var player_move_undo_redo = UndoRedo.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	var grid_tile_states = Grid.new(grid_input)

	var grid_size = grid_tile_states.get_size()
	
	height = grid_size["height"]
	width = grid_size["width"]

	_init_tiles(grid_tile_states)

	_init_units()
	
	ai_handler = AI.new()
	add_child(ai_handler)

#################
# INITALIZATION #
#################

func _init_tiles(grid_tile_states):
	grid_tiles = Grid.new(width, height)

	for x in width:
		for y in height:
			var tile = tile_scene.instantiate()

			tile.x = x
			tile.y = y
			tile.state = grid_tile_states.get_value(x,y)
			tile.position = Vector2(
				x*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_X,
				y*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_Y
			)

			tile.connect("selected", Callable(self, "_on_tile_select"))

			add_child(tile)
			grid_tiles.set_value(x,y,tile)

func _init_units():
	grid_units = Grid.new(width, height)
	
	for u in unit_input:
		var unit = unit_scene.instantiate()
		var x = u["x"]
		var y = u["y"]
		var team = u["team"]
		
		unit.connect("damaged", Callable(self, "_handle_unit_damaged"))
		unit.connect("killed", Callable(self, "_handle_unit_killed"))
		unit.connect("healed", Callable(self, "_handle_unit_healed"))
		
		unit.x = x
		unit.y = y
		unit.team = team
		unit.position = Vector2(
			x*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_X,
			y*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_Y
		)
		
		unit.type = u["data"]["type"]
		
		unit.hp_max = u["data"]["hp_max"]
		unit.moves_max = u["data"]["moves_max"]
		
		unit.abilities = u["data"]["abilities"]
		if u["team"] == "ai":
			unit.behavior = u["behavior"]
		
		add_child(unit)
		grid_units.set_value(x,y,unit)
		
		if team == "player":
			units_live_player.append(unit)
		elif team == "ai":
			units_live_ai.append(unit)
		

####################
# HEADS UP DISPLAY #
####################

func _hud_show_unit():
	$BattleUI.show_unit(unit_selected)

func _hud_show_tile():
	$SelectedTileUI.show_tile(tile_selected)

############
# CLEARING #
############

func _clear_tile_tags():
	for tile in grid_tiles.grid_data:
		tile.set_ui("none")

func _clear_unit_from_grid(unit):
	for x in width:
		for y in height:
			if grid_units.get_value(x, y) == unit:
				grid_units.set_value(x, y, null)

###################
# BATTLE HANDLING #
###################
func _check_if_turn_done():
	if active_player == "player":
		for unit in units_live_player:
			if unit.active:
				return false
	elif active_player == "ai":
		for unit in units_live_ai:
			if unit.active:
				return false
	_swap_active_player()

func _swap_active_player():
	if active_player == "player":
		active_player = "ai"
		for unit in units_live_ai:
			unit.active = true
			unit.moves_available = unit.moves_max
		unit_selected = null
		_ai_decisions()
	elif active_player == "ai":
		active_player = "player"
		for unit in units_live_player:
			unit.active = true
			unit.moves_available = unit.moves_max

func _ai_decisions():
	if active_player == "ai":
		for unit in units_live_ai:
			if unit.active:
				unit_selected = unit
				ai_handler.handle_unit(unit)
				unit.active = false
	_check_if_turn_done()

#################
# UNIT HANDLING #
#################
func _is_unit_selected_active_and_on_team():
	return unit_selected.active && (unit_selected.team == active_player)

func _handle_unit_ability(tile, unit, ability):
	var ability_range = _unit_ability_get_legal_range(
			unit,
			ability
	)
	
	if ability_range["immediate"].has(tile):
		var target_unit = grid_units.get_value(tile.x, tile.y)
		if target_unit:
			if ability.has('damage'):
				target_unit.damage(ability_selected["damage"])
				
			if ability.has('heal'):
				target_unit.heal(ability_selected['heal'])
				
			if ability.has('hp_max_add'):
				target_unit.hp_max = target_unit.hp_max + ability.hp_max_add
			
			if ability.has('moves_max_add'):
				target_unit.moves_max = target_unit.moves_max
				+ ability.moves_max_add
			
			unit.active = false
			
			if ability.has('size_cost'):
				unit.damage(ability.size_cost)
			
			_check_if_turn_done()

func _handle_unit_damaged(unit):
	_clear_unit_from_grid(unit)
	
	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)

func _handle_unit_healed(unit):
	_clear_unit_from_grid(unit)
	
	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)
	
	unit.update_body_positions(grid_units)

func _handle_unit_killed(unit):
	if unit_selected == unit:
		unit_selected = null
		click_state = "default"
	
	units_live_player.erase(unit)
	units_live_ai.erase(unit)
	_clear_unit_from_grid(unit)

func _player_handle_unit_move(tile, unit):
	if unit.moves_available:
		_handle_unit_move(tile, unit)
	
	var legal_range = _unit_move_get_legal_range(
		unit,
		unit.moves_available
	)
	
	unit.moveable()
	
	_clear_tile_tags()
	
	for moveable_tile in legal_range["all"]:
		moveable_tile.set_ui("moveable")
		
	tile_selected.deselect()
	tile_selected = tile
	tile_selected.select()
	_hud_show_unit()

func _handle_unit_move(tile, unit):
	var x = tile.x
	var y = tile.y
	var adjacent_tiles = grid_tiles.get_adjacent_values(unit.x, unit.y)
	
	if (adjacent_tiles.has(tile)):
		var into_self = grid_units.get_value(x, y) == unit
		unit.move_to(x, y, into_self)
	else: 
		return

	_clear_unit_from_grid(unit_selected)
	
	for body in unit_selected.bodies:
		grid_units.set_value(body.x, body.y, unit_selected)
	
	unit.update_body_positions(grid_units)

func _handle_unit_select(unit):
	unit_selected = unit
	_hud_show_unit()
	
func _unit_ability_get_legal_range(unit, ability):
	var curr_tile = grid_tiles.get_value(unit.x, unit.y)
	var tiles_to_explore_curr = []
	var tiles_to_explore_next = []
	var tiles_immediate = []
	# TODO: Show all possible tiles within range when using movement
	#var tiles_postmove = []
	
	var immediate_range = ability["ability_range"]
	
	tiles_to_explore_next.append(curr_tile)
	
	for depth in immediate_range + 1:
		tiles_to_explore_curr = tiles_to_explore_next.duplicate()
		tiles_to_explore_next.clear()
		
		for tile in tiles_to_explore_curr:
			var x = tile.x
			var y = tile.y
			
			if !tiles_immediate.has(tile):
				tiles_immediate.append(tile)
		
			for tile_next in grid_tiles.get_adjacent_values(x, y):
				tiles_to_explore_next.append(tile_next)
		
	tiles_immediate.erase(curr_tile)
	
	return {
		"immediate": tiles_immediate
	}

func _unit_move_get_legal_range(unit, move_range):
	var curr_tile = grid_tiles.get_value(unit.x, unit.y)
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
				var unit_on_tile = grid_units.get_value(x, y)
				
				if (unit_on_tile == null || unit_on_tile == unit):
					tiles_legal.append(tile)
					
					for tile_next in grid_tiles.get_adjacent_values(x, y):
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

# 
# HANDLING BUTTON PRESSES
#

func _handle_ability_button_pressed(ability):
	if !_is_unit_selected_active_and_on_team():
		return
	_clear_tile_tags()
	
	if ability.has('size_requirement'):
		if ability.size_requirement > unit_selected.bodies.size():
			return
	
	ability_selected = ability
	click_state = "unit_ability"
	
	var ability_range = _unit_ability_get_legal_range(
			unit_selected,
			ability_selected
	)
	
	for tile in ability_range["immediate"]:
		tile.set_ui("damageable")
	
	_check_if_turn_done()

func _clear_unit_move():
	_clear_unit_from_grid(unit_selected)
	for body in unit_selected.bodies:
		grid_units.set_value(
			body.x,
			body.y,
			unit_selected
		)

func _on_MoveButton_pressed():
	ability_selected = null
	if unit_selected:
		if !_is_unit_selected_active_and_on_team():
			return
			
		unit_selected.prep_premove()
		player_move_undo_redo.clear_history(false)
		player_move_undo_redo.create_action("Move Unit")
		player_move_undo_redo.add_undo_property(
			unit_selected,
			"x",
			unit_selected.x
		)
		player_move_undo_redo.add_undo_property(
			unit_selected,
			"y",
			unit_selected.y
		)
		player_move_undo_redo.add_undo_property(
			unit_selected,
			"position",
			unit_selected.position
		)
		player_move_undo_redo.add_undo_property(
			unit_selected,
			"moves_available",
			unit_selected.moves_available
		)
		player_move_undo_redo.add_undo_method(
			unit_selected.undo_move
		)
		player_move_undo_redo.add_undo_method(
			_clear_unit_move
		)
		player_move_undo_redo.commit_action()
		
		click_state = "unit_move"
		unit_selected.moveable()
		for tile in _unit_move_get_legal_range(
				unit_selected, unit_selected.moves_available
		)["all"]:
				tile.set_ui("moveable")

func _on_Ability1Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][0])

func _on_Ability2Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][1])

func _on_Ability3Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][2])

func _on_Ability4Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][3])

func _on_EndTurnButton_pressed():
	if unit_selected:
		unit_selected.active = false
		unit_selected.deselect()
		unit_selected = null
		click_state = "default"
		if tile_selected:
			tile_selected.deselect()
		tile_selected = null
	_clear_tile_tags()
	_hud_show_unit()
	_check_if_turn_done()

func _on_UndoMoveButton_pressed():
	if click_state == "unit_move" and player_move_undo_redo.has_undo:
		player_move_undo_redo.undo()
		unit_selected.update_body_positions(grid_units)
		_clear_tile_tags()
		tile_selected.deselect()
		tile_selected = grid_tiles.get_value(unit_selected.x, unit_selected.y)
		tile_selected.select()
		_hud_show_unit()
		_on_MoveButton_pressed()

#########
# INPUT #
#########

func _input(_ev):
	if (
			Input.is_key_pressed(KEY_Q) ||
			Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	):
		if tile_selected:
			tile_selected.deselect()
		tile_selected = null
		
		if unit_selected:
			unit_selected.deselect()
		unit_selected = null
		
		ability_selected = null

		click_state = "default"
		
		for tile in grid_tiles.grid_data:
			tile.set_ui(null)
		
		_handle_unit_select(null)
	
	if Input.is_key_pressed(KEY_E):
		if unit_selected:
			unit_selected.damage(2)
	
	if Input.is_key_pressed(KEY_R):
		if unit_selected:
			print(unit_selected.active)
			print(click_state)

func _on_tile_select(tile):
	match click_state:
		"default":
			if tile_selected:
				tile_selected.deselect()
			tile_selected = tile
			_hud_show_tile()
			tile_selected.select()

			var unit = grid_units.get_value(tile.x, tile.y)

			if unit:
				click_state = "unit_select"
				_handle_unit_select(unit)
		"unit_ability":
			if !_is_unit_selected_active_and_on_team():
				return
			_handle_unit_ability(tile, unit_selected, ability_selected)
			_clear_tile_tags()
			_hud_show_unit()
		"unit_move":
			if !_is_unit_selected_active_and_on_team():
				return
			_player_handle_unit_move(tile, unit_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
