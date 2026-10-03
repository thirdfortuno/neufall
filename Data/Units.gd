const UNITS = {
	"hack": {
		"name": "Hack",
		"abbr": "HAK",
		"side": "player",
		"generation": 1,
		"tags": ["hack"],
		"hp_max": 3,
		"moves_max": 5,
		"sprite_main": "res://Unit/Sprites/Hack/hack.png",
		"sprite_shadow": "res://Unit/Sprites/Hack/hack_shadow.png",
		"abilities": [
			{
				"ability_name": "Slice",
				"ability_range": 1,
				"targets": ["enemy"],
				"effects": [
					{
						"type": "damage",
						"amount": 2
					}
				]
			},
			{
				"ability_name": "Dice",
				"ability_range": 2,
				"targets": ["enemy"],
				"effects": [
					{
						"type": "damage",
						"amount": 2
					}
				],
				"size_requirement": 2,
				"size_cost": 1
			}
		]
	},
	"hack_support": {
		"name": "Hack",
		"abbr": "HAK",
		"side": "player",
		"generation": 1,
		"tags": ["hack", "support"],
		"hp_max": 3,
		"moves_max": 5,
		"sprite_main": "res://Unit/Sprites/Hack/hack.png",
		"sprite_shadow": "res://Unit/Sprites/Hack/hack_shadow.png",
		"abilities": [
			{
				"ability_name": "Steroids",
				"ability_range": 1,
				"targets": ["ally", "self"],
				"effects": [
					{
						"type": "hp_max_add",
						"amount": 2
					},
					{
						"type": "moves_max_add",
						"amount": 2
					}
				]
			},
			{
				"ability_name": "Heal",
				"ability_range": 2,
				"targets": ["ally", "self"],
				"effects": [
					{
						"type": "heal",
						"amount": 5
					}
				]
			}
		]
	},
	"security_camera": {
		"name": "Security Camera",
		"abbr": "CAM",
		"side": "enemy",
		"generation": 1,
		"tags": ["camera"],
		"hp_max": 3,
		"moves_max": 3,
		"sprite_main": "res://Unit/Sprites/SecurityCam/security_cam.png",
		"sprite_shadow": "res://Unit/Sprites/SecurityCam/security_cam_shadow.png",
		"abilities": [
			{
				"ability_name": "Slice",
				"ability_range": 1,
				"targets": ["enemy"],
				"effects": [
					{
						"type": "damage",
						"amount": 2
					}
				]
			}
		]
	}
}
