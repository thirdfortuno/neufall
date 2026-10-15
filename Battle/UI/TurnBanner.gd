extends CanvasLayer

const SHOW_TIME = 1.0

@onready var Box = $Box
@onready var BannerLabel = $Box/Label

var banner_id = 0

func show_banner(text):
	BannerLabel.text = text
	Box.visible = true

	banner_id = banner_id + 1
	var this_banner = banner_id
	await get_tree().create_timer(SHOW_TIME).timeout
	if this_banner == banner_id:
		Box.visible = false
