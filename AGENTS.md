# Project conventions

## Asset paths

- **Never use `res://assets/generated/`** — do not save, read or reference anything at that path.
- Flag / exit assets live in `res://assets/images/flag/`.
- Every other asset keeps its own category folder under `res://assets/images/`:
  `player/`, `background/`, `Collectibles/`, `Snail/`, `Tilemap/`. Do not move or
  re-point those paths.
- Audio lives in `res://assets/sounds/`.
- The image generators always write to `res://assets/generated/`. If a new image is
  ever needed, generate it, then `mv` it straight into the matching category folder
  above and point the reference at the new path — nothing may stay in
  `res://assets/generated/`.

## Scene structure

- `scenes/main.tscn` is the shell and holds the permanent `Player`, `HUD` and
  `LevelContainer`.
- Level scenes are `res://scenes/levels/level*.tscn`; they hold only their own content
  (background, tilemap, `PlayerSpawn`, enemies, collectibles, `Exit`) and must **not**
  contain a `Player`.
- Score, level progression and the fade live in the `GameManager` autoload; levels are
  swapped inside `LevelContainer`, never with `change_scene_to_file()`.
- Tests live in `tests/` and run with `run_tests`.
