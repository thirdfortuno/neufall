extends VBoxContainer

func show_unit(unit):
	_clear_names()
	if unit:
		$UnitName.text = unit.type
		
		
		if unit.active:
			$Ability4Button.disabled = false
			$Ability3Button.disabled = false
			$Ability2Button.disabled = false
			$Ability1Button.disabled = false
		else:
			$Ability4Button.disabled = true
			$Ability3Button.disabled = true
			$Ability2Button.disabled = true
			$Ability1Button.disabled = true
		
			
		# Yeah uh. . . four words:
		# Design Debt. Tech Debt
		var ability_size = unit.abilities.size()
		if ability_size >= 1:
			if ability_size >= 2:
				if ability_size >= 3:
					if ability_size == 4:
						$Ability4Button.text = unit.abilities[3].ability_name
						$Ability4Button.visible = true
					$Ability3Button.text = unit.abilities[2].ability_name
					$Ability3Button.visible = true
				$Ability2Button.text = unit.abilities[1].ability_name
				$Ability2Button.visible = true
			$Ability1Button.text = unit.abilities[0].ability_name
			$Ability1Button.visible = true

func _clear_names():
	$UnitName.text = ''
	$Ability4Button.visible = false
	$Ability3Button.visible = false
	$Ability2Button.visible = false
	$Ability1Button.visible = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

