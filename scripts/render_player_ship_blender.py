"""
Render the processed Meshy 3D player ship (player_ship.glb) in Blender 5.2
with high-intensity turbulent afterburner exhaust flames seated accurately inside the twin exhaust ports:
  Left/Top barrel:     X = -0.88, Y = +0.086, Z = -0.042
  Right/Bottom barrel: X = -0.88, Y = -0.086, Z = -0.042
"""
import os
import math
import bpy

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")
IMAGES_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "images")
GLB_PATH = os.path.join(MODELS_DIR, "player_ship.glb")
PREVIEW_PATH = os.path.join(MODELS_DIR, "player_ship_3d_game_perspective.png")
ICON_PATH = os.path.join(IMAGES_DIR, "player_ship.png")


def create_flame_material(name: str, is_core: bool = False):
    """
    Create a vivid, continuous-spine turbulent afterburner flame material:
    - Solid high-energy plasma spine along the center so the flame never breaks into disconnected islands
    - 3D Noise turbulence eroding the outer rim and tail into jagged, flickering flame tongues
    - White-hot core -> bright gold -> vibrant orange -> crimson-orange tips
    """
    mat = bpy.data.materials.new(name=name)
    if hasattr(mat, "blend_method"):
        mat.blend_method = "BLEND"
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "BLENDED"

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new(type="ShaderNodeOutputMaterial")
    shader = nodes.new(type="ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
    shader.inputs["Specular IOR Level"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 1.0

    tex_coord = nodes.new(type="ShaderNodeTexCoord")
    sep = nodes.new(type="ShaderNodeSeparateXYZ")
    links.new(tex_coord.outputs["Generated"], sep.inputs["Vector"])

    # Noise texture stretched along Z (flame flow direction) for flame licks
    mapping = nodes.new(type="ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (5.5, 5.5, 2.2)
    links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])

    noise = nodes.new(type="ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.2
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.65
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

    # Radial distance from center axis (0.5, 0.5) in XY -> r in [0, 1]
    sub_x = nodes.new(type="ShaderNodeMath")
    sub_x.operation = "SUBTRACT"
    sub_x.inputs[1].default_value = 0.5
    links.new(sep.outputs["X"], sub_x.inputs[0])

    sub_y = nodes.new(type="ShaderNodeMath")
    sub_y.operation = "SUBTRACT"
    sub_y.inputs[1].default_value = 0.5
    links.new(sep.outputs["Y"], sub_y.inputs[0])

    sq_x = nodes.new(type="ShaderNodeMath")
    sq_x.operation = "MULTIPLY"
    links.new(sub_x.outputs[0], sq_x.inputs[0])
    links.new(sub_x.outputs[0], sq_x.inputs[1])

    sq_y = nodes.new(type="ShaderNodeMath")
    sq_y.operation = "MULTIPLY"
    links.new(sub_y.outputs[0], sq_y.inputs[0])
    links.new(sub_y.outputs[0], sq_y.inputs[1])

    sum_sq = nodes.new(type="ShaderNodeMath")
    sum_sq.operation = "ADD"
    links.new(sq_x.outputs[0], sum_sq.inputs[0])
    links.new(sq_y.outputs[0], sum_sq.inputs[1])

    sqrt_r = nodes.new(type="ShaderNodeMath")
    sqrt_r.operation = "SQRT"
    links.new(sum_sq.outputs[0], sqrt_r.inputs[0])

    norm_r = nodes.new(type="ShaderNodeMath")
    norm_r.operation = "MULTIPLY"
    norm_r.inputs[1].default_value = 2.0
    links.new(sqrt_r.outputs[0], norm_r.inputs[0])

    # Radial falloff: 1.0 at center (r=0), 0.0 at outer surface (r=1)
    inv_r = nodes.new(type="ShaderNodeMath")
    inv_r.operation = "SUBTRACT"
    inv_r.use_clamp = True
    inv_r.inputs[0].default_value = 1.0
    links.new(norm_r.outputs[0], inv_r.inputs[1])

    # Axial falloff along Z: 1.0 at nozzle (Z=0), 0.0 at tip (Z=1)
    inv_z = nodes.new(type="ShaderNodeMath")
    inv_z.operation = "SUBTRACT"
    inv_z.use_clamp = True
    inv_z.inputs[0].default_value = 1.0
    links.new(sep.outputs["Z"], inv_z.inputs[1])

    # Smooth power on inv_z so the body stays strong through the first 65% of the plume
    pow_z = nodes.new(type="ShaderNodeMath")
    pow_z.operation = "POWER"
    pow_z.inputs[1].default_value = 0.68
    links.new(inv_z.outputs[0], pow_z.inputs[0])

    # Base continuous heat spine = inv_r * pow_z
    base_spine = nodes.new(type="ShaderNodeMath")
    base_spine.operation = "MULTIPLY"
    links.new(inv_r.outputs[0], base_spine.inputs[0])
    links.new(pow_z.outputs[0], base_spine.inputs[1])

    # Add turbulent flame tongues (stronger near outer edge/tail, never zeroing out the core):
    # noise_boost = (noise - 0.28) * 0.55 * pow_z
    noise_shift = nodes.new(type="ShaderNodeMath")
    noise_shift.operation = "SUBTRACT"
    noise_shift.inputs[1].default_value = 0.28
    links.new(noise.outputs["Fac"], noise_shift.inputs[0])

    noise_scale = nodes.new(type="ShaderNodeMath")
    noise_scale.operation = "MULTIPLY"
    noise_scale.inputs[1].default_value = 0.65
    links.new(noise_shift.outputs[0], noise_scale.inputs[0])

    noise_axial = nodes.new(type="ShaderNodeMath")
    noise_axial.operation = "MULTIPLY"
    links.new(noise_scale.outputs[0], noise_axial.inputs[0])
    links.new(pow_z.outputs[0], noise_axial.inputs[1])

    heat = nodes.new(type="ShaderNodeMath")
    heat.operation = "ADD"
    heat.use_clamp = True
    links.new(base_spine.outputs[0], heat.inputs[0])
    links.new(noise_axial.outputs[0], heat.inputs[1])

    # Fiery ColorRamp (with Emission Strength = 1.0 so orange never clips to yellow!):
    # 0.05 -> deep crimson-red outer lick
    # 0.28 -> rich fiery orange
    # 0.58 -> bright golden amber
    # 0.82 -> intense yellow-white plasma core
    ramp = nodes.new(type="ShaderNodeValToRGB")
    elems = ramp.color_ramp.elements
    elems[0].position = 0.05
    elems[0].color = (0.85, 0.06, 0.01, 1.0)
    elems[1].position = 0.85
    elems[1].color = (1.0, 0.98, 0.82, 1.0)

    e_orange = elems.new(0.32)
    e_orange.color = (1.0, 0.26, 0.01, 1.0)
    e_gold = elems.new(0.62)
    e_gold.color = (1.0, 0.68, 0.06, 1.0)

    links.new(heat.outputs[0], ramp.inputs["Fac"])

    # Crisp yet organic flame silhouette alpha ramp
    alpha_ramp = nodes.new(type="ShaderNodeValToRGB")
    a_elems = alpha_ramp.color_ramp.elements
    a_elems[0].position = 0.12
    a_elems[0].color = (0.0, 0.0, 0.0, 1.0)
    a_elems[1].position = 0.34 if not is_core else 0.25
    a_elems[1].color = (1.0, 1.0, 1.0, 1.0)
    links.new(heat.outputs[0], alpha_ramp.inputs["Fac"])

    links.new(ramp.outputs["Color"], shader.inputs["Emission Color"])
    shader.inputs["Emission Strength"].default_value = 1.0 if not is_core else 1.15
    links.new(alpha_ramp.outputs["Color"], shader.inputs["Alpha"])

    links.new(shader.outputs["BSDF"], out.inputs["Surface"])
    return mat, mapping


def create_thruster_plume(name, location, length=0.68, radius=0.088, is_core=False, mat_tuple=None):
    """
    Create an organic teardrop-shaped 3D exhaust plume mesh whose base sits inside the exhaust barrel (z=0)
    and swells slightly before tapering to a flickering tip (z=+1), with wavy longitudinal ribs for flame licks.
    """
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=24,
        radius=1.0,
        location=location,
    )
    plume = bpy.context.active_object
    plume.name = name

    for v in plume.data.vertices:
        u = (v.co.z + 1.0) * 0.5
        ang = math.atan2(v.co.y, v.co.x)
        # Wavy longitudinal ridges along the tail so the silhouette has organic flame tongues
        rib_wave = 1.0 + (0.18 * math.sin(ang * 5.0 + u * 9.0) + 0.12 * math.cos(ang * 8.0 - u * 13.0)) * u
        # Teardrop profile: starts at 0.72*r inside barrel, swells to 1.0*r at u=0.16, tapers to 0 at u=1
        if u < 0.16:
            profile = 0.72 + 0.28 * math.sin((u / 0.16) * math.pi * 0.5)
        else:
            profile = math.pow(max(0.0, 1.0 - (u - 0.16) / 0.84), 0.78)
        v.co.x *= radius * profile * rib_wave
        v.co.y *= radius * profile * rib_wave
        v.co.z = u
    plume.data.update()
    bpy.ops.object.shade_smooth()

    # Rotate -90 deg around Y so local +Z points along -X (straight out the exhaust barrel!)
    plume.rotation_euler = (0.0, -math.pi * 0.5, 0.0)
    plume.scale = (1.0, 1.0, length)

    if mat_tuple is not None:
        plume.data.materials.append(mat_tuple[0])
    return plume


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB_PATH)

    mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not mesh_objs:
        raise RuntimeError("No mesh in player_ship.glb")
    ship = mesh_objs[0]

    rig = bpy.data.objects.new("ShipRig", None)
    bpy.context.collection.objects.link(rig)
    ship.parent = rig

    outer_mat, outer_map = create_flame_material("FlameOuterMat", is_core=False)
    core_mat, core_map = create_flame_material("FlameCoreMat", is_core=True)

    # Exact rear exit openings of the two blue cylindrical exhaust barrels:
    # Left/Top barrel exit:     X = -0.965, Y = +0.095, Z = -0.028
    # Right/Bottom barrel exit: X = -0.965, Y = -0.095, Z = -0.062
    port_l = (-0.965, 0.095, -0.028)
    port_r = (-0.965, -0.095, -0.062)

    plume_outer_l = create_thruster_plume("PlumeOuterL", port_l, length=0.68, radius=0.072, is_core=False, mat_tuple=(outer_mat, outer_map))
    plume_inner_l = create_thruster_plume("PlumeInnerL", port_l, length=0.42, radius=0.042, is_core=True, mat_tuple=(core_mat, core_map))
    plume_outer_r = create_thruster_plume("PlumeOuterR", port_r, length=0.68, radius=0.072, is_core=False, mat_tuple=(outer_mat, outer_map))
    plume_inner_r = create_thruster_plume("PlumeInnerR", port_r, length=0.42, radius=0.042, is_core=True, mat_tuple=(core_mat, core_map))

    for p in (plume_outer_l, plume_inner_l, plume_outer_r, plume_inner_r):
        p.parent = rig

    cam_data = bpy.data.cameras.new("GameCamera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 3.28
    cam_obj = bpy.data.objects.new("GameCamera", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = (-0.16, -4.0, 0.0)
    cam_obj.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    bpy.context.scene.camera = cam_obj

    key_data = bpy.data.lights.new(name="KeyLight", type="SUN")
    key_data.energy = 3.8
    key_data.color = (1.0, 0.98, 0.95)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key_data)
    bpy.context.collection.objects.link(key_obj)
    key_obj.rotation_euler = (math.radians(48), math.radians(-18), math.radians(22))

    fill_data = bpy.data.lights.new(name="FillLight", type="SUN")
    fill_data.energy = 2.2
    fill_data.color = (0.35, 0.90, 1.0)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(105), math.radians(15), math.radians(-28))

    rim_data = bpy.data.lights.new(name="RimLight", type="SUN")
    rim_data.energy = 2.6
    rim_data.color = (1.0, 0.70, 0.25)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (math.radians(25), math.radians(40), math.radians(-135))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    # Neutral 2.5D dorsal perspective (banked slightly left: 26 deg)
    rig.rotation_euler = (math.radians(26.0), math.radians(-3.0), math.radians(2.0))

    # 1. Render high-res preview (690x360)
    scene.render.resolution_x = 690
    scene.render.resolution_y = 360
    scene.render.filepath = PREVIEW_PATH
    bpy.ops.render.render(write_still=True)
    print(f"Rendered high-res preview to {PREVIEW_PATH}")

    # 2. Render icon / base sprite (230x120)
    scene.render.resolution_x = 230
    scene.render.resolution_y = 120
    scene.render.filepath = ICON_PATH
    bpy.ops.render.render(write_still=True)
    print(f"Rendered player_ship.png to {ICON_PATH}")

    # 3. Render 36-frame spritesheet frames (3 bank rows x 12 columns of 230x120)
    tmp_dir = os.path.join(MODELS_DIR, "sheet_frames")
    os.makedirs(tmp_dir, exist_ok=True)
    bank_angles = [
        ("bank_left", 10.0, -5.0, 5.0),
        ("neutral", 26.0, -3.0, 2.0),
        ("bank_right", 44.0, 1.0, -3.0),
    ]
    throttles = [
        ("idle", 0.36, 0.78),
        ("cruise", 0.68, 1.0),
        ("boost", 1.02, 1.25),
    ]

    for r_idx, (b_name, roll_deg, pitch_deg, yaw_deg) in enumerate(bank_angles):
        rig.rotation_euler = (math.radians(roll_deg), math.radians(pitch_deg), math.radians(yaw_deg))
        for t_idx, (t_name, base_len, rad_scale) in enumerate(throttles):
            for f_idx in range(4):
                pulse = 1.0 + 0.14 * math.sin(f_idx * math.pi * 0.5)
                outer_map.inputs["Location"].default_value = (f_idx * 0.37, -f_idx * 0.29, -f_idx * 0.55)
                core_map.inputs["Location"].default_value = (-f_idx * 0.41, f_idx * 0.31, -f_idx * 0.70)
                for p_out in (plume_outer_l, plume_outer_r):
                    p_out.scale = (rad_scale * pulse, rad_scale * pulse, base_len * pulse)
                for p_in in (plume_inner_l, plume_inner_r):
                    p_in.scale = (rad_scale * pulse, rad_scale * pulse, (base_len * 0.68) * (0.9 + 0.2 * pulse))
                col_idx = t_idx * 4 + f_idx
                out_frame = os.path.join(tmp_dir, f"r{r_idx}_c{col_idx:02d}.png")
                scene.render.filepath = out_frame
                bpy.ops.render.render(write_still=True)

    print("Finished rendering all 36 3D spritesheet frames.")


if __name__ == "__main__":
    main()
