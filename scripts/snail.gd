extends Area2D

## Walking speed in pixels per second.
@export var speed: float = 30.0
## How far (in pixels) the snail walks from its spawn point before turning around.
@export var patrol_distance: float = 32.0

var direction: float = -1.0

var _spawn_x: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_spawn_x = position.x


func _process(delta: float) -> void:
	position.x += direction * speed * delta

	# Turn around at the end of the patrol so the snail stays on its platform.
	if absf(position.x - _spawn_x) > patrol_distance:
		position.x = _spawn_x + direction * patrol_distance
		_flip()


func _on_timer_timeout() -> void:
	_flip()


func _flip() -> void:
	direction *= -1.0
	sprite.flip_h = direction > 0 # Flip sprite based on direction


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("die"):
		body.call("die")
