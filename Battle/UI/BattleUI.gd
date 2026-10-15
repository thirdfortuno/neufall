extends Control

signal move_button_pressed
signal ability_1_button_pressed
signal ability_2_button_pressed
signal ability_3_button_pressed
signal ability_4_button_pressed
signal end_turn_button_pressed
signal undo_move_button_pressed
signal end_all_button_pressed
signal end_all_confirmed
signal event_dismissed
signal ability_hovered(index)
signal ability_unhovered

@onready var UnitInfoName = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Name
@onready var UnitInfoMove = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Move
@onready var UnitInfoSize = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Size
@onready var MoveButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/MoveButton
@onready var Ability1Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability1Button
@onready var Ability2Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability2Button
@onready var Ability3Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability3Button
@onready var Ability4Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability4Button
@onready var EndTurnButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/EndTurnButton
@onready var UndoMoveButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/UndoMoveButton
@onready var AbilityButtonList = [Ability1Button, Ability2Button, Ability3Button, Ability4Button]
@onready var RightColumn = $RightColumn
@onready var MissionNameLabel = $RightColumn/Objective/VBox/Body/Content/MissionName
@onready var GoalLabel = $RightColumn/Objective/VBox/Body/Content/Goal
@onready var TurnLabel = $RightColumn/Objective/VBox/Body/Content/Turn
@onready var LogScroll = $RightColumn/Log/VBox/Body/Content/Scroll
@onready var LogLines = $RightColumn/Log/VBox/Body/Content/Scroll/Lines
@onready var EventPanel = $EventPanel
@onready var EventText = $EventPanel/VBox/Body/Content/EventText

const MAX_LOG_LINES = 60
@onready var EndAllDialog = $EndAllDialog
@onready var MinimapView = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/Minimap/MinimapView

func _ready():
	for i in AbilityButtonList.size():
		AbilityButtonList[i].mouse_entered.connect(_on_ability_hovered.bind(i))
		AbilityButtonList[i].mouse_exited.connect(_on_ability_unhovered)

func set_battle(battle):
	MinimapView.battle = battle

func set_objective(mission_name, goal, turn_text):
	MissionNameLabel.text = mission_name
	GoalLabel.text = goal
	TurnLabel.text = turn_text

func set_right_column_visible(shown):
	RightColumn.visible = shown

func add_log(text):
	var line = Label.new()
	line.text = text
	line.custom_minimum_size = Vector2(184, 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LogLines.add_child(line)
	LogLines.move_child(line, 0)

	while LogLines.get_child_count() > MAX_LOG_LINES:
		var oldest = LogLines.get_child(LogLines.get_child_count() - 1)
		LogLines.remove_child(oldest)
		oldest.queue_free()

	await get_tree().process_frame
	LogScroll.fit(LogLines)

func show_event(title, text):
	EventPanel.set_title(title)
	EventText.text = text
	EventPanel.visible = true

func hide_event():
	EventPanel.visible = false

func get_event_height():
	if !EventPanel.visible:
		return 0.0
	return EventPanel.size.y + 8.0

func ask_end_all(count):
	if count == 1:
		EndAllDialog.dialog_text = "1 unit has not acted. End your turn anyway?"
	else:
		EndAllDialog.dialog_text = "%d units have not acted. End your turn anyway?" % count
	EndAllDialog.popup_centered()

func show_unit(unit, readonly = false):
	_clear_unit_info()
	if unit:
		UnitInfoName.text = unit.type
		UnitInfoMove.text = "Move: %d" % [unit.moves_max]
		UnitInfoSize.text = "Size: %d / %d" % [unit.bodies.size(), unit.hp_max]
		
		EndTurnButton.visible = true
		EndTurnButton.disabled = !unit.active
		
		UndoMoveButton.visible = true
		UndoMoveButton.disabled = !unit.moved || !unit.active
		
		MoveButton.visible = true
		if unit.moves_available > 0 && unit.active:
			MoveButton.disabled = false
		else:
			MoveButton.disabled = true
		
		var i = 0
		for ability in unit.abilities:
			AbilityButtonList[i].text = ability.ability_name
			var tooltip_lines = []
			if ability.description != "":
				tooltip_lines.append(ability.description)
			tooltip_lines.append("Range: %d" % ability.ability_range)
			AbilityButtonList[i].tooltip_text = "\n".join(tooltip_lines)
			AbilityButtonList[i].visible = true
			if ability.has('size_requirement'):
				if unit.bodies.size() < ability.size_requirement:
					AbilityButtonList[i].disabled = true
				else:
					AbilityButtonList[i].disabled = false
			else:
				AbilityButtonList[i].disabled = false
			if unit.active == false:
				AbilityButtonList[i].disabled = true
			i = i + 1
		
		if readonly:
			MoveButton.disabled = true
			EndTurnButton.visible = false
			UndoMoveButton.visible = false
			for button in AbilityButtonList:
				button.disabled = true

func _clear_unit_info():
	UnitInfoName.text = ""
	UnitInfoMove.text = ""
	UnitInfoSize.text = ""
	MoveButton.visible = false
	Ability1Button.visible = false
	Ability2Button.visible = false
	Ability3Button.visible = false
	Ability4Button.visible = false
	EndTurnButton.visible = false
	UndoMoveButton.visible = false

func _on_move_button_pressed():
	move_button_pressed.emit()

func _on_end_turn_button_pressed():
	end_turn_button_pressed.emit()

func _on_menu_button_pressed():
	$BattleMenu.popup_centered()

func _on_end_all_button_pressed():
	end_all_button_pressed.emit()

func _on_event_continue_pressed():
	event_dismissed.emit()

func _on_end_all_confirmed():
	end_all_confirmed.emit()

func _on_ability_hovered(index):
	ability_hovered.emit(index)

func _on_ability_unhovered():
	ability_unhovered.emit()

func _on_ability_1_button_pressed():
	ability_1_button_pressed.emit()

func _on_ability_2_button_pressed():
	ability_2_button_pressed.emit()

func _on_ability_3_button_pressed():
	ability_3_button_pressed.emit()

func _on_ability_4_button_pressed():
	ability_4_button_pressed.emit()

func _on_undo_move_button_pressed():
	undo_move_button_pressed.emit()
