extends Control

signal move_button_pressed
signal ability_1_button_pressed
signal ability_2_button_pressed
signal ability_3_button_pressed
signal ability_4_button_pressed
signal skip_button_pressed

@onready var UnitInfo = $VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/UnitInfo

func show_unit(unit):
	print(unit)
	
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_move_button_pressed():
	move_button_pressed.emit()

func _on_skip_button_pressed():
	skip_button_pressed.emit()

func _on_ability_1_button_pressed():
	ability_1_button_pressed.emit()

func _on_ability_2_button_pressed():
	ability_2_button_pressed.emit()

func _on_ability_3_button_pressed():
	ability_3_button_pressed.emit()

func _on_ability_4_button_pressed():
	ability_4_button_pressed.emit()
