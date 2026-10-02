extends Node2D

@export var tile_scene: PackedScene
@export var unit_scene: PackedScene

@onready var Grid = preload("Grid.gd")
@onready var AI = preload("AI.gd")
@onready var MissionData = preload("res://Data/Missions.gd")
@onready var UnitData = preload("res://Data/Units.gd")

signal animation_done

const TILE_SIZE = 32
const TILE_OFFSET_X = 150
const TILE_OFFSET_Y = 34

const TARGETING_DIRECTIONS = {
	"rook": [[1, 0], [-1, 0], [0, 1], [0, -1]],
	"bishop": [[1, 1], [1, -1], [-1, 1], [-1, -1]],
	"queen": [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
}

# Temporary until squad select exists
const DEFAULT_MISSION = "training_node"
const DEFAULT_SQUAD = ["hack", "hack_support"]

var mission
var squad

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
var ai_waiting = false
var DELAY_AI_UNIT = 0.5

var effect_handlers

var player_move_undo_redo = UndoRedo.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	if mission == null:
		mission = MissionData.MISSIONS[DEFAULT_MISSION]
	if squad == null:
		squad = DEFAULT_SQUAD
	
	var grid_tile_states = Grid.new(mission["grid"])

	var grid_size = grid_tile_states.get_size()
	
	height = grid_size["height"]
	width = grid_size["width"]

	_init_tiles(grid_tile_states)

	_init_units()
	
	connect("animation_done", Callable(self, "_ai_animation_done"))
	
	effect_handlers = {
		"damage": Callable(self, "_effect_damage"),
		"heal": Callable(self, "_effect_heal"),
		"hp_max_add": Callable(self, "_effect_hp_max_add"),
		"moves_max_add": Callable(self, "_effect_moves_max_add")
	}

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
	
	var placements = []
	for i in squad.size():
		var spawn = mission["spawn_tiles"][i]
		placements.append({
			"x": spawn[0],
			"y": spawn[1],
			"team": "player",
			"unit": squad[i]
		})
	for enemy in mission["enemies"]:
		placements.append({
			"x": enemy["x"],
			"y": enemy["y"],
			"team": "ai",
			"unit": enemy["unit"],
			"behavior": enemy["behavior"]
		})
	
	for u in placements:
		var unit = unit_scene.instantiate()
		var data = UnitData.UNITS[u["unit"]]
		var x = u["x"]
		var y = u["y"]
		var team = u["team"]
		
		unit.connect("damaged", Callable(self, "_handle_unit_damaged"))
		unit.connect("killed", Callable(self, "_handle_unit_killed"))
		unit.connect("healed", Callable(self, "_handle_unit_healed"))
		unit.connect("animation", Callable(self, "_ai_wait_animation"))
		
		unit.x = x
		unit.y = y
		unit.team = team
		unit.position = Vector2(
			x*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_X,
			y*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_Y
		)
		
		unit.type = data["name"]
		unit.sprite_main = data["sprite_main"]
		unit.sprite_shadow = data["sprite_shadow"]
		
		unit.hp_max = data["hp_max"]
		unit.moves_max = data["moves_max"]
		
		unit.abilities = data["abilities"].duplicate(true)
		if u["team"] == "ai":
			unit.behavior = u["behavior"].duplicate(true)
		
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
		print("AI TURN")
		for unit in units_live_ai:
			if unit.active:
				unit_selected = unit
				await _ai_await_move()
				await ai_handler.handle_unit(unit)
				unit.active = false
				await get_tree().create_timer(DELAY_AI_UNIT).timeout
	_check_if_turn_done()

func _ai_await_move():
	if ai_waiting:
		await animation_done

func _ai_wait_animation():
	ai_waiting = true

func _ai_animation_done():
	ai_waiting = false

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
		if target_unit && _is_valid_ability_target(unit, target_unit, ability):
			unit.animate_ability(target_unit, ability)
			
			for effect in ability["effects"]:
				effect_handlers[effect["type"]].call(effect, target_unit)
			
			unit.active = false
			
			if ability.has('size_cost'):
				unit.damage(ability.size_cost)
			
			_check_if_turn_done()

func _is_valid_ability_target(unit, target_unit, ability):
	var relation = "enemy"
	if target_unit == unit:
		relation = "self"
	elif target_unit.team == unit.team:
		relation = "ally"
	
	return ability["targets"].has(relation)

func _effect_damage(effect, target_unit):
	target_unit.damage(effect["amount"])

func _effect_heal(effect, target_unit):
	target_unit.heal(effect["amount"])

func _effect_hp_max_add(effect, target_unit):
	target_unit.hp_max = target_unit.hp_max + effect["amount"]

func _effect_moves_max_add(effect, target_unit):
	target_unit.moves_max = target_unit.moves_max + effect["amount"]

func _handle_unit_damaged(unit):
	_clear_unit_from_grid(unit)
	
	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)
	
	emit_signal("animation_done")

func _handle_unit_healed(unit):
	_clear_unit_from_grid(unit)
	
	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)
	
	unit.update_body_positions(grid_units)
	
	emit_signal("animation_done")

func _handle_unit_killed(unit):
	if unit_selected == unit:
		unit_selected = null
		click_state = "default"
	
	units_live_player.erase(unit)
	units_live_ai.erase(unit)
	_clear_unit_from_grid(unit)
	
	emit_signal("animation_done")

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

	_clear_unit_from_grid(unit)

	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)

	unit.update_body_positions(grid_units)

func _handle_unit_select(unit):
	unit_selected = unit
	_hud_show_unit()
	
func _unit_ability_get_legal_range(unit, ability):
	# TODO: Show all possible tiles within range when using movement
	#var tiles_postmove = []
	
	return {
		"immediate": _ability_get_range_from(unit.x, unit.y, unit, ability)
	}

func _ability_get_range_from(x, y, unit, ability):
	var targeting = "manhattan"
	if ability.has("targeting"):
		targeting = ability["targeting"]
	
	var blockers = []
	if ability.has("blockers"):
		blockers = ability["blockers"]
	
	var origin = grid_tiles.get_value(x, y)
	
	if targeting == "manhattan":
		return _range_manhattan(origin, unit, ability["ability_range"], blockers)
	
	return _range_lines(
		origin,
		unit,
		ability["ability_range"],
		blockers,
		TARGETING_DIRECTIONS[targeting]
	)

func _range_manhattan(origin, unit, ability_range, blockers):
	var tiles = []
	var visited = [origin]
	var tiles_to_explore_curr = []
	var tiles_to_explore_next = [origin]
	
	for depth in ability_range:
		tiles_to_explore_curr = tiles_to_explore_next.duplicate()
		tiles_to_explore_next.clear()
		
		for tile in tiles_to_explore_curr:
			if tile != origin && _is_shot_blocker(tile, unit, blockers):
				continue
			
			for tile_next in grid_tiles.get_adjacent_values(tile.x, tile.y):
				if !visited.has(tile_next):
					visited.append(tile_next)
					tiles.append(tile_next)
					tiles_to_explore_next.append(tile_next)
	
	return tiles

func _range_lines(origin, unit, ability_range, blockers, directions):
	var tiles = []
	
	for direction in directions:
		for step in range(1, ability_range + 1):
			var x = origin.x + direction[0] * step
			var y = origin.y + direction[1] * step
			
			if x < 0 || y < 0 || x >= width || y >= height:
				break
			
			var tile = grid_tiles.get_value(x, y)
			tiles.append(tile)
			
			if _is_shot_blocker(tile, unit, blockers):
				break
	
	return tiles

func _is_shot_blocker(tile, unit, blockers):
	if blockers.has("tile") && tile.state == 0:
		return true
	
	if blockers.has("unit"):
		var unit_on_tile = grid_units.get_value(tile.x, tile.y)
		if unit_on_tile != null && unit_on_tile != unit:
			return true
	
	return false

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
	
	unit_selected.clean_body_animations()
	
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
		unit_selected.clean_body_animations()
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
			unit_selected.clean_body_animations()
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

			if unit and active_player == "player":
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
