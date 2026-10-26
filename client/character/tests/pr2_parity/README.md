# PR2 physics parity check

`character/pr2_physics.gd` follows Flash PR2 (`flash/character/LocalCharacter.as`,
`flash/blocks/*`, `flash/items/*`, `flash/effects/*` and `Course.rotate` in the
`platform-racing-2-client` repo). Flash is the reference.

Flash can't be run here, so this folder compares the port with the HTML
remake's controller (`LocalPlayerController.hx`) instead: both play the same
random levels with the same key presses, frame by frame. Most frames match.
Where the remake differs from Flash, the port follows Flash, so these show up
as differences:

- Bump wobble: Flash's block wobble never stops (its stop check compares posY
  with x), display positions are stored in twips, and standing on a block
  uses its display position. A bumped block can stay a twip or so off.
- Landing: after a landing check Flash always sets grounded, even when a
  crumble block broke under the player.
- Rotate blocks: no "already rotating" check; a second rotate block mid-turn
  reverses the turn in progress.
- Vanish blocks: Flash's alpha steps (1/256), re-triggering during fade-in,
  and occupancy from the frame-start segments.
- Mines: Flash's placement (converted with the rotation when it appears),
  a mine hit can hurt during a rotation, and the blast uses the block's
  display position.
- Laser and sword: hits wobble the block; the sword damages blocks at six
  points; both start from the weapon position.
- Push blocks: Flash's chain push and frame-start occupancy.

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
