extends Node2D

signal selected
signal hovered
signal unhovered

var spr_tile_damageable = preload("Sprites/tile_damageable.png")
var spr_tile_hover = preload("Sprites/tile_hover.png")
var spr_tile_selected = preload("Sprites/tile_selected.png")
var spr_tile_moveable = preload("Sprites/tile_moveable.png")
var spr_tile_movearrow = preload("Sprites/tile_movearrow.png")

var x
var y
var state
var style
var state_ui = 'unselected'
var spr_base
var step_label
var preview_label
var flash_rect
var flash_tween

const ENEMY_TINT = Color(1.0, 0.45, 0.45)
const FLASH_ADD = Color(0.3, 1.0, 0.4)
const FLASH_REMOVE = Color(1.0, 0.3, 0.3)

func set_ui(sprite):
	$SpriteTag.rotation_degrees = 0
	$SpriteTag.modulate = Color(1, 1, 1)
	clear_step()
	clear_preview()
	clear_flash()
	match(sprite):
		"damageable":
			$SpriteTag.texture = spr_tile_damageable
		"moveable":
			$SpriteTag.texture = spr_tile_moveable
		"enemy_move":
			$SpriteTag.texture = spr_tile_moveable
			$SpriteTag.modulate = ENEMY_TINT
		"arrow_up":
			$SpriteTag.texture = spr_tile_movearrow
		"arrow_right":
			$SpriteTag.texture = spr_tile_movearrow
			$SpriteTag.rotation_degrees = 90
		"arrow_down":
			$SpriteTag.texture = spr_tile_movearrow
			$SpriteTag.rotation_degrees = 180
		"arrow_left":
			$SpriteTag.texture = spr_tile_movearrow
			$SpriteTag.rotation_degrees = 270
		_:
			$SpriteTag.texture = null

func set_state(new_state):
	state = new_state
	if state == 0:
		$SpriteBase.texture = null
	else:
		$SpriteBase.texture = spr_base

func set_step(text):
	if step_label == null:
		var tile_size = get_parent().TILE_SIZE
		step_label = Label.new()
		step_label.size = Vector2(tile_size, tile_size)
		step_label.position = Vector2(-tile_size / 2, -tile_size / 2)
		step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step_label.add_theme_font_size_override("font_size", 16)
		step_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
		step_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		step_label.add_theme_constant_override("outline_size", 3)
		step_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		step_label.z_index = 4
		step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(step_label)
	step_label.text = text
	step_label.visible = true

func set_preview(text):
	if preview_label == null:
		var tile_size = get_parent().TILE_SIZE
		preview_label = Label.new()
		preview_label.size = Vector2(tile_size * 3, tile_size * 1.5)
		preview_label.position = Vector2(-tile_size * 1.5, -tile_size / 2 - tile_size * 1.5)
		preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		preview_label.add_theme_font_size_override("font_size", 16)
		preview_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		preview_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		preview_label.add_theme_constant_override("outline_size", 3)
		preview_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_label.z_index = 5
		preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(preview_label)
	preview_label.text = text
	preview_label.visible = true

func set_flash(adding, certain):
	if flash_rect == null:
		var tile_size = get_parent().TILE_SIZE
		flash_rect = ColorRect.new()
		flash_rect.size = Vector2(tile_size, tile_size)
		flash_rect.position = Vector2(-tile_size / 2, -tile_size / 2)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_rect.z_index = 4
		add_child(flash_rect)

	var color = FLASH_REMOVE
	if adding:
		color = FLASH_ADD
	color.a = 0.6 if certain else 0.3
	flash_rect.color = color
	flash_rect.visible = true

	if flash_tween:
		flash_tween.kill()
	flash_rect.modulate.a = 1.0
	flash_tween = create_tween().set_loops()
	flash_tween.tween_property(flash_rect, "modulate:a", 0.2, 0.35)
	flash_tween.tween_property(flash_rect, "modulate:a", 1.0, 0.35)

func clear_flash():
	if flash_tween:
		flash_tween.kill()
		flash_tween = null
	if flash_rect:
		flash_rect.visible = false

func clear_preview():
	if preview_label:
		preview_label.visible = false

func clear_step():
	if step_label:
		step_label.visible = false

func mark_goal(text):
	var tile_size = get_parent().TILE_SIZE
	var label = Label.new()
	label.text = text
	label.size = Vector2(tile_size, tile_size)
	label.position = Vector2(-tile_size / 2, -tile_size / 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	elif style:
		$SpriteBase.texture = load(style)

func _on_mouse_entered():
	emit_signal("hovered", self)
	if state_ui != 'selected':
		$SpriteSelection.texture = spr_tile_hover

func _on_mouse_exited():
	emit_signal("unhovered", self)
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
