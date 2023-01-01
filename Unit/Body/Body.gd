extends Node2D

var spr_array = [
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

# Called when the node enters the scene tree for the first time.
func _ready():
	$Sprite.texture = spr_array[0]


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
