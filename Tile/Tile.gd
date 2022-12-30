extends Node2D

var x
var y
var state

# Called when the node enters the scene tree for the first time.
func _ready():
	if state == 0:
		$SpriteBase.texture = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
