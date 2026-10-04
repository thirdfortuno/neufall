extends ScrollContainer

@export var max_height = 200

func fit(content):
	custom_minimum_size.y = min(content.get_combined_minimum_size().y, max_height)
