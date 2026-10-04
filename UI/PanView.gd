extends Control

const WHEEL_STEP = 60.0
const PADDING = 20.0

@onready var Content = $Content

var bounds = Rect2()

func set_bounds(rect):
	bounds = rect.grow(PADDING)
	pan(Vector2.ZERO)

func pan(offset):
	var wanted = Content.position + offset
	Content.position = Vector2(
		_clamp_axis(wanted.x, size.x, bounds.position.x, bounds.end.x),
		_clamp_axis(wanted.y, size.y, bounds.position.y, bounds.end.y)
	)

func recenter():
	Content.position = -bounds.position
	pan(Vector2.ZERO)

func _clamp_axis(value, view_size, bound_start, bound_end):
	var at_start = -bound_start
	var at_end = view_size - bound_end
	return clamp(value, min(at_start, at_end), max(at_start, at_end))

func _gui_input(event):
	if (
			event is InputEventMouseMotion &&
			event.button_mask & MOUSE_BUTTON_MASK_LEFT
	):
		pan(event.relative)

func _input(event):
	if !(event is InputEventMouseButton) || !event.pressed:
		return
	if !get_global_rect().has_point(event.position):
		return

	var step = Vector2.ZERO
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			step = Vector2(0, WHEEL_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			step = Vector2(0, -WHEEL_STEP)
		MOUSE_BUTTON_WHEEL_LEFT:
			step = Vector2(WHEEL_STEP, 0)
		MOUSE_BUTTON_WHEEL_RIGHT:
			step = Vector2(-WHEEL_STEP, 0)
		_:
			return

	if event.shift_pressed:
		step = Vector2(step.y, step.x)

	pan(step)
	get_viewport().set_input_as_handled()

func _on_recenter_button_pressed():
	recenter()
