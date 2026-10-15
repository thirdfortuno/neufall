extends PanelContainer

@export var title = ""
@export var collapsible = true

@onready var TitleLabel = $VBox/Title/Text
@onready var TitleToggle = $VBox/Title/Toggle
@onready var Body = $VBox/Body
@onready var Content = $VBox/Body/Content

func set_title(text):
	title = text
	TitleLabel.text = text

func set_collapsed(collapsed):
	Body.visible = !collapsed

func _on_title_pressed():
	if collapsible:
		Body.visible = !Body.visible

func _ready():
	TitleLabel.text = title
	if collapsible:
		TitleToggle.tooltip_text = "Click to collapse or expand"
