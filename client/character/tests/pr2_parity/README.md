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

Pools: `mixed`, `rotate`, `hazard`, `movers`, `tall`, `items` (laser gun,
sword, super jump, jet pack, speed burst and teleport; `I` in the inputs
holds the item key). Each run prints the first
differing frame for any scenario that doesn't match.

Known, deliberate difference (counted separately): mines follow Flash PR2
rather than the HTML remake. Flash converts a pending mine's spot with the
course rotation at the moment it appears, so a rotation in between sends the
mine elsewhere (the "mine disappears" rotate glitch). The remake doesn't do
this yet (its TODO lists it as an open bug).

PR4 levels sit around (0, 0) while PR2 levels sit at large positive
coordinates, so the port rounds tile lookups down (PR2 truncates toward zero,
which is the same for positive numbers). Everything else, including PR2's
"block next to this one" checks on rotated courses (which make the mine
rotate glitch's walk-through work), is exactly PR2's math. Build levels with
"New PR2 level" in the editor to get PR2's coordinates.

To step a single scenario in PR4 only:

```
godot --headless res://character/tests/pr2_physics_runner.tscn -- scenario.json
```
