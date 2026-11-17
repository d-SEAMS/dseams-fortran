#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Copy a FORD build into the Sphinx site under api/generated.

FORD 7.0.13 writes some links as absolute paths into its output
directory (the result type of a module function in an interface). Those
are rewritten relative to each page so the site works when served.
"""

from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

from seo import enhance


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: assemble_site.py HTML_DIR FORD_DIR", file=sys.stderr)
        return 2
    html = Path(sys.argv[1])
    ford = Path(sys.argv[2])
    if not (html / "index.html").is_file():
        print("not a Sphinx build: {}".format(html), file=sys.stderr)
        return 2
    if not (ford / "index.html").is_file():
        print("not a FORD build: {}".format(ford), file=sys.stderr)
        return 2
    dest = html / "api" / "generated"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(ford, dest)
    prefix = str(ford.resolve())
    for page in dest.rglob("*.html"):
        text = page.read_text(encoding="utf-8")
        if prefix in text:
            rel = Path(os.path.relpath(dest, page.parent)).as_posix()
            page.write_text(text.replace(prefix, rel), encoding="utf-8")
            print("relative links in {}".format(page.relative_to(html)))
    enhance(html)
    print("copied {} -> {}".format(ford, dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
