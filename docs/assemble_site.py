#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Copy a FORD build into the Sphinx site under api/generated."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path


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
    print("copied {} -> {}".format(ford, dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
