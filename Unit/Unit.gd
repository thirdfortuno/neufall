extends Node2D

@export var body_scene: PackedScene

signal killed(unit)
signal damaged(unit)
signal healed(unit)
signal animation()

const COLOR_PLAYER = Color(0.5, 0.65, 1.0)
const COLOR_ENEMY = Color(1.0, 0.5, 0.5)

var TILE_SIZE
var TILE_OFFSET_X
var TILE_OFFSET_Y
var DELAY_DAMAGE = 0.2

var x
var y
var team

var type

var hp_max
var bodies = []
var moves_max
var moves_available

var premove_bodies = []
var moved = false

var active = true:
	set(value):
		active = value
		if done_mark:
			done_mark.visible = !value

var done_mark

var abilities
var behavior

var unit_id
var side
var bg_primary
var bg_secondary
var enemy_id
var abbr
var sprite_main
var sprite_shadow
var sound_move
var sound_hurt
var sound_death

func animate_ability(target, ability):
	get_parent().sfx.play(ability.get("sound"))

func animate_damage(body):
	pass

func damage(amount):
	emit_signal("animation")
	if amount >= bodies.size():
		get_parent().sfx.play(sound_death)
	else:
		get_parent().sfx.play(sound_hurt)
	var iterations = 0
	while bodies.size() > 0 && iterations < amount:
		await get_tree().create_timer(DELAY_DAMAGE).timeout
		var body = bodies.pop_back()
		animate_damage(body)
		body.queue_free()
		iterations = iterations + 1
	
	if bodies.size() == 0:
		emit_signal("killed", self)
		self.queue_free()
	else:
		emit_signal("damaged", self)

func heal(amount):
	emit_signal("animation")
	var iterations = 0
	while bodies.size() < hp_max && iterations < amount:
		for x in bodies.size():
			var body = bodies[-x-1]
			var adj_units = get_parent().grid_units.get_adjacent_values_dict(
				body.x,
				body.y
			)
			var adj_tiles = get_parent().grid_tiles.get_adjacent_values_dict(
				body.x,
				body.y
			)
			var keys = adj_tiles.keys()
			var valid_tiles = []
			for key in keys:
				if (adj_tiles[key].state == 1 && adj_units[key] == null):
					valid_tiles.append(adj_tiles[key])
			valid_tiles.shuffle()
			if valid_tiles.size() != 0:
				await get_tree().create_timer(DELAY_DAMAGE).timeout
				var tile = valid_tiles[0]
				var new_body = body_scene.instantiate()
				new_body.x = tile.x
				new_body.y = tile.y
				
				add_child(new_body)
				bodies.push_back(new_body)
				emit_signal("healed", self)
				break
		iterations = iterations + 1

	emit_signal("healed", self)

func move_to(x_new, y_new, into_self = false):
	moved = true
	x = x_new
	y = y_new
	moves_available = moves_available - 1
	get_parent().sfx.play_move(sound_move)
	
	self.global_position = Vector2(
		x * TILE_SIZE + TILE_OFFSET_X + TILE_SIZE/2,
		y * TILE_SIZE + TILE_OFFSET_Y + TILE_SIZE/2
	)
	
	if into_self:
		var body

		for body_search in bodies:
			if body_search.x == x && body_search.y == y:
				body = body_search
				break
		
		bodies.pop_at(bodies.find(body))
		bodies.push_front(body)
	elif bodies.size() < hp_max:
		var body = body_scene.instantiate()
		body.x = x
		body.y = y
		
		add_child(body)
		bodies.push_front(body)
	elif bodies.size() == hp_max:
		var body = bodies.pop_back()
		body.x = x
		body.y = y
		
		bodies.push_front(body)

func update_body_positions(grid_units):
	for body in bodies:
		body.global_position = Vector2(
			body.x * TILE_SIZE + TILE_OFFSET_X + TILE_SIZE/2,
			body.y * TILE_SIZE + TILE_OFFSET_Y + TILE_SIZE/2
		)
		body.update_sprite(grid_units, self)

func clean_body_animations():
	for body in bodies:
		body.clean_animations()

func moveable():
	for body in bodies:
		body.clean_animations()
		
	if bodies.size() == hp_max:
		bodies[hp_max - 1].movement_blink()

func prep_premove():
	moved = false
	for pre_body in premove_bodies:
		pre_body.queue_free()
	
	premove_bodies.clear()
	
	for body in bodies:
		var pre_body = body_scene.instantiate()
		pre_body.x = body.x
		pre_body.y = body.y
		
		add_child(pre_body)
		premove_bodies.append(pre_body)

func undo_move():
	moved = false
	for body in bodies:
		body.queue_free()
	
	bodies.clear()
	
	for pre_body in premove_bodies:
		var body = body_scene.instantiate()
		body.x = pre_body.x
		body.y = pre_body.y
		
		add_child(body)
		bodies.append(body)
	
	for pre_body in premove_bodies:
		pre_body.queue_free()
	
	premove_bodies.clear()

# Called when the node enters the scene tree for the first time.
func _ready():
	var body = body_scene.instantiate()
	body.x = x
	body.y = y

	add_child(body)
	bodies.append(body)
	
	moves_available = moves_max
	
	TILE_SIZE = get_parent().TILE_SIZE
	TILE_OFFSET_X = get_parent().TILE_OFFSET_X
	TILE_OFFSET_Y = get_parent().TILE_OFFSET_Y
	
	if sprite_main:
		$SpriteMain.texture = load(sprite_main)
		$SpriteShadow.texture = load(sprite_shadow)
	else:
		$SpriteMain.texture = null
		$SpriteShadow.texture = null
		_add_abbr_label()

	_add_done_mark()

# The unit's own colors if set (primary on the side it belongs to, secondary on the
# other), otherwise blue for player units and red for enemies
func body_tint():
	var own_side = (team == "player") == (side == "player")
	var color = bg_primary if own_side else bg_secondary
	if color != null:
		return color
	if team == "player":
		return COLOR_PLAYER
	return COLOR_ENEMY

func add_body(body_x, body_y):
	var body = body_scene.instantiate()
	body.x = body_x
	body.y = body_y
	
	add_child(body)
	bodies.append(body)

func mark_objective():
	var label = Label.new()
	label.text = "TARGET"
	label.size = Vector2(TILE_SIZE, TILE_SIZE / 2)
	label.position = Vector2(-TILE_SIZE / 2, -TILE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_index = 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func hide_done_mark():
	done_mark.visible = false

func _add_done_mark():
	done_mark = Label.new()
	done_mark.text = "✓"
	done_mark.size = Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	done_mark.position = Vector2(TILE_SIZE / 2 - TILE_SIZE / 3, -TILE_SIZE / 2)
	done_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_mark.add_theme_font_size_override("font_size", 16)
	done_mark.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	done_mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	done_mark.z_index = 3
	done_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done_mark.visible = !active
	add_child(done_mark)

func _add_abbr_label():
	var label = Label.new()
	label.text = abbr
	label.size = Vector2(TILE_SIZE, TILE_SIZE)
	label.position = Vector2(-TILE_SIZE / 2, -TILE_SIZE / 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_index = 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
