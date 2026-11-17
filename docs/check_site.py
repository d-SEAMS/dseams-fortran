#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Check the assembled HTML: videos, local links, and the FORD copy."""

from __future__ import annotations

import re
import sys
from pathlib import Path

IFRAME_RE = re.compile(
    r'<iframe\b[^>]*\bsrc="([^"]+)"',
    re.IGNORECASE,
)
HREF_RE = re.compile(r'\b(?:href|src)="([^"]+)"', re.IGNORECASE)

# Page relative to the Sphinx html root, and the player that belongs on it.
VIDEOS = {
    "tutorials/fortran.html": (
        "https://odysee.com/$/embed/dseams-fortran:"
        "e15a82c2f40ff1fdf10c89ff6c9f78b6b3fd583b"
    ),
    "user-guide/tutorials/cages.html": (
        "https://odysee.com/$/embed/dseams-cages:"
        "1c258cea9384acd2e21eeec509c5eedc050d08db"
    ),
    "user-guide/tutorials/rings.html": (
        "https://odysee.com/$/embed/dseams-rings:"
        "cfb3b6687dd81847ecb005782df8cf5143617be5"
    ),
    "user-guide/tutorials/interface.html": (
        "https://odysee.com/$/embed/dseams-interface:"
        "74af20635ceeef7945f8e22cb5b02522a865baa6"
    ),
    "user-guide/tutorials/brine.html": (
        "https://odysee.com/$/embed/dseams-brine:"
        "124a3a7fa52cdf7aff34ac00cfba6068e240a947"
    ),
    "user-guide/tutorials/nucleation.html": (
        "https://odysee.com/$/embed/dseams-nucleation:"
        "965e5772f700e5b1d91f1b069557eb9e87f1c60b"
    ),
}

REQUIRED = (
    "index.html",
    "getting-started/index.html",
    "getting-started/install.html",
    "getting-started/quickstart.html",
    "user-guide/index.html",
    "user-guide/tutorials/bulk-ice.html",
    "api/index.html",
    "api/fortran.html",
    "api/generated/index.html",
    "api/generated/module/seams.html",
    "api/generated/module/seams_c.html",
    "api/generated/module/seams_kinds.html",
    "api/generated/lists/procedures.html",
    "api/generated/lists/types.html",
    "development/index.html",
    "lang/task-fortran.html",
)


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def local_target(page: Path, root: Path, url: str) -> Path | None:
    if url.startswith(("#", "mailto:", "javascript:")):
        return None
    if "://" in url:
        return None
    path = url.split("#", 1)[0].split("?", 1)[0]
    if not path or "{{" in path or path.startswith("data:"):
        return None
    return (page.parent / path).resolve()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_site.py HTML_DIR", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    if not (root / "index.html").is_file():
        fail("not a site: {}".format(root))
    for rel in REQUIRED:
        if not (root / rel).is_file():
            fail("missing {}".format(rel))
    for rel, src in VIDEOS.items():
        text = (root / rel).read_text(encoding="utf-8", errors="replace")
        found = IFRAME_RE.findall(text)
        if src not in found:
            fail("{} is missing {}".format(rel, src))
        if "embed.txt" in text:
            fail("{} mentions embed.txt".format(rel))
    players = 0
    for page in root.rglob("*.html"):
        if "_static" in page.relative_to(root).parts:
            continue
        text = page.read_text(encoding="utf-8", errors="replace")
        for src in IFRAME_RE.findall(text):
            players += 1
            if not src.startswith("https://odysee.com/$/embed/"):
                fail("{} iframe is not an embed player: {}".format(page, src))
        for url in HREF_RE.findall(text):
            target = local_target(page, root, url)
            if target is None:
                continue
            if not target.exists():
                fail("{} -> missing {}".format(page.relative_to(root), url))
    if players < len(VIDEOS):
        fail("expected at least {} players, found {}".format(len(VIDEOS), players))
    print("pages {} players {}".format(len(list(root.rglob('*.html'))), players))
    return 0


if __name__ == "__main__":
    sys.exit(main())
