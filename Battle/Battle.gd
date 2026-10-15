extends Node2D

@export var tile_scene: PackedScene
@export var unit_scene: PackedScene

@onready var Grid = preload("Grid.gd")
@onready var AI = preload("AI.gd")
@onready var Sfx = preload("Sfx.gd")
@onready var BattleTracker = preload("BattleTracker.gd")
@onready var ResultsScene = preload("res://Battle/UI/ResultsUI.tscn")
@onready var DeployScene = preload("res://Battle/UI/DeployUI.tscn")
@onready var TurnBannerScene = preload("res://Battle/UI/TurnBanner.tscn")

signal animation_done

const TILE_SIZE = 32
const TILE_OFFSET_X = 150
const TILE_OFFSET_Y = 34
const RIGHT_COLUMN_WIDTH = 218.0
const DEPLOY_PANEL_WIDTH = 378.0

const TARGETING_DIRECTIONS = {
	"rook": [[1, 0], [-1, 0], [0, 1], [0, -1]],
	"bishop": [[1, 1], [1, -1], [-1, 1], [-1, -1]],
	"queen": [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
}

# Temporary until a mission picker exists
const DEFAULT_MISSION = "training_node"

var mission
var mission_id

var height
var width

var grid_tiles
var grid_units

var active_player = "player"
var tile_selected
var tile_hovered
var event_queue = []
var event_showing = false
var enemy_range_shown = false
var hover_path = []
var hover_path_unit
var hover_path_start
var unit_selected
var ability_selected

var click_state = "default"

var units_live_player = []
var units_live_ai = []

var ai_handler
@onready var camera = $Camera
var sfx
var ai_waiting = false
var DELAY_AI_UNIT = 0.5
var DELAY_TURN_BANNER = 1.0
var DELAY_WALK = 0.1

var effect_handlers
var effect_previews

var tracker
var battle_over = false
var resolving = false
var turn_banner

var deploying = true
var fixed_count = 0
var deploy_ui
var deploy_unit_id

var player_move_undo_redo = UndoRedo.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	if mission == null:
		mission_id = Game.selected_mission_id
		if mission_id == null:
			mission_id = DEFAULT_MISSION
		mission = Game.missions[mission_id]
	
	var grid_tile_states = Grid.new(mission["grid"])

	var grid_size = grid_tile_states.get_size()
	
	height = grid_size["height"]
	width = grid_size["width"]

	_init_tiles(grid_tile_states)
	camera.set_bounds(Rect2(
		Vector2(TILE_OFFSET_X, TILE_OFFSET_Y),
		Vector2(width * TILE_SIZE, height * TILE_SIZE)
	))
	$UI/BattleUI.set_battle(self)

	_init_units()
	
	connect("animation_done", Callable(self, "_ai_animation_done"))
	
	effect_handlers = {
		"damage": Callable(self, "_effect_damage"),
		"heal": Callable(self, "_effect_heal"),
		"hp_max_add": Callable(self, "_effect_hp_max_add"),
		"moves_max_add": Callable(self, "_effect_moves_max_add"),
		"drain": Callable(self, "_effect_drain"),
		"tile_set": Callable(self, "_effect_tile_set")
	}

	effect_previews = {
		"damage": Callable(self, "_preview_damage"),
		"heal": Callable(self, "_preview_heal"),
		"hp_max_add": Callable(self, "_preview_hp_max_add"),
		"moves_max_add": Callable(self, "_preview_moves_max_add"),
		"drain": Callable(self, "_preview_drain"),
		"tile_set": Callable(self, "_preview_tile_set")
	}

	ai_handler = AI.new()
	add_child(ai_handler)
	
	sfx = Sfx.new()
	add_child(sfx)
	
	tracker = BattleTracker.new()
	add_child(tracker)
	tracker.connect("battle_finished", Callable(self, "_on_battle_finished"))
	
	turn_banner = TurnBannerScene.instantiate()
	add_child(turn_banner)
	
	_init_deploy()
	_update_status()
	_log("Deploy: %s" % mission["name"])
	if mission["info"] != "":
		show_event(mission["name"], mission["info"])

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
			tile.style = mission["styles"][y][x]
			tile.position = Vector2(
				x*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_X,
				y*TILE_SIZE + TILE_SIZE/2 + TILE_OFFSET_Y
			)

			tile.connect("selected", Callable(self, "_on_tile_select"))
			tile.connect("hovered", Callable(self, "_on_tile_hovered"))
			tile.connect("unhovered", Callable(self, "_on_tile_unhovered"))

			add_child(tile)
			grid_tiles.set_value(x,y,tile)

func _init_units():
	grid_units = Grid.new(width, height)
	
	for fixed in mission["fixed_units"]:
		_spawn_unit({
			"x": fixed["x"],
			"y": fixed["y"],
			"team": "player",
			"unit": fixed["unit"],
			"bodies": fixed["bodies"]
		})
		fixed_count = fixed_count + 1
	
	for enemy in mission["enemies"]:
		_spawn_unit({
			"x": enemy["x"],
			"y": enemy["y"],
			"team": "ai",
			"unit": enemy["unit"],
			"id": enemy.get("id"),
			"bodies": enemy["bodies"],
			"behavior": enemy["behavior"]
		})
	
	_init_objectives()

func _init_objectives():
	var victory = mission["victory"]
	if victory["type"] == "reach_tile":
		grid_tiles.get_value(victory["x"], victory["y"]).mark_goal("PKT")

func _spawn_unit(u):
	var unit = unit_scene.instantiate()
	var data = Game.units[u["unit"]]
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
	
	unit.unit_id = u["unit"]
	unit.type = data["name"]
	unit.abbr = data["abbr"]
	unit.side = data["side"]
	unit.bg_primary = data.get("bg_primary")
	unit.bg_secondary = data.get("bg_secondary")
	unit.sprite_main = data.get("sprite_main")
	unit.sprite_shadow = data.get("sprite_shadow")
	unit.sound_move = data.get("sound_move")
	unit.sound_hurt = data.get("sound_hurt")
	unit.sound_death = data.get("sound_death")
	
	unit.hp_max = data["hp_max"]
	unit.moves_max = data["moves_max"]
	
	unit.abilities = data["abilities"].duplicate(true)
	if team == "ai":
		unit.behavior = u["behavior"].duplicate(true)
	
	unit.enemy_id = u.get("id")
	
	add_child(unit)
	grid_units.set_value(x,y,unit)
	
	var extra_bodies = u.get("bodies", [])
	for cell in extra_bodies:
		unit.add_body(cell[0], cell[1])
		grid_units.set_value(cell[0], cell[1], unit)
	if extra_bodies.size() > 0:
		unit.update_body_positions(grid_units)
	
	var victory = mission["victory"]
	if victory["type"] == "kill_unit" && team == "ai" && unit.enemy_id == victory["enemy"]:
		unit.mark_objective()
	
	if team == "player":
		units_live_player.append(unit)
	elif team == "ai":
		units_live_ai.append(unit)

func _init_deploy():
	for spawn in mission["spawn_tiles"]:
		grid_tiles.get_value(spawn[0], spawn[1]).set_ui("moveable")
	
	var roster = Game.available_units(mission["max_generation"])
	
	deploy_ui = DeployScene.instantiate()
	$UI.add_child(deploy_ui)
	deploy_ui.connect("unit_chosen", Callable(self, "_on_deploy_unit_chosen"))
	deploy_ui.connect("start_pressed", Callable(self, "_on_deploy_start_pressed"))
	deploy_ui.connect("back_pressed", Callable(self, "_on_deploy_back_pressed"))
	camera.right_inset = DEPLOY_PANEL_WIDTH
	_focus_camera_on_spawns()
	deploy_ui.show_mission(mission["name"])
	deploy_ui.show_objective(Game.victory_text(mission["victory"]))
	deploy_ui.show_roster(roster, Game.units, mission["spawn_tiles"].size())
	_deploy_refresh()
	deploy_ui.show_challenges(Game.challenges_text(mission_id, mission))

##############
# DEPLOYMENT #
##############

func _focus_camera_on_spawns():
	var total = Vector2.ZERO
	for spawn in mission["spawn_tiles"]:
		total = total + Vector2(spawn[0], spawn[1])
	var center = total / mission["spawn_tiles"].size()
	camera.ensure_visible(Vector2(
		center.x * TILE_SIZE + TILE_SIZE / 2 + TILE_OFFSET_X,
		center.y * TILE_SIZE + TILE_SIZE / 2 + TILE_OFFSET_Y
	), true)

func _is_spawn_tile(tile):
	for spawn in mission["spawn_tiles"]:
		if spawn[0] == tile.x && spawn[1] == tile.y:
			return true
	return false

func _deploy_on_tile(tile):
	if !_is_spawn_tile(tile):
		return
	
	var unit_on_tile = grid_units.get_value(tile.x, tile.y)
	if unit_on_tile:
		units_live_player.erase(unit_on_tile)
		_clear_unit_from_grid(unit_on_tile)
		unit_on_tile.queue_free()
	
	if deploy_unit_id:
		_spawn_unit({
			"x": tile.x,
			"y": tile.y,
			"team": "player",
			"unit": deploy_unit_id
		})
		deploy_unit_id = null
		deploy_ui.set_selected(null)
	
	_deploy_refresh()

func _deploy_memory():
	var memory = 0
	for unit in units_live_player:
		memory = memory + Game.units[unit.unit_id]["memory"]
	return memory

func _deploy_over_memory():
	return mission["max_memory"] > 0 && _deploy_memory() > mission["max_memory"]

func _deploy_refresh():
	deploy_ui.set_count(
		units_live_player.size() - fixed_count,
		mission["spawn_tiles"].size(),
		units_live_player.size() > 0 && !_deploy_over_memory()
	)
	deploy_ui.set_memory(_deploy_memory(), mission["max_memory"])

func _on_deploy_unit_chosen(unit_id):
	if deploy_unit_id == unit_id:
		deploy_unit_id = null
	else:
		deploy_unit_id = unit_id
	deploy_ui.set_selected(deploy_unit_id)

func _on_deploy_back_pressed():
	Game.go_to_overworld()

func _on_deploy_start_pressed():
	if units_live_player.size() == 0 || _deploy_over_memory():
		return
	
	var squad = []
	for unit in units_live_player:
		squad.append(unit.unit_id)
	tracker.start_battle(squad)
	tracker.turn_started()
	
	deploying = false
	camera.right_inset = RIGHT_COLUMN_WIDTH
	$UI/BattleUI.set_right_column_visible(true)
	_update_status()
	_log("Turn 1: Your Turn")
	deploy_unit_id = null
	turn_banner.show_banner("Your Turn")
	deploy_ui.queue_free()
	_clear_tile_tags()

####################
# HEADS UP DISPLAY #
####################

func _hud_show_unit():
	$UI/BattleUI.show_unit(unit_selected, unit_selected != null && unit_selected.team != "player")

func _update_status():
	var turn_text = "Deploy"
	if !deploying:
		var side = "Your Turn"
		if active_player == "ai":
			side = "Enemy Turn"
		turn_text = "Turn %d - %s" % [tracker.turns, side]

	var goal = Game.victory_text(mission["victory"])
	var victory = mission["victory"]
	if victory["type"] == "kill_unit":
		for enemy in mission["enemies"]:
			if enemy.get("id") == victory["enemy"]:
				goal = "%s: %s" % [goal, Game.units[enemy["unit"]]["name"]]
				break
	$UI/BattleUI.set_objective(mission["name"], goal, turn_text)

func _log(text):
	$UI/BattleUI.add_log(text)

# Event panel (bottom left): narrative beats or anything else the level wants to
# say. It takes no space while empty, and events queue up one at a time
func show_event(title, text):
	event_queue.append([title, text])
	if !event_showing:
		_next_event()

func hide_event():
	_next_event()

func _next_event():
	if event_queue.size() == 0:
		event_showing = false
		$UI/BattleUI.hide_event()
		camera.bottom_inset = 0.0
		return

	var event = event_queue.pop_front()
	event_showing = true
	$UI/BattleUI.show_event(event[0], event[1])
	await get_tree().process_frame
	camera.bottom_inset = $UI/BattleUI.get_event_height()

func _on_event_dismissed():
	_next_event()

func _on_tile_hovered(tile):
	if battle_over:
		return
	tile_hovered = tile
	var unit = grid_units.get_value(tile.x, tile.y)
	if unit && unit != unit_selected:
		$UI/BattleUI.show_unit(unit, true)
	_show_hover_overlay(tile, unit)

func _on_tile_unhovered(tile):
	if tile_hovered != tile:
		return
	tile_hovered = null
	if !battle_over:
		_hud_show_unit()
	_clear_hover_overlay()

func _show_hover_overlay(tile, unit):
	_clear_path_preview()
	if resolving || battle_over || active_player != "player":
		return
	
	if click_state == "unit_ability":
		_update_outcome_preview(tile, unit)
	elif unit && unit.team == "ai":
		if deploying || click_state == "default" || click_state == "unit_select":
			_show_enemy_move_range(unit)
	elif click_state == "unit_move":
		_update_path_preview(tile)

func _clear_path_preview():
	for tile in grid_tiles.grid_data:
		tile.clear_step()
		tile.clear_preview()
		tile.clear_flash()

func _clear_hover_overlay():
	if resolving || battle_over:
		return
	
	_clear_path_preview()
	if enemy_range_shown:
		enemy_range_shown = false
		_refresh_range_tags()

func _show_enemy_move_range(unit):
	_clear_tile_tags()
	for tile in _unit_move_get_legal_range(unit, unit.moves_max)["all"]:
		tile.set_ui("enemy_move")
	enemy_range_shown = true

func _update_path_preview(tile):
	_clear_path_preview()
	if !_can_preview_selected():
		return
	
	var legal_tiles = _unit_move_get_legal_range(
		unit_selected,
		unit_selected.moves_available
	)["all"]
	if !legal_tiles.has(tile):
		return
	
	var step = 1
	for path_tile in _hover_move_path(unit_selected, tile, legal_tiles):
		path_tile.set_step(str(step))
		step = step + 1

func _hover_move_path(unit, goal, legal_tiles):
	var start = grid_tiles.get_value(unit.x, unit.y)
	if hover_path_unit != unit || hover_path_start != start:
		hover_path = []
		hover_path_unit = unit
		hover_path_start = start
	
	var kept = 0
	while (
			kept < hover_path.size() &&
			kept < unit.moves_available &&
			legal_tiles.has(hover_path[kept])
	):
		kept = kept + 1
	hover_path = hover_path.slice(0, kept)
	
	var goal_index = hover_path.find(goal)
	if goal_index != -1:
		hover_path = hover_path.slice(0, goal_index + 1)
		return hover_path
	
	# Keep as much of the path already traced as the new target allows
	for keep in range(hover_path.size(), -1, -1):
		var prefix = hover_path.slice(0, keep)
		var from_tile = start
		if keep > 0:
			from_tile = prefix[keep - 1]
		var rest = _move_path(from_tile, goal, legal_tiles, [start] + prefix)
		if rest.size() > 0 && keep + rest.size() <= unit.moves_available:
			hover_path = prefix + rest
			return hover_path
	
	hover_path = []
	return hover_path

func _move_path(start, goal, legal_tiles, blocked):
	var distance = {start: 0}
	var queue = [start]
	var queue_index = 0
	while queue_index < queue.size():
		var tile = queue[queue_index]
		queue_index = queue_index + 1
		for tile_next in grid_tiles.get_adjacent_values(tile.x, tile.y):
			if (
					!distance.has(tile_next) &&
					legal_tiles.has(tile_next) &&
					!blocked.has(tile_next)
			):
				distance[tile_next] = distance[tile] + 1
				queue.append(tile_next)
	
	var path = []
	if !distance.has(goal):
		return path
	
	# Walk back from the goal, keeping to a straight line when there is a choice
	var path_tile = goal
	var heading = Vector2i.ZERO
	while path_tile != start:
		path.push_front(path_tile)
		var best = null
		for tile_prev in grid_tiles.get_adjacent_values(path_tile.x, path_tile.y):
			if !distance.has(tile_prev) || distance[tile_prev] != distance[path_tile] - 1:
				continue
			if best == null:
				best = tile_prev
			if Vector2i(path_tile.x - tile_prev.x, path_tile.y - tile_prev.y) == heading:
				best = tile_prev
				break
		heading = Vector2i(path_tile.x - best.x, path_tile.y - best.y)
		path_tile = best
	return path

###################
# OUTCOME PREVIEW #
###################

# Each effect has a preview next to its handler. It does not run the effect: it
# updates a range (low, high) for the unit and a chance, so a random effect can
# show its odds. Effects are fixed amounts today, which gives low == high and 100%.

func _update_outcome_preview(tile, target_unit):
	if !_can_preview_selected() || ability_selected == null:
		return
	if !_unit_ability_get_legal_range(unit_selected, ability_selected)["immediate"].has(tile):
		return
	if !_is_valid_ability_target(unit_selected, target_unit, ability_selected):
		return

	var states = {}
	for effect in ability_selected["effects"]:
		effect_previews[effect["type"]].call(effect, tile, target_unit, unit_selected, states)

	if ability_selected.has("size_cost"):
		var source_state = _preview_state(states, unit_selected)
		source_state["size_hi"] = max(0, source_state["size_hi"] - ability_selected["size_cost"])
		source_state["size_lo"] = max(0, source_state["size_lo"] - ability_selected["size_cost"])

	for key in states:
		if key is String:
			continue
		_preview_flash_unit(key, states[key])

	if target_unit == null && states.has("tile_state") && states["tile_state"] != tile.state:
		tile.set_flash(states["tile_state"] == 1, true)

	var separator = String.chr(10)
	for key in states:
		if key is String:
			continue
		var lines = _preview_lines(states[key])
		if lines.size() > 0:
			grid_tiles.get_value(key.x, key.y).set_preview(separator.join(lines))

# Flashes the tiles a unit would lose (its tail bodies) or could gain. A fainter
# flash marks tiles that only change in some outcomes
func _preview_flash_unit(unit, state):
	for index in range(state["size_lo"], unit.bodies.size()):
		var body = unit.bodies[index]
		grid_tiles.get_value(body.x, body.y).set_flash(false, index >= state["size_hi"])

	if state["size_hi"] > state["start_size"]:
		for tile in _preview_growth_tiles(unit):
			tile.set_flash(true, state["size_lo"] > state["start_size"])

# Mirrors Unit.heal: the tail-most body with a free neighbor grows, onto one of
# those neighbors chosen at random, so every free neighbor is a candidate
func _preview_growth_tiles(unit):
	for index in range(unit.bodies.size() - 1, -1, -1):
		var body = unit.bodies[index]
		var free_tiles = []
		for tile in grid_tiles.get_adjacent_values(body.x, body.y):
			if tile.state == 1 && grid_units.get_value(tile.x, tile.y) == null:
				free_tiles.append(tile)
		if free_tiles.size() > 0:
			return free_tiles
	return []

func _preview_state(states, unit):
	if !states.has(unit):
		states[unit] = {
			"start_size": unit.bodies.size(),
			"start_hp": unit.hp_max,
			"start_moves": unit.moves_max,
			"size_lo": unit.bodies.size(),
			"size_hi": unit.bodies.size(),
			"hp_lo": unit.hp_max,
			"hp_hi": unit.hp_max,
			"moves_lo": unit.moves_max,
			"moves_hi": unit.moves_max,
			"chance": 1.0
		}
	return states[unit]

func _preview_span(effect):
	var first = effect.get("amount", 0)
	var second = effect.get("amount_max", first)
	var chance = effect.get("chance", 1.0)
	var low = min(first, second)
	var high = max(first, second)
	if chance < 1.0:
		low = min(low, 0)
		high = max(high, 0)
	return {"low": low, "high": high, "chance": chance}

func _preview_damage(effect, tile, target_unit, source, states):
	if target_unit == null:
		return
	var state = _preview_state(states, target_unit)
	var span = _preview_span(effect)
	state["size_hi"] = max(0, state["size_hi"] - span["low"])
	state["size_lo"] = max(0, state["size_lo"] - span["high"])
	state["chance"] = min(state["chance"], span["chance"])

func _preview_heal(effect, tile, target_unit, source, states):
	if target_unit == null:
		return
	var state = _preview_state(states, target_unit)
	var span = _preview_span(effect)
	state["size_hi"] = min(state["size_hi"] + span["high"], state["hp_hi"])
	state["size_lo"] = min(state["size_lo"] + span["low"], state["hp_lo"])
	state["chance"] = min(state["chance"], span["chance"])

func _preview_hp_max_add(effect, tile, target_unit, source, states):
	if target_unit == null:
		return
	var state = _preview_state(states, target_unit)
	var span = _preview_span(effect)
	state["hp_lo"] = state["hp_lo"] + span["low"]
	state["hp_hi"] = state["hp_hi"] + span["high"]
	state["chance"] = min(state["chance"], span["chance"])

func _preview_moves_max_add(effect, tile, target_unit, source, states):
	if target_unit == null:
		return
	var state = _preview_state(states, target_unit)
	var span = _preview_span(effect)
	state["moves_lo"] = state["moves_lo"] + span["low"]
	state["moves_hi"] = state["moves_hi"] + span["high"]
	state["chance"] = min(state["chance"], span["chance"])

func _preview_drain(effect, tile, target_unit, source, states):
	if target_unit == null:
		return
	var target_state = _preview_state(states, target_unit)
	var source_state = _preview_state(states, source)
	var span = _preview_span(effect)
	var drained_low = min(span["low"], target_state["size_lo"])
	var drained_high = min(span["high"], target_state["size_hi"])

	target_state["size_hi"] = max(0, target_state["size_hi"] - span["low"])
	target_state["size_lo"] = max(0, target_state["size_lo"] - span["high"])
	source_state["size_hi"] = min(source_state["size_hi"] + drained_high, source_state["hp_hi"])
	source_state["size_lo"] = min(source_state["size_lo"] + drained_low, source_state["hp_lo"])
	target_state["chance"] = min(target_state["chance"], span["chance"])
	source_state["chance"] = min(source_state["chance"], span["chance"])

func _preview_tile_set(effect, tile, target_unit, source, states):
	if target_unit != null:
		return
	states["tile_state"] = effect["state"]

func _preview_lines(state):
	var lines = []
	if state == null:
		return lines

	if state["hp_lo"] != state["start_hp"] || state["hp_hi"] != state["start_hp"]:
		lines.append("Max %d -> %s" % [state["start_hp"], _preview_range_text(state["hp_lo"], state["hp_hi"])])
	if state["moves_lo"] != state["start_moves"] || state["moves_hi"] != state["start_moves"]:
		lines.append("Move %d -> %s" % [state["start_moves"], _preview_range_text(state["moves_lo"], state["moves_hi"])])

	if state["chance"] < 1.0:
		lines.append("%d%%" % int(round(state["chance"] * 100)))
	return lines

func _preview_range_text(low, high):
	if low == high:
		return str(low)
	return "%d-%d" % [low, high]

func _refresh_range_tags():
	_clear_tile_tags()
	
	if deploying:
		for spawn in mission["spawn_tiles"]:
			grid_tiles.get_value(spawn[0], spawn[1]).set_ui("moveable")
		return
	
	if unit_selected == null || !_is_unit_selected_active_and_on_team():
		return
	
	if click_state == "unit_move":
		_show_player_move_range(
			unit_selected,
			_unit_move_get_legal_range(unit_selected, unit_selected.moves_available)
		)
	elif click_state == "unit_ability" && ability_selected:
		_show_ability_range(unit_selected, ability_selected)

func _on_AbilityHovered(index):
	if !_can_preview_abilities() || index >= unit_selected.abilities.size():
		return
	
	var ability = unit_selected["abilities"][index]
	if ability.has('size_requirement') && ability.size_requirement > unit_selected.bodies.size():
		return
	
	_clear_tile_tags()
	_show_ability_range(unit_selected, ability)

func _on_AbilityUnhovered():
	if !_can_preview_abilities():
		return
	
	_refresh_range_tags()

func _can_preview_abilities():
	return (
		!resolving && !deploying && !battle_over &&
		active_player == "player" &&
		unit_selected != null
	)

func _can_preview_selected():
	return (
		!resolving && !deploying && !battle_over &&
		active_player == "player" &&
		unit_selected != null &&
		_is_unit_selected_active_and_on_team()
	)

func _show_ability_range(unit, ability):
	for tile in _unit_ability_get_legal_range(unit, ability)["immediate"]:
		tile.set_ui("damageable")

func _hud_show_tile():
	$UI/SelectedTileUI.show_tile(tile_selected)

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
	if battle_over:
		return
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
		turn_banner.show_banner("Enemy Turn")
		_update_status()
		_log("Turn %d: Enemy Turn" % tracker.turns)
		for unit in units_live_player:
			unit.hide_done_mark()
		for unit in units_live_ai:
			unit.active = true
			unit.moves_available = unit.moves_max
		unit_selected = null
		_ai_decisions()
	elif active_player == "ai":
		active_player = "player"
		turn_banner.show_banner("Your Turn")
		tracker.turn_started()
		_update_status()
		_log("Turn %d: Your Turn" % tracker.turns)
		for unit in units_live_ai:
			unit.hide_done_mark()
		for unit in units_live_player:
			unit.active = true
			unit.moved = false
			unit.moves_available = unit.moves_max

func _ai_decisions():
	if active_player == "ai":
		print("AI TURN")
		await get_tree().create_timer(DELAY_TURN_BANNER).timeout
		for unit in units_live_ai:
			if battle_over:
				break
			if unit.active:
				unit_selected = unit
				camera.ensure_visible(unit.global_position)
				await _ai_await_move()
				if battle_over:
					break
				var start_x = unit.x
				var start_y = unit.y
				await ai_handler.handle_unit(unit)
				if is_instance_valid(unit) && (unit.x != start_x || unit.y != start_y):
					_log("%s moved" % unit.type)
				unit.active = false
				await get_tree().create_timer(DELAY_AI_UNIT * ai_handler.delay_scale()).timeout
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

func _finish_moved_units(except_unit):
	for unit in units_live_player:
		if unit != except_unit && unit.active && unit.moved:
			unit.active = false
			unit.clean_body_animations()

func _handle_unit_ability(tile, unit, ability):
	var ability_range = _unit_ability_get_legal_range(
			unit,
			ability
	)
	
	if ability_range["immediate"].has(tile):
		var target_unit = grid_units.get_value(tile.x, tile.y)
		if _is_valid_ability_target(unit, target_unit, ability):
			resolving = true
			var target_text = "a tile"
			if target_unit:
				target_text = target_unit.type
			_log("%s used %s on %s" % [unit.type, ability["ability_name"], target_text])
			unit.animate_ability(target_unit, ability)
			
			for effect in ability["effects"]:
				if !ability.has("sound"):
					sfx.play(effect.get("sound"))
				await effect_handlers[effect["type"]].call(effect, tile, target_unit, unit)
			
			unit.active = false
			
			if ability.has('size_cost'):
				await unit.damage(ability.size_cost)
			
			resolving = false
			_check_if_turn_done()

func _is_valid_ability_target(unit, target_unit, ability):
	var relation = "enemy"
	if target_unit == null:
		relation = "tile"
	elif target_unit == unit:
		relation = "self"
	elif target_unit.team == unit.team:
		relation = "ally"
	
	return ability["targets"].has(relation)

func _effect_damage(effect, tile, target_unit, source):
	if target_unit:
		await target_unit.damage(effect["amount"])

func _effect_heal(effect, tile, target_unit, source):
	if target_unit:
		await target_unit.heal(effect["amount"])

func _effect_hp_max_add(effect, tile, target_unit, source):
	if target_unit:
		target_unit.hp_max = target_unit.hp_max + effect["amount"]

func _effect_moves_max_add(effect, tile, target_unit, source):
	if target_unit:
		target_unit.moves_max = target_unit.moves_max + effect["amount"]

func _effect_drain(effect, tile, target_unit, source):
	if target_unit:
		var drained = min(effect["amount"], target_unit.bodies.size())
		await target_unit.damage(effect["amount"])
		if drained > 0:
			await source.heal(drained)

func _effect_tile_set(effect, tile, target_unit, source):
	if effect["state"] == 0 && grid_units.get_value(tile.x, tile.y) != null:
		return
	tile.set_state(effect["state"])

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
	
	_log("%s destroyed" % unit.type)
	units_live_player.erase(unit)
	units_live_ai.erase(unit)
	_clear_unit_from_grid(unit)
	
	tracker.unit_killed(unit)
	
	emit_signal("animation_done")

func _on_battle_finished(result):
	battle_over = true
	unit_selected = null
	click_state = "default"
	_clear_tile_tags()
	_hud_show_unit()
	
	if result["outcome"] == "victory":
		result["summary"] = Game.record_victory(mission_id, mission, result["challenges_met"])
	
	var results_ui = ResultsScene.instantiate()
	add_child(results_ui)
	results_ui.show_result(result)

func _show_player_move_range(unit, legal_range):
	for tile in legal_range["all"]:
		tile.set_ui("moveable")
	
	for tile in legal_range["adjacent"]:
		if tile.x > unit.x:
			tile.set_ui("arrow_right")
		elif tile.x < unit.x:
			tile.set_ui("arrow_left")
		elif tile.y > unit.y:
			tile.set_ui("arrow_down")
		else:
			tile.set_ui("arrow_up")

func _player_handle_unit_move(tile, unit):
	if unit.moves_available > 0:
		var adjacent_tiles = grid_tiles.get_adjacent_values(unit.x, unit.y)
		var legal_tiles = _unit_move_get_legal_range(unit, unit.moves_available)["all"]
		if adjacent_tiles.has(tile):
			_handle_unit_move(tile, unit)
		elif legal_tiles.has(tile):
			await _walk_unit(unit, _hover_move_path(unit, tile, legal_tiles))
			if battle_over:
				return
	
	var legal_range = _unit_move_get_legal_range(
		unit,
		unit.moves_available
	)
	
	unit.moveable()
	
	_clear_tile_tags()
	
	_show_player_move_range(unit, legal_range)
		
	tile_selected.deselect()
	tile_selected = grid_tiles.get_value(unit.x, unit.y)
	tile_selected.select()
	_hud_show_unit()
	
	if tile_hovered:
		_update_path_preview(tile_hovered)

# Click to walk: takes the previewed path one tile at a time, each step an ordinary move
func _walk_unit(unit, path):
	resolving = true
	_clear_tile_tags()
	_clear_path_preview()

	for step in path:
		_handle_unit_move(step, unit)
		if battle_over || unit.x != step.x || unit.y != step.y:
			break
		if step != path.back():
			await get_tree().create_timer(DELAY_WALK).timeout

	resolving = false

func _handle_unit_move(tile, unit):
	var x = tile.x
	var y = tile.y
	var adjacent_tiles = grid_tiles.get_adjacent_values(unit.x, unit.y)
	var unit_on_tile = grid_units.get_value(x, y)
	
	if (
			adjacent_tiles.has(tile) &&
			tile.state == 1 &&
			(unit_on_tile == null || unit_on_tile == unit)
	):
		var into_self = unit_on_tile == unit
		unit.move_to(x, y, into_self)
		if unit.team == "player":
			_finish_moved_units(unit)
	else:
		return

	_clear_unit_from_grid(unit)

	for body in unit.bodies:
		grid_units.set_value(body.x, body.y, unit)

	unit.update_body_positions(grid_units)
	
	tracker.check()

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
	if resolving || !_is_unit_selected_active_and_on_team():
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
	if resolving:
		return
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
		_show_player_move_range(
				unit_selected,
				_unit_move_get_legal_range(unit_selected, unit_selected.moves_available)
		)

func _on_Ability1Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][0])

func _on_Ability2Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][1])

func _on_Ability3Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][2])

func _on_Ability4Button_pressed():
	_handle_ability_button_pressed(unit_selected["abilities"][3])

func _on_EndTurnButton_pressed():
	if resolving:
		return
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

func _on_EndAllButton_pressed():
	if resolving || deploying || battle_over || active_player != "player":
		return
	
	var idle = 0
	for unit in units_live_player:
		if unit.active && !unit.moved:
			idle = idle + 1
	
	if idle > 0:
		$UI/BattleUI.ask_end_all(idle)
	else:
		_end_all_turns()

func _end_all_turns():
	if resolving || deploying || battle_over || active_player != "player":
		return
	for unit in units_live_player:
		unit.active = false
	if unit_selected:
		unit_selected.clean_body_animations()
	unit_selected = null
	ability_selected = null
	click_state = "default"
	if tile_selected:
		tile_selected.deselect()
	tile_selected = null
	_clear_tile_tags()
	_hud_show_unit()
	_check_if_turn_done()

func _on_UndoMoveButton_pressed():
	if resolving:
		return
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
	if battle_over || resolving:
		return
	
	if deploying:
		if (
				Input.is_key_pressed(KEY_Q) ||
				Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		):
			deploy_unit_id = null
			deploy_ui.set_selected(null)
		return
	
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

func _on_tile_select(tile):
	if battle_over || resolving:
		return
	
	if deploying:
		_deploy_on_tile(tile)
		return
	
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
			_clear_tile_tags()
			await _handle_unit_ability(tile, unit_selected, ability_selected)
			_hud_show_unit()
		"unit_move":
			if !_is_unit_selected_active_and_on_team():
				return
			await _player_handle_unit_move(tile, unit_selected)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
