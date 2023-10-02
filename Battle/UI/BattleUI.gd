extends Control

signal move_button_pressed
signal ability_1_button_pressed
signal ability_2_button_pressed
signal ability_3_button_pressed
signal ability_4_button_pressed
signal end_turn_button_pressed
signal undo_move_button_pressed

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

func show_unit(unit):
	_clear_unit_info()
	if unit:
		UnitInfoName.text = unit.type
		UnitInfoMove.text = "Move: %d" % [unit.moves_max]
		UnitInfoSize.text = "Size: %d / %d" % [unit.bodies.size(), unit.hp_max]
		
		EndTurnButton.visible = true
		EndTurnButton.disabled = !unit.active
		
		UndoMoveButton.visible = true
		UndoMoveButton.disabled = !unit.moved
		
		MoveButton.visible = true
		if unit.moves_available && unit.active:
			MoveButton.disabled = false
		else:
			MoveButton.disabled = true
		
		var i = 0
		for ability in unit.abilities:
			AbilityButtonList[i].text = ability.ability_name
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
