extends Node

onready var Grid = preload("Grid.gd")

var height
var width

var grid_tiles
var grid_units

var units_live_player = []
var units_live_ai = []

func handle_unit(unit):
	_update_state()
	if unit.behavior.version == 1:
		var units_in_range = []
		var target_unit
		if unit.behavior.search:
			units_in_range = _unit_search(unit)
		if units_in_range.size() == 0:
			if unit.behavior.peace:
				_unit_peace(unit)
		else:
			if unit.behavior.war:
				target_unit = _unit_war(unit, units_in_range)

func _unit_search(unit):
	for search in unit.behavior.search:
		if search.method == "absolute":
			return _unit_search_absolute(unit, search.range)

func _unit_peace(unit):
	for peace in unit.behavior.peace:
		if peace.method == "roam":
			while unit.moves_available:
				var legal_tiles = _unit_max_mobility(unit).adjacent
				legal_tiles.shuffle()
				get_parent()._handle_unit_move(legal_tiles[0])

func _unit_war(unit, units_in_range):
	var unit_to_target = units_in_range.duplicate()
	for war in unit.behavior.war:
		if unit_to_target.size() == 1:
			break
		match(war.method):
			"nearest":
				var closest = grid_units.get_distance(
					unit_to_target[0].x,
					unit_to_target[0].y,
					unit.x,
					unit.y
				)
				var units_to_check = unit_to_target.duplicate()
				for target_unit in units_to_check:
					var target_closest = 99999
					for body in target_unit.bodies:
						var distance = grid_units.get_distance(
							body.x,
							body.y,
							unit.x,
							unit.y
						)
						if distance < target_closest:
							target_closest = distance
					if target_closest > closest:
						unit_to_target.erase(target_unit)
					elif target_closest < closest:
						unit_to_target.clear()
						unit_to_target.append(target_unit)
			"weakest":
				var weakest = unit_to_target[0].bodies.size()
				var units_to_check = unit_to_target.duplicate()
				for target_unit in units_to_check:
					print(target_unit, target_unit.bodies.size())
					if target_unit.bodies.size() > weakest:
						unit_to_target.erase(target_unit)
					elif target_unit.bodies.size() < weakest:
						unit_to_target.clear()
						unit_to_target.append(target_unit)
			"strongest":
				var strongest = unit_to_target[0].bodies.size()
				var units_to_check = unit_to_target.duplicate()
				for target_unit in units_to_check:
					if target_unit.bodies.size() < strongest:
						unit_to_target.erase(target_unit)
					elif target_unit.bodies.size() > strongest:
						unit_to_target.clear()
						unit_to_target.append(target_unit)
			"random":
				unit_to_target.shuffle()
				unit_to_target.resize(1)
			_:
				unit_to_target.resize(1)
	return unit_to_target[0]

func _unit_max_mobility(unit):
	return get_parent()._unit_move_get_legal_range(unit, unit.moves_available)

func _unit_search_absolute(unit, search_range):
	var curr_tile = grid_tiles.get_value(unit.x, unit.y)
	var tiles_to_explore_curr = []
	var tiles_to_explore_next = []
	var tiles_in_range = []
	var units_in_range = []
	
	tiles_to_explore_next.append(curr_tile)
	
	for depth in search_range + 1:
		tiles_to_explore_curr = tiles_to_explore_next.duplicate()
		tiles_to_explore_next.clear()
		
		for tile in tiles_to_explore_curr:
			var x = tile.x
			var y = tile.y
			
			if !tiles_in_range.has(tile):
				tiles_in_range.append(tile)
		
			for tile_next in grid_tiles.get_adjacent_values(x, y):
				tiles_to_explore_next.append(tile_next)
	
	for tile in tiles_in_range:
		var tile_unit = grid_units.get_value(tile.x, tile.y)
		if tile_unit != null and units_live_player.find(tile_unit) != -1:
			if units_in_range.find(tile_unit) == -1:
				units_in_range.append(tile_unit)
	
	return units_in_range

func _update_state():
	height = get_parent().height
	width = get_parent().width

	grid_tiles= get_parent().grid_tiles
	grid_units= get_parent().grid_units

	units_live_player = get_parent().units_live_player
	units_live_ai = get_parent().units_live_ai
