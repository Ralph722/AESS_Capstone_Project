#!/usr/bin/env python3
"""Cache-bust Flutter web MaterialIcons so live clients cannot keep a
tree-shaken font under the stable MaterialIcons-Regular.otf URL.

Flutter always emits the same filename. Browsers and the service worker
often keep an older subset (blank icons for glyphs added later). Renaming
the font to include its content hash forces a fresh download.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


def _md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def bust(web_root: Path) -> int:
    fonts_dir = web_root / "assets" / "fonts"
    src = fonts_dir / "MaterialIcons-Regular.otf"
    if not src.is_file():
        print(f"ERROR: missing {src}", file=sys.stderr)
        return 1

    digest = _md5(src)
    if src.stat().st_size < 500_000:
        print(
            f"ERROR: {src.name} is only {src.stat().st_size} bytes "
            "(tree-shaken). Build with --no-tree-shake-icons first.",
            file=sys.stderr,
        )
        return 1

    short = digest[:12]
    dest_name = f"MaterialIcons-Regular.{short}.otf"
    dest = fonts_dir / dest_name
    if dest.exists():
        dest.unlink()
    src.replace(dest)

    font_manifest = web_root / "assets" / "FontManifest.json"
    fonts = json.loads(font_manifest.read_text(encoding="utf-8"))
    replaced = False
    for entry in fonts:
        if entry.get("family") != "MaterialIcons":
            continue
        for face in entry.get("fonts", []):
            asset = face.get("asset", "")
            if asset.endswith("MaterialIcons-Regular.otf") or "MaterialIcons-Regular." in asset:
                face["asset"] = f"fonts/{dest_name}"
                replaced = True
    if not replaced:
        print("ERROR: MaterialIcons entry not found in FontManifest.json", file=sys.stderr)
        return 1
    font_manifest.write_text(json.dumps(fonts, separators=(",", ":")), encoding="utf-8")

    sw = web_root / "flutter_service_worker.js"
    sw_text = sw.read_text(encoding="utf-8")
    old_key = re.compile(
        r'"assets/fonts/MaterialIcons-Regular(?:\.[0-9a-f]+)?\.otf"\s*:\s*"[0-9a-f]+"'
    )
    new_entry = f'"assets/fonts/{dest_name}": "{digest}"'
    sw_text2, n = old_key.subn(new_entry, sw_text, count=1)
    if n != 1:
        print("ERROR: could not patch MaterialIcons key in service worker", file=sys.stderr)
        return 1

    # Force clients on older builds to drop polluted caches once.
    sw_text2, n_cache = re.subn(
        r"const CACHE_NAME = 'flutter-app-cache[^']*';",
        "const CACHE_NAME = 'flutter-app-cache-icons-v2';",
        sw_text2,
        count=1,
    )
    if n_cache != 1:
        print("WARN: CACHE_NAME not patched; continuing with font rename only")

    sw.write_text(sw_text2, encoding="utf-8")

    # Drop any leftover unversioned copy if replace() left nothing (Windows).
    leftover = fonts_dir / "MaterialIcons-Regular.otf"
    if leftover.exists():
        leftover.unlink()

    print(f"Icon font cache-bust OK: fonts/{dest_name} ({dest.stat().st_size} bytes)")
    return 0


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    web_root = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build" / "web"
    return bust(web_root)


if __name__ == "__main__":
    raise SystemExit(main())
