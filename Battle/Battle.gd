extends Node2D

onready var Grid = preload("Grid.gd")

var grid = [
	[0,0,0,0,0,0,0,0],
	[0,1,1,1,1,1,1,0],
	[0,1,1,1,1,1,0,0],
	[0,1,1,1,1,1,1,0],
	[0,0,0,0,0,0,0,0]
]

# Called when the node enters the scene tree for the first time.
func _ready():
	var g = Grid.new(grid)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
