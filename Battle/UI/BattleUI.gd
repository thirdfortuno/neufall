extends Control

signal move_button_pressed
signal ability_1_button_pressed
signal ability_2_button_pressed
signal ability_3_button_pressed
signal ability_4_button_pressed
signal end_turn_button_pressed

@onready var UnitInfoName = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Name
@onready var UnitInfoMove = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Move
@onready var UnitInfoSize = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/Size
@onready var MoveButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/MoveButton
@onready var Ability1Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability1Button
@onready var Ability2Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability2Button
@onready var Ability3Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability3Button
@onready var Ability4Button = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/Ability4Button
@onready var EndTurnButton = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo/VBoxContainer/EndTurnButton

func show_unit(unit):
	_clear_unit_info()
	if unit:
		UnitInfoName.text = unit.type
		UnitInfoMove.text = "Move: %d" % [unit.moves_max]
		UnitInfoSize.text = "Size: %d / %d" % [unit.bodies.size(), unit.hp_max]
		
		EndTurnButton.visible = true
		MoveButton.visible = true
		if unit.moves_available && unit.active:
			MoveButton.disabled = false
		else:
			MoveButton.disabled = true
		
		var ability_size = unit.abilities.size()
		if ability_size >= 1:
			if ability_size >= 2:
				if ability_size >= 3:
					if ability_size == 4:
						Ability4Button.text = unit.abilities[3].ability_name
						Ability4Button.visible = true
					Ability3Button.text = unit.abilities[2].ability_name
					Ability3Button.visible = true
				Ability2Button.text = unit.abilities[1].ability_name
				Ability2Button.visible = true
			Ability1Button.text = unit.abilities[0].ability_name
			Ability1Button.visible = true

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
