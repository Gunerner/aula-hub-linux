#!/usr/bin/env python3
"""Extract an Electron .asar archive (no Node.js needed).

Usage: asar_extract.py <app.asar> <output-dir>

Files marked "unpacked" are copied from the sibling <app.asar>.unpacked folder.
"""
import json
import os
import pathlib
import shutil
import struct
import sys


def extract(asar: pathlib.Path, out: pathlib.Path) -> int:
    unpacked_root = asar.with_name(asar.name + ".unpacked")
    with asar.open("rb") as f:
        # Chromium pickle framing: [4][header_size] then [payload_size][json_len][json]
        _, header_size = struct.unpack("<II", f.read(8))
        _, json_len = struct.unpack("<II", f.read(8))
        header = json.loads(f.read(json_len).decode("utf-8"))
        base = 8 + header_size

        count = 0
        out_resolved = out.resolve()

        def walk(node: dict, rel: pathlib.PurePosixPath) -> None:
            nonlocal count
            for name, entry in node.get("files", {}).items():
                if name in ("", ".", "..") or "/" in name or "\\" in name:
                    raise ValueError(f"unsafe entry name: {name!r}")
                child = rel / name
                dest = out / child
                if not dest.resolve().is_relative_to(out_resolved):
                    raise ValueError(f"entry escapes output dir: {child}")
                if "files" in entry:
                    dest.mkdir(parents=True, exist_ok=True)
                    walk(entry, child)
                elif "link" in entry:
                    continue  # symlinks are not needed for this app
                elif entry.get("unpacked"):
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(unpacked_root / child, dest)
                    count += 1
                else:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    f.seek(base + int(entry["offset"]))
                    remaining = int(entry["size"])
                    with dest.open("wb") as o:
                        while remaining:
                            chunk = f.read(min(remaining, 1 << 20))
                            if not chunk:
                                raise ValueError(f"truncated archive at {child}")
                            o.write(chunk)
                            remaining -= len(chunk)
                    if entry.get("executable"):
                        os.chmod(dest, 0o755)
                    count += 1

        out.mkdir(parents=True, exist_ok=True)
        walk(header, pathlib.PurePosixPath())
    return count


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    n = extract(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
    print(f"extracted {n} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
