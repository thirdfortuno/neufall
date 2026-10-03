extends HBoxContainer

@onready var ResourcesLabel = $Resources
@onready var OverworldButton = $OverworldButton

func _ready():
	ResourcesLabel.text = "Resources: %s" % Game.resources_text(Game.profile["resources"])

func set_current(screen):
	OverworldButton.disabled = screen == "overworld"

func _on_overworld_button_pressed():
	Game.go_to_overworld()
