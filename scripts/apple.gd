extends Area2D

signal apple_collected

var collected: bool = false


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	GameManager.add_score(1)
	GameManager.play_sfx(GameManager.Sfx.COLLECT)
	apple_collected.emit()
	queue_free()
