extends Node2D

@onready var score_label: Label = $HUD/Panel/ScoreLabel
var score: int = 0


func _ready() -> void:
	# Auto-connects every Apple already in the scene (group set in Apple.tscn)
	for apple in get_tree().get_nodes_in_group("collectibles"):
		apple.apple_collected.connect(_on_apple_collected)


func _on_apple_collected() -> void:
	score += 1
	score_label.text = "Score: %s" % score
