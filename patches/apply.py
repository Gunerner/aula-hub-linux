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
    # Firmware block: every known firmware entry point calls
    # window.__aulaHubLinuxBlockFirmware (patches/firmware-block.js) instead.
    # Supported keyboard's version page: the update button would download
    # AULA's Windows firmware updater, and the page asks AULA's server for the
    # latest firmware. Both are disabled.
    (
        "dist/assets/version-BBHkWJxs.js",
        "async goUpdate(){m(this.activeData.downloadUrl)}",
        "async goUpdate(){window.__aulaHubLinuxBlockFirmware()}",
    ),
    (
        "dist/assets/version-BBHkWJxs.js",
        "getDownloadUrl(){var e;const t=(e=this.store.deviceInfo)==null?void 0:e.deviceId;"
        "g(t).then(s=>{this.activeData.latestVersion=s.version,this.activeData.downloadUrl=n+s.fileName}).catch(s=>{})}",
        "getDownloadUrl(){}",
    ),
    # In-app firmware writes used by other AULA devices. These are all the pages
    # that set store.isBinUpdating (the app's "firmware update running" flag).
    # The blocker runs *before* that flag and the progress step are set, so the
    # app never gets stuck in an "updating" state; the firmware call itself is
    # replaced too, as a second layer.
    (
        "dist/assets/version-BFz3ZYcs.js",
        "this.store.isBinUpdating=!0,this.activeData.binStep=2,this.activeData.binProgress=0,await((s=this.ServiceDevice)",
        "window.__aulaHubLinuxBlockFirmware(),"
        "this.store.isBinUpdating=!0,this.activeData.binStep=2,this.activeData.binProgress=0,await((s=this.ServiceDevice)",
    ),
    (
        "dist/assets/version-BFz3ZYcs.js",
        "s.upgradeFirmware(v[0],t,r,",
        "window.__aulaHubLinuxBlockFirmware(v[0],t,r,",
    ),
    (
        "dist/assets/version-Biz-fiVp.js",
        "this.store.isBinUpdating=!0,this.activeData.binStep=2",
        "window.__aulaHubLinuxBlockFirmware(),this.store.isBinUpdating=!0,this.activeData.binStep=2",
    ),
    (
        "dist/assets/version-Biz-fiVp.js",
        "await this.ServiceDevice.deviceFwUpgrade(p)",
        "await window.__aulaHubLinuxBlockFirmware(p)",
    ),
    # WIN 60 / AG60 page: puts the device into bootloader mode (appToBoot, in a
    # retry loop) and then writes. Block before the loop is ever reached.
    (
        "dist/assets/version-BaxvFQW7.js",
        "this.activeData.step=2;let e;const t=this.activeData.activeBinBlob[0].blobFile",
        "window.__aulaHubLinuxBlockFirmware();"
        "this.activeData.step=2;let e;const t=this.activeData.activeBinBlob[0].blobFile",
    ),
    (
        "dist/assets/version-BaxvFQW7.js",
        "o.upgrade(s,",
        "window.__aulaHubLinuxBlockFirmware(s,",
    ),
    (
        "dist/assets/version-CZpI-VxG.js",
        "i.updateBin(a,",
        "window.__aulaHubLinuxBlockFirmware(a,",
    ),
    (
        "dist/assets/version-CZpI-VxG.js",
        "this.store.isBinUpdating=!0,await((i=this.ServiceDevice)==null?void 0:",
        "window.__aulaHubLinuxBlockFirmware(),this.store.isBinUpdating=!0,await((i=this.ServiceDevice)==null?void 0:",
    ),
    # V1 mouse page: downloads AULA's external updater zip, like this keyboard's page.
    (
        "dist/assets/version-CrZzUj4k.js",
        "async openBin(){",
        "async openBin(){window.__aulaHubLinuxBlockFirmware();",
    ),
    (
        "dist/index.html",
        "<head>",
        "<head>\n"
        + "".join(
            "<script>\n" + (HERE / name).read_text(encoding="utf-8") + "</script>\n"
            for name in ("firmware-block.js", "hid-name-fix.js")
        ),
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
            if not path.is_file():
                print(f"error: {rel} not found; is this AULA Hub 1.1.22?", file=sys.stderr)
                return 1
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
