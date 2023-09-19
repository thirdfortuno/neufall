extends Node2D

const SPR_ARRAY = [
	preload("Sprites/body0.png"),
	preload("Sprites/body1.png"),
	preload("Sprites/body2.png"),
	preload("Sprites/body3.png"),
	preload("Sprites/body4.png"),
	preload("Sprites/body5.png"),
	preload("Sprites/body6.png"),
	preload("Sprites/body7.png"),
	preload("Sprites/body8.png"),
	preload("Sprites/body9.png"),
	preload("Sprites/body10.png"),
	preload("Sprites/body11.png"),
	preload("Sprites/body12.png"),
	preload("Sprites/body13.png"),
	preload("Sprites/body14.png"),
	preload("Sprites/body15.png")
]

var x
var y

func update_sprite(grid_units, unit):
	var index = 0
	
	var adjacents = grid_units.get_adjacent_values_dict(x,y)
	
	if adjacents["up"] == unit:
		index = index + 1
	if adjacents["right"] == unit:
		index = index + 2
	if adjacents["down"] == unit:
		index = index + 4
	if adjacents["left"] == unit:
		index = index + 8
	
	$Sprite2D.texture = SPR_ARRAY[index]

# Called when the node enters the scene tree for the first time.
func _ready():
	$Sprite2D.texture = SPR_ARRAY[0]

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
