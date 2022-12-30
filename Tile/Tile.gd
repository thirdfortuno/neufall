extends Node2D

signal selected

var tile_hover = preload("tile_hover.png")

var x
var y
var state

# Called when the node enters the scene tree for the first time.
func _ready():
	if state == 0:
		$SpriteBase.texture = null

func _on_mouse_entered():
	$SpriteSelection.texture = tile_hover

func _on_mouse_exited():
	$SpriteSelection.texture = null

func _on_input(_viewport, event, _shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		# TODO: Remove the print when selection signal is implemented
		print(x, " ", y, " ", state)
		emit_signal("selected")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
