extends Node

@onready var Grid = preload("Grid.gd")

var DELAY_MOVE = 0.5

var height
var width

var grid_tiles
var grid_units

var units_live_player = []
var units_live_ai = []

func handle_unit(unit):
	_update_state()
	print(unit)
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
				var grid_distance = _get_distance_from_target(
					target_unit,
					unit.abilities[0].ability_range,
					unit
				)
				var path = _path_to_target(grid_distance, unit)
				print(path)
				await _move_along_path(path, unit)
				await _use_ability_on_target(unit.abilities[0], target_unit, unit)
				print(unit, "moved")

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
				get_parent()._handle_unit_move(legal_tiles[0], unit)

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
	var units_in_range = []
	
	for player_unit in units_live_player:
		for body in player_unit.bodies:
			if grid_units.get_distance(
				body.x,
				body.y,
				unit.x,
				unit.y
			) <= search_range:
				units_in_range.append(player_unit)
				break
	
	return units_in_range

func _get_distance_from_target(target, ability_range, unit):
	var grid_distance = Grid.new(width, height)
	var tiles_to_explore_curr = []
	var tiles_to_explore_next = []
	var tiles_explored = []
	var tiles_in_range = []
	var distance = 0
	for body in target.bodies:
		tiles_to_explore_next.append(grid_tiles.get_value(body.x, body.y))
	
	while distance <= ability_range:
		tiles_to_explore_curr = tiles_to_explore_next.duplicate()
		tiles_explored.append_array(tiles_to_explore_curr)
		tiles_to_explore_next.clear()
		
		for tile in tiles_to_explore_curr:
			var x = tile.x
			var y = tile.y
			
			if distance <= ability_range:
				grid_distance.set_value(x, y, 0)
				tiles_in_range.append(grid_tiles.get_value(x,y))

			for tile_next in grid_tiles.get_adjacent_values(x, y):
				if tiles_explored.find(tile_next) == -1:
					tiles_to_explore_next.append(tile_next)
		
		distance = distance + 1
	
	for tile in tiles_in_range:
		var x = tile.x
		var y = tile.y
		if grid_tiles.get_value(x, y).state == 0:
			grid_distance.set_value(x, y, null)
		if grid_units.get_value(x, y) != unit and grid_units.get_value(x, y) != null:
			grid_distance.set_value(x, y, null)
	
	return grid_distance

func _path_to_target(grid_distance, unit):
	var grid_weight = Grid.new(width, height)
	var grid_parent = Grid.new(width, height)
	var open_list = []
	var closed_list = []
	
	for x in width:
		for y in height:
			if grid_distance.get_value(x, y) == 0:
				if grid_units.get_value(x, y) == unit:
					return []
				grid_weight.set_value(x, y, 0)
				grid_parent.set_value(x, y, 0)
				open_list.append(grid_tiles.get_value(x, y))
			else:
				grid_weight.set_value(x, y, 9999999999)
	
	open_list.shuffle()
	
	while open_list.size() != 0:
		var smallest_distance = grid_weight.get_value(
			open_list[0].x,
			open_list[0].y
		)
		var tile_to_visit = open_list[0]
		for tile in open_list:
			if grid_weight.get_value(tile.x, tile.y) < smallest_distance:
				smallest_distance = grid_weight.get_value(tile.x, tile.y)
				tile_to_visit = tile
		
		open_list.erase(tile_to_visit)
		
		if closed_list.find(tile_to_visit) != -1:
			continue
		
		closed_list.append(tile_to_visit)
		
		var neighbors = grid_tiles.get_adjacent_values(
			tile_to_visit.x,
			tile_to_visit.y
		)
		
		for neighbor in neighbors:
			if neighbor.state == 0:
				continue
			if grid_units.get_value(neighbor.x, neighbor.y) != null:
				if grid_units.get_value(neighbor.x, neighbor.y) != unit:
					continue
			
			var tentative_dist = grid_weight.get_value(
				tile_to_visit.x,
				tile_to_visit.y
			) + 1
			
			if tentative_dist < grid_weight.get_value(neighbor.x, neighbor.y):
				grid_weight.set_value(neighbor.x, neighbor.y, tentative_dist)
				grid_parent.set_value(neighbor.x, neighbor.y, tile_to_visit)
				open_list.append(neighbor)
			
			if grid_units.get_value(neighbor.x, neighbor.y) == unit:
				open_list.clear()
				break
	
	var route = []
	var route_tile = grid_parent.get_value(unit.x, unit.y)
	while typeof(route_tile) != TYPE_INT and route_tile != null:
		route.append(route_tile)
		route_tile = grid_parent.get_value(route_tile.x, route_tile.y)
	
	return route
	
func _move_along_path(path, unit):
	var moveable_path = path.duplicate()
	
	if path.size() > unit.moves_available:
		moveable_path.resize(unit.moves_available)
	
	for tile in moveable_path:
		await get_tree().create_timer(DELAY_MOVE).timeout
		get_parent()._handle_unit_move(tile, unit)
		

func _use_ability_on_target(ability, target, unit):
	get_parent().ability_selected = ability
	for body in target.bodies:
		if grid_units.get_distance(
			body.x,
			body.y,
			unit.x,
			unit.y
		) <= ability.ability_range:
			await get_tree().create_timer(DELAY_MOVE).timeout
			get_parent()._handle_unit_ability(grid_tiles.get_value(
				body.x,
				body.y
			), unit, ability)
			break

func _update_state():
	height = get_parent().height
	width = get_parent().width

	grid_tiles = get_parent().grid_tiles
	grid_units = get_parent().grid_units

	units_live_player = get_parent().units_live_player
	units_live_ai = get_parent().units_live_ai
