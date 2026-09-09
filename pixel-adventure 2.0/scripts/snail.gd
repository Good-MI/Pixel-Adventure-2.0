extends Area2D

@export var speed: float = 30.0
var direction: float = -1.0
var player_killed: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _process(delta: float) -> void:
	position.x += direction * speed * delta


func _on_timer_timeout() -> void:
	direction *= -1.0
	sprite.flip_h = direction > 0 # Flip sprite based on direction


func _on_body_entered(body: Node2D) -> void:
	if player_killed:
		return
	if body.is_in_group("player") or body.name == "Player":
		player_killed = true
		get_tree().call_deferred("reload_current_scene")
