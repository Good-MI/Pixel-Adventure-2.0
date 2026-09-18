extends Node2D
## Main scene: a permanent shell that keeps the Player and the HUD alive while
## the GameManager swaps levels in and out of the LevelContainer.
##
## Scoring lives in the GameManager singleton and is shown by the HUD.

func _ready() -> void:
	GameManager.start_game()
