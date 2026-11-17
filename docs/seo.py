#!/usr/bin/env python3
"""Add and validate SEO metadata for every generated HTML page."""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path
from urllib.parse import urljoin
from xml.etree import ElementTree as ET

NAME = "dseams Fortran"
DESCRIPTION = (
    "Fortran bindings, tutorials, and generated API reference for the d-SEAMS "
    "molecular simulation analysis engine"
)
URL = "https://fortran.dseams.info/"
REPOSITORY = "https://github.com/d-SEAMS/dseams-fortran"
IMAGE = "https://dseams.info/images/og-card.png"
DOI = "https://doi.org/10.1021/acs.jcim.0c00031"
TITLE = re.compile(r"<title\b[^>]*>(.*?)</title>", re.I | re.S)
HEAD = re.compile(r"</head\s*>", re.I)
REMOVE = (
    re.compile(r'<meta\b[^>]*(?:name|property)=["\'](?:description|og:[^"\']+|twitter:[^"\']+)["\'][^>]*>\s*', re.I),
    re.compile(r'<link\b[^>]*rel=["\']canonical["\'][^>]*>\s*', re.I),
    re.compile(r'<script\b[^>]*id=["\']seo-json-ld["\'][^>]*>.*?</script>\s*', re.I | re.S),
)


def all_pages(root: Path) -> list[Path]:
    # Sphinx themes also ship Jinja macro fragments with an .html suffix.
    # Select complete HTML documents by structure, never by a path allowlist.
    return [
        page
        for page in sorted(root.rglob("*.html"))
        if HEAD.search(page.read_text(encoding="utf-8", errors="replace"))
    ]


def canonical(root: Path, page: Path) -> str:
    rel = page.relative_to(root)
    path = (
        ("" if rel.parent == Path(".") else rel.parent.as_posix() + "/")
        if rel.name == "index.html"
        else rel.as_posix()
    )
    return urljoin(URL, path)


def current_title(text: str, root: Path, page: Path) -> str:
    match = TITLE.search(text)
    value = re.sub(r"<[^>]+>", "", match.group(1)) if match else ""
    value = " ".join(html.unescape(value).split())
    return value or page.relative_to(root).with_suffix("").as_posix().replace("/", " - ")


def tags(title: str, description: str, page_url: str) -> str:
    esc = lambda value: html.escape(value, quote=True)
    data = {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "SoftwareApplication",
                "name": NAME,
                "description": DESCRIPTION,
                "url": URL,
                "applicationCategory": "DeveloperApplication",
                "citation": DOI,
            },
            {
                "@type": "SoftwareSourceCode",
                "name": NAME,
                "description": DESCRIPTION,
                "url": URL,
                "codeRepository": REPOSITORY,
                "programmingLanguage": "Fortran",
                "license": "https://opensource.org/license/mit",
                "citation": DOI,
            },
        ],
    }
    values = [
        f'<meta name="description" content="{esc(description)}">',
        f'<link rel="canonical" href="{esc(page_url)}">',
        '<meta property="og:type" content="website">',
        f'<meta property="og:site_name" content="{esc(NAME)}">',
        f'<meta property="og:title" content="{esc(title)}">',
        f'<meta property="og:description" content="{esc(description)}">',
        f'<meta property="og:url" content="{esc(page_url)}">',
        f'<meta property="og:image" content="{esc(IMAGE)}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{esc(title)}">',
        f'<meta name="twitter:description" content="{esc(description)}">',
        f'<meta name="twitter:image" content="{esc(IMAGE)}">',
        '<script id="seo-json-ld" type="application/ld+json">'
        + json.dumps(data, separators=(",", ":"))
        + "</script>",
    ]
    return "\n".join(values)


def enhance(root: Path) -> None:
    root = root.resolve()
    pages = all_pages(root)
    if not pages:
        raise RuntimeError(f"no HTML pages found in {root}")
    used: set[str] = set()
    for page in pages:
        text = page.read_text(encoding="utf-8")
        title = current_title(text, root, page)
        if title in used:
            label = page.relative_to(root).with_suffix("").as_posix().replace("/", " - ")
            title = f"{title} ({label})"
        used.add(title)
        description = f"{title}. {DESCRIPTION}."
        text = TITLE.sub(f"<title>{html.escape(title)}</title>", text, count=1)
        for pattern in REMOVE:
            text = pattern.sub("", text)
        if not HEAD.search(text):
            raise RuntimeError(f"{page}: missing closing head element")
        text = HEAD.sub(tags(title, description, canonical(root, page)) + "\n</head>", text, count=1)
        page.write_text(text, encoding="utf-8")
    sitemap = ET.Element("urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9")
    for page in pages:
        ET.SubElement(ET.SubElement(sitemap, "url"), "loc").text = canonical(root, page)
    ET.ElementTree(sitemap).write(root / "sitemap.xml", encoding="utf-8", xml_declaration=True)
    (root / "robots.txt").write_text(
        f"User-agent: *\nAllow: /\nSitemap: {urljoin(URL, 'sitemap.xml')}\n",
        encoding="utf-8",
    )


def validate(root: Path) -> None:
    root = root.resolve()
    pages = all_pages(root)
    if not pages:
        raise RuntimeError(f"no HTML pages found in {root}")
    titles: set[str] = set()
    descriptions: set[str] = set()
    canonicals: set[str] = set()
    required = {
        ("name", "description"), ("property", "og:type"),
        ("property", "og:site_name"), ("property", "og:title"),
        ("property", "og:description"), ("property", "og:url"),
        ("property", "og:image"), ("name", "twitter:card"),
        ("name", "twitter:title"), ("name", "twitter:description"),
        ("name", "twitter:image"),
    }
    for page in pages:
        text = page.read_text(encoding="utf-8")
        found_titles = TITLE.findall(text)
        if len(found_titles) != 1:
            raise RuntimeError(f"{page}: expected exactly one title")
        title = " ".join(html.unescape(found_titles[0]).split())
        meta = {
            (kind.lower(), name.lower()): html.unescape(value)
            for kind, name, value in re.findall(
                r'<meta\b[^>]*(name|property)=["\']([^"\']+)["\'][^>]*content=["\']([^"\']*)["\'][^>]*>',
                text, re.I
            )
        }
        missing = required - meta.keys()
        if missing:
            raise RuntimeError(f"{page}: missing metadata {sorted(missing)}")
        og_images = re.findall(
            r'<meta\b[^>]*property=["\']og:image["\'][^>]*content=["\']([^"\']*)["\'][^>]*>',
            text,
            re.I,
        )
        if og_images != [IMAGE]:
            raise RuntimeError(f"{page}: expected exactly one non-empty og:image")
        if meta[("name", "twitter:image")] != IMAGE:
            raise RuntimeError(f"{page}: twitter:image must be {IMAGE}")
        page_url = canonical(root, page)
        links = re.findall(
            r'<link\b[^>]*rel=["\']canonical["\'][^>]*href=["\']([^"\']+)["\'][^>]*>',
            text, re.I
        )
        if links != [page_url] or meta[("property", "og:url")] != page_url:
            raise RuntimeError(f"{page}: canonical and og:url must be {page_url}")
        description = meta[("name", "description")]
        if title in titles or description in descriptions or page_url in canonicals:
            raise RuntimeError(f"{page}: title, description, and canonical must be unique")
        titles.add(title)
        descriptions.add(description)
        canonicals.add(page_url)
        scripts = re.findall(
            r'<script\b[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
            text, re.I | re.S
        )
        if not any(
            {item.get("@type") for item in json.loads(script).get("@graph", [])}
            >= {"SoftwareApplication", "SoftwareSourceCode"} and DOI in script
            for script in scripts
        ):
            raise RuntimeError(f"{page}: missing required software JSON-LD")
    locations = {node.text for node in ET.parse(root / "sitemap.xml").findall(".//{*}loc")}
    if locations != canonicals:
        raise RuntimeError("sitemap URLs do not match generated HTML canonicals")
    robots = (root / "robots.txt").read_text(encoding="utf-8").splitlines()
    if robots != ["User-agent: *", "Allow: /", f"Sitemap: {urljoin(URL, 'sitemap.xml')}"]:
        raise RuntimeError("robots.txt must allow crawling and name the custom-domain sitemap")
    print(f"SEO validated for {len(pages)} HTML pages")


def sphinx_build_finished(app, exception) -> None:
    if exception is None and app.builder.format == "html":
        enhance(Path(app.outdir))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("site", type=Path)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    (validate if arguments.check else enhance)(arguments.site)
