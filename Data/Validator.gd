const EFFECT_TYPES = ["damage", "heal", "hp_max_add", "moves_max_add", "drain", "tile_set"]
const TILE_TARGET_FLAG = 8
const MAX_ABILITIES = 4

func unit_errors(unit_id, def):
	var errors = []
	var label = "Unit %s" % unit_id

	if def.unit_name == "":
		errors.append("%s: unit_name is empty" % label)
	if def.hp_max < 1:
		errors.append("%s: hp_max must be at least 1" % label)
	if def.moves_max < 0:
		errors.append("%s: moves_max cannot be negative" % label)
	if def.generation < 1:
		errors.append("%s: generation must be at least 1" % label)
	if def.sprite_main != null && def.sprite_shadow == null:
		errors.append("%s: has a sprite_main but no sprite_shadow" % label)

	if def.abilities.size() == 0:
		errors.append("%s: has no abilities" % label)
	if def.abilities.size() > MAX_ABILITIES:
		errors.append("%s: has more than %d abilities (the UI has %d buttons)" % [label, MAX_ABILITIES, MAX_ABILITIES])

	for ability in def.abilities:
		if ability == null:
			errors.append("%s: an ability slot is empty" % label)
		else:
			errors.append_array(_ability_errors(label, ability))

	return errors

func tech_errors(node_id, def, node_ids, unit_ids):
	var errors = []
	var label = "Tech node %s" % node_id

	if def.unit == null:
		errors.append("%s: has no unit" % label)
	elif !unit_ids.has(def.unit.resource_path.get_file().get_basename()):
		errors.append("%s: unit %s is not a valid unit in the UnitLibrary" % [label, def.unit.resource_path.get_file().get_basename()])

	for type in def.cost:
		if typeof(def.cost[type]) != TYPE_INT || def.cost[type] < 0:
			errors.append("%s: cost for '%s' must be a whole number of 0 or more" % [label, type])

	for required in def.requires:
		if required == null:
			errors.append("%s: a requires slot is empty" % label)
			continue
		var required_id = required.resource_path.get_file().get_basename()
		if required_id == node_id:
			errors.append("%s: requires itself" % label)
		elif !node_ids.has(required_id):
			errors.append("%s: requires %s, which is not in the TechTree" % [label, required_id])

	return errors

func tech_cycle_ids(requires_by_id):
	var in_cycle = []
	for start in requires_by_id:
		if _reaches(requires_by_id, start, start, []):
			in_cycle.append(start)
	return in_cycle

func level_errors(level_id, scene, unit_ids, level_ids):
	var errors = []
	var label = "Level %s" % level_id
	var level = scene.instantiate()

	if !(level is LevelDef):
		errors.append("%s: the root node must use the LevelDef script" % label)
		level.free()
		return errors

	if level.mission_name == "":
		errors.append("%s: mission_name is empty" % label)
	if level.max_generation < 1:
		errors.append("%s: max_generation must be at least 1" % label)

	for required_id in level.requires:
		if required_id == level_id:
			errors.append("%s: requires itself" % label)
		elif !level_ids.has(required_id):
			errors.append("%s: requires %s, which is not in the Campaign" % [label, required_id])

	errors.append_array(_challenge_errors(label, level.challenges))

	var layer = level.get_node_or_null("Floor")
	if layer == null || !(layer is TileMapLayer):
		errors.append("%s: needs a child TileMapLayer named Floor" % label)
		level.free()
		return errors

	var rect = layer.get_used_rect()
	if layer.tile_set == null:
		errors.append("%s: Floor has no TileSet" % label)
	elif rect.size == Vector2i.ZERO:
		errors.append("%s: Floor has no painted tiles" % label)
	else:
		errors.append_array(_marker_errors(label, level, layer, rect, unit_ids))

	level.free()
	return errors

func _marker_errors(label, level, layer, rect, unit_ids):
	var errors = []
	var occupied = {}
	var spawns = 0
	var enemies = 0
	var targets = 0
	var goals = 0

	for child in level.get_children():
		var kind = ""
		if child is SpawnMarker:
			kind = "SpawnMarker"
			spawns = spawns + 1
		elif child is EnemyMarker:
			kind = "EnemyMarker"
			enemies = enemies + 1
			if child.is_target:
				targets = targets + 1
		elif child is GoalMarker:
			kind = "GoalMarker"
			goals = goals + 1
		else:
			continue

		var cell = Game.marker_cell(layer, rect, child)
		var key = Vector2i(cell[0], cell[1])
		var where = "%s '%s' at tile (%d, %d)" % [kind, child.name, cell[0], cell[1]]

		if layer.get_cell_source_id(rect.position + key) == -1:
			errors.append("%s: %s is on an empty (void) tile" % [label, where])
		if occupied.has(key):
			errors.append("%s: %s shares its tile with '%s'" % [label, where, occupied[key]])
		occupied[key] = child.name

		if child is EnemyMarker:
			if child.unit == null:
				errors.append("%s: %s has no unit" % [label, where])
			elif !unit_ids.has(child.unit.resource_path.get_file().get_basename()):
				errors.append("%s: %s uses unit %s, which is not a valid unit in the UnitLibrary" % [label, where, child.unit.resource_path.get_file().get_basename()])

	if spawns == 0:
		errors.append("%s: needs at least one SpawnMarker" % label)
	if enemies == 0:
		errors.append("%s: needs at least one EnemyMarker" % label)

	if level.victory_type == "reach_tile" && goals != 1:
		errors.append("%s: reach_tile victory needs exactly one GoalMarker (found %d)" % [label, goals])
	if level.victory_type == "kill_unit" && targets == 0:
		errors.append("%s: kill_unit victory needs at least one EnemyMarker with is_target ticked" % label)

	return errors

func _challenge_errors(label, challenges):
	var errors = []
	var seen = []

	for challenge in challenges:
		if challenge == null:
			errors.append("%s: a challenge slot is empty" % label)
			continue

		var challenge_label = "%s challenge '%s'" % [label, challenge.id]
		if challenge.id == "":
			errors.append("%s: a challenge has no id" % label)
		elif seen.has(challenge.id):
			errors.append("%s: two challenges share the id '%s'" % [label, challenge.id])
		seen.append(challenge.id)

		if challenge.description == "":
			errors.append("%s: description is empty" % challenge_label)

		match challenge.type:
			"win_within_turns", "max_generation", "max_units":
				if challenge.value < 1:
					errors.append("%s: value must be at least 1" % challenge_label)
			"only_tag":
				if challenge.tag == "":
					errors.append("%s: tag is empty" % challenge_label)
			"require_tag":
				if challenge.tag == "":
					errors.append("%s: tag is empty" % challenge_label)
				if challenge.value < 1:
					errors.append("%s: value must be at least 1" % challenge_label)

		for type in challenge.reward:
			if typeof(challenge.reward[type]) != TYPE_INT || challenge.reward[type] < 0:
				errors.append("%s: reward for '%s' must be a whole number of 0 or more" % [challenge_label, type])

	return errors

func _ability_errors(unit_label, ability):
	var errors = []
	var label = "%s ability '%s'" % [unit_label, ability.ability_name]

	if ability.ability_name == "":
		errors.append("%s: ability_name is empty" % unit_label)
	if ability.ability_range < 1:
		errors.append("%s: ability_range must be at least 1" % label)
	if ability.targets == 0:
		errors.append("%s: no targets are ticked" % label)
	if ability.effects.size() == 0:
		errors.append("%s: has no effects" % label)

	var has_tile_effect = false
	for effect in ability.effects:
		if effect == null:
			errors.append("%s: an effect slot is empty" % label)
			continue

		if !EFFECT_TYPES.has(effect.type):
			errors.append("%s: unknown effect type '%s'" % [label, effect.type])
		elif effect.type == "tile_set":
			has_tile_effect = true
		elif effect.amount < 1:
			errors.append("%s: effect '%s' needs an amount of at least 1" % [label, effect.type])

	if ability.targets == TILE_TARGET_FLAG && !has_tile_effect:
		errors.append("%s: only targets tiles but has no tile_set effect" % label)

	return errors

func _reaches(requires_by_id, current, target, visited):
	for required_id in requires_by_id.get(current, []):
		if required_id == target:
			return true
		if !visited.has(required_id):
			visited.append(required_id)
			if _reaches(requires_by_id, required_id, target, visited):
				return true
	return false
