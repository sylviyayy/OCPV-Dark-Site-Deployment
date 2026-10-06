#!/usr/bin/env python3
"""The field register exists once (scripts/lib/render.py REGISTER) and is mirrored in three
places that must not drift (PRD §1 placement requirement):

  .env.example                  every key, same order, ENV_SCHEMA_VERSION first
  docs/labs/03-checklist.md     full table, rows A1..F4 in order
  README.md                     short form, rows A1..C6 in order
"""
import importlib.util
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("render", REPO / "scripts/lib/render.py")
render = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render)

errors = []

# .env.example key order
keys = [m.group(1) for m in re.finditer(r"^([A-Z][A-Z0-9_]*)=", (REPO / ".env.example").read_text(), re.M)]
expected = ["ENV_SCHEMA_VERSION"] + [k for _, k in render.REGISTER] + list(render.DERIVED)
if keys != expected:
    errors.append(".env.example keys differ from the register order:\n  got      "
                  + " ".join(keys) + "\n  expected " + " ".join(expected))
if "MIRROR_REGISTRY_PASSWORD" in keys:
    errors.append(".env.example must not hold MIRROR_REGISTRY_PASSWORD (FR-K2)")

ids_in_order = []
for fid, _ in render.REGISTER:
    if fid not in ids_in_order:
        ids_in_order.append(fid)
keys_by_id = {}
for fid, key in render.REGISTER:
    keys_by_id.setdefault(fid, []).append(key)


def table_rows(path):
    """(ID, [backticked UPPER_CASE keys]) for table rows whose first cell is a register ID."""
    rows = []
    for line in path.read_text().splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) >= 2 and re.fullmatch(r"[A-F][1-6]", cells[0]):
            rows.append((cells[0], re.findall(r"`([A-Z][A-Z0-9_]*)`", cells[1])))
    return rows


def check_table(path, wanted_ids):
    rows = table_rows(path)
    got_ids = [r[0] for r in rows]
    if got_ids != wanted_ids:
        errors.append(f"{path.relative_to(REPO)}: row IDs {got_ids} != {wanted_ids}")
        return
    for fid, row_keys in rows:
        allowed = keys_by_id[fid]
        if not row_keys or row_keys[0] != allowed[0] or any(k not in allowed for k in row_keys):
            errors.append(f"{path.relative_to(REPO)}: row {fid} names {row_keys}, register has {allowed}")


check_table(REPO / "docs/labs/03-checklist.md", ids_in_order)
check_table(REPO / "README.md", [i for i in ids_in_order if i[0] in "ABC"])

for e in errors:
    print(f"[FAIL] {e}")
print(f"check-register: {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
