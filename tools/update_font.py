#!/usr/bin/env python3
"""Regenerate the bundled Chinese font subset after changing UI/level text.

Requires: python -m pip install fonttools
Upstream font: Noto Sans SC, SIL Open Font License (assets/fonts/OFL.txt).
"""
from pathlib import Path
import tempfile
import urllib.request
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"


def main():
    path = Path(tempfile.gettempdir()) / "fallboard-NotoSansSC.ttf"
    if not path.exists():
        with urllib.request.urlopen(URL, timeout=180) as response:
            path.write_bytes(response.read())
    text = "".join(p.read_text(encoding="utf-8") for pattern in ["scripts/*.gd", "data/*.json"] for p in ROOT.glob(pattern))
    text += "".join(chr(i) for i in range(32, 127)) + "●○→↑↓←✓≤—"
    font = TTFont(path)
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    sub = subset.Subsetter(options=options)
    sub.populate(text=text)
    sub.subset(font)
    instantiateVariableFont(font, {"wght": 500}, inplace=True)
    out = ROOT / "assets/fonts/FallBoardSans.ttf"
    font.save(out)
    print(f"Saved {out.name}: {out.stat().st_size} bytes")


if __name__ == "__main__":
    main()
