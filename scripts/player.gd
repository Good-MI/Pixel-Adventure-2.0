extends CharacterBody2D
class_name Player

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound


const SPEED: float = 300.0
const JUMP_VELOCITY: float = -850.0
## The player dies after falling out of the bottom of a level.
const FALL_DEATH_Y: float = 900.0
## How long the death animation plays before the run restarts.
const DEATH_PAUSE: float = 0.9

var is_dead: bool = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	
	# Add animation
	if velocity.x > 1 or velocity.x < -1:
		animated_sprite_2d.animation = "running"
	else:
		animated_sprite_2d.animation = "idle"

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		animated_sprite_2d.animation = "jumping"

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	if direction == 1.0:
		animated_sprite_2d.flip_h = false
	elif direction == -1.0:
		animated_sprite_2d.flip_h = true

	# Fell out of the bottom of the level.
	if global_position.y > FALL_DEATH_Y:
		die()


## Kills the player (enemy contact or falling out of the map): plays the death
## animation, then asks the GameManager to restart the run.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	animated_sprite_2d.play("dying")
	GameManager.play_sfx(GameManager.Sfx.DEATH)

	await get_tree().create_timer(DEATH_PAUSE).timeout
	await GameManager.reset_game()
	is_dead = false


## Called by the GameManager every time a level is loaded.
func reset_state() -> void:
	is_dead = false
	velocity = Vector2.ZERO
	animated_sprite_2d.play("idle")
