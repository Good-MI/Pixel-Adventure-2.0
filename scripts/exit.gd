extends Area2D
class_name LevelExit
## Finish flag. When the player enters the flag the level is completed and the
## GameManager moves on to the next level in the sequence.

## Optional: an explicit scene to load instead of the next level of the sequence.
@export var next_scene: PackedScene
## Animation played by the flag sprite.
@export var flag_animation: StringName = &"flag_out"

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

var _used: bool = false


func _ready() -> void:
	# Fall back to whatever animation the sprite really has so a renamed
	# animation never silently breaks the exit.
	var frames: SpriteFrames = animated_sprite_2d.sprite_frames
	if frames != null and not frames.has_animation(flag_animation):
		var names: PackedStringArray = frames.get_animation_names()
		if names.size() > 0:
			flag_animation = names[0]
	animated_sprite_2d.play(flag_animation)


func _on_body_entered(body: Node2D) -> void:
	if _used:
		return
	if not body.is_in_group("player"): # Make sure the Player is in the "player" group
		return

	_used = true
	animated_sprite_2d.play(flag_animation)
	set_deferred("monitoring", false) # So the flag can't be triggered twice

	if next_scene != null:
		GameManager.load_scene(next_scene)
	else:
		GameManager.next_level()
