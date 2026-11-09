extends SubViewport
class_name PlayerShip3D
## Real-time 3D renderer for the Meshy.ai + Blender player starfighter (`res://assets/models/player_ship.glb`).
## Renders the 3D model in the 2.5D dorsal side-profile perspective, with smooth analog 3D roll/pitch banking,
## GPU shader-driven turbulent 3D afterburner plumes seated in the twin exhaust barrels, 360-degree dodge barrel rolls,
## dynamic Blue Giant solar self-shadowing, and real-time laser/muzzle/projectile hull reflections.

const ThrusterFlameShader = preload("res://assets/shaders/thruster_flame.gdshader")
const EnemyRimHighlightShader = preload("res://assets/shaders/enemy_rim_highlight.gdshader")

var ship_rig: Node3D = null
var ship_model: Node3D = null
var camera_3d: Camera3D = null
var sun_light: DirectionalLight3D = null
var nebula_fill_light: DirectionalLight3D = null
var weapon_lights_3d: Array[OmniLight3D] = []
var rim_material: ShaderMaterial = null

var plume_outer_l: MeshInstance3D = null
var plume_inner_l: MeshInstance3D = null
var plume_outer_r: MeshInstance3D = null
var plume_inner_r: MeshInstance3D = null
var plume_core_mats: Array[ShaderMaterial] = []
var plume_outer_mats: Array[ShaderMaterial] = []
var plume_fallback_core_mats: Array[StandardMaterial3D] = []
var plume_fallback_outer_mats: Array[StandardMaterial3D] = []
var thruster_nozzle_light: OmniLight3D = null
var dodge_ready_blend: float = 1.0
var current_exhaust_core_color: Color = Color(0.94, 1.0, 1.0, 1.0)
var current_exhaust_mid_color: Color = Color(0.14, 0.90, 1.0, 1.0)

var current_roll_deg: float = 26.0
var current_pitch_deg: float = 3.0
var current_yaw_deg: float = 2.0

const BASE_ROLL_DEG: float = 26.0
const BASE_PITCH_DEG: float = 3.0
const BASE_YAW_DEG: float = 2.0


func _init(viewport_size: Vector2i = Vector2i(230, 130)) -> void:
	size = viewport_size
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.14, 0.32)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Orthogonal Camera3D matching the 2.5D side-scroller perspective
	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.size = 1.78
	camera_3d.position = Vector3(-0.16, 0.0, 4.0)
	camera_3d.near = 0.1
	camera_3d.far = 20.0
	add_child(camera_3d)

	# Dynamic Sapphire-White Blue Giant Solar Key Light (orthogonal 3D self-shadows)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 12.0
	sun_light.shadow_bias = 0.015
	sun_light.shadow_normal_bias = 1.1
	sun_light.shadow_blur = 1.4
	sun_light.light_color = Color(0.84, 0.95, 1.0)
	sun_light.light_energy = 2.75
	var default_ray := Vector3(-0.78, -0.45, -0.32).normalized()
	add_child(sun_light)
	sun_light.look_at_from_position(-default_ray * 6.0, Vector3.ZERO, Vector3.UP)

	# Soft cosmic violet-cyan nebula bounce fill
	nebula_fill_light = DirectionalLight3D.new()
	nebula_fill_light.name = "NebulaBounceLight"
	nebula_fill_light.light_color = Color(0.32, 0.28, 0.62)
	nebula_fill_light.light_energy = 0.34
	add_child(nebula_fill_light)
	nebula_fill_light.look_at_from_position(
		Vector3(default_ray.x * 4.0, default_ray.y * 3.0 - 2.0, 3.5),
		Vector3.ZERO,
		Vector3.UP
	)

	# Dual real-time OmniLight3D nodes for live cyan laser muzzle glints & passing enemy projectile reflections
	for i in range(2):
		var wl := OmniLight3D.new()
		wl.name = "WeaponLight%d" % i
		wl.visible = false
		wl.omni_range = 2.5
		wl.omni_attenuation = 1.35
		add_child(wl)
		weapon_lights_3d.append(wl)

	# Parent rig for 3D banking and barrel rolls
	ship_rig = Node3D.new()
	ship_rig.name = "ShipRig"
	add_child(ship_rig)

	# Load the Meshy + Blender 3D player ship (.glb)
	ship_model = GameConfig.instantiate_player_ship_3d()
	if ship_model != null:
		ship_model.name = "PlayerStarfighterModel"
		ship_rig.add_child(ship_model)
		_setup_solar_pbr_and_rim(ship_model, -default_ray)

	# Create 3D twin thruster plumes seated at the rear exit openings of the two exhaust barrels:
	# Blender barrel exits: L=(-0.965, +0.095, -0.028), R=(-0.965, -0.095, -0.062)
	# Godot (X, Z_blender, -Y_blender):
	var port_l := Vector3(-0.965, -0.028, -0.095)
	var port_r := Vector3(-0.965, -0.062, 0.095)

	plume_outer_l = _create_thruster_plume("PlumeOuterL", port_l, 0.072, 0.68, false)
	plume_inner_l = _create_thruster_plume("PlumeInnerL", port_l, 0.042, 0.42, true)
	plume_outer_r = _create_thruster_plume("PlumeOuterR", port_r, 0.072, 0.68, false)
	plume_inner_r = _create_thruster_plume("PlumeInnerR", port_r, 0.042, 0.42, true)

	# Subtle 3D rear nozzle glow light casting live exhaust colour onto the rear stabilizer fins
	thruster_nozzle_light = OmniLight3D.new()
	thruster_nozzle_light.name = "ThrusterNozzleLight"
	thruster_nozzle_light.position = Vector3(-1.04, -0.045, 0.0)
	thruster_nozzle_light.omni_range = 0.78
	thruster_nozzle_light.omni_attenuation = 1.45
	thruster_nozzle_light.light_color = Color(0.14, 0.90, 1.0)
	thruster_nozzle_light.light_energy = 1.05
	ship_rig.add_child(thruster_nozzle_light)

	_apply_exhaust_palette(1.0, 0.0)
	_apply_rig_rotation(BASE_ROLL_DEG, BASE_PITCH_DEG, BASE_YAW_DEG)


func _setup_solar_pbr_and_rim(root_node: Node, initial_sun_dir: Vector3) -> void:
	if EnemyRimHighlightShader != null:
		rim_material = ShaderMaterial.new()
		rim_material.shader = EnemyRimHighlightShader
		rim_material.set_shader_parameter("rim_color", Color(0.72, 0.94, 1.0, 1.0))
		rim_material.set_shader_parameter("rim_power", 3.4)
		rim_material.set_shader_parameter("rim_strength", 0.46)
		rim_material.set_shader_parameter("sun_dir_view", initial_sun_dir)

	_configure_mesh_recursive(root_node)


func _configure_mesh_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s_idx in range(mi.mesh.get_surface_count()):
				var base_mat: Material = mi.mesh.surface_get_material(s_idx)
				if base_mat == null:
					base_mat = mi.get_active_material(s_idx)
				if base_mat is BaseMaterial3D:
					var dup: BaseMaterial3D = base_mat.duplicate()
					dup.roughness = clampf(dup.roughness * 0.68, 0.28, 0.52)
					dup.metallic = clampf(maxf(dup.metallic, 0.28), 0.0, 0.65)
					if rim_material != null:
						dup.next_pass = rim_material
					mi.set_surface_override_material(s_idx, dup)
	for ch in node.get_children():
		_configure_mesh_recursive(ch)


func _create_thruster_plume(node_name: String, nozzle_pos: Vector3, radius: float, length: float, is_core: bool) -> MeshInstance3D:
	var pivot := Node3D.new()
	pivot.name = node_name + "_Pivot"
	pivot.position = nozzle_pos
	ship_rig.add_child(pivot)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.08
	cyl.height = 1.0
	cyl.radial_segments = 24
	cyl.rings = 16
	mesh_inst.mesh = cyl

	# CylinderMesh axis is +Y; rotating -90 deg around Z sends +Y (top) -> +X (nozzle) and -Y (tip) -> -X (exhaust)
	mesh_inst.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	mesh_inst.position = Vector3(-0.5 * length, 0.0, 0.0)
	mesh_inst.scale = Vector3(1.0, length, 1.0)

	if ThrusterFlameShader != null:
		var smat := ShaderMaterial.new()
		smat.shader = ThrusterFlameShader
		if is_core:
			smat.set_shader_parameter("core_color", Color(0.94, 1.0, 1.0, 1.0))
			smat.set_shader_parameter("mid_color", Color(0.14, 0.90, 1.0, 1.0))
			smat.set_shader_parameter("edge_color", Color(0.03, 0.44, 1.0, 1.0))
			smat.set_shader_parameter("flame_speed", 17.0)
			smat.set_shader_parameter("turbulence_strength", 0.38)
			smat.set_shader_parameter("intensity", 1.12)
			plume_core_mats.append(smat)
		else:
			smat.set_shader_parameter("core_color", Color(0.55, 0.97, 1.0, 1.0))
			smat.set_shader_parameter("mid_color", Color(0.06, 0.70, 1.0, 1.0))
			smat.set_shader_parameter("edge_color", Color(0.02, 0.24, 0.95, 1.0))
			smat.set_shader_parameter("flame_speed", 14.0)
			smat.set_shader_parameter("turbulence_strength", 0.65)
			smat.set_shader_parameter("intensity", 1.0)
			plume_outer_mats.append(smat)
		mesh_inst.material_override = smat
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.55, 0.98, 1.0, 0.98) if is_core else Color(0.08, 0.68, 1.0, 0.92)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if is_core:
			plume_fallback_core_mats.append(mat)
		else:
			plume_fallback_outer_mats.append(mat)
		mesh_inst.material_override = mat

	pivot.add_child(mesh_inst)
	return mesh_inst


func _apply_rig_rotation(roll_deg: float, pitch_deg: float, yaw_deg: float) -> void:
	if ship_rig == null:
		return
	var basis := Basis.IDENTITY
	basis = basis.rotated(Vector3(1.0, 0.0, 0.0), deg_to_rad(roll_deg))
	basis = basis.rotated(Vector3(0.0, 0.0, 1.0), deg_to_rad(pitch_deg))
	basis = basis.rotated(Vector3(0.0, 1.0, 0.0), deg_to_rad(yaw_deg))
	ship_rig.basis = basis


func _apply_exhaust_palette(ready_t: float, flash_t: float) -> void:
	var t: float = clampf(ready_t, 0.0, 1.0)
	var f: float = clampf(flash_t, 0.0, 1.0)

	# Cooldown = Warm Thermal Amber-Orange; Dodge Charged = Vivid Electric Cyan-Blue
	var c_core: Color = Color(1.0, 0.96, 0.80, 1.0).lerp(Color(0.96, 1.0, 1.0, 1.0), t)
	var c_mid: Color = Color(1.0, 0.66, 0.10, 1.0).lerp(Color(0.06, 0.95, 1.0, 1.0), t).lerp(Color(0.80, 1.0, 1.0, 1.0), f * 0.45)
	var c_edge: Color = Color(0.98, 0.26, 0.02, 1.0).lerp(Color(0.06, 0.44, 1.0, 1.0), t)

	var o_core: Color = Color(1.0, 0.82, 0.26, 1.0).lerp(Color(0.58, 0.98, 1.0, 1.0), t).lerp(Color(0.92, 1.0, 1.0, 1.0), f * 0.40)
	var o_mid: Color = Color(1.0, 0.34, 0.02, 1.0).lerp(Color(0.04, 0.76, 1.0, 1.0), t)
	var o_edge: Color = Color(0.90, 0.08, 0.01, 1.0).lerp(Color(0.02, 0.28, 0.98, 1.0), t)

	current_exhaust_core_color = c_core
	current_exhaust_mid_color = c_mid

	# Keep intensity around 1.0-1.18 per AGENTS.md so ACES tonemapping preserves saturated gradients
	var core_intensity: float = 1.10 + 0.08 * f
	var outer_intensity: float = 1.00 + 0.12 * f

	for smat in plume_core_mats:
		if smat != null:
			smat.set_shader_parameter("core_color", c_core)
			smat.set_shader_parameter("mid_color", c_mid)
			smat.set_shader_parameter("edge_color", c_edge)
			smat.set_shader_parameter("intensity", core_intensity)
	for smat in plume_outer_mats:
		if smat != null:
			smat.set_shader_parameter("core_color", o_core)
			smat.set_shader_parameter("mid_color", o_mid)
			smat.set_shader_parameter("edge_color", o_edge)
			smat.set_shader_parameter("intensity", outer_intensity)

	for fmat in plume_fallback_core_mats:
		if fmat != null:
			fmat.albedo_color = Color(1.0, 0.90, 0.32, 0.98).lerp(Color(0.55, 0.98, 1.0, 0.98), t)
	for fmat in plume_fallback_outer_mats:
		if fmat != null:
			fmat.albedo_color = Color(1.0, 0.36, 0.04, 0.92).lerp(Color(0.08, 0.68, 1.0, 0.92), t)

	if thruster_nozzle_light != null:
		thruster_nozzle_light.light_color = Color(1.0, 0.46, 0.08).lerp(Color(0.14, 0.90, 1.0), t)
		thruster_nozzle_light.light_energy = 0.95 + 0.15 * t + 0.65 * f


func update_ship_pose(
	dt: float,
	vy: float,
	bank_state: String,
	thrust_state: String,
	anim_timer: float,
	is_dodging: bool = false,
	dodge_progress: float = 0.0,
	dodge_ready: bool = true,
	dodge_ready_flash: float = 0.0
) -> void:
	var bank_t: float = clampf(vy / 240.0, -1.0, 1.0)
	if absf(vy) < 0.01:
		if bank_state == "bank_left":
			bank_t = -0.85
		elif bank_state == "bank_right":
			bank_t = 0.85

	var target_roll: float = BASE_ROLL_DEG + bank_t * 18.0
	var target_pitch: float = BASE_PITCH_DEG - bank_t * 3.5
	var target_yaw: float = BASE_YAW_DEG - bank_t * 4.0

	var interp_speed: float = 1.0 - exp(-12.5 * dt)
	current_roll_deg = lerpf(current_roll_deg, target_roll, interp_speed)
	current_pitch_deg = lerpf(current_pitch_deg, target_pitch, interp_speed)
	current_yaw_deg = lerpf(current_yaw_deg, target_yaw, interp_speed)

	var final_roll: float = current_roll_deg
	if is_dodging:
		final_roll += dodge_progress * 360.0

	_apply_rig_rotation(final_roll, current_pitch_deg, current_yaw_deg)

	# Shift twin 3D thruster exhaust colour between Cooldown Amber-Orange and Charged Electric Cyan-Blue
	var target_ready_blend: float = 1.0 if (dodge_ready or is_dodging) else 0.0
	var flash_t: float = clampf(dodge_ready_flash / 0.32, 0.0, 1.0)
	if flash_t > 0.25:
		dodge_ready_blend = 1.0
	else:
		dodge_ready_blend = lerpf(dodge_ready_blend, target_ready_blend, 1.0 - exp(-16.0 * dt))
	_apply_exhaust_palette(dodge_ready_blend, flash_t)

	# Update 3D twin thruster plumes based on throttle, pulse, and recharge ignition surge
	var base_len: float = 0.68
	var rad_scale: float = 1.0
	if thrust_state == "idle":
		base_len = 0.36
		rad_scale = 0.78
	elif thrust_state == "boost":
		base_len = 1.02
		rad_scale = 1.25

	var charge_len_mult: float = lerpf(0.84, 1.16, dodge_ready_blend)
	var charge_rad_mult: float = lerpf(0.90, 1.12, dodge_ready_blend)
	var surge_len: float = charge_len_mult * (1.0 + 0.26 * flash_t)
	var surge_rad: float = charge_rad_mult * (1.0 + 0.16 * flash_t)
	var pulse: float = 1.0 + 0.14 * sin(anim_timer * 28.0)
	var out_len: float = base_len * pulse * surge_len
	var in_len: float = base_len * 0.68 * (0.9 + 0.2 * pulse) * surge_len

	for p_out in [plume_outer_l, plume_outer_r]:
		if p_out != null:
			p_out.scale = Vector3(rad_scale * pulse * surge_rad, out_len, rad_scale * pulse * surge_rad)
			p_out.position = Vector3(-0.5 * out_len, 0.0, 0.0)
	for p_in in [plume_inner_l, plume_inner_r]:
		if p_in != null:
			p_in.scale = Vector3(rad_scale * pulse * surge_rad, in_len, rad_scale * pulse * surge_rad)
			p_in.position = Vector3(-0.5 * in_len, 0.0, 0.0)


func update_dynamic_lighting(
	ship_screen_pos: Vector2,
	draw_size: Vector2,
	sun_screen_pos: Vector2,
	nearby_lights: Array = []
) -> void:
	var dx: float = clampf((ship_screen_pos.x - sun_screen_pos.x) / 720.0, -1.6, 1.6)
	var dy: float = clampf(-(ship_screen_pos.y - sun_screen_pos.y) / 480.0, -1.6, 1.6)
	if absf(dx) < 0.08 and absf(dy) < 0.08:
		dy = -0.25
	var ray_dir := Vector3(dx, dy, -0.32).normalized()

	if sun_light != null and sun_light.is_inside_tree():
		var screen_dist: float = ship_screen_pos.distance_to(sun_screen_pos) / 1920.0
		var prox_mult: float = lerpf(1.25, 0.86, clampf(screen_dist, 0.0, 1.0))
		sun_light.light_energy = 2.75 * prox_mult
		sun_light.look_at_from_position(-ray_dir * 6.0, Vector3.ZERO, Vector3.UP)

	if nebula_fill_light != null and nebula_fill_light.is_inside_tree():
		nebula_fill_light.look_at_from_position(
			Vector3(ray_dir.x * 4.0, ray_dir.y * 3.0 - 2.0, 3.5),
			Vector3.ZERO,
			Vector3.UP
		)

	if rim_material != null:
		rim_material.set_shader_parameter("sun_dir_view", -ray_dir)

	# Player camera uses KEEP_HEIGHT (camera_3d.size == ortho height in 3D units)
	var cam_h: float = camera_3d.size if camera_3d != null else 1.78
	var cam_x: float = camera_3d.position.x if camera_3d != null else -0.16
	var px_to_3d: float = cam_h / maxf(draw_size.y, 1.0)

	for i in range(weapon_lights_3d.size()):
		var omni: OmniLight3D = weapon_lights_3d[i]
		if omni == null:
			continue
		if i < nearby_lights.size():
			var wl: Dictionary = nearby_lights[i]
			var lpos: Vector2 = wl["pos"]
			var rel_px: Vector2 = lpos - ship_screen_pos
			var x_3d: float = clampf(cam_x + rel_px.x * px_to_3d, -1.9, 1.9)
			var y_3d: float = clampf(-rel_px.y * px_to_3d, -1.4, 1.4)
			var z_3d: float = float(wl.get("z", 0.66))
			var energy: float = float(wl.get("energy", 0.0))
			if energy > 0.03:
				omni.visible = true
				omni.position = Vector3(x_3d, y_3d, z_3d)
				omni.light_color = wl["color"]
				omni.light_energy = energy
				omni.omni_range = float(wl.get("range", 2.5))
			else:
				omni.visible = false
		else:
			omni.visible = false


func has_3d_model() -> bool:
	return ship_model != null
