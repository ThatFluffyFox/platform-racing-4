"""Checks PR4's PR2 physics against PR2's own player controller.

Builds random levels and key presses, runs them through both games, and
reports the first frame where position, velocity or state differ.

Usage: python3 compare.py [pool] [first_seed] [count]
Pools: mixed, rotate, hazard, movers, tall, items. See README.md for setup.
"""
import json, os, random, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PR2_CLIENT = os.environ.get("PR2_CLIENT", os.path.join(CLIENT, "..", "..", "platform-racing-2-client"))
HAXE_LIBS = os.environ.get("HAXE_LIBS", "")
GODOT = os.environ.get("GODOT", "godot")
HAXE = os.environ.get("HAXE", "haxe")

POOLS = {
    "mixed": [1, 1, 1, 1, 1, 5, 6, 7, 8, 9, 10, 16, 18, 19, 21, 22, 23, 24, 25],
    "rotate": [1, 1, 22, 23, 6, 7, 8, 9],
    "hazard": [1, 1, 10, 21, 25, 16],
    "movers": [1, 5, 18, 19, 24, 24],
    "tall": [1, 1, 1, 1, 5, 6, 7, 18, 19, 22, 23],
    "items": [1, 1, 1, 5, 5, 10, 18, 19, 22],
}


def make(seed, pool="mixed", frames=300):
    r = random.Random(seed)
    blocks = POOLS[pool]
    cells = {}
    for x in range(30, 70):
        cells[(x, 60)] = 1
    top = 5 if pool == "tall" else 45
    for _ in range(r.randint(20, 90) * (4 if pool == "tall" else 1)):
        cells[(r.randint(30, 69), r.randint(top, 59))] = r.choice(blocks)
    sx = r.randint(36, 60)
    sy = 8 if pool == "tall" else 60
    for yy in (sy - 2, sy - 1):
        cells.pop((sx, yy), None)
    inputs = []
    while len(inputs) < frames:
        letters = "LRJDI" if pool == "items" else "LRJD"
        keys = "".join(k for k in letters if r.random() < (0.45 if k in "LR" else 0.3))
        inputs += [keys] * r.randint(1, 25)
    item = r.choice([4, 5, 5, 8, 8, 11, 12, 13, 14]) if pool == "items" else None
    return {"item": item, "gravity": r.choice([1, 1, 0.5, 1.7]), "speed": r.randint(0, 100),
            "accel": r.randint(0, 100), "jump": r.randint(0, 100),
            "x": sx * 30 + 15, "y": sy * 30,
            "blocks": [[x, y, b] for (x, y), b in cells.items()],
            "inputs": inputs[:frames]}


def haxe_command(paths):
    libs = []
    for lib in ("openfl/src", "lime/src", "svg"):
        libs += ["-cp", os.path.join(HAXE_LIBS, lib)]
    return [HAXE, *libs, "-D", "openfl", "-D", "lime", "-D", "pr2_test",
            "-cp", os.path.join(PR2_CLIENT, "haxe", "src"), "-cp", HERE,
            "--run", "Pr2Reference", *paths]


def godot_command(paths):
    return [GODOT, "--headless", "--path", CLIENT,
            "res://character/tests/pr2_physics_runner.tscn", "--", *paths]


def run(command, cwd):
    out = subprocess.run(command, cwd=cwd, capture_output=True, text=True).stdout
    results, cur = {}, None
    for line in out.splitlines():
        if line.startswith("# "):
            cur = line[2:].strip()
            results[cur] = []
        elif line[:1].isdigit() and cur:
            results[cur].append(line.split())
    return results


def same(a, b):
    if len(a) != len(b):
        return False
    if any(abs(float(p) - float(q)) > 1e-6 for p, q in zip(a[1:5], b[1:5])):
        return False
    return a[5:8] == b[5:8] and int(a[8]) == int(b[8])


def main(pool, start, count):
    folder = tempfile.mkdtemp(prefix="pr2_parity_")
    paths = []
    for seed in range(start, start + count):
        path = os.path.join(folder, f"{pool}_{seed}.json")
        with open(path, "w") as f:
            json.dump(make(seed, pool), f)
        paths.append(path)
    pr2 = run(haxe_command(paths), PR2_CLIENT)
    pr4 = run(godot_command(paths), CLIENT)
    bad = 0
    known = 0
    for path in paths:
        a_rows, b_rows = pr2.get(path, []), pr4.get(path, [])
        if not a_rows or len(a_rows) != len(b_rows):
            print(f"{path}: frame counts {len(a_rows)} (PR2) vs {len(b_rows)} (PR4)")
            bad += 1
            continue
        for i, (a, b) in enumerate(zip(a_rows, b_rows)):
            if not same(a, b):
                if is_rotated_mine_blast(a_rows, i):
                    known += 1
                    break
                print(f"{path}: frame {a[0]}\n  PR2 {' '.join(a)}\n  PR4 {' '.join(b)}")
                bad += 1
                break
    print(f"{pool}: {count - bad - known}/{count} scenarios match, {known} differ only by "
          f"a known change, {bad} differ")
    return bad


def is_rotated_mine_blast(rows, i):
    """Known change: PR4 aims a mine blast on a rotated course away from the
    mine. PR2's direction there depends on where the level sits."""
    previous_mode = rows[i - 1][7] if i else rows[i][7]
    return rows[i][7] == "hurt" and previous_mode != "hurt" and rows[i][8] != "0"


if __name__ == "__main__":
    args = sys.argv[1:]
    failures = main(args[0] if args else "mixed",
                    int(args[1]) if len(args) > 1 else 1,
                    int(args[2]) if len(args) > 2 else 50)
    sys.exit(1 if failures else 0)
