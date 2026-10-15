extends Control

const COLOR_FLOOR = Color(0.7, 0.7, 0.75)
const COLOR_SPAWN = Color(0.5, 1.0, 0.5)
const COLOR_GOAL = Color(1.0, 0.9, 0.3)
const COLOR_VIEW = Color(1.0, 1.0, 1.0)

var battle
var cell = 1.0
var origin = Vector2.ZERO

func _process(_delta):
	if battle:
		queue_redraw()

func _draw():
	if battle == null || battle.grid_tiles == null:
		return

	_update_layout()

	for tile in battle.grid_tiles.grid_data:
		if tile.state == 1:
			_draw_cell(tile.x, tile.y, COLOR_FLOOR)

	if battle.deploying:
		for spawn in battle.mission["spawn_tiles"]:
			_draw_cell(spawn[0], spawn[1], COLOR_SPAWN)

	var victory = battle.mission["victory"]
	if victory["type"] == "reach_tile":
		_draw_cell(victory["x"], victory["y"], COLOR_GOAL)

	for unit in battle.units_live_player:
		for body in unit.bodies:
			_draw_cell(body.x, body.y, unit.body_tint())
	for unit in battle.units_live_ai:
		for body in unit.bodies:
			_draw_cell(body.x, body.y, unit.body_tint())

	var view = battle.camera.view_rect()
	var top_left = _world_to_local(view.position)
	var bottom_right = _world_to_local(view.end)
	var view_local = Rect2(top_left, bottom_right - top_left).intersection(Rect2(Vector2.ZERO, size))
	if view_local.has_area():
		draw_rect(view_local, COLOR_VIEW, false, 1.0)

func _update_layout():
	cell = min(size.x / battle.width, size.y / battle.height)
	if cell >= 1.0:
		cell = floor(cell)
	origin = (size - Vector2(battle.width, battle.height) * cell) / 2

func _draw_cell(x, y, color):
	var gap = 1.0 if cell >= 3.0 else 0.0
	draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell - gap, cell - gap)), color)

func _world_to_local(world_point):
	var grid_point = (world_point - Vector2(battle.TILE_OFFSET_X, battle.TILE_OFFSET_Y)) / battle.TILE_SIZE
	return origin + grid_point * cell

func _local_to_world(local_point):
	var grid_point = (local_point - origin) / cell
	return grid_point * battle.TILE_SIZE + Vector2(battle.TILE_OFFSET_X, battle.TILE_OFFSET_Y)

func _gui_input(event):
	if battle == null:
		return

	var dragging = (
			event is InputEventMouseMotion &&
			event.button_mask & MOUSE_BUTTON_MASK_LEFT
	)
	var clicking = (
			event is InputEventMouseButton &&
			event.button_index == MOUSE_BUTTON_LEFT &&
			event.pressed
	)
	if dragging || clicking:
		battle.camera.center_on(_local_to_world(event.position))
		accept_event()
