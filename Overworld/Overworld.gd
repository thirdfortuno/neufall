extends Control

const TechLayout = preload("res://Game/TechLayout.gd")
const NODE_SIZE = TechLayout.NODE_SIZE
const STATE_COLORS = {
	"cleared": Color(0.5, 1.0, 0.5),
	"available": Color(1.0, 1.0, 1.0),
	"locked": Color(0.5, 0.5, 0.5)
}

@onready var Content = $PanView/Content
@onready var Info = $Details/VBox/InfoScroll/InfoBox/Info
@onready var ErrorsLabel = $Details/VBox/InfoScroll/InfoBox/Errors
@onready var StartButton = $Details/VBox/StartButton

var mission_buttons = {}
var selected_id
var lines_canvas

func _ready():
	$TopBar.set_current("overworld")

	if Game.content_errors.size() > 0:
		ErrorsLabel.visible = true
		ErrorsLabel.text = "Content errors (also in the Output panel):" + "\n" + "\n".join(Game.content_errors)

	lines_canvas = Control.new()
	lines_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_canvas.draw.connect(_draw_lines.bind(lines_canvas))
	Content.add_child(lines_canvas)

	for mission_id in Game.missions:
		var mission = Game.missions[mission_id]

		var button = Button.new()
		button.toggle_mode = true
		button.text = mission["name"]
		button.position = mission["position"]
		button.custom_minimum_size = NODE_SIZE
		button.pressed.connect(_on_mission_pressed.bind(mission_id))
		Content.add_child(button)
		mission_buttons[mission_id] = button

	if Game.missions.size() > 0:
		var bounds
		for mission_id in Game.missions:
			var rect = Rect2(Game.missions[mission_id]["position"], NODE_SIZE)
			if bounds == null:
				bounds = rect
			else:
				bounds = bounds.merge(rect)
		$PanView.set_bounds(bounds)
		$PanView.recenter()

	_refresh()

func _draw_lines(canvas):
	for mission_id in Game.missions:
		var mission = Game.missions[mission_id]
		for required_id in mission["requires"]:
			if !Game.missions.has(required_id):
				continue

			var color = Color(0.7, 0.7, 0.7)
			if Game.has_cleared(required_id):
				color = Color(0.5, 1.0, 0.5)

			canvas.draw_line(
				Game.missions[required_id]["position"] + NODE_SIZE / 2,
				mission["position"] + NODE_SIZE / 2,
				color,
				2.0
			)

func _refresh():
	for mission_id in mission_buttons:
		mission_buttons[mission_id].modulate = STATE_COLORS[Game.mission_state(mission_id)]
		mission_buttons[mission_id].set_pressed_no_signal(mission_id == selected_id)

	lines_canvas.queue_redraw()
	_show_details()

func _show_details():
	if selected_id == null:
		Info.text = "Select a mission"
		StartButton.disabled = true
		return

	var mission = Game.missions[selected_id]
	var state = Game.mission_state(selected_id)
	var lines = [mission["name"], "Status: %s" % state]

	if mission["requires"].size() > 0:
		lines.append("Requires:")
		for required_id in mission["requires"]:
			var mark = "[ ]"
			if Game.has_cleared(required_id):
				mark = "[x]"
			var required_name = required_id
			if Game.missions.has(required_id):
				required_name = Game.missions[required_id]["name"]
			lines.append("%s %s" % [mark, required_name])

	lines.append("Objective: %s" % Game.victory_text(mission["victory"]))
	lines.append("Squad size: %d" % mission["spawn_tiles"].size())
	lines.append("Max generation: %d" % mission["max_generation"])

	if state != "cleared":
		lines.append("First clear: %s" % Game.resources_text(mission["first_clear_reward"], "+"))

	var challenges = Game.challenges_text(selected_id, mission)
	if challenges != "":
		lines.append(challenges)

	Info.text = "\n".join(lines)
	StartButton.disabled = state == "locked"

func _on_mission_pressed(mission_id):
	selected_id = mission_id
	_refresh()

func _on_start_button_pressed():
	Game.start_mission(selected_id)
