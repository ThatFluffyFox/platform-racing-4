# PR2 physics parity check

`character/pr2_physics.gd` is a port of Platform Racing 2's player physics.
This folder checks it against PR2's own controller (`LocalPlayerController.hx`
in the `platform-racing-2-client` repo): both games play the same random
levels with the same key presses, and every frame's position, velocity,
ground/crouch state, mode and course rotation must match.

## Setup

- A clone of `platform-racing-2-client`, next to this repo or set `PR2_CLIENT`.
- Haxe 4.3 (`HAXE`, default `haxe`).
- OpenFL, Lime and SVG sources in one folder (`HAXE_LIBS`), laid out as
  `openfl/`, `lime/` and `svg/` (git clones of the openfl GitHub repos work).
- Godot 4.5 (`GODOT`, default `godot`).

## Run

```
python3 compare.py mixed 1 200
```

Pools: `mixed`, `rotate`, `hazard`, `movers`, `tall`. Each run prints the first
differing frame for any scenario that doesn't match.

To step a single scenario in PR4 only:

```
godot --headless res://character/tests/pr2_physics_runner.tscn -- scenario.json
```
