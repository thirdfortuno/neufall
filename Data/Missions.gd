const CAMERA_BEHAVIOR = {
	"version": 1,
	"search": [
		{
			"range": 15,
			"method": "absolute"
		}
	],
	"peace": [
		{
			"method": "roam"
		}
	],
	"war": [
		{
			"method": "nearest"
		},
		{
			"method": "weakest"
		},
		{
			"method": "random"
		}
	]
}

const MISSIONS = {
	"training_node": {
		"name": "Training Node",
		"grid": [
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,0,1,1,1,1,1,1],
			[1,1,1,1,1,1,0,0,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,0,1,0,1,0,0,0,1,1,1,1,1,1],
			[1,0,1,1,1,0,0,0,1,1,1,1,1,1],
			[1,0,0,0,0,0,0,0,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1,1,1,1,1,1,1]
		],
		"max_generation": 1,
		"spawn_tiles": [
			[1, 1],
			[2, 2]
		],
		"victory": {
			"type": "eliminate_all"
		},
		"first_clear_reward": {
			"data": 2
		},
		"challenges": [
			{
				"id": "fast",
				"description": "Win within 6 turns",
				"type": "win_within_turns",
				"params": {
					"turns": 6
				},
				"reward": {
					"data": 3
				}
			},
			{
				"id": "no_losses",
				"description": "Win without losing a unit",
				"type": "no_unit_lost",
				"params": {},
				"reward": {
					"bandwidth": 1
				}
			},
			{
				"id": "lone_unit",
				"description": "Win with a single unit",
				"type": "max_units",
				"params": {
					"count": 1
				},
				"reward": {
					"data": 2
				}
			},
			{
				"id": "hack_only",
				"description": "Win using only Hack units",
				"type": "only_tag",
				"params": {
					"tag": "hack"
				},
				"reward": {
					"bandwidth": 1
				}
			}
		],
		"enemies": [
			{
				"unit": "security_camera",
				"x": 4,
				"y": 4,
				"behavior": CAMERA_BEHAVIOR
			},
			{
				"unit": "security_camera",
				"x": 3,
				"y": 3,
				"behavior": CAMERA_BEHAVIOR
			}
		]
	}
}
