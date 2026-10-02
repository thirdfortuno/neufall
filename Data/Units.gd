const UNITS = {
	"hack": {
		"name": "Hack",
		"generation": 1,
		"tags": ["hack"],
		"hp_max": 3,
		"moves_max": 5,
		"sprite_main": "res://Unit/Sprites/Hack/hack.png",
		"sprite_shadow": "res://Unit/Sprites/Hack/hack_shadow.png",
		"abilities": [
			{
				"ability_name": "Slice",
				"damage": 2,
				"ability_range": 1
			},
			{
				"ability_name": "Dice",
				"damage": 2,
				"ability_range": 2,
				"size_requirement": 2,
				"size_cost": 1
			}
		]
	},
	"hack_support": {
		"name": "Hack",
		"generation": 1,
		"tags": ["hack", "support"],
		"hp_max": 3,
		"moves_max": 5,
		"sprite_main": "res://Unit/Sprites/Hack/hack.png",
		"sprite_shadow": "res://Unit/Sprites/Hack/hack_shadow.png",
		"abilities": [
			{
				"ability_name": "Steroids",
				"hp_max_add": 2,
				"moves_max_add": 2,
				"ability_range": 1
			},
			{
				"ability_name": "Heal",
				"heal": 5,
				"ability_range": 2
			}
		]
	},
	"security_camera": {
		"name": "Security Camera",
		"generation": 1,
		"tags": ["camera"],
		"hp_max": 3,
		"moves_max": 3,
		"sprite_main": "res://Unit/Sprites/SecurityCam/security_cam.png",
		"sprite_shadow": "res://Unit/Sprites/SecurityCam/security_cam_shadow.png",
		"abilities": [
			{
				"ability_name": "Slice",
				"damage": 2,
				"ability_range": 1
			}
		]
	}
}
