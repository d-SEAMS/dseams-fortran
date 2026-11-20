#!/usr/bin/env python3
# Copyright (c) d-SEAMS developers
"""Verify that the documented one-file and separate-object build commands compile, link, and run."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def extract_readme_single_file(text: str) -> str:
    match = re.search(
        r"^## Single file\s+.*?```bash\n(.*?)^```",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        raise RuntimeError("Could not find '## Single file' bash block in README.md")
    return match.group(1)


def extract_rst_block(text: str, heading: str) -> str:
    pattern = (
        r"^"
        + re.escape(heading)
        + r"\n[-=]+\s+.*?\.\. code-block:: bash\n\n((?:   .*\n|\n)+)"
    )
    match = re.search(pattern, text, re.MULTILINE | re.DOTALL)
    if not match:
        raise RuntimeError(f"Could not find '{heading}' bash block in build.rst")
    lines = []
    for line in match.group(1).splitlines():
        if line.strip() == "":
            lines.append("")
        elif line.startswith("   "):
            lines.append(line[3:])
        else:
            break
    return "\n".join(lines).strip() + "\n"


def resolve_seams_libdir(csv_dirs: str) -> str:
    candidates = [d for d in csv_dirs.split(",") if d]
    for d in candidates:
        p = Path(d)
        if any((p / name).exists() for name in ("libseams.so", "libseams.dylib", "libseams.a")):
            return str(p)
    for d in os.environ.get("LD_LIBRARY_PATH", "").split(os.pathsep):
        if d:
            p = Path(d)
            if any((p / name).exists() for name in ("libseams.so", "libseams.dylib", "libseams.a")):
                return str(p)
    if candidates:
        return candidates[0]
    raise RuntimeError("Could not resolve SEAMS_LIB_DIR")


def stage_tree(root: Path, work: Path) -> None:
    shutil.copy2(root / "seams.f90", work / "seams.f90")
    for sub in ("src", "example", "test", "input"):
        shutil.copytree(root / sub, work / sub)


def rewrite_compilers(script: str, fc: str, cc: str) -> str:
    out = re.sub(r"(?m)^cc\b", cc, script)
    out = re.sub(r"(?m)^gfortran\b", fc, out)
    return out


def run_bash(script: str, cwd: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", "-euo", "pipefail", "-c", script],
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def check_one_file_block(
    label: str,
    block: str,
    root: Path,
    fc: str,
    cc: str,
    base_env: dict[str, str],
) -> None:
    if "dseams_once.c" not in block or "dseams_once.o" not in block:
        raise RuntimeError(f"{label} block must compile and link src/dseams_once.c / dseams_once.o")

    for prog, expected in (
        ("example/cubic.f90", "version "),
        ("test/test_feature_query.f90", "fortran feature query ok"),
    ):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            stage_tree(root, work)
            script = rewrite_compilers(block, fc, cc).replace("your_program.f90", prog)
            script += "\n./a.out\n"
            res = run_bash(script, work, base_env)
            if res.returncode != 0:
                raise RuntimeError(
                    f"{label} ({prog}) failed (rc={res.returncode}):\n"
                    f"--- script ---\n{script}\n--- stdout ---\n{res.stdout}\n--- stderr ---\n{res.stderr}"
                )
            if expected not in res.stdout:
                raise RuntimeError(
                    f"{label} ({prog}) missing {expected!r} in output:\n{res.stdout}"
                )


def check_separate_objects(
    block: str,
    root: Path,
    fc: str,
    cc: str,
    base_env: dict[str, str],
) -> None:
    if "dseams_once.c" not in block or "dseams_once.o" not in block:
        raise RuntimeError("Separate objects block must compile src/dseams_once.c")
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        stage_tree(root, work)
        script = rewrite_compilers(block, fc, cc)
        res = run_bash(script, work, base_env)
        if res.returncode != 0:
            raise RuntimeError(
                f"build.rst Separate objects failed (rc={res.returncode}):\n"
                f"--- script ---\n{script}\n--- stdout ---\n{res.stdout}\n--- stderr ---\n{res.stderr}"
            )
        if "fortran ok" not in res.stdout:
            raise RuntimeError(f"Separate objects missing 'fortran ok':\n{res.stdout}")

        extra = (
            f'{fc} -Ibuild/fmod test/test_feature_query.f90 '
            "build/fmod/seams_kinds.o build/fmod/seams_c.o "
            "build/fmod/seams_support.o build/fmod/seams.o "
            "build/fmod/seams_methods.o build/fmod/dseams_once.o "
            '-o build/test_fq -L"$SEAMS_LIB_DIR" -lseams -Wl,-rpath,"$SEAMS_LIB_DIR"\n'
            "./build/test_fq\n"
        )
        res2 = run_bash(extra, work, base_env)
        if res2.returncode != 0 or "fortran feature query ok" not in res2.stdout:
            raise RuntimeError(
                f"Separate objects full-module link failed (rc={res2.returncode}):\n"
                f"--- stdout ---\n{res2.stdout}\n--- stderr ---\n{res2.stderr}"
            )


def main() -> int:
    if len(sys.argv) != 5:
        print("usage: check_doc_build.py ROOT FC CC SEAMS_LIBDIR_CSV", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    fc = sys.argv[2]
    cc = sys.argv[3]
    seams_libdir = resolve_seams_libdir(sys.argv[4])

    env = os.environ.copy()
    env["SEAMS_LIB_DIR"] = seams_libdir
    ld_prev = env.get("LD_LIBRARY_PATH", "")
    env["LD_LIBRARY_PATH"] = f"{seams_libdir}:{ld_prev}" if ld_prev else seams_libdir
    env["OMP_NUM_THREADS"] = "1"

    readme_block = extract_readme_single_file((root / "README.md").read_text(encoding="utf-8"))
    build_rst = (root / "docs" / "user-guide" / "howto" / "build.rst").read_text(encoding="utf-8")
    rst_one_file = extract_rst_block(build_rst, "One file")
    rst_separate = extract_rst_block(build_rst, "Separate objects")

    check_one_file_block("README.md Single file", readme_block, root, fc, cc, env)
    check_one_file_block("build.rst One file", rst_one_file, root, fc, cc, env)
    check_separate_objects(rst_separate, root, fc, cc, env)

    print("doc build commands ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
