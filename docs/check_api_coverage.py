#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Fail when a public Fortran symbol has no FORD page.

FORD writes one HTML anchor, or one list entry, per entity it
documented. This script reads the public surface of src/seams.f90,
src/seams_c.f90 and src/seams_kinds.f90 and checks that surface
against a FORD build directory. seams_support is not part of the
public API and is not scanned. Names that the kinds module only
re-exports from iso_c_binding are not entities this package defines.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    ROOT / "src" / "seams.f90",
    ROOT / "src" / "seams_c.f90",
    ROOT / "src" / "seams_kinds.f90",
)
# Re-exported from iso_c_binding. FORD does not give them pages.
INTRINSIC = {
    "c_associated",
    "c_char",
    "c_double",
    "c_f_pointer",
    "c_int",
    "c_loc",
    "c_null_char",
    "c_null_ptr",
    "c_ptr",
    "c_size_t",
}
MODULE_RE = re.compile(
    r"^\s*module\s+(?!procedure\b|function\b|subroutine\b)([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
PUBLIC_RE = re.compile(r"^\s*public\s*::\s*(.+)$", re.IGNORECASE)
BOUND_RE = re.compile(
    r"procedure\s*,\s*public\s*::\s*([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
PARAM_RE = re.compile(
    r"parameter\s*::\s*([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
TYPE_RE = re.compile(
    r"^\s*type\s*,\s*([^:]*)::\s*([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
PROC_RE = re.compile(
    r"^\s*(?:module\s+)?(?:pure\s+|elemental\s+|recursive\s+)*"
    r"(?:function|subroutine)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)
ANCHOR_RE = re.compile(
    r'id="(?:variable|interface|boundprocedure|proc|type|module)-([^"]+)"',
    re.IGNORECASE,
)
LINK_RE = re.compile(r"<a\b[^>]*>(.*?)</a>", re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r"<[^>]+>")
SUFFIX_RE = re.compile(r"~\d+$")


def strip_comment(line: str) -> str:
    out = []
    quote = False
    for ch in line:
        if ch == '"':
            quote = not quote
        if ch == "!" and not quote:
            break
        out.append(ch)
    return "".join(out)


def public_names() -> dict[str, str]:
    """Map a public name to the module that declares it."""
    found: dict[str, str] = {}

    def add(module: str, name: str) -> None:
        name = name.strip()
        if not name or name.lower() in INTRINSIC:
            return
        found.setdefault(name, module)

    for path in SOURCES:
        module = ""
        private = False
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = strip_comment(raw).strip()
            if not line:
                continue
            opened = MODULE_RE.match(line)
            if opened and not line.lower().startswith("end "):
                module = opened.group(1)
                private = False
                add(module, module)
                continue
            if line.lower() == "private":
                private = True
                continue
            published = PUBLIC_RE.match(line)
            if published:
                for part in published.group(1).split(","):
                    add(module, part)
                continue
            for name in BOUND_RE.findall(line):
                add(module, name)
            if re.search(r"\bpublic\b", line, re.IGNORECASE) or not private:
                typed = TYPE_RE.match(line)
                if typed and "private" not in typed.group(1).lower():
                    add(module, typed.group(2))
                param = PARAM_RE.search(line)
                if param and "private" not in line.lower():
                    add(module, param.group(1))
                proc = PROC_RE.match(line)
                if proc and not private:
                    add(module, proc.group(1))
    return found


def documented(ford: Path) -> set[str]:
    names: set[str] = set()
    for page in ford.rglob("*.html"):
        text = page.read_text(encoding="utf-8", errors="replace")
        for match in ANCHOR_RE.finditer(text):
            names.add(SUFFIX_RE.sub("", match.group(1)).lower())
        for match in LINK_RE.finditer(text):
            label = TAG_RE.sub("", match.group(1))
            label = " ".join(label.split())
            if label:
                names.add(label.lower())
    return names


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_api_coverage.py BUILD_DIR", file=sys.stderr)
        return 2
    ford = Path(sys.argv[1])
    if not (ford / "lists" / "modules.html").is_file():
        print("not a FORD build: {}".format(ford), file=sys.stderr)
        return 2
    symbols = public_names()
    have = documented(ford)
    missing = sorted(name for name in symbols if name.lower() not in have)
    modules = sorted({module for module in symbols.values()})
    print("modules {}".format(len(modules)))
    print("public_symbols {}".format(len(symbols)))
    print("documented {}".format(len(symbols) - len(missing)))
    print("missing {}".format(len(missing)))
    for name in missing:
        print("missing {} ({})".format(name, symbols[name]))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
