#!/usr/bin/env python3
"""Remove macOS AppleDouble sidecar files such as `._foo.jpg`.

Usage:
  python3 scripts/remove_appledouble.py /Volumes/MySSD --dry-run
  python3 scripts/remove_appledouble.py /Volumes/MySSD
"""

from __future__ import annotations

import argparse
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class RemovalResult:
    matched: int = 0
    removed: int = 0
    failed: int = 0
    bytes_freed: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Recursively remove macOS AppleDouble sidecar files "
            "(files whose names start with '._')."
        ),
    )
    parser.add_argument(
        "target",
        nargs="?",
        default=".",
        help="Folder to scan. Defaults to the current directory.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be removed without deleting anything.",
    )
    parser.add_argument(
        "--include-git",
        action="store_true",
        help="Also scan inside .git folders. By default they are skipped.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print the final summary.",
    )
    return parser.parse_args()


def should_skip_dir(dirname: str, include_git: bool) -> bool:
    return not include_git and dirname == ".git"


def iter_appledouble_files(root: Path, include_git: bool) -> list[Path]:
    matches: list[Path] = []
    for current_root, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            dirname
            for dirname in dirnames
            if not should_skip_dir(dirname, include_git)
        ]
        for filename in filenames:
            if filename.startswith("._"):
                matches.append(Path(current_root) / filename)
    return matches


def remove_files(
    files: list[Path],
    *,
    dry_run: bool,
    quiet: bool,
) -> RemovalResult:
    result = RemovalResult(matched=len(files))

    for file_path in files:
        try:
            file_size = file_path.stat().st_size
        except OSError:
            file_size = 0

        if not quiet:
            action = "Would remove" if dry_run else "Removing"
            print(f"{action}: {file_path}")

        if dry_run:
            result.bytes_freed += file_size
            continue

        try:
            file_path.unlink()
            result.removed += 1
            result.bytes_freed += file_size
        except OSError as error:
            result.failed += 1
            print(f"Failed: {file_path} ({error})")

    return result


def format_bytes(total_bytes: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    size = float(total_bytes)
    unit = units[0]
    for unit in units:
        if size < 1024 or unit == units[-1]:
            break
        size /= 1024
    return f"{size:.2f} {unit}"


def main() -> int:
    args = parse_args()
    target = Path(args.target).expanduser().resolve()

    if not target.exists():
        print(f"Target does not exist: {target}")
        return 1

    if not target.is_dir():
        print(f"Target is not a directory: {target}")
        return 1

    files = iter_appledouble_files(target, args.include_git)
    result = remove_files(files, dry_run=args.dry_run, quiet=args.quiet)

    if args.dry_run:
        print(
            f"Dry run complete. Matched {result.matched} file(s). "
            f"Potential cleanup: {format_bytes(result.bytes_freed)}"
        )
        return 0

    print(
        f"Done. Matched {result.matched} file(s), removed {result.removed}, "
        f"failed {result.failed}, freed {format_bytes(result.bytes_freed)}."
    )
    return 0 if result.failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
