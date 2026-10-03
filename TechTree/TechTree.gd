extends Control

const NODE_SIZE = Vector2(200, 56)
const STATE_COLORS = {
	"unlocked": Color(0.5, 1.0, 0.5),
	"available": Color(1.0, 1.0, 1.0),
	"locked": Color(0.5, 0.5, 0.5)
}

@onready var Content = $PanView/Content
@onready var Info = $Details/VBox/Info
@onready var ResearchButton = $Details/VBox/ResearchButton

var node_buttons = {}
var selected_id

func _ready():
	$TopBar.set_current("tech_tree")

	var lines = Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(_draw_lines.bind(lines))
	Content.add_child(lines)

	for node_id in Game.tech_nodes:
		var node = Game.tech_nodes[node_id]

		var button = Button.new()
		button.toggle_mode = true
		button.text = "%s\n%s" % [
			Game.unit_label(node["unit"]),
			Game.resources_text(node["cost"])
		]
		button.position = node["position"]
		button.custom_minimum_size = NODE_SIZE
		button.pressed.connect(_on_node_pressed.bind(node_id))
		Content.add_child(button)
		node_buttons[node_id] = button

	_refresh()

func _draw_lines(canvas):
	for node_id in Game.tech_nodes:
		for required_id in Game.tech_nodes[node_id]["requires"]:
			canvas.draw_line(
				Game.tech_nodes[required_id]["position"] + NODE_SIZE / 2,
				Game.tech_nodes[node_id]["position"] + NODE_SIZE / 2,
				Color(0.7, 0.7, 0.7),
				2.0
			)

func _refresh():
	for node_id in node_buttons:
		node_buttons[node_id].modulate = STATE_COLORS[Game.node_state(node_id)]
		node_buttons[node_id].set_pressed_no_signal(node_id == selected_id)

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

	if node["requires"].size() > 0:
		var names = []
		for required_id in node["requires"]:
			names.append(Game.unit_label(Game.tech_nodes[required_id]["unit"]))
		lines.append("Requires: %s" % ", ".join(names))

	Info.text = "\n".join(lines)
	ResearchButton.disabled = state != "available" || !Game.can_afford(node["cost"])

func _on_node_pressed(node_id):
	selected_id = node_id
	_refresh()

func _on_research_button_pressed():
	Game.unlock_node(selected_id)
	_refresh()
