"""
Prepares crisp, unoccluded 1024x1024 transparent RGBA reference images for Meshy.ai Image-to-3D
from the 4 studio-clean white-background concept renders:
  1. scout_clean_concept.png     -> enemy_scout_menu_ref.png
  2. raider_clean_concept.png    -> enemy_raider_menu_ref.png
  3. destroyer_clean_concept.png -> boss_dreadnought_menu_ref.png
  4. titan_clean_concept.png     -> boss_titan_menu_ref.png

Uses exterior border BFS flood-fill + soft outer-glow halo stripping + white-halo de-fringing so:
  - 100% of exterior white background AND faint airbrushed outer nozzle/orb glow halos become alpha = 0
  - Bright specular highlights & glowing cores inside the ship's silhouette remain 100% solid (alpha = 255)
  - Zero white edge fringe is left on dark gunmetal / purple armor silhouettes
"""
import os
from collections import deque
import numpy as np
from PIL import Image

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")


def isolate_from_white_bg(
    src_path: str,
    out_path: str,
    canvas_size: int = 1024,
    fill_ratio: float = 0.88,
    strip_outer_glow: bool = False,
):
    im = Image.open(src_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32)
    h, w, _ = arr.shape

    border_samples = np.vstack([
        arr[0, :, :3],
        arr[-1, :, :3],
        arr[:, 0, :3],
        arr[:, -1, :3],
    ])
    bg_rgb = np.median(border_samples, axis=0)

    diff = arr[:, :, :3] - bg_rgb
    dist = np.sqrt(np.sum(diff * diff, axis=2))
    lum = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    min_c = np.minimum(arr[:, :, 0], np.minimum(arr[:, :, 1], arr[:, :, 2]))

    if strip_outer_glow:
        # Strips white background plus soft pastel airbrushed glow outside the crisp dark hull outline
        bg_candidate = (dist < 62.0) | ((lum > 178.0) & (min_c > 110.0)) | (arr[:, :, 3] < 20.0)
    else:
        bg_candidate = (dist < 38.0) | (arr[:, :, 3] < 20.0)

    exterior_bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        if bg_candidate[0, x]:
            exterior_bg[0, x] = True
            q.append((0, x))
        if bg_candidate[h - 1, x]:
            exterior_bg[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if bg_candidate[y, 0] and not exterior_bg[y, 0]:
            exterior_bg[y, 0] = True
            q.append((y, 0))
        if bg_candidate[y, w - 1] and not exterior_bg[y, w - 1]:
            exterior_bg[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
            if 0 <= ny < h and 0 <= nx < w and not exterior_bg[ny, nx] and bg_candidate[ny, nx]:
                exterior_bg[ny, nx] = True
                q.append((ny, nx))

    boundary = np.zeros((h, w), dtype=bool)
    boundary[1:, :] |= exterior_bg[:-1, :]
    boundary[:-1, :] |= exterior_bg[1:, :]
    boundary[:, 1:] |= exterior_bg[:, :-1]
    boundary[:, :-1] |= exterior_bg[:, 1:]

    boundary2 = np.zeros((h, w), dtype=bool)
    boundary2[1:, :] |= boundary[:-1, :]
    boundary2[:-1, :] |= boundary[1:, :]
    boundary2[:, 1:] |= boundary[:, :-1]
    boundary2[:, :-1] |= boundary[:, 1:]
    edge_ring2 = boundary2 & (~exterior_bg)

    alpha = np.where(exterior_bg, 0.0, 255.0)

    ring_mask = edge_ring2 & (dist < 115.0)
    ring_alpha = np.clip((dist - 24.0) / (98.0 - 24.0), 0.0, 1.0)
    alpha = np.where(ring_mask, ring_alpha * 255.0, alpha)

    rgb_clean = arr[:, :, :3].copy()
    decontam = ring_mask & (alpha > 8.0) & (alpha < 250.0)
    a_norm = np.clip(alpha / 255.0, 0.05, 1.0)[:, :, None]
    unmixed = (rgb_clean - (1.0 - a_norm) * bg_rgb[None, None, :]) / a_norm
    rgb_clean = np.where(decontam[:, :, None], np.clip(unmixed, 0.0, 255.0), rgb_clean)

    out_rgba = np.dstack([rgb_clean.astype(np.uint8), alpha.astype(np.uint8)])
    isolated = Image.fromarray(out_rgba, mode="RGBA")

    bbox = isolated.getbbox()
    if bbox is None:
        raise RuntimeError(f"Empty foreground bounding box for {src_path}")
    cropped = isolated.crop(bbox)

    max_dim = int(canvas_size * fill_ratio)
    cw, ch = cropped.size
    scale = min(max_dim / float(cw), max_dim / float(ch))
    nw, nh = max(1, int(round(cw * scale))), max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ox = (canvas_size - nw) // 2
    oy = (canvas_size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    canvas.save(out_path)
    print(f"Prepared Meshy RGBA input: {out_path} (cropped={cw}x{ch} -> {nw}x{nh} on {canvas_size}x{canvas_size})")


def main():
    pairs = [
        ("scout_clean_concept.png", "enemy_scout_menu_ref.png", False),
        ("raider_clean_concept.png", "enemy_raider_menu_ref.png", True),
        ("destroyer_clean_concept.png", "boss_dreadnought_menu_ref.png", True),
        ("titan_clean_concept.png", "boss_titan_menu_ref.png", True),
    ]
    for src_name, dst_name, strip_glow in pairs:
        src_p = os.path.join(MODELS_DIR, src_name)
        dst_p = os.path.join(MODELS_DIR, dst_name)
        if not os.path.exists(src_p):
            raise FileNotFoundError(f"Missing concept image: {src_p}")
        isolate_from_white_bg(src_p, dst_p, strip_outer_glow=strip_glow)


if __name__ == "__main__":
    main()
