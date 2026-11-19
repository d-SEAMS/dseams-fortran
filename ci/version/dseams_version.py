"""Release version for cog snippets, read from fpm.toml.

``version`` in the root fpm.toml is the only place a person writes the
version. ``sync`` copies it into ``ford.md``. Every copy listed in
ci/version/files.txt is regenerated from it by cogapp:

    python3 ci/version/dseams_version.py sync X.Y.Z
    python3 -m cogapp -I ci/version -r @ci/version/files.txt

Call cogapp through ``python3 -m cogapp``. The ``cog`` executable is
cocogitto, which creates the version commit and the ``v`` tag.
"""

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

with (ROOT / "fpm.toml").open("rb") as fh:
    VERSION = tomllib.load(fh)["version"]

_IDENT = r"(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)"
_SEMVER = re.compile(
    r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    rf"(?:-{_IDENT}(?:\.{_IDENT})*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


def numeric_core(version):
    """MAJOR, MINOR and PATCH of a semver string, as integers."""
    match = _SEMVER.fullmatch(version)
    if match is None:
        raise ValueError(f"release version is not semver: {version!r}")
    return tuple(int(part) for part in match.groups())


def _rewrite(path, pattern, replacement, label):
    text = path.read_text(encoding="utf-8")
    new, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"{label}: pattern not found")
    if new != text:
        path.write_text(new, encoding="utf-8")


def sync(version):
    """Write ``version`` into fpm.toml and into ford.md.

    ford.md is a FORD project file. A cog comment in its front matter
    ends that front matter early, so this script writes the line and
    cogapp does not.
    """
    numeric_core(version)
    _rewrite(
        ROOT / "fpm.toml",
        r'(?m)^version = "[^"]*"',
        f'version = "{version}"',
        "fpm.toml",
    )
    _rewrite(
        ROOT / "ford.md",
        r"(?m)^version: .*$",
        f"version: {version}",
        "ford.md",
    )


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "sync":
        sync(sys.argv[2])
    else:
        sys.exit(f"usage: {sys.argv[0]} sync VERSION")
