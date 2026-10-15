extends Node

const BUS = "SFX"
const VOICES = 8
const UNIT_MOVE = [
	"res://SFX/unit_move1.ogg",
	"res://SFX/unit_move2.ogg",
]

var players = []

func play(path):
	if path == null || path == "":
		return
	
	var stream = load(path)
	if stream == null:
		return
	
	for player in players:
		if !player.playing:
			player.stream = stream
			player.play()
			return
	
	players[0].stream = stream
	players[0].play()

# A unit's own move sound if it has one, otherwise a random one of the default steps
func play_move(path):
	if path == null || path == "":
		path = UNIT_MOVE.pick_random()
	play(path)

func _ready():
	for i in VOICES:
		var player = AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		players.append(player)
