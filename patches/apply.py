#!/usr/bin/env python3
"""Apply aula-hub-linux patches to an extracted AULA Hub 1.1.22 app directory.

Every rule must match exactly once; otherwise nothing is written and the script
fails. Each patched file keeps its original as <file>.orig.
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent

# Firmware variant fix: these keyboards mark the lighting mode table with
# 80 f0 at profile offset 56 instead of ff ff. Only that exact layout is
# accepted; every other profile behaves as before.
MARKER_FALLBACK = "if(t.length>=128&&t[56]===128&&t[57]===240)return 58;"

RULES = [
    (
        "dist/assets/index-BPTK-vUa.js",
        "[S(409)](t){const e=S;let a=0;for(let r=0;r<t[e(509)]-1;r++)if(t[r]===255&&t[r+1]===255){a=r+2;break}return a>0?a:-1}",
        "[S(409)](t){const e=S;let a=0;for(let r=0;r<t[e(509)]-1;r++)if(t[r]===255&&t[r+1]===255){a=r+2;break}if(a>0)return a;"
        + MARKER_FALLBACK + "return -1}",
    ),
    (
        "dist/assets/index-BPTK-vUa.js",
        "findSecond255Index(t){let e=0;for(let a=0;a<t.length-1;a++)if(t[a]===255&&t[a+1]===255){e=a+2;break}return e>0?e:-1}",
        "findSecond255Index(t){let e=0;for(let a=0;a<t.length-1;a++)if(t[a]===255&&t[a+1]===255){e=a+2;break}if(e>0)return e;"
        + MARKER_FALLBACK + "return -1}",
    ),
    # Slider ranges: the keyboard stores brightness 0-9 and speed 0-4
    # (measured with its own Fn keys); the app's sliders go to 20.
    (
        "dist/assets/light-dx3WWey8.js",
        "maxLightly:21,maxSpeed:21",
        "maxLightly:10,maxSpeed:5",
    ),
    (
        "dist/index.html",
        "<head>",
        "<head>\n<script>\n" + (HERE / "hid-name-fix.js").read_text(encoding="utf-8") + "</script>",
    ),
]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: apply.py <extracted-app-dir>", file=sys.stderr)
        return 2
    root = pathlib.Path(sys.argv[1])

    contents = {}
    for rel, old, new in RULES:
        path = root / rel
        text = contents.get(rel)
        if text is None:
            text = path.read_text(encoding="utf-8")
        count = text.count(old)
        if count != 1:
            print(f"error: expected 1 match in {rel}, found {count}; is this AULA Hub 1.1.22?", file=sys.stderr)
            return 1
        contents[rel] = text.replace(old, new)

    for rel, text in contents.items():
        path = root / rel
        path.with_name(path.name + ".orig").write_bytes(path.read_bytes())
        path.write_text(text, encoding="utf-8")
        print(f"patched {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
