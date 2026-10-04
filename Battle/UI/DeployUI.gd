extends PanelContainer

signal unit_chosen(unit_id)
signal start_pressed
signal back_pressed

var roster_buttons = {}

@onready var RosterScroll = $VBox/RosterScroll
@onready var RosterList = $VBox/RosterScroll/Roster
@onready var ObjectiveLabel = $VBox/Objective
@onready var CountLabel = $VBox/Count
@onready var GoalsLabel = $VBox/Goals
@onready var StartButton = $VBox/StartButton

func show_roster(unit_ids, units, max_count):
	for unit_id in unit_ids:
		var ability_names = []
		for ability in units[unit_id]["abilities"]:
			ability_names.append(ability["ability_name"])

		var button = Button.new()
		button.toggle_mode = true
		button.tooltip_text = Game.unit_details_text(unit_id)
		button.text = "%s: %s" % [units[unit_id]["name"], ", ".join(ability_names)]
		button.pressed.connect(_on_roster_button_pressed.bind(unit_id))
		RosterList.add_child(button)
		roster_buttons[unit_id] = button

	RosterScroll.fit(RosterList)

func show_objective(text):
	ObjectiveLabel.text = "Objective: %s" % text

func show_challenges(text):
	GoalsLabel.visible = text != ""
	GoalsLabel.text = text

func set_count(count, max_count, can_start):
	CountLabel.text = "Deployed: %d / %d" % [count, max_count]
	StartButton.disabled = !can_start

func set_selected(unit_id):
	for id in roster_buttons:
		roster_buttons[id].set_pressed_no_signal(id == unit_id)

func _on_roster_button_pressed(unit_id):
	unit_chosen.emit(unit_id)

func _on_start_button_pressed():
	start_pressed.emit()

func _on_back_button_pressed():
	back_pressed.emit()
