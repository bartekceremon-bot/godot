"""Pętla: uruchamia test kompilacji i zamienia ':=' na '=' w liniach,
gdzie Godot nie potrafi wywnioskować typu (wartość Variant)."""
import re, subprocess, sys
root = sys.argv[1]
for it in range(40):
    out = subprocess.run(["godot", "--headless", "-s", "res://tests/check_all.gd"], cwd=root,
                         capture_output=True, text=True, timeout=200)
    log = out.stdout + out.stderr
    fixes = re.findall(r'(Cannot infer the type of "\w+" variable|inferred from a Variant value)[^\n]*\n\s*at: GDScript::reload \(res://([^:]+):(\d+)\)', log)
    if not fixes:
        print("iterations:", it)
        print("\n".join(l for l in log.splitlines() if "ERROR" in l or "FAIL" in l or "CHECK_ALL" in l)[:6000])
        break
    done = set()
    for _, path, line in fixes:
        key = (path, int(line))
        if key in done: continue
        done.add(key)
        p = f"{root}/{path}"
        lines = open(p).read().split("\n")
        l = lines[int(line) - 1]
        nl = re.sub(r'(\bvar \w+) := ', r'\1 = ', l, count=1)
        if nl == l:
            nl = re.sub(r'(\bfor \w+) := ', r'\1 = ', l, count=1)
        if nl == l:
            print("cannot fix", path, line, l.strip()); continue
        lines[int(line) - 1] = nl
        open(p, "w").write("\n".join(lines))
    print("fixed", len(done))
