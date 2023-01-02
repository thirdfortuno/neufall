extends Node2D

signal selected

var spr_tile_hover = preload("Sprites/tile_hover.png")
var spr_tile_selected = preload("Sprites/tile_selected.png")
var spr_tile_moveable = preload("Sprites/tile_moveable.png")

var x
var y
var state
var state_ui = 'unselected'
var state_target

func set_ui(sprite):
	match(sprite):
		"moveable":
			$SpriteTag.texture = spr_tile_moveable
		_:
			$SpriteTag.texture = null

func select():
	state_ui = 'selected'
	$SpriteSelection.texture = spr_tile_selected

func unselect():
	state_ui = 'unselected'
	$SpriteSelection.texture = null

# Called when the node enters the scene tree for the first time.
func _ready():
	if state == 0:
		$SpriteBase.texture = null

func _on_mouse_entered():
	if state_ui != 'selected':
		$SpriteSelection.texture = spr_tile_hover

func _on_mouse_exited():
	if state_ui != 'selected':
		$SpriteSelection.texture = null

func _on_input(_viewport, event, _shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		emit_signal("selected", self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
