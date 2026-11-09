"""
Blender 5.2 headless script to inspect, orient, optimize, and export
the Meshy-generated player starfighter 3D model (player_ship_meshy_raw.glb -> player_ship.glb).
"""
import os
import math
import bpy
import mathutils

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")
RAW_GLB = os.path.join(MODELS_DIR, "player_ship_meshy_raw.glb")
OUT_GLB = os.path.join(MODELS_DIR, "player_ship.glb")
PREVIEW_PNG = os.path.join(MODELS_DIR, "player_ship_blender_preview.png")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RAW_GLB)

    mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    print(f"Imported {len(mesh_objs)} mesh objects from {RAW_GLB}")
    if not mesh_objs:
        raise RuntimeError("No mesh objects found in GLB!")

    # Join meshes if multiple
    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    if len(mesh_objs) > 1:
        bpy.ops.object.join()

    ship = bpy.context.active_object
    ship.name = "PlayerStarfighter"

    # Apply existing transforms
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Check bounding box dimensions
    bbox = [ship.matrix_world @ mathutils.Vector(corner) for corner in ship.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    dx = max(xs) - min(xs)
    dy = max(ys) - min(ys)
    dz = max(zs) - min(zs)
    print(f"Raw BBox spans: dX={dx:.3f}, dY={dy:.3f}, dZ={dz:.3f}")
    print(f"Faces before optimization: {len(ship.data.polygons)}")

    # Center geometry at origin
    cx = 0.5 * (min(xs) + max(xs))
    cy = 0.5 * (min(ys) + max(ys))
    cz = 0.5 * (min(zs) + max(zs))
    for v in ship.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= cz
    ship.data.update()

    # Normalize scale so max dimension is 2.0 units
    max_span = max(dx, dy, dz, 0.001)
    scale_factor = 2.0 / max_span
    for v in ship.data.vertices:
        v.co *= scale_factor
    ship.data.update()

    # Check which end is nose vs wings:
    # Wings have wider span at the back/middle, nose is narrow at the tip.
    # In Meshy's thumbnail (rendered from front/+Y or -Y camera), nose pointed left (-X).
    # Let's check average Y/Z width near min X vs max X:
    verts = ship.data.vertices
    neg_x_ys = [abs(v.co.y) for v in verts if v.co.x < -0.5]
    pos_x_ys = [abs(v.co.y) for v in verts if v.co.x > 0.5]
    max_neg_y = max(neg_x_ys) if neg_x_ys else 0.0
    max_pos_y = max(pos_x_ys) if pos_x_ys else 0.0
    print(f"Span near -X: {max_neg_y:.3f} | Span near +X: {max_pos_y:.3f}")

    # Rotate 180 deg around Z (up axis in Blender) so the nose points toward +X!
    if max_neg_y < max_pos_y:
        print("Rotating 180 deg around Z so nose points along +X...")
        rot_mat = mathutils.Matrix.Rotation(math.pi, 4, "Z")
        ship.data.transform(rot_mat)
        ship.data.update()

    # Decimate if polygon count > 15000 for fast real-time Godot rendering
    if len(ship.data.polygons) > 15000:
        ratio = 12000.0 / float(len(ship.data.polygons))
        mod = ship.modifiers.new(name="Decimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
        print(f"Faces after decimation: {len(ship.data.polygons)}")

    # Ensure material roughness/metallic looks great under 3D lighting
    for mat in ship.data.materials:
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    if "Roughness" in node.inputs:
                        node.inputs["Roughness"].default_value = 0.35
                    if "Metallic" in node.inputs:
                        node.inputs["Metallic"].default_value = 0.25

    # Export clean Godot-ready GLB
    # Note: Blender glTF exporter maps Blender +X -> glTF +X, Blender +Z (Up) -> glTF +Y (Up), Blender +Y -> glTF -Z
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    print(f"Exported clean 3D model to {OUT_GLB} ({os.path.getsize(OUT_GLB)} bytes)")


if __name__ == "__main__":
    main()
