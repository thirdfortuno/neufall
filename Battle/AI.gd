extends Node

@onready var Grid = preload("Grid.gd")

var DELAY_MOVE = 0.5
var DELAY_TARGET = 0.5
var DELAY_ATTACK = 0.5

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
				await _unit_peace(unit)
		else:
			if unit.behavior.war:
				target_unit = _unit_war(unit, units_in_range)
				var grid_distance = _get_distance_from_target(
					target_unit,
					unit.abilities[0],
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
			_show_move_range(unit)
			while unit.moves_available:
				await get_tree().create_timer(DELAY_MOVE).timeout
				var legal_tiles = _unit_max_mobility(unit).adjacent
				if legal_tiles.size() == 0:
					break
				legal_tiles.shuffle()
				get_parent()._handle_unit_move(legal_tiles[0], unit)
				_show_move_range(unit)
			get_parent()._clear_tile_tags()

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

func _get_distance_from_target(target, ability, unit):
	var grid_distance = Grid.new(width, height)
	var target_tiles = []
	for body in target.bodies:
		target_tiles.append(grid_tiles.get_value(body.x, body.y))
	
	for x in width:
		for y in height:
			if grid_tiles.get_value(x, y).state == 0:
				continue
			if grid_units.get_value(x, y) != unit and grid_units.get_value(x, y) != null:
				continue
			
			var tiles_in_range = get_parent()._ability_get_range_from(
				x,
				y,
				unit,
				ability
			)
			for target_tile in target_tiles:
				if tiles_in_range.has(target_tile):
					grid_distance.set_value(x, y, 0)
					break
	
	return grid_distance

func _path_to_target(grid_distance, unit):
	var grid_parent = Grid.new(width, height)
	var grid_visited = Grid.new(width, height)
	var queue = []

	for x in width:
		for y in height:
			if grid_distance.get_value(x, y) == 0:
				if x == unit.x and y == unit.y:
					return []
				grid_parent.set_value(x, y, 0)
				grid_visited.set_value(x, y, true)
				queue.append(grid_tiles.get_value(x, y))

	queue.shuffle()

	var queue_index = 0
	var target_found = false

	while queue_index < queue.size():
		var tile_to_visit = queue[queue_index]
		queue_index = queue_index + 1

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
			if grid_visited.get_value(neighbor.x, neighbor.y):
				continue

			grid_visited.set_value(neighbor.x, neighbor.y, true)
			grid_parent.set_value(neighbor.x, neighbor.y, tile_to_visit)

			if neighbor.x == unit.x and neighbor.y == unit.y:
				target_found = true
				break

			queue.append(neighbor)

		if target_found:
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
	
	if moveable_path.size() > 0:
		_show_move_range(unit)

	for tile in moveable_path:
		await get_tree().create_timer(DELAY_MOVE).timeout
		get_parent()._handle_unit_move(tile, unit)
		_show_move_range(unit)

	get_parent()._clear_tile_tags()


func _use_ability_on_target(ability, target, unit):
	get_parent().ability_selected = ability
	await get_tree().create_timer(DELAY_TARGET).timeout
	_show_ability_range(unit, ability)
	await get_tree().create_timer(DELAY_ATTACK).timeout
	var tiles_in_range = get_parent()._unit_ability_get_legal_range(
		unit,
		ability
	)["immediate"]
	for body in target.bodies:
		var tile = grid_tiles.get_value(body.x, body.y)
		if tiles_in_range.has(tile):
			get_parent()._handle_unit_ability(tile, unit, ability)
			break
	get_parent()._clear_tile_tags()

func _show_move_range(unit):
	get_parent()._clear_tile_tags()
	for tile in _unit_max_mobility(unit).all:
		tile.set_ui("moveable")

func _show_ability_range(unit, ability):
	for tile in get_parent()._unit_ability_get_legal_range(unit, ability).immediate:
		tile.set_ui("damageable")

func _update_state():
	height = get_parent().height
	width = get_parent().width

	grid_tiles = get_parent().grid_tiles
	grid_units = get_parent().grid_units

	units_live_player = get_parent().units_live_player
	units_live_ai = get_parent().units_live_ai
