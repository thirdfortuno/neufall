extends Control

@onready var MissionScroll = $Center/VBox/MissionScroll
@onready var MissionList = $Center/VBox/MissionScroll/MissionList
@onready var Details = $Center/VBox/DetailsScroll/Details
@onready var StartButton = $Center/VBox/StartButton
@onready var ErrorsLabel = $Center/VBox/Errors

var selected_id

func _ready():
	$TopBar.set_current("overworld")
	
	if Game.content_errors.size() > 0:
		ErrorsLabel.visible = true
		ErrorsLabel.text = "Content errors (also in the Output panel):" + "\n" + "\n".join(Game.content_errors)
	
	for mission_id in Game.missions:
		var mission = Game.missions[mission_id]
		
		var button = Button.new()
		button.text = mission["name"]
		if Game.has_cleared(mission_id):
			button.text = button.text + " (cleared)"
		button.disabled = !Game.is_unlocked(mission)
		button.pressed.connect(_on_mission_button_pressed.bind(mission_id))
		MissionList.add_child(button)
	
	MissionScroll.fit(MissionList)

func _details_text(mission_id):
	var mission = Game.missions[mission_id]
	var lines = [mission["name"]]
	
	if Game.has_cleared(mission_id):
		lines.append("Cleared")
	else:
		lines.append("First clear: %s" % Game.resources_text(mission["first_clear_reward"], "+"))
	
	lines.append("Objective: %s" % Game.victory_text(mission["victory"]))
	lines.append("Squad size: %d" % mission["spawn_tiles"].size())
	lines.append("Max generation: %d" % mission["max_generation"])
	
	var challenges = Game.challenges_text(mission_id, mission)
	if challenges != "":
		lines.append(challenges)
	
	return "\n".join(lines)

func _on_mission_button_pressed(mission_id):
	selected_id = mission_id
	StartButton.disabled = false
	Details.text = _details_text(mission_id)

func _on_start_button_pressed():
	Game.start_mission(selected_id)
