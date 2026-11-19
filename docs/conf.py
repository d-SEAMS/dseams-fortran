# Copyright (c) d-SEAMS developers
"""Sphinx configuration for the dseams manual."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from seo import sphinx_build_finished

project = "dseams"
author = "Rohit Goswami, Ruhila Goswami"
copyright = "2018, d-SEAMS developers"
# [[[cog import dseams_version as v; cog.outl(f'version = "{v.VERSION}"'); cog.outl(f'release = "{v.VERSION}"')]]]
version = "2.14.1"
release = "2.14.1"
# [[[end]]]

extensions = ["myst_parser"]
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
exclude_patterns = ["_build", "_includes", "_ford", "build"]
root_doc = "index"
myst_heading_anchors = 3

html_theme = "shibuya"
html_title = "dseams Fortran API and tutorials"
html_baseurl = "https://fortran.dseams.info/"
html_static_path = ["_static"]
html_favicon = "_static/dseams/favicon.ico"
html_css_files = [
    "dseams/dseams-tokens.css",
    "dseams/dseams-family.css",
    "dseams/dseams-shibuya.css",
]
html_theme_options = {
    "github_url": "https://github.com/d-SEAMS/dseams-fortran",
    "accent_color": "blue",
    "dark_code": True,
    "show_ai_links": False,
    "globaltoc_expand_depth": 1,
    "toctree_collapse": True,
    "toctree_maxdepth": 3,
    "toctree_titles_only": True,
    "nav_links": [
        {"title": "Getting started", "url": "getting-started/index"},
        {"title": "User guide", "url": "user-guide/index"},
        {"title": "API reference", "url": "api/index"},
        {"title": "Development", "url": "development/index"},
    ],
}
html_sidebars = {
    "**": [
        "sidebars/localtoc.html",
    ],
}
templates_path = ["_templates"]
html_show_sourcelink = False


def setup(app):
    app.connect("build-finished", sphinx_build_finished)
