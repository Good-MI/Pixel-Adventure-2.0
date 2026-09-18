extends CanvasLayer
class_name HUD
## Score + level readout. It reads everything from the GameManager singleton so
## the values survive level changes.

@onready var score_label: Label = $Panel/ScoreLabel
@onready var level_label: Label = $LevelLabel


func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_changed.connect(_on_level_changed)
	_on_score_changed(GameManager.score)
	_on_level_changed(GameManager.current_level_index)


func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func _on_level_changed(level_index: int) -> void:
	level_label.text = "Level %d/%d" % [level_index, GameManager.max_levels]
	# Refresh the score as well, so the readout can never go stale across a level change.
	_on_score_changed(GameManager.score)
