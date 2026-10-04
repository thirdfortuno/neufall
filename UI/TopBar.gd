extends HBoxContainer

@onready var ResourcesLabel = $Resources
@onready var OverworldButton = $OverworldButton
@onready var TechTreeButton = $TechTreeButton

func _ready():
	refresh()

func refresh():
	ResourcesLabel.text = "Resources: %s" % Game.resources_text(Game.profile["resources"])

func set_current(screen):
	OverworldButton.disabled = screen == "overworld"
	TechTreeButton.disabled = screen == "tech_tree"

func _on_overworld_button_pressed():
	Game.go_to_overworld()

func _on_tech_tree_button_pressed():
	Game.go_to_tech_tree()

func _on_refresh_button_pressed():
	$ConfirmDialog.popup_centered()

func _on_refresh_confirmed():
	Game.new_save()
	get_tree().reload_current_scene()
