#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Copy a FORD build into the Sphinx site under api/generated.

FORD 7.0.13 writes some links as absolute paths into its output
directory (the result type of a module function in an interface). Those
are rewritten relative to each page so the site works when served.

The same FORD version links the Module Procedures sidebar of an
interface page at #moduleprocedure-<name> while the page anchors the
sections with proc-<name> (seen on assignment(=), whose module
procedures have no pages of their own). Those fragment links are
rewritten to the anchors FORD emits.
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

from seo import enhance

VENDOR = Path(__file__).resolve().parent / "_ford"

CDN_CSS = re.compile(r'[ \t]*<link href="https://cdn\.jsdelivr\.net/npm/bootstrap@[^"]*"[^>]*>\n?', re.S)
CDN_JS = re.compile(r'[ \t]*<script src="https://cdn\.jsdelivr\.net/npm/bootstrap@[^"]*"[^>]*></script>\n?', re.S)
MATHJAX_CONFIG = re.compile(r'[ \t]*<script type="text/x-mathjax-config">.*?</script>\n?', re.S)
MATHJAX_LOAD = re.compile(r'[ \t]*<script src="https://cdn\.jsdelivr\.net/npm/mathjax@[^"]*"[^>]*></script>\n?', re.S)
LUNR = re.compile(r'<script src="https://unpkg\.com/lunr/lunr\.js"></script>')
DEAD_FRAGMENT = re.compile(r'#moduleprocedure-')
SCHEME = (
    "<script>document.documentElement.setAttribute('data-bs-theme',"
    "matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light')</script>"
)


def theme_page(text: str, rel: str) -> str:
    """Point a FORD page at the vendored Bootstrap and the d-SEAMS theme."""
    vendor = "{}/vendor".format(rel)
    text = CDN_CSS.sub("", text)
    text = CDN_JS.sub("", text)
    text = MATHJAX_CONFIG.sub("", text)
    text = MATHJAX_LOAD.sub("", text)
    text = LUNR.sub('<script src="{}/lunr.min.js"></script>'.format(vendor), text)
    boot = (
        SCHEME
        + '<link href="{v}/bootstrap.min.css" rel="stylesheet">'
        '<script src="{v}/bootstrap.bundle.min.js"></script>'
    ).format(v=vendor)
    theme = (
        '<link href="{v}/dseams-tokens.css" rel="stylesheet">'
        '<link href="{v}/dseams-family.css" rel="stylesheet">'
        '<link href="{v}/dseams-ford.css" rel="stylesheet">'
    ).format(v=vendor)
    text = text.replace("<!-- Bootstrap -->", "<!-- Bootstrap -->" + boot, 1)
    text = text.replace("</head>", theme + "</head>", 1)
    text = re.sub(r'[ \t]*<link rel="icon"[^>]*>\n?', "", text, count=1)
    text = re.sub(r"(<head>)", r'\1<link rel="icon" type="image/png" href="{}/favicon-32.png">'.format(vendor), text, count=1)
    family = (VENDOR / "family.html").read_text(encoding="utf-8")
    text = re.sub(r"(<body[^>]*>)", lambda m: m.group(1) + "\n" + family, text, count=1)
    return text


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
    vendor = dest / "vendor"
    shutil.copytree(VENDOR, vendor, ignore=shutil.ignore_patterns("family.html"))
    prefix = str(ford.resolve())
    for page in dest.rglob("*.html"):
        if vendor in page.parents:
            continue
        text = page.read_text(encoding="utf-8")
        rel = Path(os.path.relpath(dest, page.parent)).as_posix()
        if prefix in text:
            text = text.replace(prefix, rel)
            print("relative links in {}".format(page.relative_to(html)))
        if DEAD_FRAGMENT.search(text):
            text = DEAD_FRAGMENT.sub("#proc-", text)
            print("procedure anchors in {}".format(page.relative_to(html)))
        page.write_text(theme_page(text, rel), encoding="utf-8")
    enhance(html)
    print("copied {} -> {}".format(ford, dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
