extends Node2D

export(PackedScene) var body_scene

var x
var y

var hp_max
var bodies = []
var moves_max
var moves_available

func moveTo(x_new, y_new):
	x = x_new
	y = y_new
	moves_available = moves_available - 1
	
	self.global_position = Vector2(x*32 + 16, y*32 + 16)
	
	if bodies.size() < hp_max:
		var body = body_scene.instance()
		body.x = x
		body.y = y
		
		add_child(body)
		bodies.push_front(body)

func update_body_positions():
	for body in bodies:
		body.global_position = Vector2(body.x*32 + 16, body.y*32 + 16)
		body.update_sprite()

# Called when the node enters the scene tree for the first time.
func _ready():
	var body = body_scene.instance()
	body.x = x
	body.y = y

	add_child(body)
	bodies.append(body)
	
	moves_available = moves_max

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
