extends Node
## Integration test for the level progression handled by the GameManager singleton.
##
## It builds the minimum a level needs (a "level_container" node plus a node in
## the "player" group) instead of booting main.tscn, then drives the same calls
## the game makes: load a level, trigger the exit flag, finish the last level.

const FADE_WAIT: float = 1.4
const FLAG_ANIMATION: StringName = &"flag_out"
const FLAG_SPRITESHEET: String = "res://assets/images/flag/exit_flag_wave.png"


func test_level_progression() -> void:
	# --- fake main scene -----------------------------------------------------
	var container: Node2D = Node2D.new()
	container.name = "LevelContainer"
	add_child(container)
	container.add_to_group("level_container")

	var player: Node2D = Node2D.new()
	player.name = "Player"
	add_child(player)
	player.add_to_group("player")

	# --- every registered level exists and loads ------------------------------
	assert(GameManager.level_paths.size() == 3, "expected 3 levels")
	for path: String in GameManager.level_paths:
		assert(ResourceLoader.exists(path), "level scene missing: %s" % path)

	# --- level 1 loads, player lands on its spawn marker ----------------------
	await GameManager.load_level(1)
	assert(GameManager.current_level_index == 1, "should be on level 1")
	assert(container.get_child_count() == 1, "container should hold exactly one level")
	assert(container.get_child(0).name == "Level1", "wrong level loaded")
	# Compare against the level's own PlayerSpawn marker instead of a hard-coded
	# position, so moving the marker in the editor does not break the test.
	var spawn_marker: Node2D = container.get_child(0).get_node_or_null("PlayerSpawn")
	assert(spawn_marker != null, "level 1 has no PlayerSpawn marker")
	assert(player.global_position.is_equal_approx(spawn_marker.global_position),
		"player not on the spawn marker: %s vs %s" % [player.global_position, spawn_marker.global_position])

	# --- the exit flag advances to the next level ----------------------------
	var exit_node: Node = container.get_child(0).get_node_or_null("Exit")
	assert(exit_node != null, "level 1 has no Exit flag")
	assert(exit_node is Area2D, "Exit should be an Area2D")

	exit_node.call("_on_body_entered", player)
	await get_tree().create_timer(FADE_WAIT).timeout

	assert(GameManager.current_level_index == 2, "exit flag did not advance the level")
	assert(container.get_child_count() == 1, "old level was not replaced")
	assert(container.get_child(0).name == "Level2", "level 2 was not loaded")

	# --- a non-player body must not trigger the exit -------------------------
	var stranger: Node2D = Node2D.new()
	add_child(stranger)
	var exit2: Node = container.get_child(0).get_node_or_null("Exit")
	assert(exit2 != null, "level 2 has no Exit flag")
	exit2.call("_on_body_entered", stranger)
	await get_tree().create_timer(FADE_WAIT).timeout
	assert(GameManager.current_level_index == 2, "a non-player body triggered the exit")

	# --- score ---------------------------------------------------------------
	GameManager.reset_score()
	GameManager.add_score(3)
	GameManager.add_score(4)
	assert(GameManager.score == 7, "add_score does not accumulate")

	# --- finishing the last level loops back to level 1 with a fresh score ---
	await GameManager.load_level(3)
	assert(GameManager.current_level_index == 3, "should be on level 3")
	assert(GameManager.score == 7, "changing level should keep the score")
	GameManager.add_score(5)

	GameManager.next_level()
	await get_tree().create_timer(FADE_WAIT).timeout
	assert(GameManager.current_level_index == 1, "after the last level it should loop to level 1")
	assert(GameManager.score == 0, "a new run should start with score 0")
	assert(container.get_child(0).name == "Level1", "level 1 was not reloaded")

	# --- death restarts the run ---------------------------------------------
	GameManager.add_score(2)
	GameManager.reset_game()
	await get_tree().create_timer(FADE_WAIT).timeout
	assert(GameManager.score == 0, "reset_game should clear the score")
	assert(GameManager.current_level_index == 1, "reset_game should go back to level 1")

	# --- teardown: leave the tree and its groups clean for the other tests -----
	GameManager.current_level_node = null
	container.free()
	player.free()
	stranger.free()

	print("GameManager progression test finished.")


func test_moving_platform_drives_its_body() -> void:
	# The animation has to drive the AnimatableBody2D itself (not a child) and run
	# in the physics step, otherwise it will not carry the player.
	var slot: Node2D = Node2D.new()
	add_child(slot)

	var platform: MovingPlatform = load("res://scenes/moving_platform.tscn").instantiate()
	slot.add_child(platform)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var anim: AnimationPlayer = platform.get_node("AnimationPlayer")
	assert(anim.has_animation("move_x") and anim.has_animation("move_y"),
		"platform animations are missing")
	assert(anim.is_playing(), "the platform should start its animation in _ready")
	assert(anim.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,
		"the animation must run in the physics step to carry bodies")
	assert(platform.sync_to_physics, "sync_to_physics must stay enabled")

	var start: Vector2 = platform.position
	await get_tree().create_timer(1.0).timeout
	assert(not platform.position.is_equal_approx(start),
		"the animation did not move the platform body")

	# The vertical variant used by level 2's elevator.
	anim.play(&"move_y")
	var start_y: float = platform.position.y
	await get_tree().create_timer(0.6).timeout
	assert(absf(platform.position.y - start_y) > 0.5, "move_y did not move the platform")

	# Free immediately (not queue_free) so the platform's resources are released
	# before the process shuts down.
	slot.free()


func test_exit_flag_animation_uses_spritesheet() -> void:
	# The flag animation is baked into exit.tscn as AtlasTexture frames pointing
	# straight at the spritesheet png, so nothing depends on the generator's
	# metadata json (which has been deleted).
	var exit_node: LevelExit = load("res://scenes/exit.tscn").instantiate()
	add_child(exit_node)
	await get_tree().process_frame

	var sprite: AnimatedSprite2D = exit_node.get_node("AnimatedSprite2D")
	var frames: SpriteFrames = sprite.sprite_frames
	assert(frames != null, "the flag has no SpriteFrames resource")
	assert(frames.has_animation(FLAG_ANIMATION), "the flag animation is missing")
	assert(frames.get_frame_count(FLAG_ANIMATION) == 4,
		"expected 4 frames, got %d" % frames.get_frame_count(FLAG_ANIMATION))
	assert(sprite.animation == FLAG_ANIMATION, "the flag is not on the flag animation")
	assert(sprite.is_playing(), "the flag animation is not playing")

	# Every frame must come from the spritesheet png itself.
	for i: int in frames.get_frame_count(FLAG_ANIMATION):
		var frame_texture: Texture2D = frames.get_frame_texture(FLAG_ANIMATION, i)
		assert(frame_texture is AtlasTexture, "frame %d is not an atlas region" % i)
		var atlas: AtlasTexture = frame_texture as AtlasTexture
		assert(atlas.atlas != null, "frame %d has no source texture" % i)
		assert(atlas.atlas.resource_path == FLAG_SPRITESHEET,
			"frame %d comes from '%s' instead of the spritesheet" % [i, atlas.atlas.resource_path])
		assert(atlas.region.size == Vector2(32, 48),
			"frame %d has an unexpected region %s" % [i, atlas.region])

	exit_node.free()


func test_player_and_hud_survive_a_level_change() -> void:
	# Boots the real main.tscn (HUD + Player + LevelContainer) and changes level the
	# same way the exit flag does. main.tscn owns the Player and the HUD, so both
	# must survive and the score must stay wired to the label.
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node2D = main_scene.instantiate()
	add_child(main_node)
	await get_tree().create_timer(FADE_WAIT).timeout

	var container: Node = main_node.get_node("LevelContainer")
	var persistent_player: Node = main_node.get_node("Player")
	var hud: Node = main_node.get_node("HUD")
	assert(GameManager.current_level_index == 1, "should have booted on level 1")
	assert(container.get_child_count() == 1, "the container should hold exactly one level")

	# The shell owns the Player: a level must not carry its own copy.
	var players: Array = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.is_inside_tree() and main_node.is_ancestor_of(node):
			players.append(node)
	assert(players.size() == 1,
		"expected exactly 1 player under main, found %d: %s" % [players.size(), players])
	assert(players.has(persistent_player), "the persistent Player is not the one in play")

	GameManager.reset_score()
	GameManager.add_score(3)
	GameManager.next_level()
	await get_tree().create_timer(FADE_WAIT * 2.0).timeout

	assert(GameManager.current_level_index == 2, "the level did not change")
	assert(container.get_child_count() == 1, "the old level was not replaced")
	assert(container.get_child(0).name == "Level2", "the wrong level is loaded")
	assert(is_instance_valid(persistent_player) and persistent_player.is_inside_tree(),
		"the Player was destroyed by the level change")
	assert(persistent_player.get_parent() == main_node, "the Player was re-parented")
	assert(is_instance_valid(hud) and hud.is_inside_tree(), "the HUD was destroyed by the level change")

	# Level 2's PlayerSpawn is local (32, 176) and the level is scaled 3x.
	assert(persistent_player.global_position.distance_to(Vector2(96, 528)) < 40.0,
		"the Player was not moved to the new level's spawn: %s" % persistent_player.global_position)

	assert(GameManager.score == 3, "the level change reset the score")
	var score_label: Label = hud.get_node("Panel/ScoreLabel")
	assert(score_label.text == "Score: 3", "the HUD is out of sync: '%s'" % score_label.text)
	var level_label: Label = hud.get_node("LevelLabel")
	assert(level_label.text == "Level 2/3", "the level readout is out of sync: '%s'" % level_label.text)

	# If the fade is left black, the player and the HUD both look like they vanished.
	assert(GameManager.transition_rect == null or GameManager.transition_rect.color.a < 0.01,
		"the fade was left black (alpha=%s)" % GameManager.transition_rect.color.a)

	# --- guards: a level must never be the source of the character ------------
	# 1) A Player copy sitting inside the level that is currently running must not be
	#    the one the GameManager drives.
	var copy_in_level: Node2D = load("res://scenes/player.tscn").instantiate()
	copy_in_level.position = Vector2(40, 100)
	container.get_child(0).add_child(copy_in_level)
	await get_tree().process_frame
	assert(GameManager.get_player() == persistent_player,
		"get_player() picked a Player that lives inside the level")

	# 2) A level loaded while carrying its own Player must have that copy dropped.
	var poisoned: Node2D = Node2D.new()
	poisoned.name = "PoisonedLevel"

	var marker: Marker2D = Marker2D.new()
	marker.name = "PlayerSpawn"
	poisoned.add_child(marker)

	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(0, 148) # 200 tall box, top edge at y=48 (the player's feet)
	poisoned.add_child(floor_body)
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rect: RectangleShape2D = RectangleShape2D.new()
	floor_rect.size = Vector2(400, 200)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)

	var copy_in_new: Node2D = load("res://scenes/player.tscn").instantiate()
	poisoned.add_child(copy_in_new)
	for child: Node in poisoned.get_children():
		child.owner = poisoned
	for part: Node in floor_body.get_children():
		part.owner = poisoned

	var poisoned_scene: PackedScene = PackedScene.new()
	assert(poisoned_scene.pack(poisoned) == OK, "could not build the test level")

	GameManager.load_scene(poisoned_scene)
	await get_tree().create_timer(FADE_WAIT * 2.0).timeout

	assert(container.get_child_count() == 1, "the container should still hold one level")
	assert(container.get_child(0).name == "PoisonedLevel", "the test level was not loaded")

	# Exactly one Player may remain in the tree, and it has to be the shell's one.
	var survivors: Array = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.is_inside_tree() and main_node.is_ancestor_of(node):
			survivors.append(node)
	assert(survivors.size() == 1,
		"expected exactly 1 player in the tree, found %d: %s" % [survivors.size(), survivors])
	assert(survivors.has(persistent_player), "the shell's Player is not the one in play")
	assert(not is_instance_valid(copy_in_level) or not copy_in_level.is_inside_tree(),
		"the copy inside the running level was not dropped")
	assert(not is_instance_valid(copy_in_new) or not copy_in_new.is_inside_tree(),
		"the copy baked into the loaded level was not stripped")
	assert(persistent_player.global_position.distance_to(Vector2.ZERO) < 8.0,
		"the shell's Player was not moved to the new level's spawn: %s" % persistent_player.global_position)

	GameManager.current_level_node = null
	main_node.free()
