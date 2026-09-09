extends Area2D

signal apple_collected

var collected: bool = false


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.is_in_group("player") or body.name == "Player":
		collected = true
		apple_collected.emit()
		queue_free()
