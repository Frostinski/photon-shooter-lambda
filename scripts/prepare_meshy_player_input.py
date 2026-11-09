"""
Extracts a clean, isolated reference image of the main player starfighter
from the main menu artwork (excluding background enemies and extended laser beams)
for Meshy.ai Image-to-3D generation.
"""
import os
import numpy as np
from PIL import Image, ImageDraw

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME0_PATH = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "images", "menu_anim", "frame_0.png")
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")


def prepare_reference_image():
    os.makedirs(MODELS_DIR, exist_ok=True)
    img = Image.open(FRAME0_PATH).convert("RGBA")
    w, h = img.size

    poly_mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(poly_mask)
    draw.polygon([
        (695, 720),   # Left orange wingtip top
        (695, 855),   # Left orange wingtip bottom
        (815, 865),   # Left wing trailing edge
        (1110, 735),  # Left wing root
        (1155, 805),  # Left gun barrel tip
        (1205, 780),  # Left gun barrel inner
        (1185, 740),  # Under left intake
        (1345, 750),  # Lower fuselage
        (1585, 885),  # Nose cone bottom
        (1690, 885),  # Nose cone tip
        (1685, 710),  # Nose cone top
        (1570, 565),  # Right intake front
        (1705, 505),  # Right gun barrel tip
        (1715, 470),  # Right gun barrel outer
        (1640, 445),  # Right wing leading edge near gun
        (1835, 285),  # Right orange winglet bottom
        (1845, 165),  # Right orange winglet top
        (1788, 168),  # Right orange winglet inner top (excludes red beam)
        (1760, 240),  # Right orange winglet inner base
        (1425, 392),  # Right wing root
        (1320, 325),  # Right tail fin
        (1250, 268),  # Right tail fin tip
        (1255, 360),  # Between tail fins
        (1165, 405),  # Rear engine deck
        (1040, 360),  # Left tail fin tip
        (1095, 535),  # Left tail fin base
        (1055, 575),  # Left wing root leading edge
    ], fill=255)

    arr = np.array(img)
    p_mask = np.array(poly_mask) > 128
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]

    # Exclude any red/magenta pixels (R > 160 and G < 60) from background beams
    not_red_beam = ~((r > 150) & (g < 65) & (b > 60))
    keep = p_mask & (a > 20) & not_red_beam

    out_arr = np.zeros_like(arr)
    out_arr[keep] = arr[keep]

    hero_only = Image.fromarray(out_arr, mode="RGBA")
    bbox = hero_only.getbbox()
    cropped = hero_only.crop(bbox)

    canvas_size = 1024
    max_dim = int(canvas_size * 0.84)
    cw, ch = cropped.size
    scale = min(max_dim / float(cw), max_dim / float(ch))
    new_w, new_h = int(cw * scale), int(ch * scale)
    resized = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ox = (canvas_size - new_w) // 2
    oy = (canvas_size - new_h) // 2
    canvas.paste(resized, (ox, oy), resized)

    ref_path = os.path.join(MODELS_DIR, "player_ship_menu_ref.png")
    canvas.save(ref_path)
    print(f"Saved clean player ship reference image to {ref_path} ({canvas.size})")


if __name__ == "__main__":
    prepare_reference_image()
