extends AnimatableBody2D
class_name MovingPlatform
## Platform driven by an AnimationPlayer that is looping a position animation.
##
## The animation drives the platform's *local* position, so place the platform
## under a plain Node2D "slot" and move the slot instead of the platform itself.
## That keeps one reusable platform scene for every platform in every level.

## Animation to play from the AnimationPlayer's library ("move_x" / "move_y").
@export var animation_name: StringName = &"move_x"

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# An AnimatableBody2D must be animated in the physics step for its motion to
	# be propagated to the bodies standing on it (the Player).
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	if not animation_player.has_animation(animation_name):
		var names: PackedStringArray = animation_player.get_animation_list()
		if names.is_empty():
			push_warning("MovingPlatform: AnimationPlayer has no animation to play.")
			return
		animation_name = names[0]

	animation_player.play(animation_name)
