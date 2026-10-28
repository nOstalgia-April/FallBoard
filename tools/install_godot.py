#!/usr/bin/env python3
"""Install the pinned official Godot editor and only the required export templates.

Uses Python's standard library. Downloads are checked against the official SHA512
manifest before extraction. Intended for Linux x86_64 CI runners.
"""
import hashlib
import os
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.5.1"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"
CACHE = Path(os.environ.get("RUNNER_TEMP", "/tmp")) / "fallboard-godot"


def download(name):
    path = CACHE / name
    if not path.exists():
        print(f"Downloading {name}", flush=True)
        with urllib.request.urlopen(BASE + name, timeout=180) as response, path.open("wb") as output:
            while chunk := response.read(4 * 1024 * 1024):
                output.write(chunk)
    return path


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = download("SHA512-SUMS.txt").read_text()
    names = [f"Godot_v{VERSION}-stable_linux.x86_64.zip", f"Godot_v{VERSION}-stable_export_templates.tpz"]
    for name in names:
        path = download(name)
        expected = next(line.split()[0] for line in manifest.splitlines() if line.split()[-1].lstrip("*") == name)
        digest = hashlib.sha512()
        with path.open("rb") as source:
            while chunk := source.read(4 * 1024 * 1024):
                digest.update(chunk)
        if digest.hexdigest() != expected:
            path.unlink()
            raise RuntimeError(f"Checksum mismatch: {name}")
    with zipfile.ZipFile(CACHE / names[0]) as archive:
        editor = f"Godot_v{VERSION}-stable_linux.x86_64"
        (CACHE / "godot").write_bytes(archive.read(editor))
    (CACHE / "godot").chmod(0o755)
    target = Path.home() / f".local/share/godot/export_templates/{VERSION}.stable"
    target.mkdir(parents=True, exist_ok=True)
    wanted = {"version.txt", "windows_release_x86_64.exe", "web_nothreads_release.zip"}
    with zipfile.ZipFile(CACHE / names[1]) as archive:
        for name in archive.namelist():
            if Path(name).name in wanted:
                (target / Path(name).name).write_bytes(archive.read(name))
    if "GITHUB_PATH" in os.environ:
        with open(os.environ["GITHUB_PATH"], "a") as output:
            output.write(str(CACHE) + "\n")
    print(f"Ready: {CACHE / 'godot'}", flush=True)


if __name__ == "__main__":
    main()
