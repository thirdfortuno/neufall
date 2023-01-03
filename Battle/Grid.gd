class_name Grid

var height
var width

var grid_data = []

func get_adjacent_values(x, y):
	var values = []
	if x != 0:
		values.append(get_value(x-1, y))
	if x < width - 1:
		values.append(get_value(x+1, y))
	if y != 0:
		values.append(get_value(x, y-1))
	if y < height - 1:
		values.append(get_value(x, y+1))
	return values

func get_adjacent_values_dict(x, y):
	var values = {
		"up": null,
		"right": null,
		"down": null,
		"left": null
	}
	if x != 0:
		values["left"] = get_value(x-1, y)
	if x < width - 1:
		values["right"] = get_value(x+1, y)
	if y != 0:
		values["up"] = get_value(x, y-1)
	if y < height - 1:
		values["down"] = get_value(x, y+1)
	return values

func get_size():
	return {
		"width": width,
		"height": height
	}

func get_value(x, y):
	return grid_data[_get_index(x,y)]

func set_value(x, y, value):
	grid_data[_get_index(x,y)] = value
	

# Since gdscript doesn't currently support different inits based
# off number of arguments passed, we create our own version instead
func _init(first, second = null):
	if second:
		_init_2(first, second)
	else:
		_init_1(first)

func _init_1(input):
	height = input.size()
	width = input[0].size()
	for row in input:
		grid_data.append_array(row)

func _init_2(x, y):
	height = y
	width = x
	grid_data.resize(x*y)

func _get_index(x, y):
	return width * y + x
