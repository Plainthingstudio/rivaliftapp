"""Transparent exercise photos: Vision foreground mask + brightness key, padded to 3:2, 600x400 HEIC.

Usage (from the repo root, macOS 14+):
    swiftc -O scripts/exercise_photos/maskonly.swift -o /tmp/maskonly
    swiftc -O scripts/exercise_photos/toheic.swift -o /tmp/toheic
    python3 scripts/exercise_photos/cutout.py <source.png|jpg> <exercise_key> [<source> <key> ...]

Sources are the full-size generated images (black background), e.g. downloaded from the Figma
frame "All Exercises" (node 164:105933). The result replaces
Rivalift/Resources/Assets.xcassets/Exercises/Exercise_<key>.imageset/photo.heic.
"""
import json
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ASSETS = "Rivalift/Resources/Assets.xcassets/Exercises"


def cut(src: str, key: str, tmp: str) -> None:
    mask_path = os.path.join(tmp, f"{key}_mask.png")
    subprocess.run(["/tmp/maskonly", src, mask_path], check=True)
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    lum = 0.299 * im[..., 0] + 0.587 * im[..., 1] + 0.114 * im[..., 2]
    # Keep visible equipment (cable towers, machine frames) that Vision treats as background.
    alpha = np.clip((lum - 14) / (40 - 14), 0, 1)
    if os.path.exists(mask_path):
        v = np.asarray(Image.open(mask_path).convert("L").resize((im.shape[1], im.shape[0]), Image.BILINEAR)).astype(np.float32) / 255
        # Floor reflections sit below the lowest foot/equipment point: keep only Vision's mask there.
        rows = np.where((v > 0.5).any(axis=1))[0]
        if len(rows):
            alpha[min(im.shape[0], rows.max() + int(im.shape[0] * 0.01)):] = 0
        alpha = np.maximum(alpha, v)
    rgba = Image.fromarray(np.dstack([im, alpha * 255]).astype(np.uint8), "RGBA")
    w, h = rgba.size
    W, H = max(w, round(h * 1.5)), max(h, round(w / 1.5))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(rgba, ((W - w) // 2, (H - h) // 2))
    png = os.path.join(tmp, f"{key}.png")
    canvas.resize((600, 400), Image.LANCZOS).save(png)
    folder = f"{ASSETS}/Exercise_{key}.imageset"
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.startswith("photo."):
            os.remove(os.path.join(folder, name))
    subprocess.run(["/tmp/toheic", png, f"{folder}/photo.heic", "0.7"], check=True, capture_output=True)
    json.dump({"images": [{"filename": "photo.heic", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
              open(f"{folder}/Contents.json", "w"), indent=2)
    print("updated", key)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or len(args) % 2:
        sys.exit(__doc__)
    with tempfile.TemporaryDirectory() as tmp:
        for src, key in zip(args[::2], args[1::2]):
            cut(src, key, tmp)
