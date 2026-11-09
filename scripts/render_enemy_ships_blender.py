"""
Renders all 4 processed 3D enemy spacecraft (.glb) in Blender 5.2 with procedural turbulent 3D thruster flames
seated at their exact measured rear exhaust nozzles to produce:
  1. High-resolution preview images of each 3D enemy craft (enemy_scout_3d_preview.png, enemy_raider_3d_preview.png,
     boss_dreadnought_3d_preview.png, boss_titan_3d_preview.png)
  2. Game sprites & multi-row 2.5D fallback spritesheets in PhotonShooter_Godot/assets/images/:
     - enemy_scout.png (92x68) & enemy_scout_spritesheet.png (4 cols x 3 rows of 96x56: cruise, charge, fire)
     - enemy_raider.png (136x92) & enemy_raider_spritesheet.png (4 cols x 3 rows of 128x68: bank_left, neutral, bank_right)
     - boss_dreadnought.png (480x224)
     - boss_titan.png (880x380)
"""
import os
import math
import bpy
import mathutils

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")
GODOT_IMAGES_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "images")
TMP_DIR = os.path.join(MODELS_DIR, "enemy_frames_tmp")


def apply_rig_pose(rig, roll_deg: float, pitch_deg: float, yaw_deg: float):
    """Matches Godot EnemyShip3D._apply_rig_rotation(roll_deg, pitch_deg, yaw_deg) exactly."""
    m_roll = mathutils.Matrix.Rotation(math.radians(roll_deg), 4, "X")
    m_pitch = mathutils.Matrix.Rotation(math.radians(-pitch_deg), 4, "Y")
    m_yaw = mathutils.Matrix.Rotation(math.radians(yaw_deg), 4, "Z")
    rig.matrix_world = m_yaw @ m_pitch @ m_roll


def create_flame_material(name: str, color_scheme: str = "cyan", is_core: bool = False):
    """
    Continuous-spine turbulent thruster flame material with Emission Strength = 1.0..1.15
    under Standard view transform (avoiding channel clipping).
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

    mapping = nodes.new(type="ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (5.5, 5.5, 2.2)
    links.new(tex_coord.outputs["Generated"], mapping.inputs["Vector"])

    noise = nodes.new(type="ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.2
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.65
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

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

    inv_r = nodes.new(type="ShaderNodeMath")
    inv_r.operation = "SUBTRACT"
    inv_r.use_clamp = True
    inv_r.inputs[0].default_value = 1.0
    links.new(norm_r.outputs[0], inv_r.inputs[1])

    inv_z = nodes.new(type="ShaderNodeMath")
    inv_z.operation = "SUBTRACT"
    inv_z.use_clamp = True
    inv_z.inputs[0].default_value = 1.0
    links.new(sep.outputs["Z"], inv_z.inputs[1])

    pow_z = nodes.new(type="ShaderNodeMath")
    pow_z.operation = "POWER"
    pow_z.inputs[1].default_value = 0.68
    links.new(inv_z.outputs[0], pow_z.inputs[0])

    base_spine = nodes.new(type="ShaderNodeMath")
    base_spine.operation = "MULTIPLY"
    links.new(inv_r.outputs[0], base_spine.inputs[0])
    links.new(pow_z.outputs[0], base_spine.inputs[1])

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

    ramp = nodes.new(type="ShaderNodeValToRGB")
    elems = ramp.color_ramp.elements
    if color_scheme == "cyan":
        elems[0].position = 0.05
        elems[0].color = (0.02, 0.22, 0.88, 1.0)
        elems[1].position = 0.85
        elems[1].color = (0.92, 0.99, 1.0, 1.0)
        e_mid1 = elems.new(0.32)
        e_mid1.color = (0.05, 0.58, 1.0, 1.0)
        e_mid2 = elems.new(0.62)
        e_mid2.color = (0.35, 0.92, 1.0, 1.0)
    else:
        elems[0].position = 0.05
        elems[0].color = (0.48, 0.04, 0.82, 1.0)
        elems[1].position = 0.85
        elems[1].color = (1.0, 0.94, 1.0, 1.0)
        e_mid1 = elems.new(0.32)
        e_mid1.color = (0.88, 0.14, 0.86, 1.0)
        e_mid2 = elems.new(0.62)
        e_mid2.color = (1.0, 0.48, 0.96, 1.0)

    links.new(heat.outputs[0], ramp.inputs["Fac"])

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


def create_thruster_plume_east(name, location, length=0.55, radius=0.070, mat_tuple=None):
    """Creates a teardrop turbulent exhaust plume pointing along +X (right, rear of enemy ships)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=20, radius=1.0, location=location)
    plume = bpy.context.active_object
    plume.name = name

    for v in plume.data.vertices:
        u = (v.co.z + 1.0) * 0.5
        ang = math.atan2(v.co.y, v.co.x)
        rib_wave = 1.0 + (0.16 * math.sin(ang * 5.0 + u * 9.0) + 0.10 * math.cos(ang * 8.0 - u * 13.0)) * u
        if u < 0.16:
            profile = 0.72 + 0.28 * math.sin((u / 0.16) * math.pi * 0.5)
        else:
            profile = math.pow(max(0.0, 1.0 - (u - 0.16) / 0.84), 0.78)
        v.co.x *= radius * profile * rib_wave
        v.co.y *= radius * profile * rib_wave
        v.co.z = u
    plume.data.update()
    bpy.ops.object.shade_smooth()

    # Rotate +90 deg around Y so local +Z points along +X (rear of enemy ships)
    plume.rotation_euler = (0.0, math.pi * 0.5, 0.0)
    plume.scale = (1.0, 1.0, length)
    if mat_tuple is not None:
        plume.data.materials.append(mat_tuple[0])
    return plume


def setup_studio_scene(ortho_scale: float = 2.55, cam_x: float = 0.14):
    cam_data = bpy.data.cameras.new("GameCamera")
    cam_data.type = "ORTHO"
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.ortho_scale = ortho_scale
    cam_obj = bpy.data.objects.new("GameCamera", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = (cam_x, -4.0, 0.0)
    cam_obj.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    bpy.context.scene.camera = cam_obj

    key_data = bpy.data.lights.new(name="KeyLight", type="SUN")
    key_data.energy = 4.4
    key_data.color = (1.0, 0.98, 0.96)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key_data)
    bpy.context.collection.objects.link(key_obj)
    key_obj.rotation_euler = (math.radians(46), math.radians(18), math.radians(-26))

    fill_data = bpy.data.lights.new(name="FillLight", type="SUN")
    fill_data.energy = 0.75
    fill_data.color = (0.38, 0.56, 0.88)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(100), math.radians(-15), math.radians(28))

    rim_data = bpy.data.lights.new(name="RimLight", type="SUN")
    rim_data.energy = 3.2
    rim_data.color = (0.62, 0.92, 1.0)
    rim_obj = bpy.data.objects.new(name="RimLight", object_data=rim_data)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = (math.radians(28), math.radians(-42), math.radians(138))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    return scene


def render_scout():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb_path = os.path.join(MODELS_DIR, "enemy_scout.glb")
    bpy.ops.import_scene.gltf(filepath=glb_path)
    ship = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]

    rig = bpy.data.objects.new("ScoutRig", None)
    bpy.context.collection.objects.link(rig)
    ship.parent = rig

    outer_mat, outer_map = create_flame_material("ScoutFlameOuter", "cyan", is_core=False)
    core_mat, core_map = create_flame_material("ScoutFlameCore", "cyan", is_core=True)

    # Exact Blender-measured twin rear rocket nozzles: X=0.68, Y=+-0.201, Z=+0.095
    ports = [(0.68, -0.202, 0.095), (0.68, 0.200, 0.095)]
    plumes_out, plumes_in = [], []
    for idx, p in enumerate(ports):
        po = create_thruster_plume_east(f"ScoutOut_{idx}", p, length=0.52, radius=0.075, mat_tuple=(outer_mat, outer_map))
        pi = create_thruster_plume_east(f"ScoutIn_{idx}", p, length=0.34, radius=0.046, mat_tuple=(core_mat, core_map))
        po.parent = rig
        pi.parent = rig
        plumes_out.append(po)
        plumes_in.append(pi)

    eye_light_data = bpy.data.lights.new(name="EyeLight", type="POINT")
    eye_light_data.color = (1.0, 0.12, 0.15)
    eye_light_data.energy = 18.0
    eye_light = bpy.data.objects.new(name="EyeLight", object_data=eye_light_data)
    bpy.context.collection.objects.link(eye_light)
    eye_light.location = (-0.78, -0.15, 0.08)
    eye_light.parent = rig

    scene = setup_studio_scene(ortho_scale=2.72, cam_x=0.14)
    apply_rig_pose(rig, roll_deg=18.0, pitch_deg=4.0, yaw_deg=36.0)

    scene.render.resolution_x = 520
    scene.render.resolution_y = 380
    scene.render.filepath = os.path.join(MODELS_DIR, "enemy_scout_3d_preview.png")
    bpy.ops.render.render(write_still=True)

    scene.render.resolution_x = 92
    scene.render.resolution_y = 68
    scene.render.filepath = os.path.join(GODOT_IMAGES_DIR, "enemy_scout.png")
    bpy.ops.render.render(write_still=True)

    os.makedirs(TMP_DIR, exist_ok=True)
    scene.render.resolution_x = 96
    scene.render.resolution_y = 56
    rows = [("cruise", 14.0, 0.52), ("charge", 60.0, 0.36), ("fire", 95.0, 0.72)]
    for r_idx, (r_name, eye_e, p_len) in enumerate(rows):
        for c_idx in range(4):
            pulse = 1.0 + 0.15 * math.sin(c_idx * math.pi * 0.5)
            eye_light_data.energy = eye_e * (0.8 + 0.35 * (c_idx / 3.0))
            outer_map.inputs["Location"].default_value = (c_idx * 0.35, -c_idx * 0.25, -c_idx * 0.55)
            core_map.inputs["Location"].default_value = (-c_idx * 0.40, c_idx * 0.30, -c_idx * 0.70)
            for po in plumes_out:
                po.scale = (pulse, pulse, p_len * pulse)
            for pi in plumes_in:
                pi.scale = (pulse, pulse, p_len * 0.65 * pulse)
            scene.render.filepath = os.path.join(TMP_DIR, f"scout_r{r_idx}_c{c_idx}.png")
            bpy.ops.render.render(write_still=True)


def render_raider():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb_path = os.path.join(MODELS_DIR, "enemy_raider.glb")
    bpy.ops.import_scene.gltf(filepath=glb_path)
    ship = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]

    rig = bpy.data.objects.new("RaiderRig", None)
    bpy.context.collection.objects.link(rig)
    ship.parent = rig

    outer_mat, outer_map = create_flame_material("RaiderFlameOuter", "magenta", is_core=False)
    core_mat, core_map = create_flame_material("RaiderFlameCore", "magenta", is_core=True)

    # Exact Blender-measured twin rear engine cylinders on streamlined Interceptor: X=0.97, Y=+-0.210, Z=-0.090
    ports = [(0.97, -0.210, -0.090), (0.97, 0.210, -0.090)]
    plumes_out, plumes_in = [], []
    for idx, p in enumerate(ports):
        po = create_thruster_plume_east(f"RaiderOut_{idx}", p, length=0.62, radius=0.082, mat_tuple=(outer_mat, outer_map))
        pi = create_thruster_plume_east(f"RaiderIn_{idx}", p, length=0.40, radius=0.050, mat_tuple=(core_mat, core_map))
        po.parent = rig
        pi.parent = rig
        plumes_out.append(po)
        plumes_in.append(pi)

    orb_light_data = bpy.data.lights.new(name="OrbLight", type="POINT")
    orb_light_data.color = (0.95, 0.25, 1.0)
    orb_light_data.energy = 10.0
    orb_light = bpy.data.objects.new(name="OrbLight", object_data=orb_light_data)
    bpy.context.collection.objects.link(orb_light)
    orb_light.location = (-0.82, -0.08, 0.0)
    orb_light.parent = rig

    scene = setup_studio_scene(ortho_scale=3.18, cam_x=0.22)
    apply_rig_pose(rig, roll_deg=22.0, pitch_deg=4.0, yaw_deg=26.0)

    scene.render.resolution_x = 580
    scene.render.resolution_y = 400
    scene.render.filepath = os.path.join(MODELS_DIR, "enemy_raider_3d_preview.png")
    bpy.ops.render.render(write_still=True)

    scene.render.resolution_x = 136
    scene.render.resolution_y = 94
    scene.render.filepath = os.path.join(GODOT_IMAGES_DIR, "enemy_raider.png")
    bpy.ops.render.render(write_still=True)

    os.makedirs(TMP_DIR, exist_ok=True)
    scene.render.resolution_x = 128
    scene.render.resolution_y = 68
    banks = [
        ("bank_left", 6.0, 0.0, 22.0),
        ("neutral", 22.0, 4.0, 26.0),
        ("bank_right", 38.0, 8.0, 30.0),
    ]
    for r_idx, (b_name, roll_d, pitch_d, yaw_d) in enumerate(banks):
        apply_rig_pose(rig, roll_deg=roll_d, pitch_deg=pitch_d, yaw_deg=yaw_d)
        for c_idx in range(4):
            pulse = 1.0 + 0.14 * math.sin(c_idx * math.pi * 0.5)
            outer_map.inputs["Location"].default_value = (c_idx * 0.37, -c_idx * 0.29, -c_idx * 0.55)
            core_map.inputs["Location"].default_value = (-c_idx * 0.41, c_idx * 0.31, -c_idx * 0.70)
            for po in plumes_out:
                po.scale = (pulse, pulse, 0.60 * pulse)
            for pi in plumes_in:
                pi.scale = (pulse, pulse, 0.40 * pulse)
            scene.render.filepath = os.path.join(TMP_DIR, f"raider_r{r_idx}_c{c_idx}.png")
            bpy.ops.render.render(write_still=True)


def render_capital_ship(
    glb_name: str,
    out_img_name: str,
    preview_name: str,
    res_w: int,
    res_h: int,
    ports: list,
    roll_deg: float,
    pitch_deg: float,
    yaw_deg: float,
    ortho_scale: float,
    cam_x: float,
    plume_len: float,
    plume_rad: float,
):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb_path = os.path.join(MODELS_DIR, glb_name)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    ship = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]

    rig = bpy.data.objects.new("CapitalRig", None)
    bpy.context.collection.objects.link(rig)
    ship.parent = rig

    outer_mat, outer_map = create_flame_material("CapFlameOuter", "magenta", is_core=False)
    core_mat, core_map = create_flame_material("CapFlameCore", "magenta", is_core=True)

    for idx, p in enumerate(ports):
        po = create_thruster_plume_east(f"CapOut_{idx}", p, length=plume_len, radius=plume_rad, mat_tuple=(outer_mat, outer_map))
        pi = create_thruster_plume_east(f"CapIn_{idx}", p, length=plume_len * 0.66, radius=plume_rad * 0.60, mat_tuple=(core_mat, core_map))
        po.parent = rig
        pi.parent = rig

    scene = setup_studio_scene(ortho_scale=ortho_scale, cam_x=cam_x)
    apply_rig_pose(rig, roll_deg=roll_deg, pitch_deg=pitch_deg, yaw_deg=yaw_deg)

    # High-res preview
    scene.render.resolution_x = 880
    scene.render.resolution_y = 400
    scene.render.filepath = os.path.join(MODELS_DIR, preview_name)
    bpy.ops.render.render(write_still=True)

    # Game texture
    scene.render.resolution_x = res_w
    scene.render.resolution_y = res_h
    scene.render.filepath = os.path.join(GODOT_IMAGES_DIR, out_img_name)
    bpy.ops.render.render(write_still=True)


def main():
    render_scout()
    render_raider()
    # Destroyer: exact 2x2 quad rear rocket thruster bank measured from +X rear ortho camera
    render_capital_ship(
        glb_name="boss_dreadnought.glb",
        out_img_name="boss_dreadnought.png",
        preview_name="boss_dreadnought_3d_preview.png",
        res_w=480,
        res_h=228,
        ports=[
            (0.95, -0.205, 0.059),
            (0.95, 0.152, 0.108),
            (0.95, -0.216, -0.116),
            (0.95, 0.181, -0.114),
        ],
        roll_deg=18.0,
        pitch_deg=3.0,
        yaw_deg=16.0,
        ortho_scale=2.72,
        cam_x=0.22,
        plume_len=0.58,
        plume_rad=0.080,
    )
    # Final Ship (Boss Titan): exact 4 main + 2 flanking rear gunmetal rocket nozzles measured from +X rear ortho camera
    render_capital_ship(
        glb_name="boss_titan.glb",
        out_img_name="boss_titan.png",
        preview_name="boss_titan_3d_preview.png",
        res_w=920,
        res_h=400,
        ports=[
            (0.96, -0.090, -0.077),
            (0.96, 0.101, -0.057),
            (0.96, -0.091, -0.213),
            (0.96, 0.105, -0.214),
            (0.90, -0.215, -0.145),
            (0.90, 0.215, -0.145),
        ],
        roll_deg=20.0,
        pitch_deg=3.0,
        yaw_deg=16.0,
        ortho_scale=2.84,
        cam_x=0.26,
        plume_len=0.62,
        plume_rad=0.074,
    )
    print("Finished rendering all 3D enemy previews, sprites, and spritesheet frames!")


if __name__ == "__main__":
    main()
