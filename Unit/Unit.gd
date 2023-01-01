extends Node2D

export(PackedScene) var body_scene

var x
var y

var hp_max
var bodies = []

# Called when the node enters the scene tree for the first time.
func _ready():
	var body = body_scene.instance()
	body.x = x
	body.y = y

	add_child(body)
	bodies.append(body)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
