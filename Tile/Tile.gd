extends Node2D

signal selected

var spr_tile_damageable = preload("Sprites/tile_damageable.png")
var spr_tile_hover = preload("Sprites/tile_hover.png")
var spr_tile_selected = preload("Sprites/tile_selected.png")
var spr_tile_moveable = preload("Sprites/tile_moveable.png")

var x
var y
var state
var state_ui = 'unselected'
var spr_base

func set_ui(sprite):
	match(sprite):
		"damageable":
			$SpriteTag.texture = spr_tile_damageable
		"moveable":
			$SpriteTag.texture = spr_tile_moveable
		_:
			$SpriteTag.texture = null

func set_state(new_state):
	state = new_state
	if state == 0:
		$SpriteBase.texture = null
	else:
		$SpriteBase.texture = spr_base

func mark_goal(text):
	var tile_size = get_parent().TILE_SIZE
	var label = Label.new()
	label.text = text
	label.size = Vector2(tile_size, tile_size)
	label.position = Vector2(-tile_size / 2, -tile_size / 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.z_index = 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func select():
	state_ui = 'selected'
	$SpriteSelection.texture = spr_tile_selected

func deselect():
	state_ui = 'unselected'
	$SpriteSelection.texture = null

# Called when the node enters the scene tree for the first time.
func _ready():
	spr_base = $SpriteBase.texture
	if state == 0:
		$SpriteBase.texture = null

func _on_mouse_entered():
	if state_ui != 'selected':
		$SpriteSelection.texture = spr_tile_hover

func _on_mouse_exited():
	if state_ui != 'selected':
		$SpriteSelection.texture = null

func _on_input(_viewport, event, _shape_idx):
	if (
			event is InputEventMouseButton &&
			event.button_index == MOUSE_BUTTON_LEFT &&
			event.is_pressed()
	):
		emit_signal("selected", self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
