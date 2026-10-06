#!/usr/bin/env python3
"""Fail on any broken relative Markdown link or in-page anchor (FR-J1, FR-I5)."""
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)|!\[[^\]]*\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$")


def tracked_markdown():
    out = subprocess.run(["git", "-C", str(REPO), "ls-files", "*.md"], capture_output=True, text=True, check=True)
    return [REPO / p for p in out.stdout.split()]


def slug(text):
    """GitHub heading anchor: lowercase, drop punctuation except '-' and '_', spaces -> '-'."""
    text = re.sub(r"`|\*\*|\*|_(?=\w)|(?<=\w)_", lambda m: "_" if m.group(0) == "_" else "", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text).strip().lower()
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE)
    return text.replace(" ", "-")


def anchors(path):
    seen, result, in_code = {}, set(), False
    for line in path.read_text().splitlines():
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        m = None if in_code else HEADING.match(line)
        if m:
            base = slug(m.group(1))
            n = seen.get(base, 0)
            result.add(base if n == 0 else f"{base}-{n}")
            seen[base] = n + 1
    return result


def main():
    broken = []
    for md in tracked_markdown():
        text = re.sub(r"```.*?```", "", md.read_text(), flags=re.S)
        text = re.sub(r"`[^`\n]*`", "", text)  # inline code is never a link
        for m in LINK.finditer(text):
            target = m.group(1) or m.group(2)
            if re.match(r"^[a-z][a-z0-9+.-]*:", target):
                continue
            path_part, _, frag = target.partition("#")
            dest = md if not path_part else (md.parent / path_part).resolve()
            if not dest.exists():
                broken.append(f"{md.relative_to(REPO)}: {target} (missing file)")
            elif frag and dest.suffix == ".md" and frag not in anchors(dest):
                broken.append(f"{md.relative_to(REPO)}: {target} (missing anchor)")
    for b in broken:
        print(f"[FAIL] {b}")
    print(f"check-links: {len(broken)} broken relative link(s)")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
