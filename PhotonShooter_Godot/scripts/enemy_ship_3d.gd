extends SubViewport
class_name EnemyShip3D
## Real-time 3D renderer for the streamlined Option C Meshy.ai + Blender enemy spacecraft:
## - "scout": Compact silver-titanium & gunmetal Scout with crimson V-visor (`res://assets/models/enemy_scout.glb`)
## - "raider": Streamlined crimson-orchid Crescent Gull-Wing Interceptor (`res://assets/models/enemy_raider.glb`)
## - "dreadnought": Streamlined royal-violet Shark-Prow Destroyer (`res://assets/models/boss_dreadnought.glb`)
## - "boss_titan": Colossal streamlined royal-violet Multi-Turret Flagship (`res://assets/models/boss_titan.glb`)
## Includes dynamic Blue Giant solar self-shadowing, sun-gated directional rim light,
## continuous fluid aerodynamic banking, and real-time 3D weapon/laser reflections.

const ThrusterFlameShader = preload("res://assets/shaders/thruster_flame.gdshader")
const EnemyRimHighlightShader = preload("res://assets/shaders/enemy_rim_highlight.gdshader")

var ship_type: String = "scout"
var ship_rig: Node3D = null
var ship_model: Node3D = null
var camera_3d: Camera3D = null
var sun_light: DirectionalLight3D = null
var nebula_fill_light: DirectionalLight3D = null
var core_light: OmniLight3D = null
var weapon_lights_3d: Array[OmniLight3D] = []
var rim_material: ShaderMaterial = null

var plumes_outer: Array[MeshInstance3D] = []
var plumes_inner: Array[MeshInstance3D] = []

var base_roll_deg: float = 18.0
var base_pitch_deg: float = 3.0
var base_yaw_deg: float = 16.0
var base_plume_len: float = 0.56

var current_roll_deg: float = 18.0
var current_pitch_deg: float = 3.0
var current_yaw_deg: float = 16.0


func _init(p_type: String = "scout", viewport_size: Vector2i = Vector2i(136, 100)) -> void:
	ship_type = p_type
	size = viewport_size
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

	match ship_type:
		"scout":
			base_roll_deg = 18.0
			base_pitch_deg = 4.0
			base_yaw_deg = 32.0
			base_plume_len = 0.72
		"raider":
			base_roll_deg = 22.0
			base_pitch_deg = 4.0
			base_yaw_deg = 26.0
			base_plume_len = 0.72
		"dreadnought":
			base_roll_deg = 18.0
			base_pitch_deg = 3.0
			base_yaw_deg = 16.0
			base_plume_len = 0.58
		"boss_titan":
			base_roll_deg = 20.0
			base_pitch_deg = 3.0
			base_yaw_deg = 16.0
			base_plume_len = 0.60

	current_roll_deg = base_roll_deg
	current_pitch_deg = base_pitch_deg
	current_yaw_deg = base_yaw_deg


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.17, 0.09, 0.28)
	env.ambient_light_energy = 0.14
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.04

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.keep_aspect = Camera3D.KEEP_WIDTH
	match ship_type:
		"scout":
			camera_3d.size = 2.68
			camera_3d.position = Vector3(0.20, 0.0, 4.0)
		"raider":
			camera_3d.size = 3.12
			camera_3d.position = Vector3(0.26, 0.0, 4.0)
		"dreadnought":
			camera_3d.size = 2.74
			camera_3d.position = Vector3(0.24, 0.0, 4.0)
		"boss_titan":
			camera_3d.size = 2.86
			camera_3d.position = Vector3(0.26, 0.0, 4.0)
		_:
			camera_3d.size = 2.60
			camera_3d.position = Vector3(0.15, 0.0, 4.0)
	camera_3d.near = 0.1
	camera_3d.far = 20.0
	add_child(camera_3d)

	# Dynamic Sapphire-White Blue Giant Solar Light (real orthogonal 3D self-shadows)
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 12.0
	sun_light.shadow_bias = 0.015
	sun_light.shadow_normal_bias = 1.1
	sun_light.shadow_blur = 1.4
	sun_light.light_color = Color(0.82, 0.94, 1.0)
	sun_light.light_energy = 2.85
	var default_ray := Vector3(-0.62, -0.50, -0.32).normalized()
	add_child(sun_light)
	sun_light.look_at_from_position(-default_ray * 6.0, Vector3.ZERO, Vector3.UP)

	# Opposite-side soft cosmic violet nebula bounce fill so shadowed side blends naturally into space
	nebula_fill_light = DirectionalLight3D.new()
	nebula_fill_light.name = "NebulaBounceLight"
	nebula_fill_light.light_color = Color(0.40, 0.15, 0.50)
	nebula_fill_light.light_energy = 0.26
	add_child(nebula_fill_light)
	nebula_fill_light.look_at_from_position(
		Vector3(default_ray.x * 4.0, default_ray.y * 3.0 - 2.0, 3.5),
		Vector3.ZERO,
		Vector3.UP
	)

	# Dual real-time 3D OmniLight3D nodes for live Photon Plasma Lance, Torpedo & Blast hull reflections
	for i in range(2):
		var wl := OmniLight3D.new()
		wl.name = "WeaponLight%d" % i
		wl.visible = false
		wl.omni_range = 2.6
		wl.omni_attenuation = 1.35
		add_child(wl)
		weapon_lights_3d.append(wl)

	ship_rig = Node3D.new()
	ship_rig.name = "EnemyShipRig"
	add_child(ship_rig)

	ship_model = GameConfig.instantiate_enemy_ship_3d(ship_type)
	if ship_model != null:
		ship_model.name = "EnemyModel_" + ship_type
		ship_rig.add_child(ship_model)
		_setup_solar_pbr_and_rim(ship_model, -default_ray)

	# Tight accent OmniLight3D strictly for Scout visor & Raider energy orb
	if ship_type in ["scout", "raider"]:
		core_light = OmniLight3D.new()
		core_light.name = "CoreGlowLight"
		core_light.position = Vector3(-0.76, 0.02, 0.18)
		core_light.omni_range = 0.44
		core_light.light_color = Color(1.0, 0.16, 0.22) if ship_type == "scout" else Color(0.95, 0.28, 1.0)
		core_light.light_energy = 0.48
		ship_rig.add_child(core_light)

	_setup_thruster_plumes()
	_apply_rig_rotation(base_roll_deg, base_pitch_deg, base_yaw_deg)


func _setup_solar_pbr_and_rim(root_node: Node, initial_sun_dir: Vector3) -> void:
	if EnemyRimHighlightShader != null:
		rim_material = ShaderMaterial.new()
		rim_material.shader = EnemyRimHighlightShader
		rim_material.set_shader_parameter("rim_color", Color(0.68, 0.92, 1.0, 1.0))
		rim_material.set_shader_parameter("rim_power", 3.3)
		rim_material.set_shader_parameter("rim_strength", 0.56)
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
					dup.roughness = clampf(dup.roughness * 0.65, 0.28, 0.50)
					dup.metallic = clampf(maxf(dup.metallic, 0.30), 0.0, 0.65)
					if ship_type == "raider":
						# Preserve rich orchid-magenta hue while allowing shadow facets to sink into deep cosmic plum
						dup.albedo_color = Color(0.95, 0.86, 1.0, 1.0)
					if rim_material != null:
						dup.next_pass = rim_material
					mi.set_surface_override_material(s_idx, dup)
	for ch in node.get_children():
		_configure_mesh_recursive(ch)


func _setup_thruster_plumes() -> void:
	# Exact Blender-measured rear (+X) exhaust nozzle positions mapped via Vector3(x_b, z_b, -y_b)
	var ports: Array[Vector3] = []
	var rad: float = 0.074

	match ship_type:
		"scout":
			ports = [
				Vector3(0.68, 0.101, 0.201),
				Vector3(0.68, 0.101, -0.200),
			]
			rad = 0.074
		"raider":
			ports = [
				Vector3(0.97, -0.090, 0.210),
				Vector3(0.97, -0.090, -0.210),
			]
			rad = 0.082
		"dreadnought":
			ports = [
				Vector3(0.95, 0.059, 0.205),
				Vector3(0.95, 0.108, -0.152),
				Vector3(0.95, -0.116, 0.216),
				Vector3(0.95, -0.114, -0.181),
			]
			rad = 0.080
		"boss_titan":
			ports = [
				Vector3(1.06, 0.029, 0.228),
				Vector3(1.06, 0.024, 0.080),
				Vector3(1.06, 0.024, -0.068),
				Vector3(1.06, 0.024, -0.222),
				Vector3(1.06, -0.098, 0.228),
				Vector3(1.06, -0.098, 0.080),
				Vector3(1.06, -0.098, -0.073),
				Vector3(1.06, -0.098, -0.224),
			]
			rad = 0.070

	for idx in range(ports.size()):
		var p_out := _create_plume("PlumeOuter_%d" % idx, ports[idx], rad, base_plume_len, false)
		var p_in := _create_plume("PlumeInner_%d" % idx, ports[idx], rad * 0.58, base_plume_len * 0.65, true)
		plumes_outer.append(p_out)
		plumes_inner.append(p_in)


func _create_plume(node_name: String, nozzle_pos: Vector3, radius: float, length: float, is_core: bool) -> MeshInstance3D:
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
	cyl.radial_segments = 20
	cyl.rings = 12
	mesh_inst.mesh = cyl

	mesh_inst.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	mesh_inst.position = Vector3(0.5 * length, 0.0, 0.0)
	mesh_inst.scale = Vector3(1.0, length, 1.0)

	if ThrusterFlameShader != null:
		var smat := ShaderMaterial.new()
		smat.shader = ThrusterFlameShader
		if ship_type == "scout":
			if is_core:
				smat.set_shader_parameter("core_color", Color(0.92, 0.99, 1.0, 1.0))
				smat.set_shader_parameter("mid_color", Color(0.20, 0.88, 1.0, 1.0))
				smat.set_shader_parameter("edge_color", Color(0.05, 0.42, 0.95, 1.0))
			else:
				smat.set_shader_parameter("core_color", Color(0.45, 0.95, 1.0, 1.0))
				smat.set_shader_parameter("mid_color", Color(0.08, 0.58, 1.0, 1.0))
				smat.set_shader_parameter("edge_color", Color(0.02, 0.22, 0.85, 1.0))
		else:
			if is_core:
				smat.set_shader_parameter("core_color", Color(1.0, 0.94, 1.0, 1.0))
				smat.set_shader_parameter("mid_color", Color(0.96, 0.38, 1.0, 1.0))
				smat.set_shader_parameter("edge_color", Color(0.68, 0.12, 0.95, 1.0))
			else:
				smat.set_shader_parameter("core_color", Color(1.0, 0.55, 0.98, 1.0))
				smat.set_shader_parameter("mid_color", Color(0.85, 0.16, 0.88, 1.0))
				smat.set_shader_parameter("edge_color", Color(0.45, 0.05, 0.78, 1.0))
		smat.set_shader_parameter("flame_speed", 16.0 if is_core else 13.0)
		smat.set_shader_parameter("turbulence_strength", 0.35 if is_core else 0.60)
		smat.set_shader_parameter("intensity", 1.1 if is_core else 1.0)
		mesh_inst.material_override = smat

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


func reset_pose_for_spawn(initial_vy: float = 0.0, vy_full_bank: float = 115.0) -> void:
	var bank_t: float = clampf(initial_vy / maxf(40.0, vy_full_bank), -1.0, 1.0)
	if ship_type == "raider":
		current_roll_deg = base_roll_deg + bank_t * 26.0
		current_pitch_deg = base_pitch_deg + bank_t * 7.5
		current_yaw_deg = base_yaw_deg + bank_t * 6.0
	elif ship_type == "scout":
		current_roll_deg = base_roll_deg + bank_t * 18.0
		current_pitch_deg = base_pitch_deg + bank_t * 5.0
		current_yaw_deg = base_yaw_deg + bank_t * 4.5
	else:
		current_roll_deg = base_roll_deg
		current_pitch_deg = base_pitch_deg
		current_yaw_deg = base_yaw_deg
	_apply_rig_rotation(current_roll_deg, current_pitch_deg, current_yaw_deg)


func update_pose(
	dt: float,
	vy: float,
	bank_state: String,
	anim_timer: float,
	is_charging_or_firing: bool = false,
	is_boosting: bool = false,
	vy_full_bank: float = 115.0
) -> void:
	var bank_t: float = clampf(vy / maxf(40.0, vy_full_bank), -1.0, 1.0)
	if absf(vy) < 0.01:
		if bank_state == "bank_left":
			bank_t = -0.85
		elif bank_state == "bank_right":
			bank_t = 0.85

	var idle_sway_r: float = sin(anim_timer * 2.2) * 2.2 * (1.0 - absf(bank_t))
	var idle_sway_p: float = cos(anim_timer * 1.7) * 1.2 * (1.0 - absf(bank_t))

	var target_roll: float = base_roll_deg
	var target_pitch: float = base_pitch_deg
	var target_yaw: float = base_yaw_deg

	if ship_type == "raider":
		# Continuous fluid 52-degree aerodynamic roll arc + pitch/yaw turn lead
		target_roll = base_roll_deg + bank_t * 26.0 + idle_sway_r
		target_pitch = base_pitch_deg + bank_t * 7.5 + idle_sway_p
		target_yaw = base_yaw_deg + bank_t * 6.0
	elif ship_type == "scout":
		target_roll = base_roll_deg + bank_t * 18.0 + idle_sway_r
		target_pitch = base_pitch_deg + bank_t * 5.0 + idle_sway_p
		target_yaw = base_yaw_deg + bank_t * 4.5
	else:
		var cap_t: float = clampf(vy / 220.0, -1.0, 1.0)
		target_roll = base_roll_deg + cap_t * 6.5 + sin(anim_timer * 1.4) * 1.8
		target_pitch = base_pitch_deg + cap_t * 2.2 + cos(anim_timer * 1.1) * 1.0
		target_yaw = base_yaw_deg

	var interp: float = 1.0 - exp(-11.5 * dt)
	current_roll_deg = lerpf(current_roll_deg, target_roll, interp)
	current_pitch_deg = lerpf(current_pitch_deg, target_pitch, interp)
	current_yaw_deg = lerpf(current_yaw_deg, target_yaw, interp)

	_apply_rig_rotation(current_roll_deg, current_pitch_deg, current_yaw_deg)

	if core_light != null:
		var base_e: float = 0.72 if is_charging_or_firing else 0.45
		core_light.light_energy = base_e + 0.12 * sin(anim_timer * 16.0)

	var base_len: float = base_plume_len
	var rad_scale: float = 1.0
	if is_boosting:
		base_len = base_plume_len * 1.55
		rad_scale = 1.26
	elif is_charging_or_firing:
		base_len = base_plume_len * 0.78
		rad_scale = 0.92

	var pulse: float = 1.0 + 0.14 * sin(anim_timer * 26.0)
	var out_len: float = base_len * pulse
	var in_len: float = base_len * 0.65 * (0.9 + 0.2 * pulse)

	for p_out in plumes_outer:
		if p_out != null:
			p_out.scale = Vector3(rad_scale * pulse, out_len, rad_scale * pulse)
			p_out.position = Vector3(0.5 * out_len, 0.0, 0.0)
	for p_in in plumes_inner:
		if p_in != null:
			p_in.scale = Vector3(rad_scale * pulse, in_len, rad_scale * pulse)
			p_in.position = Vector3(0.5 * in_len, 0.0, 0.0)


func update_dynamic_lighting(
	ship_screen_pos: Vector2,
	draw_size: Vector2,
	sun_screen_pos: Vector2,
	nearby_lights: Array = []
) -> void:
	# 1. Dynamic Sun -> Ship 3D ray vector from Blue Giant screen position
	var dx: float = clampf((ship_screen_pos.x - sun_screen_pos.x) / 720.0, -1.6, 1.6)
	var dy: float = clampf(-(ship_screen_pos.y - sun_screen_pos.y) / 480.0, -1.6, 1.6)
	if absf(dx) < 0.08 and absf(dy) < 0.08:
		dy = -0.25
	var ray_dir := Vector3(dx, dy, -0.32).normalized()

	if sun_light != null and sun_light.is_inside_tree():
		var screen_dist: float = ship_screen_pos.distance_to(sun_screen_pos) / 1920.0
		var prox_mult: float = lerpf(1.25, 0.86, clampf(screen_dist, 0.0, 1.0))
		sun_light.light_energy = 2.85 * prox_mult
		sun_light.look_at_from_position(-ray_dir * 6.0, Vector3.ZERO, Vector3.UP)

	if nebula_fill_light != null and nebula_fill_light.is_inside_tree():
		nebula_fill_light.look_at_from_position(
			Vector3(ray_dir.x * 4.0, ray_dir.y * 3.0 - 2.0, 3.5),
			Vector3.ZERO,
			Vector3.UP
		)

	if rim_material != null:
		rim_material.set_shader_parameter("sun_dir_view", -ray_dir)

	# 2. Real-time 3D reflections from passing Photon Plasma Lances, Torpedoes & Blasts
	var cam_w: float = camera_3d.size if camera_3d != null else 2.8
	var cam_x: float = camera_3d.position.x if camera_3d != null else 0.24
	var px_to_3d: float = cam_w / maxf(draw_size.x, 1.0)

	for i in range(weapon_lights_3d.size()):
		var omni: OmniLight3D = weapon_lights_3d[i]
		if omni == null:
			continue
		if i < nearby_lights.size():
			var wl: Dictionary = nearby_lights[i]
			var lpos: Vector2 = wl["pos"]
			var rel_px: Vector2 = lpos - ship_screen_pos
			var x_3d: float = clampf(cam_x + rel_px.x * px_to_3d, -2.2, 2.2)
			var y_3d: float = clampf(-rel_px.y * px_to_3d, -1.6, 1.6)
			var z_3d: float = float(wl.get("z", 0.68))
			var energy: float = float(wl.get("energy", 0.0))
			if energy > 0.03:
				omni.visible = true
				omni.position = Vector3(x_3d, y_3d, z_3d)
				omni.light_color = wl["color"]
				omni.light_energy = energy
				omni.omni_range = float(wl.get("range", 2.6))
			else:
				omni.visible = false
		else:
			omni.visible = false


func has_3d_model() -> bool:
	return ship_model != null
