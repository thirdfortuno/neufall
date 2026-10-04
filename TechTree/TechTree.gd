extends Control

const TechLayout = preload("res://Game/TechLayout.gd")
const NODE_SIZE = TechLayout.NODE_SIZE
const STATE_COLORS = {
	"unlocked": Color(0.5, 1.0, 0.5),
	"available": Color(1.0, 1.0, 1.0),
	"locked": Color(0.5, 0.5, 0.5)
}

@onready var Content = $PanView/Content
@onready var Info = $Details/VBox/InfoScroll/Info
@onready var ResearchButton = $Details/VBox/ResearchButton

var node_buttons = {}
var selected_id
var lines_canvas

func _ready():
	$TopBar.set_current("tech_tree")

	lines_canvas = Control.new()
	lines_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_canvas.draw.connect(_draw_lines.bind(lines_canvas))
	Content.add_child(lines_canvas)

	for node_id in Game.tech_nodes:
		var node = Game.tech_nodes[node_id]

		var button = Button.new()
		button.toggle_mode = true
		button.text = "%s\n%s" % [
			Game.unit_label(node["unit"]),
			Game.resources_text(node["cost"])
		]
		if node["required_units"].size() > 1:
			button.text = button.text + "\nNeeds %s of %d" % [
				node["requires_mode"].to_upper(),
				node["required_units"].size()
			]
		button.position = node["position"]
		button.custom_minimum_size = NODE_SIZE
		button.pressed.connect(_on_node_pressed.bind(node_id))
		Content.add_child(button)
		node_buttons[node_id] = button

	if Game.tech_nodes.size() > 0:
		var bounds
		for node_id in Game.tech_nodes:
			var rect = Rect2(Game.tech_nodes[node_id]["position"], NODE_SIZE)
			if bounds == null:
				bounds = rect
			else:
				bounds = bounds.merge(rect)
		$PanView.set_bounds(bounds)
		$PanView.recenter()

	_refresh()

func _draw_lines(canvas):
	for node_id in Game.tech_nodes:
		var node = Game.tech_nodes[node_id]
		for unit_id in node["required_units"]:
			var from_id = Game.node_for_unit(unit_id)
			if from_id == null:
				continue
			
			var color = Color(0.7, 0.7, 0.7)
			if Game.is_unit_unlocked(unit_id):
				color = Color(0.5, 1.0, 0.5)
			
			var from = Game.tech_nodes[from_id]["position"] + NODE_SIZE / 2
			var to = node["position"] + NODE_SIZE / 2
			if node["requires_mode"] == "any" && node["required_units"].size() > 1:
				canvas.draw_dashed_line(from, to, color, 2.0, 8.0)
			else:
				canvas.draw_line(from, to, color, 2.0)

func _refresh():
	for node_id in node_buttons:
		node_buttons[node_id].modulate = STATE_COLORS[Game.node_state(node_id)]
		node_buttons[node_id].set_pressed_no_signal(node_id == selected_id)

	lines_canvas.queue_redraw()
	$TopBar.refresh()
	_show_details()

func _show_details():
	if selected_id == null:
		Info.text = "Select a node"
		ResearchButton.disabled = true
		return

	var node = Game.tech_nodes[selected_id]
	var state = Game.node_state(selected_id)
	var lines = [
		Game.unit_label(node["unit"]),
		"Generation: %d" % Game.units[node["unit"]]["generation"],
		"Status: %s" % state,
		"Cost: %s" % Game.resources_text(node["cost"])
	]

	if node["required_units"].size() == 1:
		lines.append("Requires:")
	elif node["required_units"].size() > 1:
		lines.append("Requires %s of:" % node["requires_mode"].to_upper())
	for unit_id in node["required_units"]:
		var mark = "[ ]"
		if Game.is_unit_unlocked(unit_id):
			mark = "[x]"
		lines.append("%s %s" % [mark, Game.unit_label(unit_id)])

	Info.text = "\n".join(lines)
	ResearchButton.disabled = state != "available" || !Game.can_afford(node["cost"])

func _on_node_pressed(node_id):
	selected_id = node_id
	_refresh()

func _on_research_button_pressed():
	Game.unlock_node(selected_id)
	_refresh()
