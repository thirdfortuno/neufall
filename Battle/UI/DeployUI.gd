extends "res://Battle/UI/SidePanel.gd"

signal unit_chosen(unit_id)
signal start_pressed
signal back_pressed

var roster_buttons = {}

@onready var RosterScroll = $VBox/Body/Content/RosterScroll
@onready var RosterList = $VBox/Body/Content/RosterScroll/Roster
@onready var MissionNameLabel = $VBox/Body/Content/MissionName
@onready var ObjectiveLabel = $VBox/Body/Content/Objective
@onready var CountLabel = $VBox/Body/Content/Count
@onready var MemoryLabel = $VBox/Body/Content/Memory
@onready var GoalsLabel = $VBox/Body/Content/Goals
@onready var StartButton = $VBox/Body/Content/StartButton

func show_roster(unit_ids, units, max_count):
	for unit_id in unit_ids:
		var ability_names = []
		for ability in units[unit_id]["abilities"]:
			ability_names.append(ability["ability_name"])

		var button = Button.new()
		button.toggle_mode = true
		button.clip_text = true
		button.tooltip_text = Game.unit_details_text(unit_id)
		button.text = "%s [%d]" % [units[unit_id]["name"], units[unit_id]["memory"]]
		if ability_names.size() > 0:
			button.text = button.text + ": " + ", ".join(ability_names)
		button.pressed.connect(_on_roster_button_pressed.bind(unit_id))
		RosterList.add_child(button)
		roster_buttons[unit_id] = button

	RosterScroll.fit(RosterList)

func show_mission(mission_name):
	MissionNameLabel.text = mission_name

func show_objective(text):
	ObjectiveLabel.text = "Objective: %s" % text

func show_challenges(text):
	GoalsLabel.visible = text != ""
	GoalsLabel.text = text

func set_count(count, max_count, can_start):
	CountLabel.text = "Deployed: %d / %d" % [count, max_count]
	StartButton.disabled = !can_start

func set_memory(used, max_memory):
	if max_memory <= 0:
		MemoryLabel.text = "Memory: %d" % used
	elif used > max_memory:
		MemoryLabel.text = "Memory: %d / %d (over the limit)" % [used, max_memory]
	else:
		MemoryLabel.text = "Memory: %d / %d" % [used, max_memory]

func set_selected(unit_id):
	for id in roster_buttons:
		roster_buttons[id].set_pressed_no_signal(id == unit_id)

func _on_roster_button_pressed(unit_id):
	unit_chosen.emit(unit_id)

func _on_start_button_pressed():
	start_pressed.emit()

func _on_back_button_pressed():
	back_pressed.emit()
