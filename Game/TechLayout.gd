const NODE_SIZE = Vector2(200, 70)
const COLUMN_STEP = 240.0
const ROW_STEP = 120.0
const MARGIN = Vector2(20, 20)
const SWEEPS = 4

func layout(tech_nodes):
	var ids = tech_nodes.keys()
	if ids.size() == 0:
		return {}

	var parents = _parents(tech_nodes)
	var depth = _depths(ids, parents)
	var layers = _ordered_layers(ids, parents, depth)
	return _positions(layers)

func _parents(tech_nodes):
	var result = {}
	for node_id in tech_nodes:
		var list = []
		for unit_id in tech_nodes[node_id]["required_units"]:
			for other_id in tech_nodes:
				if other_id != node_id && tech_nodes[other_id]["unit"] == unit_id:
					list.append(other_id)
		result[node_id] = list
	return result

func _depths(ids, parents):
	var depth = {}
	for node_id in ids:
		depth[node_id] = 0

	for iteration in ids.size():
		var changed = false
		for node_id in ids:
			for parent_id in parents[node_id]:
				var wanted = min(depth[parent_id] + 1, ids.size())
				if wanted > depth[node_id]:
					depth[node_id] = wanted
					changed = true
		if !changed:
			break

	return depth

func _ordered_layers(ids, parents, depth):
	var layer_count = 0
	for node_id in ids:
		layer_count = max(layer_count, depth[node_id] + 1)

	var layers = []
	for i in layer_count:
		layers.append([])
	for node_id in ids:
		layers[depth[node_id]].append(node_id)

	for sweep in SWEEPS:
		var index_of = {}
		for layer in layers:
			for i in layer.size():
				index_of[layer[i]] = i

		for layer_index in range(1, layers.size()):
			var keyed = []
			for i in layers[layer_index].size():
				var node_id = layers[layer_index][i]
				var total = 0.0
				var count = 0
				for parent_id in parents[node_id]:
					if depth[parent_id] < layer_index:
						total = total + index_of[parent_id]
						count = count + 1

				var barycenter = float(i)
				if count > 0:
					barycenter = total / count
				keyed.append([barycenter, i, node_id])

			keyed.sort_custom(Callable(self, "_compare_keyed"))

			var ordered = []
			for entry in keyed:
				ordered.append(entry[2])
			layers[layer_index] = ordered

	return layers

func _compare_keyed(a, b):
	if a[0] == b[0]:
		return a[1] < b[1]
	return a[0] < b[0]

func _positions(layers):
	var positions = {}
	var min_x = INF

	for layer_index in layers.size():
		var layer = layers[layer_index]
		for i in layer.size():
			var x = (i - (layer.size() - 1) / 2.0) * COLUMN_STEP
			positions[layer[i]] = Vector2(x, layer_index * ROW_STEP)
			min_x = min(min_x, x)

	for node_id in positions:
		positions[node_id] = positions[node_id] - Vector2(min_x, 0) + MARGIN

	return positions
