# Copyright (c) d-SEAMS developers
"""Sphinx configuration for the dseams manual."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from seo import sphinx_build_finished

project = "dseams"
author = "d-SEAMS developers"
copyright = "2018, d-SEAMS developers"
version = "2.14.0"
release = "2.14.0"

extensions = ["myst_parser"]
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}
exclude_patterns = ["_build", "_includes", "build"]
root_doc = "index"
myst_heading_anchors = 3

html_theme = "pydata_sphinx_theme"
html_title = "dseams Fortran API and tutorials"
html_baseurl = "https://fortran.dseams.info/"
html_static_path = ["_static"]
html_css_files = ["dseams.css"]
html_theme_options = {
    "navigation_depth": 3,
    "show_nav_level": 2,
    "collapse_navigation": False,
    "external_links": [
        {"name": "d-SEAMS", "url": "https://docs.dseams.info/"},
    ],
    "icon_links": [
        {
            "name": "GitHub",
            "url": "https://github.com/d-SEAMS/dseams-fortran",
            "icon": "fa-brands fa-github",
        },
    ],
    "footer_start": ["copyright"],
    "footer_end": [],
    "secondary_sidebar_items": ["page-toc"],
}
templates_path = []
html_show_sourcelink = False


def setup(app):
    app.connect("build-finished", sphinx_build_finished)
