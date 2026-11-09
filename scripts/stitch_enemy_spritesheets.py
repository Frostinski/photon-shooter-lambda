"""
Stitches the Blender-rendered 3D Scout and Interceptor (Raider) frames into
master spritesheets and applies crisp dark outer-silhouette arcade ink outlines
to the 2D fallback sprites in PhotonShooter_Godot/assets/images/.
"""
import os
import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")
TMP_DIR = os.path.join(MODELS_DIR, "enemy_frames_tmp")
GODOT_IMAGES_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "images")


def apply_arcade_ink_outline(im: Image.Image, radius_px: int = 1, ink_rgb=(5, 5, 18)) -> Image.Image:
    """Applies Option C's crisp dark arcade ink outline around the outer alpha silhouette of a 2D RGBA sprite."""
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    a = arr[:, :, 3] / 255.0
    max_a = a.copy()
    for dy in range(-radius_px, radius_px + 1):
        for dx in range(-radius_px, radius_px + 1):
            if dx == 0 and dy == 0:
                continue
            if dx * dx + dy * dy <= radius_px * radius_px + 1:
                shifted = np.pad(a, ((max(0, dy), max(0, -dy)), (max(0, dx), max(0, -dx))), mode="constant")
                sy = max(0, -dy)
                sx = max(0, -dx)
                shifted = shifted[sy : sy + a.shape[0], sx : sx + a.shape[1]]
                max_a = np.maximum(max_a, shifted)

    ring = np.clip(max_a - a, 0.0, 1.0)
    ink = np.array(ink_rgb, dtype=np.float32)[None, None, :]
    out_rgb = arr[:, :, :3] * a[:, :, None] + ink * (1.0 - a[:, :, None])
    out_a = np.clip(a + ring, 0.0, 1.0)
    out = np.dstack([np.clip(out_rgb, 0.0, 255.0).astype(np.uint8), (out_a * 255.0).astype(np.uint8)])
    return Image.fromarray(out, mode="RGBA")


def stitch_sheet(prefix: str, fw: int, fh: int, out_filename: str):
    sheet = Image.new("RGBA", (fw * 4, fh * 3), (0, 0, 0, 0))
    for r in range(3):
        for c in range(4):
            fpath = os.path.join(TMP_DIR, f"{prefix}_r{r}_c{c}.png")
            frame = Image.open(fpath).convert("RGBA")
            if frame.size != (fw, fh):
                frame = frame.resize((fw, fh), Image.Resampling.LANCZOS)
            frame = apply_arcade_ink_outline(frame, radius_px=1)
            sheet.paste(frame, (c * fw, r * fh))
    out_godot = os.path.join(GODOT_IMAGES_DIR, out_filename)
    sheet.save(out_godot)
    print(f"Saved stitched 3D spritesheet to {out_godot} ({sheet.size})")


def main():
    stitch_sheet("scout", 96, 56, "enemy_scout_spritesheet.png")
    stitch_sheet("raider", 128, 68, "enemy_raider_spritesheet.png")

    for fname, rad in [("enemy_scout.png", 1), ("enemy_raider.png", 1), ("boss_dreadnought.png", 2), ("boss_titan.png", 2)]:
        src = os.path.join(GODOT_IMAGES_DIR, fname)
        if os.path.exists(src):
            inked = apply_arcade_ink_outline(Image.open(src), radius_px=rad)
            inked.save(src)

    for prev in ["enemy_scout_3d_preview.png", "enemy_raider_3d_preview.png", "boss_dreadnought_3d_preview.png", "boss_titan_3d_preview.png"]:
        src = os.path.join(MODELS_DIR, prev)
        if os.path.exists(src):
            inked_prev = apply_arcade_ink_outline(Image.open(src), radius_px=2)
            inked_prev.save(src)
    print("Updated all Godot 3D enemy fallback sprites and previews.")


if __name__ == "__main__":
    main()
