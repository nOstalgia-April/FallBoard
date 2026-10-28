#!/usr/bin/env python3
"""Package exported builds without editor sidecar files or absolute paths."""
import hashlib
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)

for name, folder in [("Windows", "windows"), ("Web", "web")]:
    source = ROOT / "builds" / folder
    target = DIST / f"FallBoard-{name}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file in sorted(source.iterdir()):
            if file.is_file() and not file.name.endswith(".import") and not file.name.startswith("."):
                archive.write(file, f"FallBoard-{name}/{file.name}")
        for name_in_repo in ["README.md", "THIRD_PARTY_NOTICES.md"]:
            archive.write(ROOT / name_in_repo, f"FallBoard-{name}/{name_in_repo}")
        archive.write(ROOT / "assets/fonts/OFL.txt", f"FallBoard-{name}/FONT_LICENSE.txt")
    print(target.name, target.stat().st_size)

(DIST / "SHA256SUMS.txt").write_text("".join(
    f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
    for path in sorted(DIST.glob("FallBoard-*.zip"))
))
