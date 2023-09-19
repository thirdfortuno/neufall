extends Node2D

export(PackedScene) var body_scene

signal killed(unit)
signal damaged(unit)

var x
var y
var team

var type

var hp_max
var bodies = []
var moves_max
var moves_available

var active = true

var abilities
var behavior

# See the _ready() function for knowing what's an ai unit
var spr_cam_main = preload("Sprites/SecurityCam/security_cam.png")
var spr_cam_shadow = preload("Sprites/SecurityCam/security_cam_shadow.png")
var spr_bow_main = preload("Sprites/Bow/bow.png")
var spr_bow_shadow = preload("Sprites/Bow/bow_shadow.png")
var spr_wall_main = preload("Sprites/Firewall/firewall.png")
var spr_wall_shadow = preload("Sprites/Firewall/firewall_shadow.png")

func damage(amount):
	var iterations = 0
	while bodies.size() > 0 && iterations < amount:
		var body = bodies.pop_back()
		body.queue_free()
		iterations = iterations + 1
	
	if bodies.size() == 0:
		emit_signal("killed", self)
		self.queue_free()
	else:
		emit_signal("damaged", self)

func move_to(x_new, y_new, into_self = false):
	x = x_new
	y = y_new
	moves_available = moves_available - 1
	
	self.global_position = Vector2(x*32 + 16, y*32 + 16)
	
	if into_self:
		var body

		for body_search in bodies:
			if body_search.x == x && body_search.y == y:
				body = body_search
				break
		
		bodies.pop_at(bodies.find(body))
		bodies.push_front(body)
	elif bodies.size() < hp_max:
		var body = body_scene.instance()
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
		body.global_position = Vector2(body.x*32 + 16, body.y*32 + 16)
		body.update_sprite(grid_units, self)

# Called when the node enters the scene tree for the first time.
func _ready():
	var body = body_scene.instance()
	body.x = x
	body.y = y

	add_child(body)
	bodies.append(body)
	
	moves_available = moves_max
	
	# Temporary so it's easier to know the enemy unit when testing
	if type == "Bow":
		$SpriteMain.texture = spr_bow_main
		$SpriteShadow.texture = spr_bow_shadow
	if type == "Security Camera":
		$SpriteMain.texture = spr_cam_main
		$SpriteShadow.texture = spr_cam_shadow
	if type == "Wall":
		$SpriteMain.texture = spr_wall_main
		$SpriteShadow.texture = spr_wall_shadow

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
