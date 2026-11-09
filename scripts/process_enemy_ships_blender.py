"""
Blender 5.2 headless script to process, orient, simplify/calibrate Option C two-tone PBR materials,
measure rear thruster nozzle coordinates, and export all 4 Meshy-generated 3D enemy craft:
  1. Scout (compact silver-titanium & gunmetal drone with crimson visor) -> enemy_scout.glb
  2. Interceptor / Raider (streamlined crimson-orchid gull-wing fighter) -> enemy_raider.glb
  3. Destroyer / Dreadnought (streamlined royal-violet shark-prow warship) -> boss_dreadnought.glb
  4. Final Ship / Boss Titan (streamlined royal-violet multi-turret flagship) -> boss_titan.glb

Canonical orientation for all exported enemy .glb models:
  - Nose / Prow / Forward Weapons: -X (Left on screen)
  - Rear Exhaust Nozzles:          +X (Right on screen)
  - Dorsal Top / Turrets / Fins:   +Z in Blender (+Y Up in glTF / Godot 4)
  - Wingspan / Sponsons:           -Y..+Y in Blender (+Z..-Z in glTF / Godot 4)
"""
import os
import math
import bpy
import bmesh
import mathutils
import numpy as np

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")


def srgb_to_linear(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.04045, x / 12.92, np.power((x + 0.055) / 1.055, 2.4))


def linear_to_srgb(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1.0 / 2.4) - 0.055)


def gaussian_blur_2d(arr: np.ndarray, sigma: float) -> np.ndarray:
    if sigma <= 0.2:
        return arr
    radius = max(1, int(round(sigma * 2.5)))
    x = np.arange(-radius, radius + 1, dtype=np.float32)
    kernel = np.exp(-0.5 * (x / sigma) ** 2)
    kernel /= kernel.sum()

    pad_w = [(0, 0)] * arr.ndim
    pad_w[1] = (radius, radius)
    padded = np.pad(arr, pad_w, mode="edge")
    out_w = np.zeros_like(arr, dtype=np.float32)
    for i, k in enumerate(kernel):
        out_w += k * padded[:, i : i + arr.shape[1]]

    pad_h = [(0, 0)] * arr.ndim
    pad_h[0] = (radius, radius)
    padded_h = np.pad(out_w, pad_h, mode="edge")
    out = np.zeros_like(arr, dtype=np.float32)
    for i, k in enumerate(kernel):
        out += k * padded_h[i : i + arr.shape[0], :]
    return out


def masked_blur_rgb(rgb: np.ndarray, valid_mask: np.ndarray, sigma: float) -> np.ndarray:
    """Normalized convolution within valid UV islands so empty (0,0,0) UV gutters never bleed inward."""
    num = gaussian_blur_2d(rgb * valid_mask[..., None], sigma)
    den = gaussian_blur_2d(valid_mask, sigma)[..., None]
    return np.where(den > 1e-3, num / np.maximum(den, 1e-3), rgb)


def recenter_and_normalize(ship, target_span: float = 2.0):
    xs = [v.co.x for v in ship.data.vertices]
    ys = [v.co.y for v in ship.data.vertices]
    zs = [v.co.z for v in ship.data.vertices]
    cx = 0.5 * (min(xs) + max(xs))
    cy = 0.5 * (min(ys) + max(ys))
    cz = 0.5 * (min(zs) + max(zs))
    dx = max(xs) - min(xs)
    dy = max(ys) - min(ys)
    dz = max(zs) - min(zs)
    span = max(dx, dy, dz, 0.001)
    scale_factor = target_span / span

    for v in ship.data.vertices:
        v.co.x = (v.co.x - cx) * scale_factor
        v.co.y = (v.co.y - cy) * scale_factor
        v.co.z = (v.co.z - cz) * scale_factor
    ship.data.update()


def import_and_prepare_glb(raw_glb_path: str, obj_name: str, rot_z_deg: float = "auto", target_span: float = 2.0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=raw_glb_path)

    mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not mesh_objs:
        raise RuntimeError(f"No mesh objects in {raw_glb_path}")

    bpy.ops.object.select_all(action="DESELECT")
    for o in mesh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    if len(mesh_objs) > 1:
        bpy.ops.object.join()

    ship = bpy.context.active_object
    ship.name = obj_name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    xs0 = [v.co.x for v in ship.data.vertices]
    ys0 = [v.co.y for v in ship.data.vertices]
    zs0 = [v.co.z for v in ship.data.vertices]
    dx0, dy0, dz0 = max(xs0) - min(xs0), max(ys0) - min(ys0), max(zs0) - min(zs0)
    print(f"[{obj_name}] Raw Bounds before Z-rot: dX={dx0:.3f}, dY={dy0:.3f}, dZ={dz0:.3f}")

    if rot_z_deg == "auto":
        # Meshy sets front along -Y by default unless elongated sideways along X
        resolved_rot = -90.0 if dy0 >= dx0 else 0.0
    else:
        resolved_rot = float(rot_z_deg)

    if abs(resolved_rot) > 0.001:
        rot_mat = mathutils.Matrix.Rotation(math.radians(resolved_rot), 4, "Z")
        ship.data.transform(rot_mat)
        ship.data.update()

    recenter_and_normalize(ship, target_span=target_span)
    return ship


def enhance_option_c_materials(ship, ship_key: str, target_faces: int = 16000):
    if len(ship.data.polygons) > target_faces * 1.15:
        ratio = float(target_faces) / float(len(ship.data.polygons))
        mod = ship.modifiers.new(name="Decimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)

    bpy.context.view_layer.objects.active = ship
    try:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    except Exception:
        pass
    bm = bmesh.new()
    bm.from_mesh(ship.data)
    uv_lay = bm.loops.layers.uv.active
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00025)
    boundary_edges = [e for e in bm.edges if e.is_boundary]
    filled_uv_boxes = []
    if 0 < len(boundary_edges) < 200:
        edge_vert_uv = {}
        edge_adj_norm = {}
        for e in boundary_edges:
            if e.link_faces:
                f_adj = e.link_faces[0]
                edge_adj_norm[e] = f_adj.normal.copy()
                if uv_lay is not None:
                    for l in f_adj.loops:
                        if l.vert in e.verts:
                            edge_vert_uv[(e, l.vert)] = l[uv_lay].uv.copy()
        res = bmesh.ops.holes_fill(bm, edges=boundary_edges, sides=128)
        new_faces = res.get("faces", [])
        for f_new in new_faces:
            f_new.normal_update()
            adj_norms = [edge_adj_norm[e] for e in f_new.edges if e in edge_adj_norm]
            if adj_norms:
                avg_n = sum(adj_norms, mathutils.Vector((0.0, 0.0, 0.0)))
                if f_new.normal.dot(avg_n) < 0.0:
                    f_new.normal_flip()
            if uv_lay is not None:
                uvs_assigned = []
                for l in f_new.loops:
                    uv_val = edge_vert_uv.get((l.edge, l.vert)) or edge_vert_uv.get((l.link_loop_prev.edge, l.vert))
                    if uv_val is None:
                        other_uvs = [ol[uv_lay].uv.copy() for ol in l.vert.link_loops if ol.face != f_new]
                        if other_uvs:
                            uv_val = other_uvs[0]
                    if uv_val is not None:
                        l[uv_lay].uv = uv_val
                        uvs_assigned.append((float(uv_val.x), float(uv_val.y)))
                if uvs_assigned:
                    us = [p[0] for p in uvs_assigned]
                    vs = [p[1] for p in uvs_assigned]
                    if (max(us) - min(us)) < 0.25 and (max(vs) - min(vs)) < 0.25:
                        filled_uv_boxes.append((min(us), max(us), min(vs), max(vs)))
        if new_faces:
            bmesh.ops.triangulate(bm, faces=new_faces)
            print(f"  [{ship_key}] Sealed {len(new_faces)} open mesh boundary holes ({len(boundary_edges)} boundary edges)")
    bm.to_mesh(ship.data)
    bm.free()
    ship.data.update()
    bpy.ops.object.shade_smooth()

    for mat in ship.data.materials:
        if not mat or not mat.node_tree:
            continue
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links

        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        base_tex_node = next(
            (n for n in nodes if n.type == "TEX_IMAGE" and n.image and (n.label == "BASE COLOR" or "Image_0" in n.image.name)),
            None,
        )
        mr_tex_node = next(
            (n for n in nodes if n.type == "TEX_IMAGE" and n.image and (n.label == "METALLIC ROUGHNESS" or "Image_1" in n.image.name)),
            None,
        )
        norm_tex_node = next(
            (n for n in nodes if n.type == "TEX_IMAGE" and n.image and (n.label == "NORMAL MAP" or "Image_2" in n.image.name)),
            None,
        )
        if not bsdf or not base_tex_node:
            continue

        w, h = base_tex_node.image.size[0], base_tex_node.image.size[1]
        base_lin_px = np.array(base_tex_node.image.pixels[:], dtype=np.float32).reshape((h, w, 4))
        rgb_raw_srgb = linear_to_srgb(base_lin_px[..., :3])
        uv_valid = (np.max(rgb_raw_srgb, axis=-1) > 0.035).astype(np.float32)

        # Heal any unbaked black UV patches inside sealed mesh holes or active UV islands
        in_island = np.zeros((h, w), dtype=np.float32)
        for u0, u1, v0, v1 in filled_uv_boxes:
            x0 = max(0, int(u0 * w) - 6)
            x1 = min(w, int(u1 * w) + 7)
            y0 = max(0, int(v0 * h) - 6)
            y1 = min(h, int(v1 * h) + 7)
            in_island[y0:y1, x0:x1] = 1.0
        if ship.data.uv_layers.active is not None:
            uv_data = ship.data.uv_layers.active.data
            n_loops = len(uv_data)
            uvs = np.empty(n_loops * 2, dtype=np.float32)
            uv_data.foreach_get("uv", uvs)
            uvs = uvs.reshape((n_loops, 2))
            grid_sz = 512
            gx = np.clip((uvs[:, 0] * grid_sz).astype(np.int32), 0, grid_sz - 1)
            gy = np.clip((uvs[:, 1] * grid_sz).astype(np.int32), 0, grid_sz - 1)
            uv_occ = np.zeros((grid_sz, grid_sz), dtype=np.float32)
            uv_occ[gy, gx] = 1.0
            uv_occ = (gaussian_blur_2d(uv_occ, sigma=2.5) > 0.03).astype(np.float32)
            rep_y, rep_x = h // grid_sz, w // grid_sz
            occ_up = np.repeat(np.repeat(uv_occ, rep_y, axis=0), rep_x, axis=1)
            if occ_up.shape != (h, w):
                occ_up = np.pad(occ_up, ((0, max(0, h - occ_up.shape[0])), (0, max(0, w - occ_up.shape[1]))), mode="edge")[:h, :w]
            in_island = np.maximum(in_island, occ_up)
        unbaked_hole = (in_island > 0.5) & (uv_valid < 0.5)
        if np.any(unbaked_hole):
            inpainted = masked_blur_rgb(rgb_raw_srgb, uv_valid, sigma=26.0)
            rgb_raw_srgb = np.where(unbaked_hole[..., None], inpainted, rgb_raw_srgb)
            uv_valid = np.maximum(uv_valid, in_island)

        major_cavity = np.zeros((h, w), dtype=np.float32)
        major_bevel = np.zeros((h, w), dtype=np.float32)

        if norm_tex_node is not None:
            norm_px = np.array(norm_tex_node.image.pixels[:], dtype=np.float32).reshape((h, w, 4))
            nx = norm_px[..., 0] * 2.0 - 1.0
            ny = norm_px[..., 1] * 2.0 - 1.0
            nxy_s = masked_blur_rgb(np.stack([nx, ny], axis=-1), uv_valid, sigma=4.0)
            nx_s, ny_s = nxy_s[..., 0], nxy_s[..., 1]

            dnx_du = 0.5 * (np.roll(nx_s, -2, axis=1) - np.roll(nx_s, 2, axis=1)) * uv_valid
            dny_dv = 0.5 * (np.roll(ny_s, -2, axis=0) - np.roll(ny_s, 2, axis=0)) * uv_valid
            div_macro = dnx_du + dny_dv

            major_cavity = np.clip((np.maximum(0.0, -div_macro) - 0.02) * 3.5, 0.0, 1.0) * uv_valid
            major_bevel = np.clip((np.maximum(0.0, div_macro) - 0.02) * 3.2, 0.0, 1.0) * uv_valid

            # Attenuate normal micro-chatter so specular sheen stays sleek across clean hull plates
            flat_strength = 0.22
            nx_flat = nx_s * flat_strength
            ny_flat = ny_s * flat_strength
            nz_flat = np.sqrt(np.maximum(1.0 - nx_flat * nx_flat - ny_flat * ny_flat, 0.01))
            norm_clean = np.dstack([
                nx_flat * 0.5 + 0.5,
                ny_flat * 0.5 + 0.5,
                nz_flat * 0.5 + 0.5,
                norm_px[..., 3],
            ])
            norm_tex_node.image.pixels[:] = np.clip(norm_clean, 0.0, 1.0).ravel().tolist()
            norm_tex_node.image.update()

        r0, g0, b0 = rgb_raw_srgb[..., 0], rgb_raw_srgb[..., 1], rgb_raw_srgb[..., 2]
        lum0 = 0.299 * r0 + 0.587 * g0 + 0.114 * b0

        if ship_key == "scout":
            glow_mask = np.clip((r0 - np.maximum(g0, b0) * 1.30) * 4.5, 0.0, 1.0) * uv_valid
            emis_srgb = np.stack([np.ones_like(r0), np.full_like(g0, 0.18), np.full_like(b0, 0.22)], axis=-1)
        elif ship_key == "raider":
            # Violet-magenta orb (high B & R compared to G, bright)
            orb_score = np.clip((b0 - g0 * 1.25) * 3.8, 0.0, 1.0) * np.clip((b0 - r0 * 0.72) * 3.5, 0.0, 1.0) * np.clip((lum0 - 0.42) * 3.8, 0.0, 1.0)
            glow_mask = np.clip(orb_score, 0.0, 1.0) * uv_valid
            emis_srgb = np.stack([np.full_like(r0, 0.88), np.full_like(g0, 0.36), np.ones_like(b0)], axis=-1)
        else:
            # Crimson eyes & vertical reactor gills (R distinctly > B and >> G)
            glow_mask = np.clip((r0 - b0 * 1.06) * 5.5, 0.0, 1.0) * np.clip((r0 - g0 * 1.45) * 5.0, 0.0, 1.0) * np.clip((r0 - 0.42) * 4.0, 0.0, 1.0) * uv_valid
            emis_srgb = np.stack([np.ones_like(r0), np.full_like(g0, 0.18), np.full_like(b0, 0.28)], axis=-1)

        non_glow = 1.0 - glow_mask

        # Mild UV-island-safe smoothing to unify plate colors cleanly
        rgb_smooth = masked_blur_rgb(rgb_raw_srgb, uv_valid * non_glow + 1e-4, sigma=3.0)
        rs, gs, bs = rgb_smooth[..., 0], rgb_smooth[..., 1], rgb_smooth[..., 2]
        lums = 0.299 * rs + 0.587 * gs + 0.114 * bs
        max_cs = np.maximum(rs, np.maximum(gs, bs))
        min_cs = np.minimum(rs, np.minimum(gs, bs))
        sats = (max_cs - min_cs) / np.maximum(max_cs, 1e-4)

        valid_lums = lums[(uv_valid > 0.5) & (glow_mask < 0.2)]
        p_low, p_high = (np.percentile(valid_lums, 6), np.percentile(valid_lums, 92)) if valid_lums.size > 0 else (0.1, 0.8)
        norm_l = np.clip((lums - p_low) / max(p_high - p_low, 0.08), 0.0, 1.0)
        scurve = norm_l * norm_l * (3.0 - 2.0 * norm_l)

        if ship_key == "scout":
            mech_mask = np.clip((0.38 - norm_l) * 3.6, 0.0, 1.0) * non_glow
            plate_srgb = np.stack([0.34 + 0.44 * scurve, 0.38 + 0.46 * scurve, 0.44 + 0.48 * scurve], axis=-1)
            mech_srgb = np.stack([0.11 + 0.15 * norm_l, 0.13 + 0.17 * norm_l, 0.17 + 0.20 * norm_l], axis=-1)
            out_srgb = plate_srgb * (1.0 - mech_mask[..., None]) + mech_srgb * mech_mask[..., None]

        elif ship_key == "raider":
            # Crisp dark gunmetal rear thruster cylinders (low saturation) vs vibrant crimson-magenta crescent wings!
            mech_mask = np.clip(np.maximum((0.32 - sats) * 4.8, (0.24 - norm_l) * 4.0), 0.0, 1.0) * non_glow
            armor_srgb = np.stack([
                0.44 + 0.44 * scurve,
                0.11 + 0.16 * scurve,
                0.30 + 0.36 * scurve,
            ], axis=-1)
            mech_srgb = np.stack([
                0.13 + 0.20 * norm_l,
                0.16 + 0.24 * norm_l,
                0.22 + 0.30 * norm_l,
            ], axis=-1)
            out_srgb = armor_srgb * (1.0 - mech_mask[..., None]) + mech_srgb * mech_mask[..., None]

        else:
            # Destroyer & Big Boss: Separate neutral low-saturation gunmetal barrels/nozzles from violet-saturated hull plates!
            violet_dom = np.clip((bs - gs * 1.18) / np.maximum(bs, 1e-4), 0.0, 1.0)
            mech_mask = np.clip(np.maximum((0.24 - sats) * 5.2, (0.22 - violet_dom) * 4.5), 0.0, 1.0) * non_glow
            # Boost Dreadnought's mid-luminance floor slightly so its curved shark hull matches Boss Titan's luminous royal-violet pop
            hull_boost = 0.22 if ship_key == "dreadnought" else 0.06
            scurve_cap = np.clip(scurve + hull_boost * (1.0 - scurve), 0.0, 1.0)
            armor_srgb = np.stack([
                0.30 + 0.38 * scurve_cap,
                0.22 + 0.30 * scurve_cap,
                0.50 + 0.44 * scurve_cap,
            ], axis=-1)
            mech_srgb = np.stack([
                0.12 + 0.22 * norm_l,
                0.14 + 0.25 * norm_l,
                0.19 + 0.30 * norm_l,
            ], axis=-1)
            out_srgb = armor_srgb * (1.0 - mech_mask[..., None]) + mech_srgb * mech_mask[..., None]

        out_srgb = out_srgb * (1.0 - 0.50 * major_cavity[..., None] * non_glow[..., None])
        bevel_col = np.array([0.78, 0.88, 1.0], dtype=np.float32) if ship_key != "raider" else np.array([1.0, 0.72, 0.92], dtype=np.float32)
        out_srgb = np.clip(out_srgb + 0.16 * major_bevel[..., None] * non_glow[..., None] * bevel_col[None, None, :], 0.0, 1.0)
        out_srgb = out_srgb * (1.0 - glow_mask[..., None]) + emis_srgb * glow_mask[..., None]

        new_lin_rgb = srgb_to_linear(out_srgb) * uv_valid[..., None]
        base_out = np.dstack([new_lin_rgb, base_lin_px[..., 3]])
        base_tex_node.image.pixels[:] = base_out.ravel().tolist()
        base_tex_node.image.update()

        if mr_tex_node is not None:
            mr_px = np.array(mr_tex_node.image.pixels[:], dtype=np.float32).reshape((h, w, 4))
            ao = np.clip(1.0 - 0.55 * major_cavity, 0.25, 1.0)
            rough = np.where(glow_mask > 0.2, 0.16, 0.44 + 0.16 * major_cavity - 0.06 * major_bevel)
            metal = np.where(glow_mask > 0.2, 0.04, 0.24 + 0.22 * mech_mask if ship_key != "scout" else 0.40)
            mr_out = np.dstack([ao, rough, np.broadcast_to(metal, ao.shape), mr_px[..., 3]])
            mr_tex_node.image.pixels[:] = mr_out.ravel().tolist()
            mr_tex_node.image.update()

        emis_lin_rgb = srgb_to_linear(emis_srgb) * glow_mask[..., None]
        emis_img = bpy.data.images.new(name=f"{ship_key}_emissive", width=w, height=h, alpha=False)
        emis_out = np.dstack([np.clip(emis_lin_rgb, 0.0, 1.0), np.ones((h, w), dtype=np.float32)])
        emis_img.pixels[:] = emis_out.ravel().tolist()
        emis_img.update()

        emis_node = nodes.new(type="ShaderNodeTexImage")
        emis_node.image = emis_img
        links.new(emis_node.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.15


def inspect_rear_nozzles(ship, label: str):
    xs = [v.co.x for v in ship.data.vertices]
    ys = [v.co.y for v in ship.data.vertices]
    zs = [v.co.z for v in ship.data.vertices]
    max_x = max(xs)
    min_x = min(xs)
    print(
        f"[{label}] Normalized Bounds: X=[{min_x:.3f}, {max_x:.3f}], "
        f"Y=[{min(ys):.3f}, {max(ys):.3f}], Z=[{min(zs):.3f}, {max(zs):.3f}], "
        f"Polys={len(ship.data.polygons)}"
    )
    rear_vs = [v.co for v in ship.data.vertices if v.co.x > max_x - 0.16]
    if rear_vs:
        neg_y = [v for v in rear_vs if v.y < -0.02]
        pos_y = [v for v in rear_vs if v.y > 0.02]
        pos_z = [v for v in rear_vs if v.z > 0.01]
        neg_z = [v for v in rear_vs if v.z < -0.01]
        print(f"  [{label}] Rear (+X) vertex count={len(rear_vs)}, max_x={max_x:.3f}")
        if neg_y and pos_y:
            ny_c = (max(v.x for v in neg_y), sum(v.y for v in neg_y) / len(neg_y), sum(v.z for v in neg_y) / len(neg_y))
            py_c = (max(v.x for v in pos_y), sum(v.y for v in pos_y) / len(pos_y), sum(v.z for v in pos_y) / len(pos_y))
            print(f"  [{label}] Y-split nozzles (Blender): negY=({ny_c[0]:.3f}, {ny_c[1]:.3f}, {ny_c[2]:.3f}), posY=({py_c[0]:.3f}, {py_c[1]:.3f}, {py_c[2]:.3f})")
            print(f"  [{label}] Y-split nozzles (Godot):   negY=({ny_c[0]:.3f}, {ny_c[2]:.3f}, {-ny_c[1]:.3f}), posY=({py_c[0]:.3f}, {py_c[2]:.3f}, {-py_c[1]:.3f})")
        if pos_z and neg_z:
            pz_c = (max(v.x for v in pos_z), sum(v.y for v in pos_z) / len(pos_z), sum(v.z for v in pos_z) / len(pos_z))
            nz_c = (max(v.x for v in neg_z), sum(v.y for v in neg_z) / len(neg_z), sum(v.z for v in neg_z) / len(neg_z))
            print(f"  [{label}] Z-split nozzles (Blender): topZ=({pz_c[0]:.3f}, {pz_c[1]:.3f}, {pz_c[2]:.3f}), botZ=({nz_c[0]:.3f}, {nz_c[1]:.3f}, {nz_c[2]:.3f})")
            print(f"  [{label}] Z-split nozzles (Godot):   topZ=({pz_c[0]:.3f}, {pz_c[2]:.3f}, {-pz_c[1]:.3f}), botZ=({nz_c[0]:.3f}, {nz_c[2]:.3f}, {-nz_c[1]:.3f})")


def export_clean_glb(ship_obj, out_glb_path: str):
    bpy.ops.object.select_all(action="DESELECT")
    ship_obj.select_set(True)
    bpy.context.view_layer.objects.active = ship_obj
    bpy.ops.export_scene.gltf(
        filepath=out_glb_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print(f"Exported {out_glb_path} ({os.path.getsize(out_glb_path)} bytes)")


def main():
    scout = import_and_prepare_glb(
        os.path.join(MODELS_DIR, "enemy_scout_meshy_raw.glb"),
        "EnemyScout",
        rot_z_deg=-90.0,
        target_span=1.90,
    )
    enhance_option_c_materials(scout, "scout", target_faces=18000)
    inspect_rear_nozzles(scout, "EnemyScout")
    export_clean_glb(scout, os.path.join(MODELS_DIR, "enemy_scout.glb"))

    raider = import_and_prepare_glb(
        os.path.join(MODELS_DIR, "enemy_raider_meshy_raw.glb"),
        "EnemyRaider",
        rot_z_deg=0.0,
        target_span=2.00,
    )
    enhance_option_c_materials(raider, "raider", target_faces=14000)
    inspect_rear_nozzles(raider, "EnemyRaider")
    export_clean_glb(raider, os.path.join(MODELS_DIR, "enemy_raider.glb"))

    dread = import_and_prepare_glb(
        os.path.join(MODELS_DIR, "boss_dreadnought_meshy_raw.glb"),
        "BossDreadnought",
        rot_z_deg=0.0,
        target_span=2.00,
    )
    enhance_option_c_materials(dread, "dreadnought", target_faces=14000)
    inspect_rear_nozzles(dread, "BossDreadnought")
    export_clean_glb(dread, os.path.join(MODELS_DIR, "boss_dreadnought.glb"))

    titan = import_and_prepare_glb(
        os.path.join(MODELS_DIR, "boss_titan_meshy_raw.glb"),
        "BossTitan",
        rot_z_deg=0.0,
        target_span=2.04,
    )
    enhance_option_c_materials(titan, "boss_titan", target_faces=16000)
    inspect_rear_nozzles(titan, "BossTitan")
    export_clean_glb(titan, os.path.join(MODELS_DIR, "boss_titan.glb"))


if __name__ == "__main__":
    main()
