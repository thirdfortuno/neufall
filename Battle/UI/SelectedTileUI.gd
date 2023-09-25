extends VBoxContainer

func show_tile(tile):
	_clear_names()
	$TileCoords.text = "%d %d" % [tile.x, tile.y]
	$TileState.text = "On" if tile.state else "Off"

func _clear_names():
	$TileCoords.text = ""
	$TileState.text = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
