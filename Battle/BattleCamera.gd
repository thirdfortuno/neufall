extends Camera2D

const UI_LEFT = 150.0
const UI_TOP = 34.0
const EDGE_MARGIN = 16.0
const MIN_VISIBLE = 64.0
const MAX_ZOOM = 3
const FOCUS_TIME = 0.25
const STEP = 8.0

var bounds = Rect2()
var right_inset = 0.0
var bottom_inset = 0.0
var target = Vector2.ZERO
var zoom_level = 1
var panning = false
var focus_tween

func set_bounds(rect):
	bounds = rect
	_move_to(target)

func view_size():
	return get_viewport_rect().size / zoom.x

func view_rect():
	return Rect2(position, view_size())

func pan(offset):
	_stop_focus()
	_move_to(target + offset)

func set_zoom_level(level, screen_point):
	level = clamp(level, 1, MAX_ZOOM)
	if level == zoom_level:
		return

	_stop_focus()
	var world_point = position + screen_point / zoom.x
	zoom_level = level
	zoom = Vector2(level, level)
	_move_to(world_point - screen_point / level)

func center_on(world_point):
	_stop_focus()
	_move_to(world_point - view_size() / 2)

func focus(world_point):
	_stop_focus()
	var goal = _limited(world_point - view_size() / 2)
	if _snapped(goal) == position:
		return

	focus_tween = create_tween()
	focus_tween.tween_method(_move_to, target, goal, FOCUS_TIME)

func ensure_visible(world_point, instant = false):
	var covered = Vector2(UI_LEFT, UI_TOP) / zoom.x
	var covered_far = Vector2(right_inset, bottom_inset) / zoom.x
	var field = Rect2(position + covered, view_size() - covered - covered_far).grow(-EDGE_MARGIN / zoom.x)
	if field.has_point(world_point):
		return
	
	if instant:
		center_on(world_point)
	else:
		focus(world_point)

# The camera only rests on multiples of STEP so the pixel art stays aligned;
# target keeps the unrounded value so slow drags still add up
func _move_to(wanted):
	target = _limited(wanted)
	position = _snapped(target)

func _snapped(point):
	return (point / STEP).round() * STEP

# Soft limit: the camera may leave the map, but at least MIN_VISIBLE screen
# pixels of it must stay in the visible field (the part not under the panels)
func _limited(wanted):
	var covered = Vector2(UI_LEFT, UI_TOP) / zoom.x
	var covered_far = Vector2(right_inset, bottom_inset) / zoom.x
	var keep = MIN_VISIBLE / zoom.x
	var low = bounds.position + Vector2(keep, keep) - (view_size() - covered_far)
	var high = bounds.end - Vector2(keep, keep) - covered
	return Vector2(
		clamp(wanted.x, low.x, max(low.x, high.x)),
		clamp(wanted.y, low.y, max(low.y, high.y))
	)

func _stop_focus():
	if focus_tween:
		focus_tween.kill()
		focus_tween = null

func _input(event):
	if (
			event is InputEventMouseButton &&
			event.button_index == MOUSE_BUTTON_MIDDLE &&
			!event.pressed
	):
		panning = false

func _unhandled_input(event):
	if event is InputEventMouseButton && event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				panning = true
			MOUSE_BUTTON_WHEEL_UP:
				set_zoom_level(zoom_level + 1, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				set_zoom_level(zoom_level - 1, event.position)
	elif event is InputEventMouseMotion && panning:
		pan(-event.relative / zoom.x)

func _ready():
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
