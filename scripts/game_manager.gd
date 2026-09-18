extends Node
## Autoload singleton registered as "GameManager" (Project Settings > Globals > Autoload).
##
## Responsibilities:
##  - the player's score, broadcast with [signal score_changed] so the HUD follows it,
##  - level progression: level1 -> level2 -> level3 -> back to level1,
##  - the black fade transition between levels (ColorRect + Tween),
##  - the shared sound effects (death / collect).
##
## Levels are swapped inside the node of the running scene that belongs to the
## "level_container" group, so the Player and the HUD survive a level change.

signal score_changed(new_score: int)
signal level_changed(level_index: int)
signal game_finished()

## Sound effect ids for [method play_sfx].
enum Sfx { DEATH, COLLECT }

const FIRST_LEVEL: int = 1
const FADE_TIME: float = 0.4
const LEVEL_CONTAINER_GROUP: String = "level_container"
const SFX_PATHS: Dictionary = {
	Sfx.DEATH: "res://assets/sounds/death.wav",
	Sfx.COLLECT: "res://assets/sounds/collect_apple.wav",
}

## Level folder structure: res://scenes/levels/
var level_paths: Array[String] = [
	"res://scenes/levels/level1.tscn",
	"res://scenes/levels/level2.tscn",
	"res://scenes/levels/level3.tscn",
]

var score: int = 0
var current_level_index: int = FIRST_LEVEL
var max_levels: int = 3
var current_level_node: Node = null
var transition_rect: ColorRect = null
var is_transitioning: bool = false

var _sfx_players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_transition_layer()
	_build_sfx_players()


# --- Setup -------------------------------------------------------------------

## Builds the CanvasLayer + ColorRect used for the fade effect (transparent at start).
func _build_transition_layer() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "TransitionLayer"
	canvas_layer.layer = 100
	add_child(canvas_layer)

	transition_rect = ColorRect.new()
	transition_rect.name = "TransitionRect"
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(transition_rect)
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_sfx_players() -> void:
	for key: int in SFX_PATHS.keys():
		var path: String = SFX_PATHS[key]
		if not ResourceLoader.exists(path):
			push_warning("GameManager: sound file not found: %s" % path)
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx%d" % key
		player.stream = load(path)
		add_child(player)
		_sfx_players[key] = player


# --- Score -------------------------------------------------------------------

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	print("Score saat ini: ", score)


func reset_score() -> void:
	score = 0
	score_changed.emit(score)


# --- Level flow --------------------------------------------------------------

## Entry point, called once by the main scene when the game boots.
func start_game() -> void:
	reset_score()
	current_level_index = FIRST_LEVEL
	if transition_rect:
		transition_rect.color.a = 1.0
	_swap_level_from_path(FIRST_LEVEL)
	_place_player_at_spawn()
	if transition_rect:
		await fade_in(FADE_TIME)
	level_changed.emit(current_level_index)


## Advances to the next level, or loops back to level 1 after the last one.
func next_level() -> void:
	if is_transitioning:
		return
	var next: int = current_level_index + 1
	if next > max_levels:
		print("Game Tamat! Mengulang dari level 1.")
		game_finished.emit()
		reset_game()
	else:
		load_level(next)


## Restarts the whole run: score back to 0, back to level 1. Used on player death.
func reset_game() -> void:
	if is_transitioning:
		return
	reset_score()
	await load_level(FIRST_LEVEL)


## Restarts the level the player is on, keeping the score.
func restart_level() -> void:
	await load_level(current_level_index)


func load_level(level_num: int) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	current_level_index = clampi(level_num, FIRST_LEVEL, max_levels)

	if transition_rect:
		await fade_out(FADE_TIME)

	_swap_level_from_path(current_level_index)
	_place_player_at_spawn()

	if transition_rect:
		await fade_in(FADE_TIME)

	is_transitioning = false
	level_changed.emit(current_level_index)


## Jumps to an explicit scene instead of the next level (used by LevelExit.next_scene).
func load_scene(scene: PackedScene) -> void:
	if is_transitioning or scene == null:
		return
	is_transitioning = true

	if transition_rect:
		await fade_out(FADE_TIME)

	_swap_level(scene)
	_place_player_at_spawn()

	if transition_rect:
		await fade_in(FADE_TIME)

	is_transitioning = false


# --- Audio -------------------------------------------------------------------

func play_sfx(sfx: Sfx) -> void:
	var player: AudioStreamPlayer = _sfx_players.get(sfx)
	if player == null:
		return
	player.play()


func _exit_tree() -> void:
	# Release the sound effects so nothing is left holding them on shutdown.
	for key: int in _sfx_players.keys():
		var player: AudioStreamPlayer = _sfx_players[key]
		player.stop()
		player.stream = null
	_sfx_players.clear()


# --- Fade --------------------------------------------------------------------

func fade_out(duration: float = FADE_TIME) -> void:
	if transition_rect == null:
		return
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = FADE_TIME) -> void:
	if transition_rect == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, duration)
	await tween.finished
	if transition_rect:
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Helpers -----------------------------------------------------------------

func get_level_container() -> Node:
	var container: Node = get_tree().get_first_node_in_group(LEVEL_CONTAINER_GROUP)
	if container:
		return container
	var scene: Node = get_tree().current_scene
	if scene:
		return scene.get_node_or_null("LevelContainer")
	return null


## Returns the persistent player (the one that lives in the shell scene, outside the
## level container). A level must never be the source of the character, otherwise it
## would be destroyed together with the level on the next swap.
func get_player() -> Node2D:
	var container: Node = get_level_container()
	var inside_level: Node2D = null
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player: Node2D = node as Node2D
		if player == null or not player.is_inside_tree():
			continue
		if container != null and container.is_ancestor_of(player):
			inside_level = player
			continue
		return player
	return inside_level


func _swap_level_from_path(level_num: int) -> void:
	var path: String = level_paths[level_num - 1]
	if not ResourceLoader.exists(path):
		push_error("GameManager: level scene not found: %s" % path)
		return
	_swap_level(load(path) as PackedScene)


func _swap_level(scene: PackedScene) -> void:
	if scene == null:
		push_error("GameManager: cannot load level scene.")
		return

	var container: Node = get_level_container()
	if container == null:
		push_error("GameManager: no node in the '%s' group to load levels into." % LEVEL_CONTAINER_GROUP)
		return

	if is_instance_valid(current_level_node):
		# Detach right away so the new level never shares the container with the old one.
		container.remove_child(current_level_node)
		current_level_node.queue_free()
		current_level_node = null

	current_level_node = scene.instantiate()
	container.add_child(current_level_node)
	_strip_level_players()


## A level must not bring its own Player node: the character belongs to the shell
## scene (main.tscn) and is reused for every level. Any copy found inside a level is
## removed, so it can neither hijack the spawn logic nor disappear on the next swap.
func _strip_level_players() -> void:
	if not is_instance_valid(current_level_node):
		return
	for node: Node in get_tree().get_nodes_in_group("player"):
		if not current_level_node.is_ancestor_of(node):
			continue
		push_warning("GameManager: '%s' contains its own Player node ('%s'). Levels must not - the Player lives in the main scene. The copy was removed." % [current_level_node.name, node.name])
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node) # out of the tree right away so it cannot be picked up
		node.queue_free()


## Puts the player on the level's PlayerSpawn marker (origin if the level has none).
func _place_player_at_spawn() -> void:
	var player: Node2D = get_player()
	if player == null or not is_instance_valid(player):
		return

	var spawn_position: Vector2 = Vector2.ZERO
	if is_instance_valid(current_level_node):
		var marker: Node = current_level_node.get_node_or_null("PlayerSpawn")
		if marker is Node2D:
			spawn_position = (marker as Node2D).global_position

	if player.has_method("reset_state"):
		player.call("reset_state")
	player.global_position = spawn_position
