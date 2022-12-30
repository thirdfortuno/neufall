class_name Grid

var height
var width

var grid_data = []

func getValue(x,y):
	var index = width * y + x
	print(grid_data[index])

func _init(input):
	height = input.size()
	width = input[0].size()
	for row in input:
		grid_data.append_array(row)
