extends Node2D

@export var body_scene: PackedScene

signal killed(unit)
signal damaged(unit)
signal healed(unit)

var TILE_SIZE
var TILE_OFFSET_X
var TILE_OFFSET_Y
var DELAY_DAMAGE = 0.2

var x
var y
var team

var type

var hp_max
var bodies = []
var moves_max
var moves_available

var premove_bodies = []
var moved = false

var active = true

var abilities
var behavior

# See the _ready() function for knowing what's an ai unit
var spr_main = preload("Sprites/SecurityCam/security_cam.png")
var spr_shadow = preload("Sprites/SecurityCam/security_cam_shadow.png")

func damage(amount):
	var iterations = 0
	while bodies.size() > 0 && iterations < amount:
		await get_tree().create_timer(DELAY_DAMAGE).timeout
		var body = bodies.pop_back()
		body.queue_free()
		iterations = iterations + 1
	
	if bodies.size() == 0:
		emit_signal("killed", self)
		self.queue_free()
	else:
		emit_signal("damaged", self)

func heal(amount):
	var iterations = 0
	while bodies.size() < hp_max && iterations < amount:
		for x in bodies.size():
			var body = bodies[-x-1]
			var adj_units = get_parent().grid_units.get_adjacent_values_dict(
				body.x,
				body.y
			)
			var adj_tiles = get_parent().grid_tiles.get_adjacent_values_dict(
				body.x,
				body.y
			)
			var keys = adj_tiles.keys()
			var valid_tiles = []
			for key in keys:
				if (adj_tiles[key].state == 1 && adj_units[key] == null):
					valid_tiles.append(adj_tiles[key])
			valid_tiles.shuffle()
			if valid_tiles.size() != 0:
				await get_tree().create_timer(DELAY_DAMAGE).timeout
				var tile = valid_tiles[0]
				var new_body = body_scene.instantiate()
				new_body.x = tile.x
				new_body.y = tile.y

				add_child(new_body)
				bodies.push_back(new_body)
				emit_signal("healed", self)
				break
		iterations = iterations + 1

func move_to(x_new, y_new, into_self = false):
	moved = true
	x = x_new
	y = y_new
	moves_available = moves_available - 1
	
	self.global_position = Vector2(
		x * TILE_SIZE + TILE_OFFSET_X + TILE_SIZE/2,
		y * TILE_SIZE + TILE_OFFSET_Y + TILE_SIZE/2
	)
	
	if into_self:
		var body

		for body_search in bodies:
			if body_search.x == x && body_search.y == y:
				body = body_search
				break
		
		bodies.pop_at(bodies.find(body))
		bodies.push_front(body)
	elif bodies.size() < hp_max:
		var body = body_scene.instantiate()
		body.x = x
		body.y = y
		
		add_child(body)
		bodies.push_front(body)
	elif bodies.size() == hp_max:
		var body = bodies.pop_back()
		body.x = x
		body.y = y
		
		bodies.push_front(body)

func update_body_positions(grid_units):
	for body in bodies:
		body.global_position = Vector2(
			body.x * TILE_SIZE + TILE_OFFSET_X + TILE_SIZE/2,
			body.y * TILE_SIZE + TILE_OFFSET_Y + TILE_SIZE/2
		)
		body.update_sprite(grid_units, self)

func deselect():
	for body in bodies:
		body.clean_animations()

func moveable():
	for body in bodies:
		body.clean_animations()
		
	if bodies.size() == hp_max:
		bodies[hp_max - 1].movement_blink()

func prep_premove():
	moved = false
	for pre_body in premove_bodies:
		pre_body.queue_free()
	
	premove_bodies.clear()
	
	for body in bodies:
		var pre_body = body_scene.instantiate()
		pre_body.x = body.x
		pre_body.y = body.y
		
		add_child(pre_body)
		premove_bodies.append(pre_body)

func undo_move():
	moved = false
	for body in bodies:
		body.queue_free()
	
	bodies.clear()
	
	for pre_body in premove_bodies:
		var body = body_scene.instantiate()
		body.x = pre_body.x
		body.y = pre_body.y
		
		add_child(body)
		bodies.append(body)
	
	for pre_body in premove_bodies:
		pre_body.queue_free()
	
	premove_bodies.clear()

# Called when the node enters the scene tree for the first time.
func _ready():
	var body = body_scene.instantiate()
	body.x = x
	body.y = y

	add_child(body)
	bodies.append(body)
	
	moves_available = moves_max
	
	TILE_SIZE = get_parent().TILE_SIZE
	TILE_OFFSET_X = get_parent().TILE_OFFSET_X
	TILE_OFFSET_Y = get_parent().TILE_OFFSET_Y
	
	# Temporary so it's easier to know the enemy unit when testing
	if team == "ai":
		$SpriteMain.texture = spr_main
		$SpriteShadow.texture = spr_shadow

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
