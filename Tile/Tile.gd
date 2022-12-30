extends Node2D

var tile_hover = preload("tile_hover.png")

var x
var y
var state

# Called when the node enters the scene tree for the first time.
func _ready():
	var area = get_node('Area2D')
	
	if state == 0:
		$SpriteBase.texture = null

func _on_mouse_entered():
	$SpriteSelection.texture = tile_hover

func _on_mouse_exited():
	$SpriteSelection.texture = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
